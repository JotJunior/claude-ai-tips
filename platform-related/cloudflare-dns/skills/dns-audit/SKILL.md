---
name: dns-audit
description: |
  Auditoria completa de DNS de uma zone (security, performance, hygiene).
  Use quando o usuario mencionar: "audit dns", "auditoria dns", "review dns",
  "dns security check", "auditar zone dns", "checar dns security".
  Nao use para operacoes CRUD basicas.
allowed-tools:
  - Bash
  - Glob
  - Grep
  - Read
---

# dns-audit

Realiza auditoria completa de DNS em uma zone da Cloudflare, cobrindo
security (SPF/DKIM/DMARC/CAA), performance, hygiene e compliance.

## Pre-flight

### 1. Identificar zone

```bash
DOMAIN="example.com"
TOKEN=$(bash ~/Sistemas/claude-ai-tips/global/skills/cred-store/scripts/resolve.sh cloudflare.idcbr.api_token)

ZONE_ID=$(curl -s -X GET "https://api.cloudflare.com/client/v4/zones?name=${DOMAIN}" \
  -H "Authorization: Bearer ${TOKEN}" \
  -H "Content-Type: application/json" | jq -r '.result[0].id')
```

### 2. Coletar todos os records

```bash
# Funcao para coletar todos os records com paginacao
get_all_records() {
  local ZONE_ID="$1"
  local PAGE=1
  local TOTAL_PAGES=1
  
  while [ "$PAGE" -le "$TOTAL_PAGES" ]; do
    RESP=$(curl -s -X GET "https://api.cloudflare.com/client/v4/zones/${ZONE_ID}/dns_records?per_page=100&page=${PAGE}" \
      -H "Authorization: Bearer ${TOKEN}" \
      -H "Content-Type: application/json")
    
    echo "$RESP" | jq -r '.result[] | @json'
    TOTAL_PAGES=$(echo "$RESP" | jq '.result_info.total_pages')
    PAGE=$((PAGE + 1))
    sleep 0.2
  done
}

# Coletar em array
declare -a RECORDS_JSON=()
while IFS= read -r rec; do
  RECORDS_JSON+=("$rec")
done < <(get_all_records "$ZONE_ID")

TOTAL_RECORDS=${#RECORDS_JSON[@]}
echo "Total records: $TOTAL_RECORDS"
```

## Workflow

### Check 1 — SPF (Sender Policy Framework)

```bash
# Buscar TXT records contendo "v=spf1"
check_spf() {
  echo "### SPF (TXT) ###"
  
  SPF_RECORD=$(curl -s -X GET "https://api.cloudflare.com/client/v4/zones/${ZONE_ID}/dns_records?type=TXT&name=${DOMAIN}&per_page=5" \
    -H "Authorization: Bearer ${TOKEN}" \
    -H "Content-Type: application/json" | jq -r '.result[] | select(.content | test("v=spf1")) | @json' | head -1)
  
  if [ -z "$SPF_RECORD" ]; then
    echo "ALERTA: Nenhum record SPF encontrado para ${DOMAIN}"
    echo "Recomendacao: Adicionar TXT record com 'v=spf1 -all' ou 'v=spf1 include:_spf.example.com -all'"
    return
  fi
  
  echo "$SPF_RECORD" | jq -r '.content'
  
  # Verificar mecanismos
  LOOKUPS=$(echo "$SPF_RECORD" | jq -r '.content' | grep -oE 'include:|~all|\?all|-all' | wc -l)
  echo "Mecanismos encontrados: $LOOKUPS"
  
  if [ "$LOOKUPS" -gt 10 ]; then
    echo "ALERTA: SPF com mais de 10 lookups (limite DNS)"
    echo "Resolucao: Consolidar includes ou usar subdomain专有"
  fi
  
  if echo "$SPF_RECORD" | jq -r '.content' | grep -q '\?all'; then
    echo "NOTA: SPF usa ?all (softfail) — menos restritivo que -all"
  fi
}
```

### Check 2 — DKIM (DomainKeys Identified Mail)

