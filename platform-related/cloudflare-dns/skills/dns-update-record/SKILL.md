---
name: dns-update-record
description: |
  Atualiza um DNS record existente (PATCH parcial ou PUT total).
  Use quando o usuario mencionar: "update dns", "editar dns", "modificar dns record",
  "patch dns", "alterar record dns", "atualizar dns".
  Nao use para criar records novos ou deletar existentes.
allowed-tools:
  - Bash
  - Glob
  - Grep
  - Read
---

# dns-update-record

Atualiza um DNS record existente em uma zone da Cloudflare via API v4,
suportando PATCH (parcial) e PUT (substituicao total).

## Pre-flight

### 1. Identificar zone_id e record_id

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

### 2. Buscar record por nome + tipo (se nao tem id)

```bash
# Quando只知道 name e type, mas nao record_id
NAME="api.example.com"
TYPE="A"

RECORD_ID=$(curl -s -X GET "https://api.cloudflare.com/client/v4/zones/${ZONE_ID}/dns_records?name=${NAME}&type=${TYPE}&per_page=1" \
  -H "Authorization: Bearer ${TOKEN}" \
  -H "Content-Type: application/json" | jq -r '.result[0].id')

echo "Record ID: $RECORD_ID"
```

## Workflow

### Passo 1 — GET record atual (obrigatorio antes de modificar)

```bash
RECORD_ID="abc123def456"

CURRENT=$(curl -s -X GET "https://api.cloudflare.com/client/v4/zones/${ZONE_ID}/dns_records/${RECORD_ID}" \
  -H "Authorization: Bearer ${TOKEN}" \
  -H "Content-Type: application/json")

echo "Estado atual:"
echo "$CURRENT" | jq '{id, type, name, content, ttl, proxied, modified_at}'
```

### Passo 2 — Mostrar diff ao usuario (confirmacao)

```bash
echo "=== Mudancas propostas ==="
echo "Type:  $(echo "$CURRENT" | jq -r '.result.type')"
echo "Name:  $(echo "$CURRENT" | jq -r '.result.name')"
echo "Content ATUAL:  $(echo "$CURRENT" | jq -r '.result.content')"
echo "Content NOVO:   $NEW_CONTENT"
echo "TTL ATUAL:  $(echo "$CURRENT" | jq -r '.result.ttl')"
echo "TTL NOVO:   $NEW_TTL"
echo "Proxied ATUAL: $(echo "$CURRENT" | jq -r '.result.proxied')"
echo "Proxied NOVO:  $NEW_PROXIED"
```

### Passo 3 — Escolher metodo

| Metodo | Quando usar | Comportamento |
|--------|-------------|---------------|
| **PATCH** | Mudar 1-2 campos | Envia apenas campos que mudam; o resto permanece |
| **PUT** | Substituicao total | Substitui todos os campos; campos omitidos voltam ao default |

### Passo 4 — PATCH (update parcial)

```bash
# Mudar apenas content e ttl
RECORD_ID="abc123def456"
NEW_CONTENT="203.0.113.20"
NEW_TTL=600

RESPONSE=$(curl -s -X PATCH "https://api.cloudflare.com/client/v4/zones/${ZONE_ID}/dns_records/${RECORD_ID}" \
  -H "Authorization: Bearer ${TOKEN}" \
  -H "Content-Type: application/json" \
  -d "$(jq -n \
    --arg content "$NEW_CONTENT" \
    --argjson ttl "$NEW_TTL" \
    '{content: $content, ttl: $ttl}')")

if [ "$(echo "$RESPONSE" | jq -r '.success')" = "true" ]; then
  echo "Record atualizado:"
  echo "$RESPONSE" | jq '.result | {id, type, name, content, ttl, proxied}'
else
  echo "Erro: $(echo "$RESPONSE" | jq -r '.errors[0].message')"
  exit 1
fi
```

### Passo 5 — PUT (substituicao total)

```bash
# Substituir todos os campos (exceto id, created_at, zone_id)
RECORD_ID="abc123def456"

RESPONSE=$(curl -s -X PUT "https://api.cloudflare.com/client/v4/zones/${ZONE_ID}/dns_records/${RECORD_ID}" \
  -H "Authorization: Bearer ${TOKEN}" \
  -H "Content-Type: application/json" \
  -d "$(jq -n \
    --arg type "$(echo "$CURRENT" | jq -r '.result.type')" \
    --arg name "$(echo "$CURRENT" | jq -r '.result.name')" \
    --arg content "$NEW_CONTENT" \
    --argjson ttl "$NEW_TTL" \
    --argjson proxied "$(echo "$CURRENT" | jq -r '.result.proxied')" \
    '{type: $type, name: $name, content: $content, ttl: $ttl, proxied: $proxied}')")

echo "$RESPONSE" | jq '.result | {id, type, name, content, ttl, proxied}'
```

