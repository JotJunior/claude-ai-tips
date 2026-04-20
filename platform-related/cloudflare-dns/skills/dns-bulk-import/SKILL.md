---
name: dns-bulk-import
description: |
  Importa multiplos DNS records de CSV ou arquivo de zona BIND.
  Use quando o usuario mencionar: "bulk import dns", "import zone file", "import csv dns",
  "bulk dns", "importar zona dns", "batch dns import".
  Nao use para operacoes single-record.
allowed-tools:
  - Bash
  - Glob
  - Grep
  - Read
---

# dns-bulk-import

Importa multiplos DNS records em uma zone da Cloudflare via API v4, suportando
CSV e arquivos de zona BIND como input, com validacao, rate limiting e
relatorio de resultados.

## Pre-flight

### 1. Identificar zone

```bash
DOMAIN="example.com"
TOKEN=$(bash ~/Sistemas/claude-ai-tips/global/skills/cred-store/scripts/resolve.sh cloudflare.idcbr.api_token)

ZONE_ID=$(curl -s -X GET "https://api.cloudflare.com/client/v4/zones?name=${DOMAIN}" \
  -H "Authorization: Bearer ${TOKEN}" \
  -H "Content-Type: application/json" | jq -r '.result[0].id')
```

### 2. Instalar dependencias

```bash
command -v jq >/dev/null || brew install jq
command -v awk >/dev/null || echo "awk ja disponivel"
```

## Workflow

### Formato CSV aceito

```csv
type,name,content,ttl,proxied
A,api.example.com,203.0.113.10,300,true
AAAA,api.example.com,2001:db8::10,300,false
CNAME,www.example.com,api.example.com,300,true
MX,example.com,mail.example.com,10,300,false
TXT,example.com,"v=spf1 include:_spf.example.com -all",300,false
SRV,_sip._tcp.example.com,sip.example.com,10,5,5060,300
```

### Formato BIND (zone file)

```
$ORIGIN example.com.
$TTL 300

@  IN  SOA  ns1.cloudflare.com. dns.cloudflare.com.  2024062001  7200  2400  604800  3600
@  IN  NS    ns1.cloudflare.com.
@  IN  NS    ns2.cloudflare.com.
@  IN  A     203.0.113.10
api  IN  A     203.0.113.10
www  IN  CNAME  api.example.com.
@  IN  MX  10  mail.example.com.
@  IN  TXT  "v=spf1 include:_spf.example.com -all"
_sip._tcp  IN  SRV  10  5  5060  sip.example.com.
```

### Passo 1 — Parse CSV

```bash
parse_csv() {
  local CSV_FILE="$1"
  
  # Validar header
  HEAD=$(head -1 "$CSV_FILE")
  if ! echo "$HEAD" | grep -q "type,name,content"; then
    echo "CSV invalido: header deve conter type,name,content,ttl,proxied"
    return 1
  fi
  
  # Parse cada linha (skip header)
  tail -n +2 "$CSV_FILE" | while IFS=',' read -r TYPE NAME CONTENT TTL PROXIED; do
    # Trim whitespace
    TYPE=$(echo "$TYPE" | xargs)
    NAME=$(echo "$NAME" | xargs)
    CONTENT=$(echo "$CONTENT" | xargs)
    TTL=${TTL:-300}
    PROXIED=${PROXIED:-false}
    
    # Validar record
    if [ -z "$TYPE" ] || [ -z "$NAME" ] || [ -z "$CONTENT" ]; then
      echo "SKIP (campos obrigatorios faltando): $TYPE $NAME $CONTENT" >&2
      continue
    fi
    
    # Output JSON para validacao
    jq -n \
      --arg type "$TYPE" \
      --arg name "$NAME" \
      --arg content "$CONTENT" \
      --argjson ttl "$TTL" \
      --argjson proxied "$PROXIED" \
      '{type: $type, name: $name, content: $content, ttl: $ttl, proxied: $proxied}'
  done
}
```

### Passo 2 — Parse BIND zone file

