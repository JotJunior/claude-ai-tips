---
name: dns-migrate-zone
description: |
  Migra uma zone DNS entre contas Cloudflare (export + import).
  Use quando o usuario mencionar: "migrate zone", "migrar dns zone", "transferir zone cloudflare",
  "move zone between accounts", "export zone dns".
  Nao use para operacoes single-record.
allowed-tools:
  - Bash
  - Glob
  - Grep
  - Read
---

# dns-migrate-zone

Migra uma zone DNS completa entre contas Cloudflare, realizando export
da zone origen, backup, import no destino, validacao de paridade e
ativacao gradual com corte ao final.

## Pre-flight

### 1. Verificar prerrequisitos

```bash
# Token da conta origem com Zone:DNS:Read
TOKEN_SRC=$(bash ~/Sistemas/claude-ai-tips/global/skills/cred-store/scripts/resolve.sh cloudflare.src.api_token)

# Token da conta destino com Zone:DNS:Edit
TOKEN_DST=$(bash ~/Sistemas/claude-ai-tips/global/skills/cred-store/scripts/resolve.sh cloudflare.dst.api_token)

# Verificar se tokens tem as permissoes corretas
echo "Conta origem:"
curl -s -X GET "https://api.cloudflare.com/client/v4/user" \
  -H "Authorization: Bearer ${TOKEN_SRC}" | jq '.result.email'

echo "Conta destino:"
curl -s -X GET "https://api.cloudflare.com/client/v4/user" \
  -H "Authorization: Bearer ${TOKEN_DST}" | jq '.result.email'
```

### 2. Identificar zone origen

```bash
DOMAIN="example.com"

ZONE_ID_SRC=$(curl -s -X GET "https://api.cloudflare.com/client/v4/zones?name=${DOMAIN}" \
  -H "Authorization: Bearer ${TOKEN_SRC}" \
  -H "Content-Type: application/json" | jq -r '.result[0].id')

echo "Zone origem: $ZONE_ID_SRC"
```

### 3. Verificar DNSSEC status

```bash
DNSSEC_SRC=$(curl -s -X GET "https://api.cloudflare.com/client/v4/zones/${ZONE_ID_SRC}/dnssec" \
  -H "Authorization: Bearer ${TOKEN_SRC}" \
  -H "Content-Type: application/json" | jq '.result.status')

echo "DNSSEC origem: $DNSSEC_SRC"
```

## Workflow

### Fase 1 — Export da zone origen

```bash
# Export completo (todas as paginas)
export_zone() {
  local ZONE_ID="$1"
  local TOKEN="$2"
  
  declare -a ALL_RECORDS=()
  PAGE=1
  
  while true; do
    RESP=$(curl -s -X GET "https://api.cloudflare.com/client/v4/zones/${ZONE_ID}/dns_records?per_page=100&page=${PAGE}" \
      -H "Authorization: Bearer ${TOKEN}" \
      -H "Content-Type: application/json")
    
    COUNT=$(echo "$RESP" | jq '.result | length')
    [ "$COUNT" -eq 0 ] && break
    
    echo "$RESP" | jq -r '.result[] | @json' >> /tmp/zone-export-temp.json
    TOTAL_PAGES=$(echo "$RESP" | jq '.result_info.total_pages')
    
    [ "$PAGE" -ge "$TOTAL_PAGES" ] && break
    PAGE=$((PAGE + 1))
    sleep 0.2
  done
  
  # Parse para array
  jq -s '.' /tmp/zone-export-temp.json > /tmp/zone-export.json
  rm /tmp/zone-export-temp.json
  
  echo "Records exportados: $(jq '. | length' /tmp/zone-export.json)"
}

export_zone "$ZONE_ID_SRC" "$TOKEN_SRC"
```

### Fase 2 — Backup local

