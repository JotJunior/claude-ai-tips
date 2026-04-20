---
name: neon-anonymize-branch
description: Cria branch + anonymiza PII para dev/staging seguro. Use quando mencionar "anonymize branch", "neon anonymize", "pii redact branch", "safe dev data", "mask data", "fake data", "test data safe". Tambem para "GDPR safe data", "synthetic data", "dev database safe". Nao use para merge de branch (use neon-merge-branch) ou configuracao inicial (use neon-create-project).
allowed-tools:
  - Read
  - Glob
  - Grep
  - Bash
---

# Neon Anonymize Branch

Cria uma branch Neon e anonymiza dados PII (Personally Identifiable Information) para uso seguro em ambientes de desenvolvimento e staging, garantindo conformidade com LGPD/GDPR.

## Condicoes de Execucao

**Use quando**:
- Criar ambiente de dev seguro com dados reais
- Setup de staging com PII mascarada
- Compartilhar dump de banco com terceiros
- Treinar modelos de ML sem expor dados reais
- Testes de performance com dados realistas
- Onboarding de novos desenvolvedores

**Nao use quando**:
- Criar project inicial (use `neon-create-project`)
- Merge de branch com main (use `neon-merge-branch`)
- Apenas listar conexoes (use `neon-list-connections`)
- Configurar credenciais (use `neon-credentials-setup`)
- Dump de production real (dados NAO anonymizados)

## Conceitos de PII

### Dados Pessoais (LGPD Art. 5, I)
- Nome completo
- CPF, RG
- Email pessoal
- Telefone
- Endereco
- Data de nascimento
- Foto/Imagem identificavel

### Dados Sensiveis (LGPD Art. 5, II)
- Origem racial ou etnica
- Opinião política
- Crença religiosa
- Dados de saúde
- Dados genéticos
- Biometria

### Dados de Conexao/Usage (LGPD Art. 5, II)
- IP de acesso
- Logs de navegação
- Cookies (em alguns casos)

## Workflow

### Passo 1: Criar Branch Anonima

```bash
# Branch anonima a partir de main
BRANCH_NAME="dev-anon-$(date +%Y%m%d)"

neonctl branches create \
  --project-id $NEON_PROJECT_ID \
  --name $BRANCH_NAME \
  --parent main

# Obter connection string
ANON_DB_URL=$(neonctl connection-string $NEON_PROJECT_ID \
  --branch-name $BRANCH_NAME \
  --pooler false)
export ANON_DATABASE_URL=$ANON_DB_URL
```

### Passo 2: Identificar Tabelas com PII

```sql
-- Listar todas tabelas
SELECT table_schema, table_name 
FROM information_schema.tables 
WHERE table_type = 'BASE TABLE'
  AND table_schema NOT IN ('pg_catalog', 'information_schema')
ORDER BY table_schema, table_name;

-- Identificar colunas com potencial PII
SELECT 
  table_schema,
  table_name, 
  column_name,
  data_type
FROM information_schema.columns
WHERE column_name LIKE '%name%'
   OR column_name LIKE '%email%'
   OR column_name LIKE '%phone%'
   OR column_name LIKE '%cpf%'
   OR column_name LIKE '%address%'
   OR column_name LIKE '%document%'
   OR column_name LIKE '%birth%'
ORDER BY table_schema, table_name;
```

### Passo 3: Script de Anonymization