```bash
parse_bind() {
  local ZONE_FILE="$1"
  local ORIGIN="${2:-}"
  
  # Extrair $ORIGIN e $TTL se presentes
  if [ -z "$ORIGIN" ]; then
    ORIGIN=$(grep -i '^\$ORIGIN' "$ZONE_FILE" | awk '{print $2}' | sed 's/.$//')
    [ -z "$ORIGIN" ] && ORIGIN="."
  fi
  
  DEFAULT_TTL=$(grep -i '^\$TTL' "$ZONE_FILE" | awk '{print $2}')
  DEFAULT_TTL=${DEFAULT_TTL:-300}
  
  # Parse registros (ignora comentarios, SOA, NS)
  awk '
    /^;/ { next }
    /^\$/ { next }
    /^[ \t]*$/ { next }
    $3 == "SOA" || $4 == "SOA" { next }
    $3 == "NS" || $4 == "NS" { next }
    {
      # Deterministic parsing
      name = $1
      if (name == "@") name = origin
      if (name ~ /\.$/) name = substr(name, 1, length(name)-1)
      
      ttl = default_ttl
      if ($2 ~ /^[0-9]+$/) { ttl = $2; shift = 1 }
      
      type = ""
      content = ""
      
      if ($3 == "A") { type = "A"; content = $4 }
      else if ($3 == "AAAA") { type = "AAAA"; content = $4 }
      else if ($3 == "CNAME") { type = "CNAME"; content = $4 }
      else if ($3 == "MX") { type = "MX"; priority = $4; content = $5 }
      else if ($3 == "TXT") { type = "TXT"; content = $0; sub(/.*TXT.*"/, ""); sub(/".*/, "") }
      else if ($3 == "SRV") { type = "SRV"; content = $6; priority = $4; weight = $5; port = $6 }
      
      if (type != "" && content != "") {
        printf "{\"type\":\"%s\",\"name\":\"%s\",\"content\":\"%s\",\"ttl\":%d,\"proxied\":false}\n", type, name, content, ttl
      }
    }
  ' origin="$ORIGIN" default_ttl="$DEFAULT_TTL" "$ZONE_FILE"
}
```

### Passo 3 — Validacao pre-flight (dry-run)

```bash
DRY_RUN=true
CONTINUE_ON_ERROR=true
SLEEP_MS=250

while [[ $# -gt 0 ]]; do
  case "$1" in
    --apply) DRY_RUN=false; shift ;;
    --dry-run) DRY_RUN=true; shift ;;
    --fail-fast) CONTINUE_ON_ERROR=true; shift ;;
    --continue) CONTINUE_ON_ERROR=true; shift ;;
    *) shift ;;
  esac
done

echo "=== Validacao pre-flight (dry-run) ==="
VALID_COUNT=0
ERRORS=()

while IFS= read -r RECORD; do
  TYPE=$(echo "$RECORD" | jq -r '.type')
  NAME=$(echo "$RECORD" | jq -r '.name')
  CONTENT=$(echo "$RECORD" | jq -r '.content')
  
  # Validacoes basicas
  case "$TYPE" in
    A)
      [[ "$CONTENT" =~ ^([0-9]{1,3}\.){3}[0-9]{1,3}$ ]] || ERRORS+=("A: IPv4 invalido $CONTENT")
      ;;
    AAAA)
      [[ "$CONTENT" =~ :$ ]] || ERRORS+=("AAAA: IPv6 invalido $CONTENT")
      ;;
    CNAME)
      [[ "$CONTENT" =~ \..+$ ]] || ERRORS+=("CNAME: FQDN invalido $CONTENT")
      ;;
    *)
      ;;
  esac
  
  VALID_COUNT=$((VALID_COUNT + 1))
done < <(parse_csv "$INPUT_FILE")

echo "Registros validos: $VALID_COUNT"
if [ ${#ERRORS[@]} -gt 0 ]; then
  echo "Erros encontrados:"
  printf '%s\n' "${ERRORS[@]}"
  [ "$DRY_RUN" = "false" ] && exit 1
fi

if [ "$DRY_RUN" = "true" ]; then
  echo ""
  echo "DRY-RUN: Nenhum record foi importado."
  echo "Execute com --apply para importar."
  exit 0
fi
```

### Passo 4 — Import em batch com rate limiting

```bash
SUCCESS_COUNT=0
FAIL_COUNT=0
declare -a FAIL_RECORDS=()

# Processar com sleep para rate limit (1200 req/5min = 1 req a cada 250ms)
while IFS= read -r RECORD; do
  RESPONSE=$(curl -s -X POST "https://api.cloudflare.com/client/v4/zones/${ZONE_ID}/dns_records" \
    -H "Authorization: Bearer ${TOKEN}" \
    -H "Content-Type: application/json" \
    -d "$RECORD")
  
  if [ "$(echo "$RESPONSE" | jq -r '.success')" = "true" ]; then
    SUCCESS_COUNT=$((SUCCESS_COUNT + 1))
  else
    FAIL_COUNT=$((FAIL_COUNT + 1))
    ERROR_MSG=$(echo "$RESPONSE" | jq -r '.errors[0].message')
    FAIL_RECORDS+=("$(echo "$RECORD" | jq -r '.name'): $ERROR_MSG")
    
    if [ "$CONTINUE_ON_ERROR" = "false" ]; then
      echo "Fail-fast: parando na primeira falha."
      break
    fi
  fi
  
  # Rate limit: 250ms entre requests
  sleep 0.25
done < <(parse_csv "$INPUT_FILE")

echo ""
echo "=== Relatorio de Importacao ==="
echo "Sucesso: $SUCCESS_COUNT"
echo "Falhas: $FAIL_COUNT"
if [ ${#FAIL_RECORDS[@]} -gt 0 ]; then
  echo ""
  echo "Detalhes das falhas:"
  printf '%s\n' "${FAIL_RECORDS[@]}"
fi
```