```bash
BACKUP_FILE="zone-backup-${DOMAIN}-$(date +%Y%m%d-%H%M%S).json"

# Incluir metadados da zone
jq -n \
  --arg domain "$DOMAIN" \
  --arg zone_id "$ZONE_ID_SRC" \
  --arg timestamp "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
  --arg dnssec "$DNSSEC_SRC" \
  --argjson records "$(cat /tmp/zone-export.json)" \
  '{domain: $domain, zone_id: $zone_id, exported_at: $timestamp, dnssec_status: $dnssec, records: $records}' > "$BACKUP_FILE"

echo "Backup salvo em: $BACKUP_FILE"
echo "Tamanho: $(wc -c < "$BACKUP_FILE") bytes"
```

### Fase 3 — Criar zone no destino

```bash
# Verificar se zone ja existe no destino
ZONE_EXISTS=$(curl -s -X GET "https://api.cloudflare.com/client/v4/zones?name=${DOMAIN}" \
  -H "Authorization: Bearer ${TOKEN_DST}" \
  -H "Content-Type: application/json" | jq '.result | length')

if [ "$ZONE_EXISTS" -gt 0 ]; then
  echo "ALERTA: Zone ${DOMAIN} ja existe na conta destino"
  ZONE_ID_DST=$(curl -s -X GET "https://api.cloudflare.com/client/v4/zones?name=${DOMAIN}" \
    -H "Authorization: Bearer ${TOKEN_DST}" \
    -H "Content-Type: application/json" | jq -r '.result[0].id')
  echo "Zone ID destino: $ZONE_ID_DST"
else
  echo "Criando zone ${DOMAIN} na conta destino..."
  CREATE_RESP=$(curl -s -X POST "https://api.cloudflare.com/client/v4/zones" \
    -H "Authorization: Bearer ${TOKEN_DST}" \
    -H "Content-Type: application/json" \
    -d "$(jq -n --arg name "$DOMAIN" '{name: $name, jump_start: false}')")
  
  if [ "$(echo "$CREATE_RESP" | jq -r '.success')" = "true" ]; then
    ZONE_ID_DST=$(echo "$CREATE_RESP" | jq -r '.result.id')
    echo "Zone criada: $ZONE_ID_DST"
  else
    echo "Erro ao criar zone: $(echo "$CREATE_RESP" | jq -r '.errors[0].message')"
    exit 1
  fi
fi
```

### Fase 4 — Configurar NS records no registrar

```bash
# Obter NS records da nova zone
NS_RECORDS=$(curl -s -X GET "https://api.cloudflare.com/client/v4/zones/${ZONE_ID_DST}/dns_records?type=NS&name=${DOMAIN}&per_page=5" \
  -H "Authorization: Bearer ${TOKEN_DST}" \
  -H "Content-Type: application/json" | jq -r '.result[] | .content')

echo "=== NS Records da nova zone (configurar no registrar) ==="
echo "$NS_RECORDS" | while read -r ns; do echo "  $ns"; done
echo ""
echo "ATENCAO: Altere os NS no registrador antes de continuar."
echo "A propagacao pode levar 24-48h."
```

### Fase 5 — Importar records (exceto SOA/NS)

```bash
IMPORT_FILE="/tmp/zone-import.json"

# Filtrar records que nao devem ser importados
# SOA e NS sao auto-gerenciados pelo Cloudflare
jq '[.[] | select(.type != "SOA" and .type != "NS")]' /tmp/zone-export.json > "$IMPORT_FILE"

IMPORT_COUNT=$(jq '. | length' "$IMPORT_FILE")
echo "Records a importar: $IMPORT_COUNT"

SUCCESS=0
FAIL=0
declare -a FAIL_RECORDS=()

for rec in $(jq -r '.[] | @json' "$IMPORT_FILE"); do
  TYPE=$(echo "$rec" | jq -r '.type')
  NAME=$(echo "$rec" | jq -r '.name')
  
  # Pular proxied para records que nao suportam
  PROXIED=$(echo "$rec" | jq -r '.proxied')
  if [ "$TYPE" = "MX" ] || [ "$TYPE" = "TXT" ] || [ "$TYPE" = "SRV" ] || [ "$TYPE" = "CAA" ]; then
    PROXIED="false"
  fi
  
  PAYLOAD=$(echo "$rec" | jq --argjson proxied "$PROXIED" '. + {proxied: $proxied}')
  
  RESP=$(curl -s -X POST "https://api.cloudflare.com/client/v4/zones/${ZONE_ID_DST}/dns_records" \
    -H "Authorization: Bearer ${TOKEN_DST}" \
    -H "Content-Type: application/json" \
    -d "$PAYLOAD")
  
  if [ "$(echo "$RESP" | jq -r '.success')" = "true" ]; then
    SUCCESS=$((SUCCESS + 1))
  else
    FAIL=$((FAIL + 1))
    ERROR_MSG=$(echo "$RESP" | jq -r '.errors[0].message')
    FAIL_RECORDS+=("$TYPE $NAME: $ERROR_MSG")
  fi
  
  # Rate limit: 1200 req/5min
  sleep 0.25
done

echo ""
echo "=== Importacao concluida ==="
echo "Sucesso: $SUCCESS"
echo "Falhas: $FAIL"
if [ ${#FAIL_RECORDS[@]} -gt 0 ]; then
  echo "Detalhes:"
  printf '%s\n' "${FAIL_RECORDS[@]}" | head -20
fi
```

