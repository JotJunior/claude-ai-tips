---
name: neon-create-branch
description: Cria branch Neon para ambiente efemero de dev/test. Use quando mencionar "create neon branch", "novo branch neon", "branch database", "neon dev branch", "feature branch database". Tambem para "neon ephemeral", "test database", "isolated database". Nao use para merge de branch (use neon-merge-branch) ou setup inicial (use neon-create-project).
allowed-tools:
  - Read
  - Glob
  - Grep
  - Bash
---

# Neon Create Branch

Cria uma branch Neon (snapshot copy-on-write isolado) para workflow de desenvolvimento efemero: feature branches, ambientes de teste, CI/CD pipelines, reviews de PR.

## Condicoes de Execucao

**Use quando**:
- Criar ambiente isolado para feature branch
- Preparar banco para PR review
- Criar ambiente de teste temporario
- Setup de pipeline CI com banco isolado
- Validar migracoes em ambiente safe

**Nao use quando**:
- Setup inicial de project (use `neon-create-project`)
- Merge/sync de branch com main (use `neon-merge-branch`)
- Operacoes de pooler ou connection (use `neon-configure-pooler` ou `neon-credentials-setup`)
- Criar ambiente de staging production-like (criar branch de main, nao de outra branch)

## Pre-Flight Checks

1. Verificar project existe e tem quota de branches:
```bash
neonctl branches list --project-id $NEON_PROJECT_ID
```

2. Verificar branch pai (geralmente `main`):
```bash
neonctl branches get --project-id $NEON_PROJECT_ID --branch-name main
```

3. Verificar roles disponiveis:
```bash
neonctl roles list --project-id $NEON_PROJECT_ID
```

## Workflow

### Passo 1: Criar Branch

```bash
# Branch simples a partir de main
neonctl branches create \
  --project-id $NEON_PROJECT_ID \
  --name dev-feature-xyz \
  --parent main

# Branch com timestamp especifico (point-in-time recovery)
neonctl branches create \
  --project-id $NEON_PROJECT_ID \
  --name dev-feature-xyz \
  --parent main \
  --parent-timestamp "2024-01-15T10:30:00Z"

# Output:
# {
#   "id": "br-xxx-yyy",
#   "name": "dev-feature-xyz",
#   "parent_id": "main",
#   "parent_branch_id": "main",
#   "created_at": "2024-01-20T15:00:00Z"
# }
```

### Passo 2: Obter Connection URI

```bash
# Connection string pooled (serverless)
neonctl connection-string $NEON_PROJECT_ID \
  --branch-name dev-feature-xyz

# Connection string unpooled (migrations/long tx)
neonctl connection-string $NEON_PROJECT_ID \
  --branch-name dev-feature-xyz \
  --pooler false
```

### Passo 3: Exportar Variavel de Ambiente

```bash
export FEATURE_DATABASE_URL="postgres://user:pass@ep-xxx-pooler.region.neon.tech/dbname?sslmode=require"
```

### Passo 4: Executar Migrations (se necessario)

```bash
# Usar DIRECT_URL (unpooled) para migrations
export DIRECT_URL="postgres://user:pass@ep-xxx.region.neon.tech/dbname?sslmode=require"

# Rodar migrations (exemplo com alembic)
alembic upgrade head

# ou com drizzle
drizzle-kit push:pg

# ou raw SQL
psql "$DIRECT_URL" -f migrations/001_feature.sql
```

### Passo 5: Testar Schema e Dados

```bash
# Verificar estrutura
psql "$DIRECT_URL" -c "\dt"

# Verificar dados de teste
psql "$DIRECT_URL" -c "SELECT COUNT(*) FROM users;"

# Testar queries da feature
psql "$DIRECT_URL" -c "SELECT * FROM orders WHERE status = 'pending';"
```

### Passo 6: Apos PR Merged - Deletar Branch

```bash
# Listar branches para confirmar ID
neonctl branches list --project-id $NEON_PROJECT_ID

# Deletar branch efemera
neonctl branches delete \
  --project-id $NEON_PROJECT_ID \
  --branch-id br-xxx-yyy

# Confirma deletion
neonctl branches list --project-id $NEON_PROJECT_ID
```

## Exemplo Bom