```bash
check_dkim() {
  echo ""
  echo "### DKIM (TXT _domainkey) ###"
  
  DKIM_RECORD=$(curl -s -X GET "https://api.cloudflare.com/client/v4/zones/${ZONE_ID}/dns_records?type=TXT&name=_domainkey.${DOMAIN}&per_page=5" \
    -H "Authorization: Bearer ${TOKEN}" \
    -H "Content-Type: application/json" | jq -r '.result[0] | @json')
  
  if [ -z "$DKIM_RECORD" ] || [ "$DKIM_RECORD" = "null" ]; then
    echo "ALERTA: Nenhum record DKIM encontrado (_domainkey.${DOMAIN})"
    echo "Recomendacao: Configurar DKIM no servidor de email (Google Workspace, Microsoft 365, etc.)"
  else
    echo "$DKIM_RECORD" | jq -r '.content'
  fi
}
```

### Check 3 — DMARC (Domain-based Message Authentication)

```bash
check_dmarc() {
  echo ""
  echo "### DMARC (TXT _dmarc) ###"
  
  DMARC_RECORD=$(curl -s -X GET "https://api.cloudflare.com/client/v4/zones/${ZONE_ID}/dns_records?type=TXT&name=_dmarc.${DOMAIN}&per_page=5" \
    -H "Authorization: Bearer ${TOKEN}" \
    -H "Content-Type: application/json" | jq -r '.result[0] | @json')
  
  if [ -z "$DMARC_RECORD" ] || [ "$DMARC_RECORD" = "null" ]; then
    echo "ALERTA: Nenhum record DMARC encontrado (_dmarc.${DOMAIN})"
    echo "Recomendacao: Adicionar 'v=DMARC1; p=reject; rua=mailto:dmarc@example.com'"
  else
    echo "$DMARC_RECORD" | jq -r '.content'
    
    # Extrair policy
    POLICY=$(echo "$DMARC_RECORD" | jq -r '.content' | grep -oE 'p=(reject|quarantine|none)' | cut -d= -f2)
    echo "Policy: $POLICY"
    
    if echo "$DMARC_RECORD" | jq -r '.content' | grep -q 'rua='; then
      echo "Aggregate report: CONFIGURADO"
    else
      echo "ALERTA: DMARC sem rua (sem aggregate reports)"
    fi
  fi
}
```

### Check 4 — CAA (Certificate Authority Authorization)

```bash
check_caa() {
  echo ""
  echo "### CAA (Authorization) ###"
  
  CAA_RECORDS=$(curl -s -X GET "https://api.cloudflare.com/client/v4/zones/${ZONE_ID}/dns_records?type=CAA&name=${DOMAIN}&per_page=5" \
    -H "Authorization: Bearer ${TOKEN}" \
    -H "Content-Type: application/json" | jq -r '.result | length')
  
  if [ "$CAA_RECORDS" -eq 0 ]; then
    echo "ALERTA: Nenhum record CAA encontrado"
    echo "Impacto: Qualquer CA pode emitir certificados para ${DOMAIN}"
    echo "Recomendacao: Adicionar 'issue letsencrypt.org' e 'issue digicert.com'"
  else
    curl -s -X GET "https://api.cloudflare.com/client/v4/zones/${ZONE_ID}/dns_records?type=CAA&name=${DOMAIN}&per_page=5" \
      -H "Authorization: Bearer ${TOKEN}" \
      -H "Content-Type: application/json" | jq -r '.result[] | "CAA: \(.content)"'
  fi
}
```

### Check 5 — DNSSEC

```bash
check_dnssec() {
  echo ""
  echo "### DNSSEC ###"
  
  DNSSEC_STATUS=$(curl -s -X GET "https://api.cloudflare.com/client/v4/zones/${ZONE_ID}/dnssec" \
    -H "Authorization: Bearer ${TOKEN}" \
    -H "Content-Type: application/json")
  
  if [ "$(echo "$DNSSEC_STATUS" | jq -r '.result.status')" = "active" ]; then
    echo "DNSSEC: ATIVO"
    echo "Algo: $(echo "$DNSSEC_STATUS" | jq -r '.result.algorithm')"
  else
    echo "ALERTA: DNSSEC nao esta ativo"
    echo "Recomendacao: Habilitar no dashboard Cloudflare -> DNS -> DNSSEC"
  fi
}
```

### Check 6 — NS Records Consistency

