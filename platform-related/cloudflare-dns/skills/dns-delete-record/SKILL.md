---
name: dns-delete-record
description: |
  Remove um DNS record existente com confirmacao do usuario e dry-run mode.
  Use quando o usuario mencionar: "delete dns", "remover dns", "deletar record dns",
  "apagar dns record", "remove dns entry".
  Nao use para listar, criar ou editar records.
allowed-tools:
  - Bash
  - Glob
  - Grep
  - Read
---

# dns-delete-record

Remove um DNS record de uma zone da Cloudflare via API v4, com validacao
obrigatoria antes da remocao e modo dry-run como padrao.

## Pre-flight

### 1. Identificar zone e record

```bash
DOMAIN="example.com"
TOKEN=$(bash ~/Sistemas/claude-ai-tips/global/skills/cred-store/scripts/resolve.sh cloudflare.idcbr.api_token)

ZONE_ID=$(curl -s -X GET "https://api.cloudflare.com/client/v4/zones?name=${DOMAIN}" \
  -H "Authorization: Bearer ${TOKEN}" \
  -H "Content-Type: application/json" | jq -r '.result[0].id')

# Listar records para encontrar o record_id
curl -s -X GET "https://api.cloudflare.com/client/v4/zones/${ZONE_ID}/dns_records?per_page=100" \
  -H "Authorization: Bearer ${TOKEN}" \
  -H "Content-Type: application/json" | jq '.result[] | select(.name | contains("api")) | {id, type, name, content}'
```

### 2. Backup antes de deletar (OBRIGATORIO em producao)

```bash
# Exportar todos os records antes de qualquer operacao destrutiva
BACKUP_FILE="dns-backup-$(date +%Y%m%d-%H%M%S).json"

curl -s -X GET "https://api.cloudflare.com/client/v4/zones/${ZONE_ID}/dns_records?per_page=100" \
  -H "Authorization: Bearer ${TOKEN}" \
  -H "Content-Type: application/json" | jq '.result' > "$BACKUP_FILE"

echo "Backup salvo em: $BACKUP_FILE"
echo "Total records: $(jq '. | length' "$BACKUP_FILE")"
```

## Workflow

### Passo 1 — GET record para exibir antes da confirmacao

```bash
RECORD_ID="abc123def456"

RECORD=$(curl -s -X GET "https://api.cloudflare.com/client/v4/zones/${ZONE_ID}/dns_records/${RECORD_ID}" \
  -H "Authorization: Bearer ${TOKEN}" \
  -H "Content-Type: application/json")

if [ "$(echo "$RECORD" | jq -r '.success')" != "true" ]; then
  echo "Record nao encontrado: $RECORD_ID"
  exit 1
fi

echo "=== Record a ser removido ==="
echo "$RECORD" | jq -r '.result | "ID:       \(.id)\nType:     \(.type)\nName:     \(.name)\nContent:  \(.content)\nTTL:      \(.ttl)\nProxied: \(.proxied)\nCriado:   \(.created_at)\nModificado: \(.modified_at)"'
```

### Passo 2 — Confirmacao interativa (dry-run default)

```bash
DRY_RUN=true
SKIP_PROMPT=false

while [[ $# -gt 0 ]]; do
  case "$1" in
    --yes) SKIP_PROMPT=true; DRY_RUN=false; shift ;;
    --dry-run) DRY_RUN=true; shift ;;
    --apply) DRY_RUN=false; shift ;;
    *) shift ;;
  esac
done

if [ "$DRY_RUN" = "true" ]; then
  echo "DRY-RUN MODE: Nenhuma alteracao sera feita."
  echo "Use --apply para confirmar a remocao."
  echo "Use --yes para skipar este prompt."
  exit 0
fi

if [ "$SKIP_PROMPT" = "false" ]; then
  echo ""
  echo "CONFIRMACAO REQUERIDA"
  echo "Tem certeza que deseja deletar este record? (digite 'sim' para confirmar)"
  read -r CONFIRM
  
  if [ "$CONFIRM" != "sim" ]; then
    echo "Operacao cancelada pelo usuario."
    exit 0
  fi
fi
```

### Passo 3 — DELETE

```bash
RESPONSE=$(curl -s -X DELETE "https://api.cloudflare.com/client/v4/zones/${ZONE_ID}/dns_records/${RECORD_ID}" \
  -H "Authorization: Bearer ${TOKEN}" \
  -H "Content-Type: application/json")

echo "$RESPONSE" | jq '.'
```

### Passo 4 — Validar remocao

```bash
SUCCESS=$(echo "$RESPONSE" | jq -r '.success')

if [ "$SUCCESS" = "true" ]; then
  echo "Record removido com sucesso."
  echo "ID deletado: $RECORD_ID"
  echo ""
  echo "Audit log:"
  echo "$(date -u +%Y-%m-%dT%H:%M:%SZ) DELETE dns_record ${RECORD_ID} (zone: ${ZONE_ID})" >> ~/.claude/credentials/cloudflare/audit.log
else
  echo "Erro ao deletar: $(echo "$RESPONSE" | jq -r '.errors[0].message')"
  exit 1
fi
```

### Passo 5 — Verificar que foi removido