### Fase 6 — Validar paridade

```bash
# Comparar counts por tipo
echo "=== Validacao de Paridade ==="

echo "Type | Origem | Destino | Status"
echo "-----|--------|---------|--------"

for type in A AAAA CNAME MX TXT SRV CAA; do
  SRC_COUNT=$(jq "[.[] | select(.type == \"$type\")] | length" /tmp/zone-export.json)
  DST_COUNT=$(curl -s -X GET "https://api.cloudflare.com/client/v4/zones/${ZONE_ID_DST}/dns_records?type=${type}&per_page=1" \
    -H "Authorization: Bearer ${TOKEN_DST}" \
    -H "Content-Type: application/json" | jq '.result_info.total_records')
  
  if [ "$SRC_COUNT" -eq "$DST_COUNT" ]; then
    STATUS="OK"
  else
    STATUS="DIFERENCA"
  fi
  
  echo "$type | $SRC_COUNT | $DST_COUNT | $STATUS"
done
```

### Fase 7 — Aguardar propagacao DNS

```bash
echo ""
echo "=== Aguardando propagacao DNS ==="
echo "Propagacao tipica: 24-48h"
echo "Use 'dig NS ${DOMAIN}' para verificar o status."
echo ""
echo "Ate a propagacao completa, ambos os sets de NS funcionarao."
echo "Apos confirmacao, proceeda para cleanup."
```

### Fase 8 — Cleanup (delete zone origen)

```bash
# SOLO APOS confirmacao de que nova zone esta ativa e resolving
echo "ALERTA: Esta operacao e IRREVERSIVEL"
echo ""
echo "Confirme que:"
echo "1. NS no registrador aponta para a nova account"
echo "2. DNS resolution esta funcionando para a nova zone"
echo "3. DNSSEC foi reconfigurado na nova account"
echo ""
read -p "Digite '${DOMAIN}' para confirmar exclusao da zone origen: " CONFIRM

if [ "$CONFIRM" != "$DOMAIN" ]; then
  echo "Operacao cancelada."
  exit 0
fi

# Desabilitar DNSSEC na origem antes de deletar
curl -s -X DELETE "https://api.cloudflare.com/client/v4/zones/${ZONE_ID_SRC}/dnssec" \
  -H "Authorization: Bearer ${TOKEN_SRC}" \
  -H "Content-Type: application/json"

# Deletar zone origen
RESP=$(curl -s -X DELETE "https://api.cloudflare.com/client/v4/zones/${ZONE_ID_SRC}" \
  -H "Authorization: Bearer ${TOKEN_SRC}" \
  -H "Content-Type: application/json")

if [ "$(echo "$RESP" | jq -r '.success')" = "true" ]; then
  echo "Zone origen deletada."
else
  echo "Erro ao deletar zone origen: $(echo "$RESP" | jq -r '.errors[0].message')"
fi
```

## Exemplo Bom

