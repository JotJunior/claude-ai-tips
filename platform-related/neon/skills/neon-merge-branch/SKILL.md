---
name: neon-merge-branch
description: Merge/sync de branch Neon ao main (schema diff e data sync). Use quando mencionar "merge neon branch", "promote branch", "merge branch to main", "neon merge", "sync branch", "schema migration from branch". Tambem para "apply branch changes", "deploy branch to prod". Nao use para criar branch (use neon-create-branch) ou delete de branch (use neon-delete-branch se existir).
allowed-tools:
  - Read
  - Glob
  - Grep
  - Bash
---

# Neon Merge Branch

Realiza merge/sync de uma branch Neon ao main via schema diff + data sync seletivo. Neon NAO tem merge nativo (diferente Git), entao o processo requer geracao manual de diff SQL e aplicacao controlada.

## Condicoes de Execucao

**Use quando**:
- Feature branch pronta para production
- Validar que schema da branch pode ser aplicado ao main
- Sincronizar dados de staging para production
- Promote de branch efemera para ambiente estavel

**Nao use quando**:
- Criar branch (use `neon-create-branch`)
- Criar project (use `neon-create-project`)
- Apenas comparar schemas (generate diff apenas, sem apply)
- Delete de branch (delete manualmente apos merge bem-sucedido)

## Pre-Flight Checks

1. Verificar branchs envolvidas:
```bash
# Listar branchs
neonctl branches list --project-id $NEON_PROJECT_ID

# Verificar branch fonte (feature)
neonctl branches get \
  --project-id $NEON_PROJECT_ID \
  --branch-name dev-feature-xyz

# Verificar branch destino (main)
neonctl branches get \
  --project-id $NEON_PROJECT_ID \
  --branch-name main
```

2. Verificar roles e permissoes:
```bash
# Verificar que role tem permissao DDL no main
psql "$(neonctl connection-string $NEON_PROJECT_ID --branch-name main --pooler false)" \
  -c "SELECT rolname, rolsuper, rolcreatedb FROM pg_roles WHERE rolname = current_user;"
```

3. Backup point (opcional mas recomendado):
```bash
# Criar branch de backup antes de merge
neonctl branches create \
  --project-id $NEON_PROJECT_ID \
  --name pre-merge-backup \
  --parent main
```

## Workflow

### Passo 1: Gerar Schema Diff

```bash
# Dump schema da branch fonte
pg_dump \
  --schema-only \
  --no-owner \
  --no-acl \
  "$(neonctl connection-string $NEON_PROJECT_ID --branch-name dev-feature-xyz --pooler false)" \
  > /tmp/branch_schema.sql

# Dump schema do main
pg_dump \
  --schema-only \
  --no-owner \
  --no-acl \
  "$(neonctl connection-string $NEON_PROJECT_ID --branch-name main --pooler false)" \
  > /tmp/main_schema.sql

# Gerar diff ( requer tools como migra,atlas,sqitch )
diff /tmp/main_schema.sql /tmp/branch_schema.sql > /tmp/schema_diff.sql
# ou usar migra:
# migra compare "$(neon connection-string --pooler false --branch-name main)" \
#                     "$(neon connection-string --pooler false --branch-name dev-feature-xyz)"
```

### Passo 2: Analisar Diff (REVISAO OBRIGATORIA)

```bash
cat /tmp/schema_diff.sql

# Identificar operacoes perigosas:
# - DROP TABLE, DROP COLUMN (destrutivo)
# - ALTER COLUMN TYPE (pode perder dados)
# - DROP CONSTRAINT, DROP INDEX (pode quebrar integridade)
# - ALTER TABLE ... SET NOT NULL (pode falhar se dados nulos existirem)
```

### Passo 3: Gerar Migration SQL Seguro