```sql
-- ============================================
-- Script de Anonymization para Dev/Staging
-- ============================================
-- Executar APENAS na branch anonima
-- NUNCA executar em production

BEGIN;

-- ============================================
-- USERS: Exemplo de tabela principal
-- ============================================
UPDATE auth.users SET
  email = 'user_' || id || '@example.test',
  full_name = 'Usuario Teste ' || id,
  phone = '+55119' || LPAD(id::text, 8, '0'),
  cpf = LPAD(id::text, 11, '0'),
  rg = NULL,
  address = 'Rua Exemplo ' || id || ', 123 - Sao Paulo, SP',
  date_of_birth = NULL,
  avatar_url = NULL,
  -- Manter id e created_at para FK consistency
  updated_at = NOW()
WHERE true;

-- ============================================
-- CUSTOMERS: Clientes da aplicacao
-- ============================================
UPDATE public.customers SET
  name = 'Cliente ' || id,
  email = 'cliente_' || id || '@test.example',
  phone = '+55119' || LPAD((id * 2)::text, 8, '0'),
  document = NULL,
  address = NULL,
  updated_at = NOW()
WHERE true;

-- ============================================
-- ORDERS: Pedidos (manter metadata, mascarar customer ref)
-- ============================================
-- Orders geralmente NAO tem PII direto
-- Mas pode ter shipping_address com PII
UPDATE sales.orders SET
  shipping_name = 'Destinatario ' || id,
  shipping_phone = '+55119' || LPAD(id::text, 8, '0'),
  shipping_address = 'Endereco de Entrega ' || id || ', Sao Paulo, SP',
  updated_at = NOW()
WHERE shipping_address IS NOT NULL;

-- ============================================
-- PAYMENTS: Dados de pagamento
-- ============================================
UPDATE payments.transactions SET
  card_last4 = '0000',
  card_brand = 'test',
  payer_email = 'pagamento_' || id || '@test.example',
  payer_name = 'Pagador Teste ' || id,
  payer_document = NULL,
  updated_at = NOW()
WHERE true;

-- ============================================
-- TOKENS/SESSIONS: Resetar autenticacao
-- ============================================
DELETE FROM auth.sessions WHERE true;
DELETE FROM auth.refresh_tokens WHERE true;
-- Se preferir manter sessions:
-- UPDATE auth.sessions SET 
--   token = 'anon_token_' || gen_random_uuid()::text,
--   expires_at = NOW() + INTERVAL '30 days';

-- ============================================
-- LOGS/AUDIT: Limpar logs potencialmente sensiveis
-- ============================================
DELETE FROM audit.action_logs 
WHERE created_at < NOW() - INTERVAL '90 days';

-- ============================================
-- NOTIFICATIONS: Contatos de usuario
-- ============================================
UPDATE notifications.destinations SET
  value = 'notify_' || id || '@test.example'
WHERE type = 'email';

UPDATE notifications.destinations SET
  value = '+55119' || LPAD(id::text, 8, '0')
WHERE type = 'sms';

COMMIT;
```

### Passo 4: Verificar Anonymization

```sql
-- Verificar que emails foram mascarados
SELECT email FROM auth.users LIMIT 5;
-- Esperado: user_xxx@example.test

-- Verificar que CPFs foram mascarados
SELECT cpf FROM auth.users LIMIT 5;
-- Esperado: sequencia numerica ou NULL

-- Verificar que tokens foram resetados
SELECT COUNT(*) FROM auth.sessions;
-- Esperado: 0 (se deletou)

-- Contagem de linhas (deve ser igual)
SELECT 
  'users' as table_name, COUNT(*) as count FROM auth.users
UNION ALL
SELECT 'customers', COUNT(*) FROM public.customers
UNION ALL
SELECT 'orders', COUNT(*) FROM sales.orders;
```

### Passo 5: Vacuum Analyze

```sql
-- Apos updates massivos, vacuum para liberar espaco
VACUUM (ANALYZE, VERBOSE) auth.users;
VACUUM (ANALYZE, VERBOSE) public.customers;
VACUUM (ANALYZE, VERBOSE) sales.orders;
VACUUM (ANALYZE, VERBOSE) payments.transactions;
```

### Passo 6: Exportar Connection String

```bash
# Exportar para .env ou CI/CD
echo "ANON_DATABASE_URL=$ANON_DB_URL"

# Documentar no README do projeto
# ANON_BRANCH_URL=postgres://.../dev-anon-20240115
```

## Exemplo Completo (Script Bash)

```bash
#!/bin/bash
set -e
set -o pipefail

BRANCH_NAME="dev-anon-$(date +%Y%m%d)"
NEON_PROJECT_ID="soft-hour-12345678"

echo "=== Criando branch anonima: $BRANCH_NAME ==="

# 1. Criar branch
BRANCH_OUTPUT=$(neonctl branches create \
  --project-id $NEON_PROJECT_ID \
  --name $BRANCH_NAME \
  --parent main)
echo "$BRANCH_OUTPUT"

# 2. Obter connection string (unpooled para writes)
ANON_URL=$(neonctl connection-string $NEON_PROJECT_ID \
  --branch-name $BRANCH_NAME \
  --pooler false)
export ANON_DATABASE_URL=$ANON_URL

# 3. Executar anonymization
echo "[1/3] Anonymizing users..."
psql "$ANON_URL" -c "
UPDATE auth.users SET
  email = 'user_' || id || '@example.test',
  full_name = 'Usuario Teste ' || id,
  phone = '+55119' || LPAD(id::text, 8, '0'),
  cpf = LPAD(id::text, 11, '0'),
  address = 'Rua Exemplo ' || id || ', 123 - Sao Paulo, SP',
  updated_at = NOW()
WHERE true;
"

echo "[2/3] Anonymizing customers..."
psql "$ANON_URL" -c "
UPDATE public.customers SET
  name = 'Cliente ' || id,
  email = 'cliente_' || id || '@test.example',
  phone = '+55119' || LPAD((id * 2)::text, 8, '0'),
  updated_at = NOW()
WHERE true;
"

echo "[3/3] Resetando sessions..."
psql "$ANON_URL" -c "DELETE FROM auth.sessions;"
psql "$ANON_URL" -c "DELETE FROM auth.refresh_tokens;"

# 4. Vacuum
echo "Vacuum analyze..."
psql "$ANON_URL" -c "VACUUM ANALYZE auth.users;"
psql "$ANON_URL" -c "VACUUM ANALYZE public.customers;"

echo ""
echo "=== Branch anonima pronta ==="
echo "Connection string (unpooled):"
echo "$ANON_URL"
echo ""
echo "ATENCAO: Esta branch e apenas para dev/test."
echo "NUNCA faca merge desta branch para production."
```

