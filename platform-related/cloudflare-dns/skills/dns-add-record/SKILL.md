---
name: dns-add-record
description: |
  Cria um novo DNS record em uma zone existente na Cloudflare.
  Use quando o usuario mencionar: "add dns", "criar dns record", "novo dns",
  "add a record", "add cname record", "criar registro dns", "novo registro A".
  Nao use para listar, editar ou deletar records existentes.
allowed-tools:
  - Bash
  - Glob
  - Grep
  - Read
---

# dns-add-record

Cria um DNS record unico em uma zone da Cloudflare via API v4, validando
o payload conforme o tipo de record.

## Pre-flight

### 1. Identificar zone_id

```bash
# Buscar zone_id via nome do dominio
DOMAIN="example.com"
TOKEN=$(bash ~/Sistemas/claude-ai-tips/global/skills/cred-store/scripts/resolve.sh cloudflare.idcbr.api_token)

ZONE_ID=$(curl -s -X GET "https://api.cloudflare.com/client/v4/zones?name=${DOMAIN}" \
  -H "Authorization: Bearer ${TOKEN}" \
  -H "Content-Type: application/json" | jq -r '.result[0].id')

[ -z "$ZONE_ID" ] && echo "Zone nao encontrada: ${DOMAIN}" && exit 1
echo "Zone ID: $ZONE_ID"
```

### 2. Validar token e permissoes

```bash
curl -s -X GET "https://api.cloudflare.com/client/v4/user" \
  -H "Authorization: Bearer ${TOKEN}" | jq '.result.email, .result.account.id'
```

O token precisa do scope `Zone:DNS:Edit` para criar records.

### 3. Conhecer tipos de record e seus requisitos

| Tipo | Campos obrigatorios | Campos opcionais | Restricoes |
|------|---------------------|------------------|------------|
| A | `type=A`, `name`, `content` (IPv4) | `ttl`, `proxied` | content deve ser IPv4 valido |
| AAAA | `type=AAAA`, `name`, `content` (IPv6) | `ttl`, `proxied` | content deve ser IPv6 valido |
| CNAME | `type=CNAME`, `name`, `content` (FQDN) | `ttl`, `proxied` | Nao pode ter outros records no mesmo nome |
| MX | `type=MX`, `name`, `content`, `priority` | `ttl` | priority 0-65535, apex apenas |
| TXT | `type=TXT`, `name`, `content` | `ttl` | max 255 chars por string; usar array para strings longas |
| SRV | `type=SRV`, `name`, `content`, `priority`, `weight`, `port` | `ttl` | FQDN no content |
| CAA | `type=CAA`, `name`, `data: {flags, tag, value}` | `ttl` | issue/iodef/issuewild |
| NS | — | — | NS records sao gerenciados automaticamente pelo CF |

## Workflow

### Passo 1 — Validar payload

```bash
# Validacao basica para cada tipo
validate_payload() {
  local TYPE="$1"
  local NAME="$2"
  local CONTENT="$3"

  case "$TYPE" in
    A)
      [[ "$CONTENT" =~ ^([0-9]{1,3}\.){3}[0-9]{1,3}$ ]] || { echo "IPv4 invalido: $CONTENT"; return 1; }
      ;;
    AAAA)
      [[ "$CONTENT" =~ ^([0-9a-fA-F]{0,4}:){7}[0-9a-fA-F]{0,4}$ ]] || { echo "IPv6 invalido: $CONTENT"; return 1; }
      ;;
    CNAME)
      [[ "$CONTENT" =~ \..+$ ]] || { echo "CNAME precisa ser FQDN: $CONTENT"; return 1; }
      ;;
    TXT)
      [ ${#CONTENT} -gt 255 ] && { echo "TXT > 255 chars; sera dividido"; }
      ;;
    MX)
      [[ "$PRIORITY" =~ ^[0-9]+$ ]] || { echo "Priority deve ser numerico"; return 1; }
      ;;
    *)
      echo "Tipo '$TYPE' desconhecido ou nao suportado por esta skill"
      return 1
      ;;
  esac
}
```

### Passo 2 — Verificar record conflitante

```bash
# CNAME nao pode coexistir com outros types no mesmo nome
check_conflicts() {
  local ZONE_ID="$1"
  local NAME="$2"
  local TYPE="$3"

  EXISTING=$(curl -s -X GET "https://api.cloudflare.com/client/v4/zones/${ZONE_ID}/dns_records?name=${NAME}&type=${TYPE}&per_page=1" \
    -H "Authorization: Bearer ${TOKEN}" \
    -H "Content-Type: application/json" | jq '.result | length')

  if [ "$EXISTING" -gt 0 ]; then
    echo "CONFLITO: Ja existe record $TYPE para $NAME"
    return 1
  fi
}
```