```bash
# Para cada diff, gerar migration idempotente

# Exemplo: nova tabela (OK)
# CREATE TABLE IF NOT EXISTS schema.new_table (...);

# Exemplo: nova coluna (OK)
# ALTER TABLE schema.existing_table ADD COLUMN IF NOT EXISTS new_col TYPE;

# Exemplo: nova constraint (OK)
# ALTER TABLE schema.table ADD CONSTRAINT IF NOT EXISTS constraint_name CHECK (...);

# Exemplo: remover coluna (PERIGOSO - nunca em merge, marcar como deprecated primeiro)
# -- NUNCA FAZER ASSIM:
# ALTER TABLE schema.table DROP COLUMN old_column;
# -- CORRETO: adicionar deprecation period e migration separada
```

### Passo 4: Aplicar Migration ao Main (dry-run primeiro)

```bash
# DRY-RUN (sempre fazer primeiro)
psql "$(neonctl connection-string $NEON_PROJECT_ID --branch-name main --pooler false)" \
  -v ON_ERROR_STOP=1 \
  --echo-queries \
  -f /tmp/merge_migration.sql 2>&1 | head -50

# Se dry-run OK, aplicar
psql "$(neonctl connection-string $NEON_PROJECT_ID --branch-name main --pooler false)" \
  -v ON_ERROR_STOP=1 \
  -f /tmp/merge_migration.sql
```

### Passo 5: Data Sync (opcional, se necessario)

```bash
# Para tabelas que precisam de dados da branch

# Metodo 1: Insert/Update seletivo (preferido)
psql "$(neonctl connection-string $NEON_PROJECT_ID --branch-name main --pooler false)" <<'SQL'
INSERT INTO schema.table (id, col1, col2, updated_at)
SELECT id, col1, col2, NOW()
FROM schema.table
WHERE condition = 'specific_value'
ON CONFLICT (id) DO UPDATE SET
  col1 = EXCLUDED.col1,
  col2 = EXCLUDED.col2,
  updated_at = NOW();
SQL

# Metodo 2: Copy completo (CUIDADO - sobrescreve tudo)
# pg_dump --data-only --table=schema.table \
#   "$(neon connection-string --branch-name dev-feature-xyz --pooler false)" \
#   | psql "$(neon connection-string --branch-name main --pooler false)"

# Metodo 3: Sync via JOIN (para FK consistency)
# Sincronizar child records antes de parent records
```

### Passo 6: Verificar Integridade

```bash
# Checksum de tabelas principais
psql "$(neonctl connection-string $NEON_PROJECT_ID --branch-name main --pooler false)" <<'SQL'
SELECT 
  'users' as table_name,
  COUNT(*) as row_count,
  md5(array_agg(id ORDER BY id)::text) as checksum
FROM auth.users
UNION ALL
SELECT 
  'orders',
  COUNT(*),
  md5(array_agg(id ORDER BY id)::text)
FROM orders.orders;
SQL

# Verificar constraints
psql "$(neonctl connection-string $NEON_PROJECT_ID --branch-name main --pooler false)" \
  -c "SELECT conname, conrelid::regclass FROM pg_constraint WHERE contype = 'f';"
```

### Passo 7: Delete da Branch Efemera (apos confirmacao)

```bash
# Confirmar que merge foi bem-sucedido antes de deletar
neonctl branches delete \
  --project-id $NEON_PROJECT_ID \
  --branch-id br-xxx-yyy
```

## Exemplo Bom

