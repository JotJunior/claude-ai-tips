---
name: cf-workers-create-d1
description: |
  Use quando precisar criar um novo database D1 do zero (wrangler d1 create),
  alem de ja ter o binding configurado e a primeira migration aplicada.
  Tambem quando mencionar "create d1", "novo d1 database", "setup d1", "init d1",
  "criar banco d1", "primeira migration d1", "wrangler d1 create". Foco em
  provisionamento do recurso + estrutura de migrations — NAO em queries SQL
  ou patterns de consumo (ver data-related/d1). Para adicionar binding ao
  Worker veja cf-workers-add-binding.
allowed-tools:
  - Read
  - Bash
  - Glob
  - Grep
---

# Cloudflare Workers: Criar D1 Database

Cria um novo database SQLite via D1, configura o binding no `wrangler.toml`,
e aplica a primeira migration. D1 usa SQLite com algumas limitacoes
especificas da plataforma.

## Pre-Flight Reads

1. **`wrangler.toml`** atual — verificar secao `[[d1_databases]]` existente
2. **`wrangler.toml`** — localizar `name` do Worker e `compatibility_date`
3. **`migrations/`** se existir — identificar proximo numero de migration
4. **`wrangler d1 list`** — confirmar que database ainda nao existe
5. **`src/index.ts`** ou codigo existente — verificar interface `Env` com `DB`

## Workflow: Criar D1 e Primeira Migration

### Passo 1 — Criar o database local e remote

```bash
# Criar local (instantaneo, sem custo)
wrangler d1 create auth-db --local

# OU criar remote (provisiona na edge, pode levar ate 30s)
wrangler d1 create auth-db --remote

# Output contem:
# database_name: auth-db
# database_id: f2a8c4d1-5e3b-4a9c-8d7f-1234567890ab
```

Copie o `database_id` outputado.

### Passo 2 — Adicionar binding ao wrangler.toml

```toml
name = "my-worker"
main = "src/index.ts"
compatibility_date = "2024-01-01"

[[d1_databases]]
  binding = "DB"
  database_name = "auth-db"
  database_id = "f2a8c4d1-5e3b-4a9c-8d7f-1234567890ab"
  # preview_id = "local-uuid"  # se criou local, especifice para dev
```

### Passo 3 — Criar estrutura de migrations

```bash
mkdir -p migrations

# Primeira migration: 0001_init.sql
cat > migrations/0001_init.sql <<'SQLEOF'
-- Migration: 0001_init
-- Description: create users and sessions tables

BEGIN;

CREATE TABLE IF NOT EXISTS users (
    id TEXT PRIMARY KEY,
    email TEXT NOT NULL UNIQUE,
    password_hash TEXT NOT NULL,
    created_at INTEGER NOT NULL DEFAULT (unixepoch()),
    updated_at INTEGER
);

CREATE TABLE IF NOT EXISTS sessions (
    id TEXT PRIMARY KEY,
    user_id TEXT NOT NULL,
    expires_at INTEGER NOT NULL,
    created_at INTEGER NOT NULL DEFAULT (unixepoch()),
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
);

CREATE INDEX IF NOT EXISTS idx_sessions_user_id ON sessions(user_id);
CREATE INDEX IF NOT EXISTS idx_sessions_expires_at ON sessions(expires_at);

COMMIT;
SQLEOF
```

### Passo 4 — Aplicar migration localmente

```bash
# Aplicar no database local (wrangler dev usa este)
wrangler d1 migrations apply auth-db --local

# OU se criou com --local explicitamente
wrangler d1 migrations apply auth-db --local --force  # --force para recriar
```

Verificar que tabelas foram criadas:

```bash
wrangler d1 execute auth-db --local --command ".tables"
# Output esperado: users, sessions
```

### Passo 5 — Aplicar migration no remote (production)

```bash
wrangler d1 migrations apply auth-db --remote

# Primeira vez pode pedir confirmacao
# Type "yes" to confirm
```

### Passo 6 — Gerar tipos e atualizar interface

```bash
wrangler types
```

```typescript
// worker-configuration.d.ts gerado automaticamente
interface Env {
  DB: D1Database;
}
```

## Formato de Migration

```sql
-- 0001_init.sql
-- Migration description (obrigatorio — ajuda em audits)

BEGIN;

-- Suas alteracoes aqui
CREATE TABLE IF NOT EXISTS example (...);
CREATE INDEX IF NOT EXISTS idx_... ON ...;

COMMIT;
```

**Regras de formato:**
- Numeracao: zero-padded 4 digitos (`0001`, `0002`, ... `9999`)
- Sempre usar `BEGIN` / `COMMIT` (transactions)
- `IF NOT EXISTS` em tudo (idempotencia)
- Usar `unixepoch()` para timestamps (nao `NOW()` que tem precision diferente)
- Colunas de auditoria: `created_at INTEGER`, `updated_at INTEGER` (epoch)