```bash
# Workflow completo: feature branch
#!/bin/bash
set -e

FEATURE_BRANCH="dev-feature-payment-refactor"
export NEON_PROJECT_ID="soft-hour-12345678"

# 1. Criar branch
echo "Criando branch $FEATURE_BRANCH..."
BRANCH_OUTPUT=$(neonctl branches create \
  --project-id $NEON_PROJECT_ID \
  --name $FEATURE_BRANCH \
  --parent main)
echo "$BRANCH_OUTPUT"

# 2. Obter connection string
FEATURE_DB_URL=$(neonctl connection-string $NEON_PROJECT_ID \
  --branch-name $FEATURE_BRANCH)
export DATABASE_URL=$FEATURE_DB_URL
echo "DATABASE_URL=$DATABASE_URL"

# 3. Rodar migrations
echo "Aplicando migrations..."
psql "$DATABASE_URL" -f ./migrations/001_init.sql
psql "$DATABASE_URL" -f ./migrations/002_feature.sql

# 4. Seed de dados de teste
echo "Seed..."
psql "$DATABASE_URL" -c "INSERT INTO test_scenarios (name) VALUES ('payment_refactor_test');"

# 5. Testar
echo "Rodando testes..."
pytest tests/integration/

# 6. Apos sucesso: deletar branch
echo "Deletando branch efemera..."
neonctl branches delete \
  --project-id $NEON_PROJECT_ID \
  --branch-name $FEATURE_BRANCH
```

## Exemplo Ruim

```bash
# RUIM: Branch de production direto
neonctl branches create --project-id $NEON_PROJECT_ID --name prod-hotfix --parent production
# (branches devem derivar de main ou staging, nunca de prod)

# RUIM: Esquecer de deletar branch
# Branch ficaocupando quota (max 10 no free tier)
# Resultado: proxima criacao de branch falha

# RUIM: Usar branch para dados persistentes
# Branch efemera = descartavel
# Dados importantes devem estar em main/staging

# RUIM: Connection string hardcoded
FEATURE_URL="postgres://user:pass@ep-old-xxx.neon.tech/db"  # ID errado
# Sempre usar neonctl para gerar connection string atual

# RUIM: Migrar sem DIRECT_URL (unpooled)
# Pooler em transaction mode nao suporta migrations DDL
# Resultado: "ERROR: cannot execute CREATE TABLE in a transaction"
```

## Gotchas (5-7 itens)

1. **Branches sao CoW (Copy-on-Write)**: Storage compartilhado entre branch pai e filha. Modificacoes na filha NAO afetam o pai. Delete da filha libera espaco imediatamente.

2. **Branch de timestamp especifico**: Use `--parent-timestamp` para criar branch point-in-time. Útil para debug de incidentes em produção (ate 7 dias de retention).

3. **Cold start do endpoint**: Nova branch cria endpoint on-demand. Primeira query pode demorar ~500ms. Considere warm-up antes de testes.

4. **Max branches free tier = 10**: Limite de branches. Delete branches efemeras imediatamente após uso. CI/CD deve cleanup ao final.

5. **Branch e seu proprio endpoint**: Cada branch tem compute proprio. Custo de compute multiplica pelo numero de branches ativas. Free tier = 191h/mês total.

6. **pg_stat_activity na branch**: Queries em branch diferente NAO aparecem em pg_stat_activity da main. Monitar conexoes por branch separadamente.

7. **Delete nao e undo**: Branch deletada NAO pode ser recuperada. Confirmar que nao ha dados importantes antes de deletar. Snapshot antes se necessario.

## Pattern: Branch para CI/CD

```yaml
# .github/workflows/test.yml
jobs:
  integration-test:
    runs-on: ubuntu-latest
    steps:
      - name: Criar branch efemera
        run: |
          BRANCH_NAME="ci-pr-${{ github.event.pull_request.number }}"
          neonctl branches create \
            --project-id $NEON_PROJECT_ID \
            --name $BRANCH_NAME \
            --parent main
          echo "FEATURE_BRANCH=$BRANCH_NAME" >> $GITHUB_ENV

      - name: Rodar testes
        run: |
          DATABASE_URL=$(neonctl connection-string $NEON_PROJECT_ID \
            --branch-name ${{ env.FEATURE_BRANCH }})
          pytest tests/integration/

      - name: Cleanup branch
        if: always()
        run: |
          neonctl branches delete \
            --project-id $NEON_PROJECT_ID \
            --branch-name ${{ env.FEATURE_BRANCH }}
```

## Quando Nao Usar

- **Merge de branch**: Para sincronizar schema/dados de volta ao main, use `neon-merge-branch`
- **Criar project**: Para primeiro setup, use `neon-create-project` antes de criar branches
- **Setup de credenciais**: Para configurar .env, use `neon-credentials-setup`
- **Ambiente production-like permanente**: Use staging (branch derivada de main, persistente)