### Passo 3 — Enviar POST

```bash
#Construir JSON conforme tipo
TYPE="A"
NAME="api.example.com"
CONTENT="203.0.113.10"
TTL=300
PROXIED=true

PAYLOAD=$(jq -n \
  --arg type "$TYPE" \
  --arg name "$NAME" \
  --arg content "$CONTENT" \
  --argjson ttl "$TTL" \
  --argjson proxied "$PROXIED" \
  '{type: $type, name: $name, content: $content, ttl: $ttl, proxied: $proxied}')

RESPONSE=$(curl -s -X POST "https://api.cloudflare.com/client/v4/zones/${ZONE_ID}/dns_records" \
  -H "Authorization: Bearer ${TOKEN}" \
  -H "Content-Type: application/json" \
  -d "$PAYLOAD")

echo "$RESPONSE" | jq '.'
```

### Passo 4 — Validar resposta

```bash
SUCCESS=$(echo "$RESPONSE" | jq '.success')
if [ "$SUCCESS" = "true" ]; then
  RECORD_ID=$(echo "$RESPONSE" | jq -r '.result.id')
  echo "Record criado com sucesso!"
  echo "ID: $RECORD_ID"
  echo "Type: $TYPE"
  echo "Name: $NAME"
  echo "Content: $CONTENT"
else
  ERROR=$(echo "$RESPONSE" | jq '.errors[0].message')
  echo "Erro ao criar record: $ERROR"
  exit 1
fi
```

## Exemplos por Tipo

### A Record (IPv4)

```bash
curl -s -X POST "https://api.cloudflare.com/client/v4/zones/${ZONE_ID}/dns_records" \
  -H "Authorization: Bearer ${TOKEN}" \
  -H "Content-Type: application/json" \
  -d '{
    "type": "A",
    "name": "api.example.com",
    "content": "203.0.113.10",
    "ttl": 300,
    "proxied": true
  }' | jq '.result | {id, type, name, content, ttl, proxied}'
```

### AAAA Record (IPv6)

```bash
curl -s -X POST "https://api.cloudflare.com/client/v4/zones/${ZONE_ID}/dns_records" \
  -H "Authorization: Bearer ${TOKEN}" \
  -H "Content-Type: application/json" \
  -d '{
    "type": "AAAA",
    "name": "api.example.com",
    "content": "2001:db8::10",
    "ttl": 300,
    "proxied": false
  }' | jq '.result'
```

### CNAME Record

```bash
curl -s -X POST "https://api.cloudflare.com/client/v4/zones/${ZONE_ID}/dns_records" \
  -H "Authorization: Bearer ${TOKEN}" \
  -H "Content-Type: application/json" \
  -d '{
    "type": "CNAME",
    "name": "www",
    "content": "api.example.com",
    "ttl": 300,
    "proxied": true
  }' | jq '.result'
```

### MX Record (com priority)

```bash
curl -s -X POST "https://api.cloudflare.com/client/v4/zones/${ZONE_ID}/dns_records" \
  -H "Authorization: Bearer ${TOKEN}" \
  -H "Content-Type: application/json" \
  -d '{
    "type": "MX",
    "name": "example.com",
    "content": "mail.example.com",
    "priority": 10,
    "ttl": 300
  }' | jq '.result'
```

### TXT Record (SPF multi-string)

```bash
# Strings > 255 chars devem ser divididas em array
curl -s -X POST "https://api.cloudflare.com/client/v4/zones/${ZONE_ID}/dns_records" \
  -H "Authorization: Bearer ${TOKEN}" \
  -H "Content-Type: application/json" \
  -d '{
    "type": "TXT",
    "name": "_dmarc.example.com",
    "content": "v=DMARC1; p=reject; rua=mailto:dmarc-reports@example.com; pct=100",
    "ttl": 300
  }' | jq '.result'
```

### SRV Record

```bash
curl -s -X POST "https://api.cloudflare.com/client/v4/zones/${ZONE_ID}/dns_records" \
  -H "Authorization: Bearer ${TOKEN}" \
  -H "Content-Type: application/json" \
  -d '{
    "type": "SRV",
    "name": "_sip._tcp.example.com",
    "content": "sip.example.com",
    "priority": 10,
    "weight": 5,
    "port": 5060,
    "ttl": 300
  }' | jq '.result'
```

### CAA Record

