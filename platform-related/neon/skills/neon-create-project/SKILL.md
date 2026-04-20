---
name: neon-create-project
description: Cria novo project Neon via CLI ou API. Use quando mencionar "create neon project", "novo project neon", "init neon", "setup neon project". Tambem para "neon init", "criar banco neon", "provisionar neon". Nao use para configuracao de credenciais (use neon-credentials-setup) ou operacoes em project existente.
allowed-tools:
  - Read
  - Glob
  - Grep
  - Bash
---

# Neon Create Project

Cria um novo project Neon Postgres serverless com region otimizada, tier gratuito configurado e estrutura inicial (branches dev/staging, roles, databases).

## Condicoes de Execucao

**Use quando**:
- Primeiro project Neon do projeto/organizacao
- Criar ambiente isolado (staging production-like)
- Project para cliente/tenant separado
- Substituir database managed tradicional

**Nao use quando**:
- Apenas configurar credenciais em project existente (use `neon-credentials-setup`)
- Criar branch efemera para feature (use `neon-create-branch`)
- Operar em project ja existente (listar, verificar, etc.)
- Setup de pooler em project existente (use `neon-configure-pooler`)

## Pre-Flight Checks

1. Verificar se `neonctl` esta instalado:
```bash
neonctl --version
```

2. Verificar se ha API key configurada:
```bash
neonctl auth status
# Se nao autenticado: neonctl auth (seguir neon-credentials-setup)
```

3. Listar projects existentes (evitar duplicacao):
```bash
neonctl projects list
```

## Workflow

### Passo 1: Escolher Region

| Region Code | Localidade | Latencia BA |
|-------------|------------|-------------|
| `aws-us-east-1` | Norte Virginia, USA | ~100ms |
| `aws-us-east-2` | Ohio, USA | ~110ms |
| `aws-eu-central-1` | Frankfurt, Alemanha | ~200ms |
| `aws-ap-southeast-1` | Singapura | ~250ms |
| `azure-eastus2` | Virginia, EUA | ~100ms |

**Importante**: Region NAO pode ser alterada apos criacao. Escolha a mais proxima do seu compute (Workers Lambda, servidores, etc.).

### Passo 2: Criar Project

```bash
# Criar project com nome descritivo
neonctl projects create \
  --name meu-projeto-main \
  --region aws-us-east-1

# Output contem:
# {
#   "id": "soft-hour-12345678",
#   "name": "meu-projeto-main",
#   "region_id": "aws-us-east-1",
#   "pg_version": 16
# }
```

### Passo 3: Copiar Project ID

```bash
export NEON_PROJECT_ID=soft-hour-12345678
```

### Passo 4: Listar Endpoints (compute instances)

```bash
neonctl endpoints list --project-id $NEON_PROJECT_ID

# Output:
# [
#   {
#     "id": "ep-xxx-123456",
#     "type": "read_write",
#     "branch_id": "main",
#     "autosuspend_seconds": 300
#   }
# ]
```

### Passo 5: Obter Connection Strings

```bash
# Branch main (pooled - para aplicacao)
neonctl connection-string $NEON_PROJECT_ID --branch-name main

# Branch main (unpooled - para migrations)
neonctl connection-string $NEON_PROJECT_ID --branch-name main --pooler false
```

### Passo 6: Criar Branches Dev/Staging

```bash
# Branch dev (para desenvolvimento local)
neonctl branches create \
  --project-id $NEON_PROJECT_ID \
  --name dev \
  --parent main

# Branch staging (espelho de prod para testes)
neonctl branches create \
  --project-id $NEON_PROJECT_ID \
  --name staging \
  --parent main
```

### Passo 7: Configurar Roles e Databases (via PSQL)

```bash
# Conectar ao project
psql "$(neonctl connection-string $NEON_PROJECT_ID --pooler false)"

# Dentro do PSQL:
# CREATE ROLE meuasuario WITH LOGIN PASSWORD 'senhaforte123';
# CREATE DATABASE meubanco;
# GRANT ALL PRIVILEGES ON DATABASE meubanco TO meuasuario;
# \q
```

## Exemplo Bom

```bash
# Setup completo de novo project
export NEON_PROJECT_ID=$(neonctl projects create \
  --name fintech-api-prod \
  --region aws-us-east-1 \
  --output json | jq -r '.id')

echo "Project ID: $NEON_PROJECT_ID"

# Obter connection strings
MAIN_URL=$(neonctl connection-string $NEON_PROJECT_ID --branch-name main)
echo "DATABASE_URL=$MAIN_URL"

# Criar branchs derivadas
neonctl branches create --project-id $NEON_PROJECT_ID --name staging --parent main
neonctl branches create --project-id $NEON_PROJECT_ID --name dev --parent main

# Verificar resources
neonctl branches list --project-id $NEON_PROJECT_ID
neonctl endpoints list --project-id $NEON_PROJECT_ID
```

## Exemplo Ruim

```bash
# RUIM: Region longe do compute
neon projects create --name app --region aws-ap-southeast-1
# (compute no Brasil, region em Singapura = latencia 250ms+)

# RUIM: Nao especificar region (pode criar em region nao ideal)
neon projects create --name app

# RUIM: Free tier sem monitoramento de storage
# Free tier: 0.5GB storage, 191 compute hours/mês
# Esquecer de monitorar = project bloqueado quando estourar

# RUIM: Compartilhar project entre ambientes
# Usar mesmo project para dev/staging/prod = isolamento quebrado
# Branches existem para isso!
```

## Gotchas (5-7 itens)

1. **Region imutavel**: Project NAO pode ter region alterada apos criacao. Se errou, DELETE e recrie (perde todos os dados).

2. **Free tier limites**: 0.5GB storage, 191 compute hours/mês. Aplicacoes em producao inevitavelmente estouram. Upgrade para tier pago antes de production.

3. **Autosuspend default 5min**: Compute suspende apos 5 min de inatividade. Primeira query apos suspend tem cold start ~500ms. Para workloads constantes, desabilite autosuspend.

4. **Branches compartilham storage (CoW)**: Branchs sao snapshots copy-on-write. Storage "real" e a soma de todas as branches com mudancas, nao soma simples.

5. **pg_version padrao 16**: Versao do Postgres nao pode ser alterada no free tier. Planos pagos permitem upgrade de versao.

6. **Max branches free tier = 10**: Limite de branches no tier gratuito. Delete branches efemeras apos uso para evitar bloqueio.

7. **Connection pooler por branch**: Cada branch tem seu proprio pooler. Configurar `DATABASE_URL` com a branch correta para cada ambiente.

## Plano de Custos e Limites

| Tier | Storage | Compute Hours | Max Branches | Max Endpoints |
|------|---------|---------------|--------------|---------------|
| Free | 0.5 GB | 191/mês | 10 | 1 |
| Starter | 10 GB | ilimitado | 100 | 5 |
| Launch | 50 GB | ilimitado | 100 | 10 |
| Scale | 200 GB | ilimitado | 100 | 20 |

## Quando Nao Usar

- **Configurar credenciais**: Apos criar project, use `neon-credentials-setup` para configurar .env
- **Branch efemera**: Para feature branches, use `neon-create-branch` (cria branch derivada, não project)
- **Migracao de DB existente**: Neon tem ferramentas de migration (migra, pg_dump), mas esse processo requer skill dedicada
- **Operacoes diarias**: Em produção, você raramente cria projects. Frequentemente usa branches, pooler, connections