## Exemplo Bom

```bash
#!/usr/bin/env bash
set -euo pipefail

INPUT_FILE="${1:-}"
DOMAIN="${2:-}"

if [ -z "$INPUT_FILE" ] || [ -z "$DOMAIN" ]; then
  echo "Uso: $0 <input.csv|zonefile> <domain> [--apply]"
  echo ""
  echo "Formato CSV:"
  echo "  type,name,content,ttl,proxied"
  echo "  A,api.example.com,203.0.113.10,300,true"
  exit 1
fi

# Validar arquivo existe
[ -f "$INPUT_FILE" ] || { echo "Arquivo nao encontrado: $INPUT_FILE"; exit 1; }

TOKEN=$(bash ~/Sistemas/claude-ai-tips/global/skills/cred-store/scripts/resolve.sh cloudflare.idcbr.api_token)
ZONE_ID=$(curl -s -X GET "https://api.cloudflare.com/client/v4/zones?name=${DOMAIN}" \
  -H "Authorization: Bearer ${TOKEN}" \
  -H "Content-Type: application/json" | jq -r '.result[0].id')

# Dry-run padrao
if [[ "${3:-}" != "--apply" ]]; then
  echo "=== DRY-RUN: Validando input ==="
  COUNT=0
  while IFS= read -r line; do
    COUNT=$((COUNT + 1))
    echo "  $line" | jq '.'
  done < <(tail -n +2 "$INPUT_FILE")
  echo ""
  echo "Total: $COUNT records"
  echo "Execute com --apply para importar."
  exit 0
fi

# Importar
echo "=== Importando records ==="
SUCCESS=0; FAIL=0
while IFS= read -r RECORD; do
  RESP=$(curl -s -X POST "https://api.cloudflare.com/client/v4/zones/${ZONE_ID}/dns_records" \
    -H "Authorization: Bearer ${TOKEN}" \
    -H "Content-Type: application/json" \
    -d "$RECORD")
  
  if [ "$(echo "$RESP" | jq -r '.success')" = "true" ]; then
    SUCCESS=$((SUCCESS + 1))
  else
    FAIL=$((FAIL + 1))
    echo "FAIL: $(echo "$RECORD" | jq -r '.name') — $(echo "$RESP" | jq -r '.errors[0].message')"
  fi
  sleep 0.25
done < <(parse_csv "$INPUT_FILE")

echo ""
echo "Sucesso: $SUCCESS | Falhas: $FAIL"
```

## Exemplo Ruim

```bash
# ERRO: Nao validar input antes de importar
# Records invalidos gerarao erros em cascata e podem feder rate limit

# ERRO: Importar sem dry-run
# Erros de formato so aparecem apos inicio do processo

# ERRO: Rate limit ignorado
# 1200 req/5min = 4 req/s. Sem sleep, vai receber 429 e falhar

# ERRO: Nao handle strings TXT > 255 chars
# A API aceita, mas resolvers publicos truncam
# Exemplo: SPF com muitas includs pode ultrapassar

# ERRO: Importar SOA/NS records
# SOA e NS sao gerenciados automaticamente
# Importalos pode causar inconsistencias na zone

# ERRO: Nao fazer backup antes
# Imports em producao devem sempre ter backup previo
```

## Gotchas

1. **Rate limit: 1200 req/5min** — 1 request a cada 250ms para evitar 429.
   Em importacoes grandes, usar `sleep 0.3` para margem de seguranca.

2. **$ORIGIN em BIND** — Se o arquivo nao tiver `$ORIGIN`, usar o apex
   domain como padrao. Record names relativos sao resolvidos contra
   o ORIGIN.

3. **TTL inheritance em BIND** — Se `$TTL` estiver presente, todas as
   records sem TTL explicito herdarao esse valor. Padrao CF: 300.

4. **CNAME conflicts** — CNAME nao pode coexistir com outros types no
   mesmo nome. Se o import falhar com 400, verifique conflitos.

5. **TXT strings > 255 chars** — Dividir em chunks de max 255.
   A API aceita strings maiores, mas resolvers standard as ignoram.

6. **Importar SOA/NS** — Records SOA e NS sao auto-gerenciados pela
   Cloudflare. Tentar importalos retornara erro ou sera sobrescrito.

7. **BIND format complexo** — Parsers caseiros falham em edge cases.
   Para zonas complexas, considere conversao para CSV primeiro.

## Quando NAO Usar

- **Single record create** → `dns-add-record`
- **Single record update** → `dns-update-record`
- **Auditar zone** → `dns-audit`
- **Migrar zone completa** → `dns-migrate-zone`