```bash
# Confirmar que o record realmente sumiu
VERIFY=$(curl -s -X GET "https://api.cloudflare.com/client/v4/zones/${ZONE_ID}/dns_records/${RECORD_ID}" \
  -H "Authorization: Bearer ${TOKEN}" \
  -H "Content-Type: application/json")

FOUND=$(echo "$VERIFY" | jq -r '.result // empty | .id')

if [ -z "$FOUND" ]; then
  echo "Verificacao: record nao existe mais (OK)"
else
  echo "AVISO: Record ainda aparece na API. A propagacao pode tardar."
fi
```

## Exemplo Bom

```bash
#!/usr/bin/env bash
set -euo pipefail

DOMAIN="${1:-}"
RECORD_ID="${2:-}"

if [ -z "$DOMAIN" ] || [ -z "$RECORD_ID" ]; then
  echo "Uso: $0 <domain> <record_id> [--yes]"
  echo "Exemplo: $0 example.com rec_abc123def456 --yes"
  exit 1
fi

TOKEN=$(bash ~/Sistemas/claude-ai-tips/global/skills/cred-store/scripts/resolve.sh cloudflare.idcbr.api_token)
ZONE_ID=$(curl -s -X GET "https://api.cloudflare.com/client/v4/zones?name=${DOMAIN}" \
  -H "Authorization: Bearer ${TOKEN}" \
  -H "Content-Type: application/json" | jq -r '.result[0].id')

# DRY-RUN DEFAULT
if [[ "${3:-}" != "--apply" ]]; then
  RECORD=$(curl -s -X GET "https://api.cloudflare.com/client/v4/zones/${ZONE_ID}/dns_records/${RECORD_ID}" \
    -H "Authorization: Bearer ${TOKEN}" \
    -H "Content-Type: application/json")

  echo "=== DRY-RUN: Record que seria deletado ==="
  echo "$RECORD" | jq -r '.result | "ID: \(.id)\nType: \(.type)\nName: \(.name)\nContent: \(.content)"'
  echo ""
  echo "Execute com --apply para confirmar a remocao."
  exit 0
fi

# BACKUP antes de deletar em prod
BACKUP_FILE="/tmp/dns-backup-$(date +%Y%m%d-%H%M%S).json"
curl -s -X GET "https://api.cloudflare.com/client/v4/zones/${ZONE_ID}/dns_records?per_page=100" \
  -H "Authorization: Bearer ${TOKEN}" \
  -H "Content-Type: application/json" | jq '.result' > "$BACKUP_FILE"
echo "Backup: $BACKUP_FILE"

# DELETE
RESPONSE=$(curl -s -X DELETE "https://api.cloudflare.com/client/v4/zones/${ZONE_ID}/dns_records/${RECORD_ID}" \
  -H "Authorization: Bearer ${TOKEN}" \
  -H "Content-Type: application/json")

if [ "$(echo "$RESPONSE" | jq -r '.success')" = "true" ]; then
  echo "Record deletado: $RECORD_ID"
  echo "$(date -u +%Y-%m-%dT%H:%M:%SZ) DELETE $RECORD_ID (zone: $ZONE_ID)" >> ~/.claude/credentials/cloudflare/audit.log
else
  echo "Erro: $(echo "$RESPONSE" | jq -r '.errors[0].message')"
  exit 1
fi
```

## Exemplo Ruim

```bash
# ERRO CRITICO: Deletar sem backup (producao)
curl -s -X DELETE ".../dns_records/${RECORD_ID}" -H "Authorization: Bearer $TOKEN"
# Se algo der errado, nao ha como fazer rollback

# ERRO: Deletar sem confirmar (perigoso em producao)
curl -s -X DELETE ".../dns_records/${RECORD_ID}" -H "Authorization: Bearer $TOKEN"
# Sem dry-run, sem prompt — pode deletar record errado

# ERRO: Confundir record_id com zone_id
# Deletar usando zone_id retorna 400, mas se funcionar (raro), deleta TODA a zone

# ERRO: Deletar sem verificar NS records
# NS records nao podem ser deletados via API (so dashboard)
# Mas outros records dependentes de NS podem causar issues
```

## Gotchas

1. **NS records nao deletaveis via API** — Tentativas retornam 400.
   Deletar NS precisa ser feito pelo Dashboard (mas isso raramente faz sentido).

2. **Sem backup = sem rollback** — A Cloudflare nao tem "lixeira" para DNS.
   Uma vez deletado, o record so pode ser recriado manualmente.

3. **CNAME deletion pode quebrar dependents** — Se outros records apontam
   para o CNAME sendo deletado, eles ficarao quebrados apos a remocao.

4. **MX deletion pode causar bounce** — Se o record MX for deletado,
   emails para esse dominio serao rejeitados/bounced.

5. **Dry-run como default** — Sempre valide o record antes de deletar.
   Use `--apply` ou `--yes` apenas quando tiver certeza.

6. **Audit trail obrigatorio** — Log todas as remocoes com timestamp,
   record_id, zone_id e operador (quem solicitou).

7. **Rate limit 1200/5min** — mesmo em delete; se批量 delete,
   use sleep entre chamadas.

## Quando NAO Usar

- **Listar records** → `dns-list-records`
- **Criar record** → `dns-add-record`
- **Atualizar record** → `dns-update-record`
- **Auditar zone** → `dns-audit`
- **Migrar zone** → `dns-migrate-zone`