```bash
curl -s -X POST "https://api.cloudflare.com/client/v4/zones/${ZONE_ID}/dns_records" \
  -H "Authorization: Bearer ${TOKEN}" \
  -H "Content-Type: application/json" \
  -d '{
    "type": "CAA",
    "name": "example.com",
    "data": {
      "flags": 0,
      "tag": "issue",
      "value": "letsencrypt.org"
    },
    "ttl": 300
  }' | jq '.result'
```

## Exemplo Bom

```bash
#!/usr/bin/env bash
set -euo pipefail

DOMAIN="example.com"
TYPE="A"
NAME="api.${DOMAIN}"
CONTENT="203.0.113.10"
TTL=300
PROXIED=true

TOKEN=$(bash ~/Sistemas/claude-ai-tips/global/skills/cred-store/scripts/resolve.sh cloudflare.idcbr.api_token)
ZONE_ID=$(curl -s -X GET "https://api.cloudflare.com/client/v4/zones?name=${DOMAIN}" \
  -H "Authorization: Bearer ${TOKEN}" \
  -H "Content-Type: application/json" | jq -r '.result[0].id')

# Verificar duplicata
EXISTING=$(curl -s -G "https://api.cloudflare.com/client/v4/zones/${ZONE_ID}/dns_records" \
  --data-urlencode "name=${NAME}" --data-urlencode "type=${TYPE}" \
  -H "Authorization: Bearer ${TOKEN}" \
  -H "Content-Type: application/json" | jq '.result | length')

if [ "$EXISTING" -gt 0 ]; then
  echo "Record ja existe. Use dns-update-record para modifica-lo."
  exit 1
fi

RESPONSE=$(curl -s -X POST "https://api.cloudflare.com/client/v4/zones/${ZONE_ID}/dns_records" \
  -H "Authorization: Bearer ${TOKEN}" \
  -H "Content-Type: application/json" \
  -d "$(jq -n --arg type "$TYPE" --arg name "$NAME" --arg content "$CONTENT" \
    --argjson ttl "$TTL" --argjson proxied "$PROXIED" \
    '{type: $type, name: $name, content: $content, ttl: $ttl, proxied: $proxied}')")

if [ "$(echo "$RESPONSE" | jq -r '.success')" = "true" ]; then
  echo "Record criado:"
  echo "$RESPONSE" | jq -r '.result | "ID: \(.id)\nType: \(.type)\nName: \(.name)\nContent: \(.content)\nTTL: \(.ttl)\nProxied: \(.proxied)"'
else
  echo "Erro: $(echo "$RESPONSE" | jq -r '.errors[0].message')"
  exit 1
fi
```

## Exemplo Ruim

```bash
# ERRO: Esquecer priority no MX (400 Bad Request)
curl -s -X POST ".../dns_records" \
  -H "Authorization: Bearer ${TOKEN}" \
  -H "Content-Type: application/json" \
  -d '{"type":"MX","name":"example.com","content":"mail.example.com","ttl":300}'

# ERRO: CNAME com proxied=false (funciona, mas nao faz sentido)
# proxied=true em CNAME ativa CNAME flattening (apex domain)
# proxied=false em CNAME nao faz flattening

# ERRO: content IPv4 em AAAA ou vice-versa (400 ou silencio)
# Validar ANTES de enviar

# ERRO: TXT string > 255 chars sem dividir (truncado pela API)
# Max 255 por string; usar array se necessario
```

## Gotchas

1. **MX priority=0 desabilita email** — Se `priority=0`, emails para esse
   dominio serao rejeitados. Use priority > 0 para ativar.

2. **CNAME flattening no apex** — Quando `proxied=true` e `type=CNAME` no apex
   (`example.com`), Cloudflare aplica CNAME flattening (converte em A/AAAA).
   Isso pode causar surpresas se voce espera um CNAME real.

3. **TXT max 255 chars por string** — A API aceita strings maiores, mas
   resolvers standard truncam em 255. Divida em multiplas strings de ate
   255 chars usando array: `"content": ["string1", "string2"]`.

4. **AAAA rapid drift** — Enderecos IPv6 mudam com frequncia em ISPs.
   Considere `proxied=true` para evitar problemas de reachability.

5. **`proxied` so para A/AAAA/CNAME** — Para outros tipos, `proxied`
   sera ignorado ou causara erro.

6. **TTL=1 = automatic** — Nao significa 1 segundo; Cloudflare otimiza
   conforme carga e status do proxy.

7. **CNAME nao pode coexistir** — Se ja existe A/AAAA/TXT/MX no mesmo
   nome, criar CNAME falhara com 400.

## Quando NAO Usar

- **Listar records** → `dns-list-records`
- **Atualizar record existente** → `dns-update-record`
- **Deletar record** → `dns-delete-record`
- **Auditar security** → `dns-audit`
- **Importar bulk** → `dns-bulk-import`