## Exemplo BOM

```toml
# wrangler.toml
[[d1_databases]]
  binding = "DB"
  database_name = "auth-db"
  database_id = "f2a8c4d1-5e3b-4a9c-8d7f-1234567890ab"
```

```sql
-- migrations/0002_add_status.sql
BEGIN;

ALTER TABLE users ADD COLUMN status TEXT NOT NULL DEFAULT 'active';

COMMIT;
```

```typescript
// src/index.ts
export interface Env {
  DB: D1Database;
}

export default {
  async fetch(request: Request, env: Env): Promise<Response> {
    // Exemplo de query
    const user = await env.DB
      .prepare("SELECT * FROM users WHERE email = ?")
      .bind(email)
      .first();

    if (!user) {
      return new Response("User not found", { status: 404 });
    }

    return Response.json(user);
  },
};
```

## Exemplo RUIM

```sql
-- WRONG: sem transaction
CREATE TABLE users (...);  -- Missing BEGIN/COMMIT

-- WRONG: ALTER COLUMN sem suporte (D1 SQLite < 3.35)
ALTER TABLE users ALTER COLUMN email TEXT;  -- INVALIDO em D1

-- WRONG: timestamp com NOW() em vez de unixepoch()
CREATE TABLE users (
    created_at INTEGER NOT NULL DEFAULT NOW()  -- WRONG
);

-- WRONG: nao usar IF NOT EXISTS (erro em re-run)
CREATE TABLE users (...);  -- Fails on second run
```

## Gotchas

### 1. SQLite limitations — sem ALTER COLUMN antes 3.35

D1 roda SQLite 3.35+ (suporta `ALTER TABLE ADD COLUMN`), mas **NAO suporta**
`ALTER COLUMN` para renomear ou modificar tipo de coluna existente.workaround:
criar nova tabela, migrar dados, deletar a antiga. Nao tente `ALTER COLUMN`
direto.

### 2. Max database size: 10GB

D1 tem limite hard de 10GB por database. Para dados que crescem muito,
considere particao via multiplos databases (um por dominio/contexto).

### 3. Max query CPU time: 1000ms

Queries que excedem 1 segundo de CPU recebem erro `D1_REQUEST_TIMEOUT`.
Otimize com indexes, evite full table scans, use `EXPLAIN` para debugar.

### 4. Batch vs prepare().bind().all()

```typescript
// Modo recomendado para multiplas queries
const stmt = env.DB.prepare("SELECT * FROM users WHERE id = ?");
const result = await stmt.bind(userId).first();

// Modo batch (transacao automatica, mais lento)
const batch = await env.DB
  .prepare("INSERT INTO users (id, email) VALUES (?, ?)")
  .bind(id, email)
  .run();
```

### 5. Local DB em .wrangler/state/v3/d1

O D1 local nao usa SQLite em memoria — ele persiste em
`.wrangler/state/v3/d1/<uuid>.sqlite`. Se voce commitar esse arquivo,
ele sera versionado. Para干净的 local dev, delete o arquivo e rode
migrations novamente.

### 6. Foreign keys desabilitados por default em batches

Batches (`prepare().bind().run()`) desabilitam foreign key enforcement por
default. Para garantir FK checks, use transactions explcitas:

```typescript
await env.DB.exec("BEGIN IMMEDIATE");
try {
  await env.DB.exec("INSERT INTO users ...");
  await env.DB.exec("INSERT INTO sessions ...");
  await env.DB.exec("COMMIT");
} catch (e) {
  await env.DB.exec("ROLLBACK");
  throw e;
}
```

### 7. D1 nao suporta boolean como tipo nativo

Booleans sao armazenados como INTEGER (0/1). Queries que esperam `WHERE active = true`
devem usar `WHERE active = 1`. Isso pode surpreender se voce vem de Postgres.

## Quando NAO Usar

- **Queries complexas com JOINs pesados** — D1 tem limite de CPU; use
  Postgres (Neon) para queries analiticas
- **Dados que ultrapassam 10GB** — D1 nao faz sharding automatico
- **Full-text search avancado** — use D1 com FTS5 (data-related/d1/)
- **Operacoes que requerem transactions ACID completas** — D1 transactions
  podem ser eventualmente consistentes; para financial data, considere
  Postgres
- **Multi-region writes sincronos** — D1 writes vao para uma regiao primaria;
  para writes distribuidos, Postgres (Neon) com read replicas
- **Adicionar binding sem criar database** — use `cf-workers-add-binding`