```bash
#!/usr/bin/env bash
set -euo pipefail

DOMAIN="${1:-}"
MODE="${2:-dry-run}"

if [ -z "$DOMAIN" ]; then
  echo "Uso: $0 <domain> [dry-run|validate|import|cleanup]"
  echo "Exemplo: $0 example.com dry-run"
  exit 1
fi

TOKEN_SRC=$(bash ~/Sistemas/claude-ai-tips/global/skills/cred-store/scripts/resolve.sh cloudflare.src.api_token)
TOKEN_DST=$(bash ~/Sistemas/claude-ai-tips/global/skills/cred-store/scripts/resolve.sh cloudflare.dst.api_token)

# Identificar zones
ZONE_ID_SRC=$(curl -s -G "https://api.cloudflare.com/client/v4/zones" \
  --data-urlencode "name=${DOMAIN}" \
  -H "Authorization: Bearer ${TOKEN_SRC}" \
  -H "Content-Type: application/json" | jq -r '.result[0].id')

case "$MODE" in
  dry-run)
    echo "=== Dry-run: Validando prerrequisitos ==="
    DNSSEC_SRC=$(curl -s -X GET "https://api.cloudflare.com/client/v4/zones/${ZONE_ID_SRC}/dnssec" \
      -H "Authorization: Bearer ${TOKEN_SRC}" \
      -H "Content-Type: application/json" | jq '.result.status')
    echo "DNSSEC origem: $DNSSEC_SRC"
    echo "Zone ID origem: $ZONE_ID_SRC"
    
    # Count records
    REC_COUNT=$(curl -s -X GET "https://api.cloudflare.com/client/v4/zones/${ZONE_ID_SRC}/dns_records?per_page=1" \
      -H "Authorization: Bearer ${TOKEN_SRC}" \
      -H "Content-Type: application/json" | jq '.result_info.total_records')
    echo "Total records: $REC_COUNT"
    echo ""
    echo "Execute com 'import' para iniciar migracao."
    ;;
    
  validate)
    echo "=== Validacao: Paridade de records ==="
    # Comparar counts...
    ;;
    
  import)
    # Executar migracao completa
    ;;
    
  cleanup)
    # Cleanup da zone origen
    ;;
esac
```

## Exemplo Ruim

```bash
# ERRO: Nao aguardar propagacao NS
# NS change precisa de tempo para propagar
# Deletar zone muito cedo = downtime de DNS

# ERRO: Nao desabilitar DNSSEC antes de deletar
# DNSSEC chain quebrado = validacao falha por dias

# ERRO: Migrar Page Rules via DNS API
# Page Rules NAO migram via DNS API
# Precisa recriar manualmente no dashboard

# ERRO: Importar SOA/NS records
# SOA e NS sao auto-gerenciados
# Importalos causa conflitos

# ERRO: Migrar sem backup
# Backup local e obrigatorio para rollback

# ERRO: Nao reemitir SSL certs
# Universal SSL pode precisar reissue apos migracao
```

## Gotchas

1. **NS change leva 24-48h** — O TTL antigo persiste ate propagar.
   Nao	delete a zone origen ate ter certeza da propagacao.

2. **Zone activation requer NS no registrar** — Voce precisa configurar
   os NS da nova account no registrador antes da migracao fazer efeito.

3. **DNSSEC re-key obrigatorio** — Apos migracao, DNSSEC precisa ser
   reconfigurado (desabilitar na origem, habilitar no destino).

4. **Rate limit por zone** — 1200 req/5min por zone. Imports grandes
   devem usar sleep de 250ms+ entre requests.

5. **SOA/NS auto-managed** — Nao importar SOA e NS records. Eles sao
   gerenciados automaticamente pelo Cloudflare no destino.

6. **Page Rules nao migram** — Page Rules, Redirect Rules, Workers
   routes etc. NAO migram via DNS API. Precisa recriar manualmente.

7. **SSL certs precisam re-issue** — Aps migracao, Universal SSL
   certificates precisam ser revalidados. Pode causar interrupcao breve.

## Quando NAO Usar

- **Single record operations** → `dns-add-record`, `dns-update-record`
- **Auditar zone** → `dns-audit`
- **Bulk import entre zones da mesma account** → `dns-bulk-import`
