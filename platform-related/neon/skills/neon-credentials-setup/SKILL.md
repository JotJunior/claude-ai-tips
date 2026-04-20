---
name: neon-credentials-setup
description: Configura credenciais do Neon (NEON_API_KEY, NEON_PROJECT_ID, DATABASE_URL) em .env. Use quando mencionar "setup neon", "configurar neon", "neon credentials", "neon api key". Tambem para "neon env", "neon connection string", "neon configure". Nao use para operacoes de provisionamento (use neon-create-project) ou migracoes.
allowed-tools:
  - Read
  - Glob
  - Grep
  - Bash
---

# Neon Credentials Setup

Configura as credenciais do Neon Postgres serverless em `.env` seguindo as praticas de seguranca obrigatorias: nunca commitar secrets, separar ambientes, usar connection pooler para serverless.

## Condicoes de Execucao

**Use quando**:
- Primeiro setup do projeto com Neon
- Adicionar novo ambiente (dev/staging/prod)
- Rotacionar API key
- Configurar connection strings

**Nao use quando**:
- Criar project/branch/endpoint (use `neon-create-project` ou `neon-create-branch`)
- Executar migracoes (config ja deve existir)
- Operacoes de merge de branch (use `neon-merge-branch`)

## Pre-Flight Checks

1. Verificar se `neonctl` esta instalado e autenticado:
```bash
neonctl auth status
```

2. Verificar se o projeto ja tem `.env` ou `.env.example`:
```bash
ls -la .env* 2>/dev/null || echo "Nenhum .env encontrado"
```

3. Verificar se ha `gitignored` adequado para `.env`:
```bash
grep -q "\.env" .gitignore 2>/dev/null || echo "ATENCAO: .env nao esta no gitignore"
```

## Variaveis Obrigatorias

| Variavel | Descricao | Exemplo |
|----------|-----------|---------|
| `NEON_API_KEY` | Chave da API Neon (console.neon.tech/app/settings/api-keys) | `ntoy_...` |
| `NEON_PROJECT_ID` | ID do project (formato `soft-hour-...`) | `soft-hour-12345678` |
| `DATABASE_URL` | Connection string completa (pooled, para serverless) | `postgres://user:pass@ep-xxx-pooler.region.neon.tech/db?sslmode=require` |

## Variaveis Opcionais

| Variavel | Descricao | Quando Usar |
|----------|-----------|-------------|
| `DIRECT_URL` | Connection string unpooled (migrations, manutencao) | Quando migracoes falham com pooler |
| `NEON_BRANCH_ID` | ID da branch ativa (auto-setado em branch efemeras) | Dev/test isolated |

## Workflow

### Passo 1: Obter API Key

1. Acessar https://console.neon.tech/app/settings/api-keys
2. Clicar em "Generate new key"
3. Selecionar funcao minima necessaria (Read-only para observabilidade, Full para operacoes)
4. **NUNCA** usar chave com permissao maior que o necessario
5. Copiar a chave IMEDIATAMENTE (so aparece uma vez)

### Passo 2: Adicionar ao .env (gitignored)

```bash
# .env (NUNCA commitar)
NEON_API_KEY=ntoy_xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx

# .env.example (OK commitar - sem valores reais)
NEON_API_KEY=your_neon_api_key_here
```

### Passo 3: Registrar no 1Password/Vault (opcional mas recomendado)

```bash
# Registrar via cred-store (se configurado)
bash global/skills/cred-store-setup/scripts/register.sh \
  --name neon.main.api_key \
  --value "$NEON_API_KEY" \
  --vault 1Password
```

### Passo 4: Exportar Project ID

```bash
# Listar projects disponiveis
neonctl projects list

# Exportar ID do project desejado
export NEON_PROJECT_ID=$(neonctl projects list --output json | jq -r '.projects[0].id')
echo "NEON_PROJECT_ID=$NEON_PROJECT_ID"
```

### Passo 5: Obter Connection String

```bash
# Connection string pooled (default - para serverless/Workers)
neonctl connection-string $NEON_PROJECT_ID

# Connection string unpooled (para migrations/long transactions)
neonctl connection-string $NEON_PROJECT_ID --pooler false

# Connection string de branch especifica
neonctl connection-string $NEON_PROJECT_ID --branch-name dev-feature-x
```

### Passo 6: Adicionar ao .env

```bash
# .env completo
NEON_API_KEY=ntoy_xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
NEON_PROJECT_ID=soft-hour-12345678
DATABASE_URL=postgres://usuario:senha@ep-xxx-pooler.region.neon.tech/dbname?sslmode=require
# Para migrations, usar DIRECT_URL (unpooled):
# DIRECT_URL=postgres://usuario:senha@ep-xxx.region.neon.tech/dbname?sslmode=require
```

## Exemplo Bom

```bash
# 1. Instalar neonctl
npm i -g neonctl

# 2. Autenticar
neonctl auth

# 3. Listar projects
neonctl projects list

# 4. Obter connection string
neonctl connection-string soft-hour-12345678 --branch-name main

# Resultado:
# postgres://alex:password@ep-xxx.region.aws-neon.tech/dbname?sslmode=require

# 5. Testar conexao
psql "$DATABASE_URL" -c "SELECT version();"
```

## Exemplo Ruim

```bash
# RUIM: API key hardcoded em codigo
const db = new Pool({
  connectionString: "postgres://user:pass@ep-xxx.neon.tech/db?sslmode=require"
})

# RUIM: Connection string com sslmode=disable (inseguro)
DATABASE_URL=postgres://user:pass@ep-xxx.neon.tech/db?sslmode=disable

# RUIM: Mesmo .env commitado no git
git add .env
git commit -m "add database config"

# RUIM: API key em .env.example
# .env.example:
# NEON_API_KEY=ntoy_abc123xxxxxxxxxxxx  # RUIM - credencial exposta
```

## Gotchas (4-7 itens)

1. **API key nunca commita**: Adicione `NEON_API_KEY` ao `.gitignore` e use `git update-index --assume-unchanged .env` em maquinas compartilhadas.

2. **Pooled vs Unpooled**: Connection strings com `-pooler` no host usam pgbouncer em transaction mode. Para migrations, USE SEMPRE `--pooler false` (DIRECT_URL).

3. **sslmode=require obrigatorio**: Neon exija TLS. `sslmode=disable` ou `sslmode=allow` resultara em erro de conexao.

4. **Separacao por ambiente**: Cada ambiente (dev/staging/prod) deve ter sua propria API key e project/branch. Nao compartilhar credenciais entre ambientes.

5. **Rotacao de chaves**: Rotacione API keys a cada 90 dias. Revogue chaves antigas imediatamente apos geracao de nova.

6. **Prefixo da API key**: Keys do Neon comecam com `ntoy_` para producao. Keys de teste podem ter outro prefixo. Validar antes de usar.

7. **Rate limits**: API Neon tem rate limits (100 req/min para free tier). Em pipelines CI, implementar retry com backoff exponencial.

## Quando Nao Usar

- **Criar resources**: Use `neon-create-project` para project novo, `neon-create-branch` para branch efemera
- **Migracoes**: Apos setup inicial, use tools como alembic/drizzle com DIRECT_URL configurado
- **Operacoes de merge**: Use `neon-merge-branch` que ja assume credenciais configuradas
- **Debug de conexao**: Para debugging, use `neon-list-connections` que lista queries ativas
