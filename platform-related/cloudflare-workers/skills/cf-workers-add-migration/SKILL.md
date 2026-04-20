---
name: cf-workers-add-migration
description: |
  Apply D1 migration via wrangler migrations system. Use quando: "add d1 migration", "nova migration cloudflare", "wrangler migration", "d1 migration", "criar migration d1". Tambem quando: criar/alterar tabelas D1, adicionar indice, seed data. NAO use quando: migrating PostgreSQL (use go-add-migration), operacao via API REST (use cf-api-call).
allowed-tools:
  - Read
  - Bash
  - Glob
  - Grep
---

# Cloudflare Workers — Add D1 Migration

Aplica migrations SQL em banco D1 via sistema nativo do Wrangler. Cria arquivos
versionados com timestamp, aplica localmente para teste, e entao faz deploy
para producao com validacao previa.

## Trigger Phrases

- "add d1 migration"
- "nova migration cloudflare"
- "wrangler migration"
- "d1 migration"
- "criar migration d1"
- "alterar tabela d1"

## Pre-Flight Checks

Antes de iniciar, leia:

1. **wrangler.toml** — identificar database binding e ambiente atual
   ```bash
   grep -E "d1_|binding" wrangler.toml | head -20
   ```
2. **Migrations existentes** — ver estrutura e ultimo timestamp
   ```bash
   ls -la *.sql 2>/dev/null | head -10 || ls -la d1/migrations/ 2>/dev/null | head -10
   ```
3. **D1 bind no codigo** — procurar uso de `env.DB` ou similar
   ```bash
   grep -rn "env\." --include="*.ts" src/ | grep -E "d1|db|D1" | head -10
   ```

## Workflow

### Passo 1 — Criar migration vazia

```bash
wrangler d1 migrations create <DB_NAME> <migration_name>
```

Exemplo:
```bash
wrangler d1 migrations create minha-db add_users_table
```

O Wrangler gera arquivo:
```
migrations/
  0001_add_users_table.sql
```

O prefixo `0001_` eh gerado automaticamente pelo Wrangler (nao manual).

### Passo 2 — Editar SQL da migration

Abrir o arquivo gerado e escrever SQL idempotente:

```sql
-- 0001: Add users table
CREATE TABLE IF NOT EXISTS users (
    id      TEXT PRIMARY KEY,
    email   TEXT NOT NULL UNIQUE,
    name    TEXT,
    created_at TEXT DEFAULT (strftime('%s', 'now'))
);

CREATE INDEX IF NOT EXISTS idx_users_email ON users(email);
```

**Regras SQL**:
- Sempre `CREATE TABLE IF NOT EXISTS` e `CREATE INDEX IF NOT EXISTS`
- Coluna id: TEXT com UUID (gerado na aplicacao, nao auto-increment)
- Timestamps: usar `strftime('%s', 'now')` para Unix epoch (D1 nao tem TIMESTAMP)
- Batch DDL: envolver em `BEGIN; ... COMMIT;` para multiplas mudancas

### Passo 3 — Aplicar localmente e testar

```bash
# Aplicar migration local
wrangler d1 migrations apply <DB_NAME> --local

# Verificar schema
wrangler d1 execute <DB_NAME> --local --command="SELECT name FROM sqlite_master WHERE type='table';"

# Seed data se necessario
wrangler d1 execute <DB_NAME> --local --command="INSERT INTO users (id, email, name) VALUES ('...', '...', '...');"
```

### Passo 4 — Aplicar em producao

```bash
# Deploy migration (producao)
wrangler d1 migrations apply <DB_NAME> --remote

# Verificar
wrangler d1 migrations list <DB_NAME> --remote
```

## Exemplo: Multi-tenant com prefixo

Para projetos multi-tenant, Prefixe todas as tabelas:

```sql
-- 0002: Add tenant_projects table
BEGIN;
CREATE TABLE IF NOT EXISTS tenant_projects (
    id         TEXT PRIMARY KEY,
    tenant_id  TEXT NOT NULL,
    name       TEXT NOT NULL,
    created_at TEXT DEFAULT (strftime('%s', 'now'))
);
CREATE INDEX IF NOT EXISTS idx_tenant_projects_tenant ON tenant_projects(tenant_id);
COMMIT;
```

## Exemplo: Wrangler.toml binding

```toml
name = "my-worker"
main = "src/index.ts"

[observability]
enabled = true

# Binding D1 — nome em uppercase para acesso via env.X
[[d1_databases]]
binding = "DB"           # acesso: env.DB
database_name = "minha-db"
database_id = "abc123..."

[[d1_databases]]
binding = "AUDIT_DB"     # acesso: env.AUDIT_DB
database_name = "audit-db"
database_id = "def456..."
```

Acessar no codigo TypeScript:
```typescript
export default {
    async fetch(request: Request, env: Env): Promise<Response> {
        const users = await env.DB
            .prepare("SELECT * FROM users WHERE email = ?")
            .bind(email)
            .first();
        return Response.json(users);
    }
}
```

## Exemplo Ruim (EVITAR)

```sql
-- EVITAR: migration sem idempotencia
DROP TABLE users;           -- falha se tabela nao existe
CREATE TABLE users (...);   -- nao verifica se ja existe

-- EVITAR: timestamp como ISO string
created_at TEXT DEFAULT '2024-01-01'  -- mal-formatado, nao compativel com sort

-- EVITAR: batch sem transacao
CREATE TABLE a (...);
CREATE TABLE b (...);      -- se b falhar, a ja foi criada
```

## Gotchas

1. **Timestamp prefix obrigatorio**: Wrangler exige prefixo numerico
   (`0001_`, `0002_`). Nao renomear manualmente.

2. **Sem rollback nativo**: D1 nao suporta `down` migrations. Se precisar
   reverter, crie migration reversa manual (ex: `DROP INDEX` se criou index,
   `DROP TABLE` se dropar tabela).

3. **Teste SQL com seed local**: Sempre valide SQL localmente antes de
   aplicar em prod. D1 SQLite tem limitacoes especificas.

4. **Max query CPU 1000ms**: Queries podem falhar com timeout em queries
   complexas. Use indices apropriados e evite full table scans.

5. **Batch DDL com transacao**: Para multiplas alteracoes, use
   `BEGIN; ... COMMIT;`. Sem isso, uma falha nao impede as outras.

6. **Prefixo multi-tenant**: Em apps multi-tenant, prefixe todas as tabelas
   com identificador do tenant (ex: `tenant_projects`, nao `projects`).

7. **Variaveis de ambiente nao suportadas**: SQL migrations nao suportam
   interpolacao de env vars. Hardcode valores ou use application-level seeds.

## Quando NAO usar

- **Migration PostgreSQL** → use `language-related/go/skills/go-add-migration`
- **Operacao via API REST** → use `platform-related/cloudflare-shared/skills/cf-api-call`
- **Query de dados** → use `data-related/d1/skills/d1-query-optimization`
- **Criacao de banco D1** → use `cf-workers-create-d1`

## Ver tambem

- [`language-related/typescript/skills/ts-add-migration/`](../../../language-related/typescript/skills/ts-add-migration/) — **GERAR** arquivo de migration via Drizzle (use ANTES desta skill)
- [`platform-related/cloudflare-workers/skills/cf-workers-create-d1/`](./cf-workers-create-d1/) — criar banco D1
- [`data-related/d1/`](../../../data-related/d1/) — padroes de query e otimizacao
- [`global/skills/cred-store/`](../../../global/skills/cred-store/) — gerenciamento de credenciais

Workflow tipico:
1. `ts-add-migration` → gera arquivo SQL via Drizzle
2. `cf-workers-add-migration` (esta skill) → aplica no D1 local + producao
