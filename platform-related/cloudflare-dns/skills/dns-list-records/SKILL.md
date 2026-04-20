---
name: dns-list-records
description: |
  Lista todos os DNS records de uma zone com suporte a paginacao e filtros.
  Use quando o usuario mencionar: "list dns", "listar dns", "ver records dns",
  "dns records cloudflare", "listar zone dns", "get dns records".
  Nao use para criar, editar ou deletar records (veja dns-add-record,
  dns-update-record, dns-delete-record).
allowed-tools:
  - Bash
  - Glob
  - Grep
  - Read
---

# dns-list-records

Lista registros DNS de uma zone na Cloudflare via API v4, com paginacao
automática e filtros combináveis.

## Pre-flight

### 1. Identificar a zone

**Opcao A — via `wrangler whoami`** (mais rapido):
```bash
wrangler whoami 2>/dev/null | grep -E 'zone|id' | head -5
```

**Opcao B — via API com busca por nome**:
```bash
# Buscar zone_id pelo nome de dominio
curl -s -X GET "https://api.cloudflare.com/client/v4/zones?name=example.com" \
  -H "Authorization: Bearer $CF_API_TOKEN" \
  -H "Content-Type: application/json" | jq '.result[] | {id, name, status}'
```

**Opcao C — listar todas as zones da conta**:
```bash
curl -s -X GET "https://api.cloudflare.com/client/v4/zones?per_page=50" \
  -H "Authorization: Bearer $CF_API_TOKEN" \
  -H "Content-Type: application/json" | jq '.result[] | {id, name}'
```

Guarde o `zone_id` — todas as operacoes DNS subsequentes dependem dele.

### 2. Validar credencial

```bash
curl -s -X GET "https://api.cloudflare.com/client/v4/user" \
  -H "Authorization: Bearer $CF_API_TOKEN" \
  -H "Content-Type: application/json" | jq '.result.email'
```

Se retornar vazio ou erro 401, a credencial esta invalida. Use
`cloudflare-shared/skills/cf-credentials-setup/` para reconfigurar.

### 3. Instalar dependencias

```bash
command -v jq >/dev/null || brew install jq
command -v curl >/dev/null || echo "curl ja disponivel"
```

## Workflow

### Passo 1 — Listar sem filtros (paginacao completa)

```bash
ZONE_ID="abc123def456"
TOKEN="•••"

# Primeira pagina
curl -s -X GET "https://api.cloudflare.com/client/v4/zones/${ZONE_ID}/dns_records?per_page=100&page=1" \
  -H "Authorization: Bearer ${TOKEN}" \
  -H "Content-Type: application/json" | jq '.'
```

Resposta esperada:
```json
{
  "result": [
    {
      "id": "rec_id_1",
      "type": "A",
      "name": "api.example.com",
      "content": "203.0.113.10",
      "ttl": 300,
      "proxied": true,
      "created_at": "2024-01-15T10:00:00Z",
      "modified_at": "2024-06-20T14:30:00Z"
    }
  ],
  "result_info": {
    "page": 1,
    "per_page": 100,
    "total_pages": 3,
    "total_records": 245
  },
  "success": true,
  "errors": [],
  "messages": []
}
```

### Passo 2 — Calcular paginas totais

```bash
TOTAL_PAGES=$(curl -s -X GET "https://api.cloudflare.com/client/v4/zones/${ZONE_ID}/dns_records?per_page=100&page=1" \
  -H "Authorization: Bearer ${TOKEN}" \
  -H "Content-Type: application/json" | jq '.result_info.total_pages')

echo "Pages: $TOTAL_PAGES"
```

### Passo 3 — Iterar todas as paginas

```bash
# Loop para coletar todos os records
ALL_RECORDS=()
for PAGE in $(seq 1 "$TOTAL_PAGES"); do
  RESPONSE=$(curl -s -X GET "https://api.cloudflare.com/client/v4/zones/${ZONE_ID}/dns_records?per_page=100&page=${PAGE}" \
    -H "Authorization: Bearer ${TOKEN}" \
    -H "Content-Type: application/json")
  RECORDS=$(echo "$RESPONSE" | jq -r '.result[] | @json')
  ALL_RECORDS+=("$RECORDS")
  # Rate limit: 1200 req/5min — espaçar se muitas pages
  [ "$PAGE" -lt "$TOTAL_PAGES" ] && sleep 0.3
done
```

### Passo 4 — Aplicar filtros (opcional)

**Por tipo**:
```bash
curl -s -X GET "https://api.cloudflare.com/client/v4/zones/${ZONE_ID}/dns_records?type=A&per_page=100" \
  -H "Authorization: Bearer ${TOKEN}" \
  -H "Content-Type: application/json" | jq '.result[] | select(.type=="A") | {id, name, content, proxied}'
```

**Por nome (contem)**:
```bash
curl -s -X GET "https://api.cloudflare.com/client/v4/zones/${ZONE_ID}/dns_records?name=api&per_page=100" \
  -H "Authorization: Bearer ${TOKEN}" \
  -H "Content-Type: application/json" | jq '.result[] | select(.name | contains("api"))'
```