## Exemplo Ruim

```sql
-- RUIM: Anonymizar apenas email, esquecer phone
UPDATE users SET email = 'test@example.com';
-- phone ainda tem dado real = VIOLACAO

-- RUIM: Manter primeiros digitos do CPF real
UPDATE users SET cpf = '123.' || id || '.xxx-xx';
-- Primeiros digitos identificam pessoa = PII parcial exposta

-- RUIM: Deletar usuarios inteiros
DELETE FROM users;
-- FK quebram, dados inconsistentes, useless para dev

-- RUIM: Anonymization em production
-- RODAR ESSE SCRIPT EM PRODUCTION = DESASTRE
-- Anonymization APENAS em branch efemera

-- RUIM: Nao documentar o que foi anonymizado
-- Equipe pensa que dados sao reais
-- Adicionar audit log da anonymization

-- RUIM: Fazer anonymization sem backup
-- UPDATE errado = dado irrecuperavel
-- SEMPRE fazer em branch efemera, nao direto
```

## Gotchas (5-7 itens)

1. **GDPR Right to be Forgotten**: Se usuario solicitou deletion, anonymizar NAO satisfaz request. deletion = hard delete. anonymize = pseudonymization, dado ainda identificavel via FK.

2. **FK consistency**: UPDATE deve manter chaves para FK. Nao alterar IDs. Alterar apenas dados sensiveis (email, phone, name). ID = identificador de integridade.

3. **JSONB columns**: Dados em `data` column (JSONB) com PII sao faceis de esquecer. Usar `jsonb_set()` ou `jsonb_each()`. Ex: `UPDATE orders SET data = jsonb_set(data, '{customer_email}', '"anonymized"');`

4. **Deterministic fakes**: Se ID = 1, email deve ser sempre `user_1@example.test`. Funcao random() causa inconsistencia em refresh. Usar `id` como seed deterministico.

5. **Audit da anonymization**: Criar tabela `audit.anonymization_runs` documentando quando, quem, quais tabelas. Requisito de compliance para demostrar que dados foram protegidos.

6. **Historico de senhas/tokens**: Tabela `auth.passwords`, `auth.tokens` pode conter hashes de senhas. Resetar todos (DELETE) ao inves de anonymizar. Hashes podem ser quebrados.

7. **Logs e audit trails**: `audit_logs`, `access_logs` podem ter IP, user-agent, actions. Considerar truncate ou mascarar IP parcialmente (`192.168.xxx.xxx`).

## Extension: postgres-anonymizer

Para bases maiores, considerar usar a extension `postgres_anonymizer`:

```sql
-- Habilitar extension (requer superuser)
CREATE EXTENSION IF NOT EXISTS anon CASCADE;

-- Marcar colunas como PII
SECURITY LABEL FOR anon ON COLUMN auth.users.email IS 'MASKED WITH FUNCTION anonymize.anonymize_email(users.email)';
SECURITY LABEL FOR anon ON COLUMN auth.users.phone IS 'MASKED WITH FUNCTION anonymize.anonymize_phone(users.phone)';

-- Anonymizar toda a tabela
SELECT anon.anonymize_table('auth.users');

-- Ver dados anonymizados
SELECT * FROM auth.users LIMIT 5;
```

## Quando Nao Usar

- **Production**: NUNCA anonymize em production (dados reais sao valiosos)
- **Merge de branch**: Para syncar schema de volta, use `neon-merge-branch`
- **Setup inicial**: Use `neon-create-project` seguido de `neon-credentials-setup`
- **Backup de production**: Dump de production deve ser anonymizado ANTES de compartilhar