```bash
#!/bin/bash
set -e
BRANCH_NAME="dev-feature-xyz"
NEON_PROJECT_ID="soft-hour-12345678"

echo "=== Merge Branch: $BRANCH_NAME -> main ==="

# 1. Gerar e revisar diff
echo "[1/6] Gerando schema diff..."
pg_dump --schema-only --no-owner "$(neonctl connection-string $NEON_PROJECT_ID --branch-name $BRANCH_NAME --pooler false)" > /tmp/branch.sql
pg_dump --schema-only --no-owner "$(neonctl connection-string $NEON_PROJECT_ID --branch-name main --pooler false)" > /tmp/main.sql
diff /tmp/main.sql /tmp/branch.sql || true

echo "[2/6] Analisar diff (pressione Enter para continuar ou Ctrl+C para abortar)..."
read

# 2. Criar backup branch
echo "[3/6] Criando backup branch..."
neonctl branches create --project-id $NEON_PROJECT_ID --name "pre-merge-$(date +%Y%m%d%H%M)" --parent main

# 3. Aplicar migration
echo "[4/6] Aplicando migration ao main..."
psql "$(neonctl connection-string $NEON_PROJECT_ID --branch-name main --pooler false)" \
  -f ./migrations/pending_from_branch.sql

# 4. Verificar
echo "[5/6] Verificando integridade..."
psql "$(neonctl connection-string $NEON_PROJECT_ID --branch-name main --pooler false)" \
  -c "SELECT COUNT(*) as users FROM auth.users;"
psql "$(neonctl connection-string $NEON_PROJECT_ID --branch-name main --pooler false)" \
  -c "SELECT COUNT(*) as orders FROM orders.orders WHERE created_at > NOW() - INTERVAL '1 day';"

# 5. Delete branch efemera
echo "[6/6] Deletando branch $BRANCH_NAME..."
neonctl branches delete --project-id $NEON_PROJECT_ID --branch-name $BRANCH_NAME

echo "=== Merge concluido com sucesso ==="
```

## Exemplo Ruim

```bash
# RUIM: Merge sem revisar diff
psql "$(neonctl connection-string $NEON_PROJECT_ID --branch-name main --pooler false)" \
  -f <(pg_dump --schema-only "$(neonctl connection-string $NEON_PROJECT_ID --branch-name feature --pooler false)")
# Pode aplicar operacoes destrutivas sem review

# RUIM: Data merge sem considerar FK
# Insert parent record antes de child
# Resultado: FK violation ou orphan records

# RUIM: Confiar que branch tem mesmo schema que main
# Branch pode ter migracoes conflitantes de outra feature
# SEMPRE fazer diff manual

# RUIM: Nao criar backup antes de merge
# Se merge falhar, rollback é manual e arriscado

# RUIM: Delete branch antes de confirmar merge
# Se algo quebrar, branch ja foi deletada
# Rule: Merge -> Verificar -> Delete
```

## Gotchas (5-7 itens)

1. **Neon NAO tem merge nativo**: Diferente de Git, branches Neon sao snapshots. Merge requer geracao manual de diff SQL e aplicacao controlada.

2. **Schema diff manual ou via tool**: Use tools como `migra`, `atlas`, `sqitch` ou `pg_dump --schema-only` + `diff`. Nao ha comando automatico.

3. **FK conflicts em data sync**: Parent record deve existir antes de child. Ordem: primeiro tables sem FK, depois com FK. DELETE na ordem inversa.

4. **Operacoes destrutivas**: DROP TABLE, DROP COLUMN, ALTER TYPE = PERIGOSO. Nao aplicar em merge automatico. Fazer deprecation period.

5. **Branches efemeras para test-only**: Se branch e para teste e nao para persistir mudancas, NAO faca merge. Delete e recrie quando necessario.

6. **Migrations versionadas no main**: Mantenha migrations em pasta `migrations/` versionadas. APLICAR via migration tool, nao via psql direto.

7. **Data sync seletivo**: E raro fazer merge de dados. Geralmente schema sync足够了. Data sync sÃ³ para dados de referencia (countries, categories, etc.).

## Alternativa: Branch como Staging Persistente

Se merge de branch e frequente, considere:

```bash
# Staging = branch permanente espelhando prod
neonctl branches create --project-id $NEON_PROJECT_ID --name staging --parent main

# Fluxo:
# 1. Dev em branch efemera
# 2. Merge dev -> staging (validar)
# 3. Merge staging -> main (deploy)
# Staging nunca deletada, apenas resync de main periodicamente
```

## Quando Nao Usar

- **Criar branch**: Use `neon-create-branch`
- **Setup inicial**: Use `neon-create-project` seguido de `neon-credentials-setup`
- **Comparacao apenas**: Gere diff, revise, mas nao aplique se ainda em validacao
- **Delete de branch**: Apos merge concluido, delete manualmente com `neonctl branches delete`