**Filtros combinados** (type + name):
```bash
curl -s -X GET "https://api.cloudflare.com/client/v4/zones/${ZONE_ID}/dns_records?type=CNAME&name=www&per_page=100" \
  -H "Authorization: Bearer ${TOKEN}" \
  -H "Content-Type: application/json" | jq '.result[]'
```

### Passo 5 — Output formatado

```bash
# Tabela simples (id | type | name | content | ttl | proxied)
echo "ID                           | TYPE | NAME                     | CONTENT          | TTL  | PROXIED"
echo "-----------------------------|------|--------------------------|------------------|------|--------"
curl -s -X GET "https://api.cloudflare.com/client/v4/zones/${ZONE_ID}/dns_records?per_page=100" \
  -H "Authorization: Bearer ${TOKEN}" \
  -H "Content-Type: application/json" | jq -r '.result[] | "\(.id) | \(.type) | \(.name) | \(.content) | \(.ttl) | \(.proxied)"'
```

## Exemplo Bom

```bash
#!/usr/bin/env bash
# Listar todos os records da zone example.com com output formatado

set -euo pipefail

TOKEN=$(bash ~/Sistemas/claude-ai-tips/global/skills/cred-store/scripts/resolve.sh cloudflare.idcbr.api_token)
ZONE_ID=$(curl -s -X GET "https://api.cloudflare.com/client/v4/zones?name=example.com" \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" | jq -r '.result[0].id')

echo "=== DNS Records: example.com ==="
echo "Zone ID: $ZONE_ID"
echo ""

# Coletar todas as paginas
declare -a ALL_JSON=()
PAGE=1
while true; do
  RESP=$(curl -s -X GET "https://api.cloudflare.com/client/v4/zones/${ZONE_ID}/dns_records?per_page=100&page=${PAGE}" \
    -H "Authorization: Bearer ${TOKEN}" \
    -H "Content-Type: application/json")
  
  TOTAL=$(echo "$RESP" | jq '.result_info.total_records')
  ALL_JSON+=$(echo "$RESP" | jq -r '.result | length')
  
  PER_PAGE=$(echo "$RESP" | jq '.result_info.per_page')
  TOTAL_PAGES=$(echo "$RESP" | jq '.result_info.total_pages')
  
  echo "$RESP" | jq -r '.result[] | "\(.id) | \(.type) | \(.name) | \(.content) | \(.ttl) | \(.proxied)"'
  
  [ "$PAGE" -ge "$TOTAL_PAGES" ] && break
  PAGE=$((PAGE + 1))
  sleep 0.25
done

echo ""
echo "Total records: $(echo "${ALL_JSON[*]}" | awk '{s+=$1}END{print s}')"
```

## Exemplo Ruim

```bash
# ERRO COMUM: Listar apenas pagina 1 sem paginacao
curl -s -X GET "https://api.cloudflare.com/client/v4/zones/${ZONE_ID}/dns_records" \
  -H "Authorization: Bearer ${TOKEN}" | jq '.result'
# Retorna no maximo 100 records — pode estar truncado!

# ERRO COMUM: Não handle rate limit
for PAGE in {1..50}; do
  curl ... # Sem sleep — vai atingir rate limit em 5min
done
```

## Gotchas

1. **Paginacao maxima: 100 por pagina** — A API nunca retorna mais de 100
   records por request. Se a zone tem 500+ records, iterar todas as paginas
   eh obrigatorio.

2. **TTL=1 significa "automatic"** — Cloudflare gerencia o TTL automaticamente.
   Nao significa TTL de 1 segundo.

3. **`proxied: true` vs `false`** — `true` = трафíc через proxy Cloudflare
   (protecao DDoS, cache, etc.). `false` = DNS "nú" (apenas resolution).

4. **Rate limit: 1200 req/5min** — Em zones com muitas paginas, espacar
   requests com `sleep 0.25` ou `0.3` entre chamadas para evitar 429.

5. **Filtros `name` sao prefix-only** — `?name=api` matcha `api.example.com`
   mas NAO `beta.api.example.com` (subdominio mais profundo).

6. **Filtros `type` sao exact-match** — `?type=a` nao funciona; use
   maiusculas: `?type=A`.

7. **Page `result_info.total_records`** — Use este campo, nao `length(result)`,
   porque a ultima pagina pode ter menos de 100 records.

## Quando NAO Usar

- **Criar record** → `dns-add-record`
- **Editar record existente** → `dns-update-record`
- **Deletar record** → `dns-delete-record`
- **Auditar security (SPF/DKIM/DMARC)** → `dns-audit`
- **Migrar zone entre accounts** → `dns-migrate-zone`

## Ver tambem

- [cloudflare-shared/skills/cf-api-call/](../cloudflare-shared/skills/cf-api-call/) — wrapper REST com retry e rate-limit
- [cloudflare-shared/references/api-endpoint-catalog.md](../cloudflare-shared/references/api-endpoint-catalog.md) — endpoints DNS
- `dns-audit` — auditoria completa de security e hygiene