## Exemplo Bom

```bash
#!/usr/bin/env bash
set -euo pipefail

DOMAIN="example.com"
RECORD_ID="${1:-}"  # Passar como argumento: ./update.sh <record_id>

TOKEN=$(bash ~/Sistemas/claude-ai-tips/global/skills/cred-store/scripts/resolve.sh cloudflare.idcbr.api_token)
ZONE_ID=$(curl -s -X GET "https://api.cloudflare.com/client/v4/zones?name=${DOMAIN}" \
  -H "Authorization: Bearer ${TOKEN}" \
  -H "Content-Type: application/json" | jq -r '.result[0].id')

# Buscar record atual
CURRENT=$(curl -s -X GET "https://api.cloudflare.com/client/v4/zones/${ZONE_ID}/dns_records/${RECORD_ID}" \
  -H "Authorization: Bearer ${TOKEN}" \
  -H "Content-Type: application/json")

if [ "$(echo "$CURRENT" | jq -r '.success')" != "true" ]; then
  echo "Record nao encontrado: $RECORD_ID"
  exit 1
fi

# Mostrar estado atual
echo "=== Record Atual ==="
echo "$CURRENT" | jq -r '.result | "ID: \(.id)\nType: \(.type)\nName: \(.name)\nContent: \(.content)\nTTL: \(.ttl)\nProxied: \(.proxied)\nModificado: \(.modified_at)"'

# PATCH apenas os campos que o usuario forneceu
NEW_CONTENT="203.0.113.30"
NEW_TTL=1200

RESPONSE=$(curl -s -X PATCH "https://api.cloudflare.com/client/v4/zones/${ZONE_ID}/dns_records/${RECORD_ID}" \
  -H "Authorization: Bearer ${TOKEN}" \
  -H "Content-Type: application/json" \
  -d "$(jq -n \
    --arg content "$NEW_CONTENT" \
    --argjson ttl "$NEW_TTL" \
    '{content: $content, ttl: $ttl}')")

if [ "$(echo "$RESPONSE" | jq -r '.success')" = "true" ]; then
  echo ""
  echo "=== Record Atualizado ==="
  echo "$RESPONSE" | jq -r '.result | "ID: \(.id)\nContent: \(.content)\nTTL: \(.ttl)"'
else
  echo "Erro: $(echo "$RESPONSE" | jq -r '.errors[0].message')"
  exit 1
fi
```

## Exemplo Ruim

```bash
# ERRO: PUT sem enviar todos os campos (campos omitidos voltam ao default)
# Ex: omitting priority on MX record -> priority=0 (email disabled!)
curl -s -X PUT ".../dns_records/${RECORD_ID}" \
  -H "Authorization: Bearer ${TOKEN}" \
  -H "Content-Type: application/json" \
  -d '{"type":"MX","name":"example.com","content":"mail.example.com","ttl":300}'
# priority e caa_tag faltando -> revertidos para defaults

# ERRO: PATCH sem GET previo (nao sabe estado atual)
# Pode inadvertidamente sobrescrever campos sem querer

# ERRO: Mudar proxied=true para proxied=false em A record com SSL existente
# SSL certificate da Cloudflare pode Invalidar se o trafego sair do proxy
```

## Gotchas

1. **PATCH vs PUT** — PATCH envia apenas campos a alterar (parcial);
   PUT substitui todos os campos (full replace). Use PATCH para mudancas
   pequenas, PUT para migracao de values completos.

2. **Proxied toggle quebra SSL** — Trocar de `proxied=true` para
   `proxied=false` remove o trafego do proxy Cloudflare, o que invalida
   certificados Universal SSL. Planeje a mudanca com antecedencia.

3. **TTL change pode demorar** — Se o TTL anterior era alto (ex: 86400s)
   e voce mudou para baixo, a propagacao pode levar ate o TTL antigo
   para invalidate cache. Use `proxied=false` TTL=120 para testes rapidos.

4. **Content change em CNAME** — Trocar o target de um CNAME pode
   requerer purge do Cloudflare cache para evitar servir old target.

5. **NS records nao editaveis via API** — NS records sao gerenciados
   automaticamente. Tentativa de PUT/PATCH em NS retornara 400.

6. **MX priority revertida** — Se usar PUT em MX sem especificar
   priority, ela volta para 0, desabilitando email.

7. **Rate limit** — 1200 req/5min. Updates em batch devem usar sleep
   de 250ms+ entre chamadas para evitar 429.

## Quando NAO Usar

- **Criar record** → `dns-add-record`
- **Listar records** → `dns-list-records`
- **Deletar record** → `dns-delete-record`
- **Auditar zone** → `dns-audit`
- **Migrar zone** → `dns-migrate-zone`