```bash
check_ns_records() {
  echo ""
  echo "### NS Records ###"
  
  NS_RECORDS=$(curl -s -X GET "https://api.cloudflare.com/client/v4/zones/${ZONE_ID}/dns_records?type=NS&name=${DOMAIN}&per_page=5" \
    -H "Authorization: Bearer ${TOKEN}" \
    -H "Content-Type: application/json" | jq -r '.result[] | .content')
  
  echo "NS records configurados:"
  echo "$NS_RECORDS" | while read -r ns; do echo "  $ns"; done
  
  # Verificar se指向 Cloudflare
  CF_NS=$(echo "$NS_RECORDS" | grep -c "cloudflare.com")
  if [ "$CF_NS" -ge 2 ]; then
    echo "NS指向 Cloudflare: OK"
  else
    echo "ALERTA: NS records nao apontam para Cloudflare"
  fi
}
```

### Check 7 — Stale Records (modificacao > 90 dias)

```bash
check_stale_records() {
  echo ""
  echo "### Stale Records (> 90 dias sem modificacao) ###"
  
  CUTOFF_DATE=$(date -v-90d -u +%Y-%m-%dT%H:%M:%SZ)
  
  STALE_COUNT=0
  declare -a STALE_RECORDS=()
  
  for rec in "${RECORDS_JSON[@]}"; do
    MODIFIED=$(echo "$rec" | jq -r '.modified_on')
    if [ "$MODIFIED" \< "$CUTOFF_DATE" ]; then
      STALE_COUNT=$((STALE_COUNT + 1))
      STALE_RECORDS+=("$(echo "$rec" | jq -r '.name') ($(echo "$rec" | jq -r '.type')) — modificado em $MODIFIED")
    fi
  done
  
  echo "Records stale: $STALE_COUNT"
  if [ "$STALE_COUNT" -gt 0 ]; then
    echo "Recomendacao: Review os seguintes records:"
    printf '%s\n' "${STALE_RECORDS[@]}" | head -20
    [ "$STALE_COUNT" -gt 20 ] && echo "  ... e mais $((STALE_COUNT - 20)) records"
  fi
}
```

### Check 8 — Open Redirect (CNAME para third-party)

```bash
check_redirects() {
  echo ""
  echo "### CNAMEs para third-party (open redirect risk) ###"
  
  THIRD_PARTIES=("godaddy.com" "squarespace.com" "wix.com" "shopify.com" "netlify.com" "vercel.com" "herokuapp.com")
  
  CNAME_REDIRECTS=()
  
  for rec in "${RECORDS_JSON[@]}"; do
    TYPE=$(echo "$rec" | jq -r '.type')
    if [ "$TYPE" = "CNAME" ]; then
      CONTENT=$(echo "$rec" | jq -r '.content')
      for tp in "${THIRD_PARTIES[@]}"; do
        if echo "$CONTENT" | grep -q "$tp"; then
          CNAME_REDIRECTS+=("$(echo "$rec" | jq -r '.name') -> $CONTENT")
        fi
      done
    fi
  done
  
  if [ ${#CNAME_REDIRECTS[@]} -gt 0 ]; then
    echo "ALERTA: CNAMEs apontando para third-parties (possible redirect):"
    printf '%s\n' "${CNAME_REDIRECTS[@]}"
  else
    echo "Nenhum CNAME redirect suspeito encontrado: OK"
  fi
}
```

### Check 9 — MX Records

```bash
check_mx() {
  echo ""
  echo "### MX Records ###"
  
  MX_RECORDS=$(curl -s -X GET "https://api.cloudflare.com/client/v4/zones/${ZONE_ID}/dns_records?type=MX&name=${DOMAIN}&per_page=10" \
    -H "Authorization: Bearer ${TOKEN}" \
    -H "Content-Type: application/json" | jq -r '.result[] | "MX \(.priority): \(.content)"')
  
  if [ -z "$MX_RECORDS" ]; then
    echo "ALERTA: Nenhum MX record — emails para ${DOMAIN} serao rejeitados"
  else
    echo "$MX_RECORDS"
    
    # Verificar priority 0 (desabilita email)
    ZERO_PRIO=$(echo "$MX_RECORDS" | grep -c "MX 0:")
    if [ "$ZERO_PRIO" -gt 0 ]; then
      echo "ALERTA: MX com priority=0 — email desabilitado"
    fi
  fi
}
```

## Gerar Relatorio Markdown

```bash
generate_report() {
  local REPORT_FILE="dns-audit-$(date +%Y%m%d-%H%M%S).md"
  
  {
    echo "# DNS Audit Report — ${DOMAIN}"
    echo ""
    echo "Data: $(date -u +%Y-%m-%dT%H:%M:%SZ)"
    echo "Zone ID: \`${ZONE_ID}\`"
    echo "Total Records: ${TOTAL_RECORDS}"
    echo ""
    echo "---"
    echo ""
    echo "## Resumo Executivo"
    echo ""
    echo "| Check | Status |"
    echo "|-------|--------|"
    echo "| SPF | $([ -n "$SPF_RECORD" ] && echo "OK" || echo "ALERTA") |"
    echo "| DKIM | $([ -n "$DKIM_RECORD" ] && echo "OK" || echo "ALERTA") |"
    echo "| DMARC | $([ -n "$DMARC_RECORD" ] && echo "OK" || echo "ALERTA") |"
    echo "| CAA | $([ "$CAA_RECORDS" -gt 0 ] && echo "OK" || echo "ALERTA") |"
    echo "| DNSSEC | $([ "$(echo "$DNSSEC_STATUS" | jq -r '.result.status')" = "active" ] && echo "OK" || echo "ALERTA") |"
    echo ""
    echo "## Detalhamento"
    echo ""
    # ... append checks output ...
  } > "$REPORT_FILE"
  
  echo "Relatorio salvo em: $REPORT_FILE"
}
```

## Exemplo Bom

```bash
#!/usr/bin/env bash
set -euo pipefail

DOMAIN="${1:-}"

if [ -z "$DOMAIN" ]; then
  echo "Uso: $0 <domain>"
  echo "Exemplo: $0 example.com"
  exit 1
fi

TOKEN=$(bash ~/Sistemas/claude-ai-tips/global/skills/cred-store/scripts/resolve.sh cloudflare.idcbr.api_token)
ZONE_ID=$(curl -s -X GET "https://api.cloudflare.com/client/v4/zones?name=${DOMAIN}" \
  -H "Authorization: Bearer ${TOKEN}" \
  -H "Content-Type: application/json" | jq -r '.result[0].id')

echo "=== DNS Audit: ${DOMAIN} ==="
echo "Zone ID: $ZONE_ID"
echo ""

# Executar todos os checks
check_spf
check_dkim
check_dmarc
check_caa
check_dnssec
check_ns_records
check_stale_records
check_redirects
check_mx

echo ""
echo "=== Audit Concluido ==="
```

## Exemplo Ruim

```bash
# ERRO: Nao verificar SPF lookup limit
# SPF com mais de 10 lookups = falha em alguns resolvers

# ERRO: DMARC sem rua
# Sem rua, nao ha aggregate reports = sem visibilidade de falhas

# ERRO: CAA ausente
# Qualquer CA pode emitir certificado, inclusive CA comprometidas

# ERRO: Nao verificar DNSSEC chain
# DNSSEC ativo localmente, mas DS no registrar pode estar quebrado

# ERRO:忽略 stale records
# Records antigos sem manutencao podem ser vectores de ataque

# ERRO: CNAME para third-party sem aviso
# Possible open redirect ou domain shadowing
```

## Gotchas

1. **SPF max 10 lookups** — O limite de 10 lookups DNS RR e do RFC 4408.
   Exceder = SPF fail em muitos resolvers.

2. **DMARC sem rua = sem feedback** — Se `rua=` nao estiver presente,
   voce nao sabera quando emails falham autenticacao.

3. **CAA missing = qualquer CA** — Se nenhum CAA record, qualquer CA
   confiavel pode emitir certificado. CA compromissada = MITM.

4. **DNSSEC chain validation** — DNSSEC ativo no CF, mas o registro no
   registrar (DS record) precisa estar configurado.

5. **MX priority 0** — `priority=0` significa "desabilita email".
   Nao confunda com highest priority.

6. **Recursive CNAME depth** — CNAMEs encadeados aumenta latencia.
   Cloudflare flattening ajuda, mas limites existem.

7. **TXT record split** — Strings TXT > 255 chars precisam ser divididas.
   Isso pode quebrar parsers que nao handle arrays.

## Quando NAO Usar

- **Operacoes CRUD basicas** → `dns-list-records`, `dns-add-record`, etc.
- **Migracao de zone** → `dns-migrate-zone`
- **Bulk import** → `dns-bulk-import`
