# Exemplo: Setup de DNS na Cloudflare via API

Cenário completo — registrar conta CF, criar zona nova, popular DNS records
(A, CNAME, TXT/SPF, DKIM, DMARC) via `cf-api-call`.

## Contexto

Você comprou um domínio novo `example.com` e quer:

1. Registrar a conta CF no `cred-store`
2. Adicionar a zona na Cloudflare
3. Configurar DNS para apontar para servidor + email (SPF/DKIM/DMARC)

## Pré-requisitos

- Conta Cloudflare ativa
- Domínio `example.com` registrado em registrar qualquer (não precisa estar na CF ainda)
- `claude-ai-tips` instalado (`~/Sistemas/claude-ai-tips/`)
- `jq`, `curl`, `op` (recomendado) instalados

## Passo 1 — Criar API Token na Cloudflare

1. Acesse [`https://dash.cloudflare.com/profile/api-tokens`](https://dash.cloudflare.com/profile/api-tokens)
2. Clique em **Create Token**
3. Escolha **Custom token** (template "Edit zone DNS" também serve)
4. Permissões:
   - **Zone / DNS / Edit**
   - **Zone / Zone / Read** (para listar zonas)
5. Zone Resources:
   - **Include / All zones** (ou zone específica, mais restrito)
6. Account Resources:
   - **Include / <sua conta>**
7. **Create Token** → copie o valor (mostrado uma vez)

## Passo 2 — Obter Account ID

Do dashboard principal, a URL contém:

```
https://dash.cloudflare.com/1783e2ca3a473ef8334a8b17df42878e/
                            ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
                            este é seu Account ID
```

Copie os 32 hex chars.

## Passo 3 — Registrar no cred-store

Se é primeira vez, bootstrap:

```bash
bash ~/Sistemas/claude-ai-tips/global/skills/cred-store/scripts/init-store.sh
```

No Claude Code (no diretório que quiser):

```
configure credenciais Cloudflare para conta pessoal
```

A skill `cf-credentials-setup` pergunta:

```
1. Nickname da conta? → pessoal
2. Escopo (case de uso)? → DNS management
3. Fonte de armazenamento?
   [1] op (1Password) — recomendado
   [2] keychain (macOS)
   [3] file (chmod 600)
   → 1

4. URI 1Password? → op://Personal/CF pessoal Token/credential

   (primeiro crie o item no 1Password com campo 'credential' contendo o token)

5. Account ID? → 1783e2ca3a473ef8334a8b17df42878e
6. Email? → you@example.com
7. Zone IDs conhecidos? → (vazio, vamos criar agora)

Validando... GET /user/tokens/verify
✓ Token ativo, status=active

Registrado: cloudflare.pessoal.api_token
```

Verificar:

```bash
bash ~/Sistemas/claude-ai-tips/global/skills/cred-store/scripts/list.sh --provider=cloudflare
```

```
KEY                                      SOURCE     CREATED                        METADATA
---------------------------------------- ---------- ------------------------------ --------
cloudflare.pessoal.api_token             op         2026-04-19T21:00:00Z           {"account_id":"1783...","email":"you@example.com"}
```

## Passo 4 — Adicionar zona na Cloudflare

```bash
CALL="bash ~/Sistemas/claude-ai-tips/platform-related/cloudflare-shared/skills/cf-api-call/scripts/call.sh"

$CALL POST /zones \
  --account=pessoal \
  --data='{
    "name": "example.com",
    "account": {"id": "1783e2ca3a473ef8334a8b17df42878e"},
    "type": "full"
  }' \
  --format=pretty
```

Resposta:

```json
{
  "success": true,
  "result": {
    "id": "abc123def456...",
    "name": "example.com",
    "status": "pending",
    "name_servers": [
      "art.ns.cloudflare.com",
      "jeff.ns.cloudflare.com"
    ],
    "plan": {"name": "Free Website"},
    "created_on": "2026-04-19T21:00:00Z"
  }
}
```

Anote o `zone_id` (`abc123def456...`).

## Passo 5 — Apontar nameservers no registrar

**Fora da CF**: no painel do seu registrar (GoDaddy, Registro.br, etc.),
altere os nameservers para os 2 informados na resposta:

```
art.ns.cloudflare.com
jeff.ns.cloudflare.com
```

Aguarde propagação (minutos a 24h).

Verificar:

```bash
dig NS example.com +short
# Deve retornar: art.ns.cloudflare.com, jeff.ns.cloudflare.com
```

## Passo 6 — Popular DNS

### Apex record (A)

Aponta `example.com` para servidor web:

```bash
$CALL POST /zones/:zone_id/dns_records \
  --zone=abc123def456 \
  --account=pessoal \
  --data='{
    "type": "A",
    "name": "@",
    "content": "203.0.113.10",
    "proxied": true,
    "ttl": 1,
    "comment": "Web server production"
  }'
```

`name: "@"` = apex. `ttl: 1` = Auto (obrigatório com proxied). `proxied: true`
ativa CDN/WAF.

### WWW (CNAME apontando para apex)

```bash
$CALL POST /zones/:zone_id/dns_records \
  --zone=abc123def456 \
  --account=pessoal \
  --data='{
    "type": "CNAME",
    "name": "www",
    "content": "example.com",
    "proxied": true,
    "ttl": 1
  }'
```

### API subdomain (A record separado)

```bash
$CALL POST /zones/:zone_id/dns_records \
  --zone=abc123def456 \
  --account=pessoal \
  --data='{
    "type": "A",
    "name": "api",
    "content": "203.0.113.11",
    "proxied": false,
    "ttl": 300,
    "comment": "API backend (no proxy for gRPC)"
  }'
```

`proxied: false` porque CF não suporta gRPC em modo proxy (usa HTTP/1.1 + 2).
TTL 300 = 5min (ajuste-se a mudanças).

### MX records para email (Google Workspace)

```bash
$CALL POST /zones/:zone_id/dns_records \
  --zone=abc123def456 \
  --account=pessoal \
  --data='{
    "type": "MX",
    "name": "@",
    "content": "smtp.google.com",
    "priority": 1,
    "ttl": 3600
  }'
```

MX aceita um por request. Se precisar de múltiplos:

```bash
for PRIORITY_HOST in "1:smtp.google.com"; do
  P="${PRIORITY_HOST%%:*}"
  H="${PRIORITY_HOST#*:}"
  $CALL POST /zones/:zone_id/dns_records \
    --zone=abc123def456 --account=pessoal \
    --data="{\"type\":\"MX\",\"name\":\"@\",\"content\":\"$H\",\"priority\":$P,\"ttl\":3600}"
done
```

### SPF (TXT)

```bash
$CALL POST /zones/:zone_id/dns_records \
  --zone=abc123def456 \
  --account=pessoal \
  --data='{
    "type": "TXT",
    "name": "@",
    "content": "v=spf1 include:_spf.google.com include:amazonses.com ~all",
    "ttl": 3600
  }'
```

Regras:

- `v=spf1` versão
- `include:` lista providers autorizados
- `~all` soft fail (recomendado em setup inicial; depois `-all` quando
  confiante de que todos providers estão listados)

### DKIM (TXT)

Primeiro, gere a chave no Google Workspace Admin (ou provider de email).
Você receberá um valor longo começando com `v=DKIM1; k=rsa; p=...`.

```bash
DKIM_VALUE="v=DKIM1; k=rsa; p=MIGfMA0GCSqGSIb3DQEBAQUAA4GNADCBiQK..."

$CALL POST /zones/:zone_id/dns_records \
  --zone=abc123def456 \
  --account=pessoal \
  --data="{
    \"type\": \"TXT\",
    \"name\": \"google._domainkey\",
    \"content\": \"$DKIM_VALUE\",
    \"ttl\": 3600
  }"
```

Nome do selector (`google`, `s1`, `selector1`) depende do provider.

### DMARC (TXT)

Policy inicial conservadora (monitoramento apenas):

```bash
$CALL POST /zones/:zone_id/dns_records \
  --zone=abc123def456 \
  --account=pessoal \
  --data='{
    "type": "TXT",
    "name": "_dmarc",
    "content": "v=DMARC1; p=none; rua=mailto:dmarc-reports@example.com; pct=100",
    "ttl": 3600
  }'
```

Após 2-4 semanas de monitoramento, escalate:

- `p=quarantine` — mensagens suspeitas vão pra spam
- `p=reject` — mensagens suspeitas são rejeitadas

### CAA records (opcional mas recomendado)

Autoriza apenas Let's Encrypt a emitir certs para `example.com`:

```bash
$CALL POST /zones/:zone_id/dns_records \
  --zone=abc123def456 \
  --account=pessoal \
  --data='{
    "type": "CAA",
    "name": "@",
    "data": {
      "flags": 0,
      "tag": "issue",
      "value": "letsencrypt.org"
    },
    "ttl": 3600
  }'
```

## Passo 7 — Verificar setup

Listar todos os records:

```bash
$CALL GET /zones/:zone_id/dns_records \
  --zone=abc123def456 \
  --account=pessoal \
  --query="per_page=50" \
  --format=pretty | jq -r '.result[] | "\(.type)\t\(.name)\t\(.content)"'
```

Saída:

```
A       example.com             203.0.113.10
CNAME   www.example.com         example.com
A       api.example.com         203.0.113.11
MX      example.com             smtp.google.com
TXT     example.com             v=spf1 include:_spf.google.com ~all
TXT     google._domainkey.example.com  v=DKIM1; k=rsa; p=...
TXT     _dmarc.example.com      v=DMARC1; p=none; ...
CAA     example.com             0 issue "letsencrypt.org"
```

Testar externamente:

```bash
dig A example.com +short           # → 203.0.113.10 (ou IP proxy CF)
dig CNAME www.example.com +short   # → example.com
dig TXT example.com +short         # → SPF record
dig MX example.com +short          # → "1 smtp.google.com"
```

## Passo 8 — Atualizar metadata do cred-store

Adicione a zone_id nos metadata da credencial para futuras chamadas:

```bash
KEY=cloudflare.pessoal.api_token
REGISTRY=~/.claude/credentials/registry.json

jq --arg zid "abc123def456" --arg zname "example.com" '
  .[$key].metadata.zone_ids = ((.[$key].metadata.zone_ids // []) + [$zid]) |
  .[$key].metadata.default_zone = $zid |
  .[$key].metadata["zone_" + $zname | gsub("\\."; "_")] = $zid
' --arg key "$KEY" "$REGISTRY" > /tmp/reg.json && mv /tmp/reg.json "$REGISTRY"
```

Agora você pode usar:

```bash
$CALL GET /zones/:zone_id/dns_records --account=pessoal
# :zone_id será default_zone automaticamente
```

## Passo 9 — Audit trail

Ver operações feitas:

```bash
cat ~/.claude/credentials/cloudflare/pessoal/audit.log
```

```
2026-04-19T21:00:00Z POST /zones account=pessoal status=200 success=true
2026-04-19T21:02:15Z POST /zones/abc.../dns_records account=pessoal status=200 success=true
2026-04-19T21:02:20Z POST /zones/abc.../dns_records account=pessoal status=200 success=true
2026-04-19T21:02:25Z POST /zones/abc.../dns_records account=pessoal status=200 success=true
...
2026-04-19T21:05:00Z GET /zones/abc.../dns_records account=pessoal status=200 success=true
```

Todas as operações destrutivas/criativas ficam rastreáveis (sem valores
sensíveis — apenas metadata).

## Operações avançadas

### Bulk import via BIND zonefile

Se você já tem zonefile em formato BIND:

```bash
$CALL POST /zones/:zone_id/dns_records/import \
  --zone=abc123def456 \
  --account=pessoal \
  --data-file=./zonefile.txt \
  --format=pretty
```

Formato esperado (BIND):

```
$ORIGIN example.com.
$TTL 3600
@       IN A       203.0.113.10
www     IN CNAME   example.com.
api     IN A       203.0.113.11
```

### Export de zona completa

```bash
$CALL GET /zones/:zone_id/dns_records/export \
  --zone=abc123def456 \
  --account=pessoal \
  --format=raw > example.com.zone
```

### Deletar record com confirmação

```bash
# 1. Identificar o record_id
RECORD=$($CALL GET /zones/:zone_id/dns_records \
  --zone=abc123def456 --account=pessoal \
  --query="name=old.example.com&type=A" | jq -r '.result[0].id')

echo "Record ID: $RECORD"

# 2. Dry-run
$CALL DELETE /zones/:zone_id/dns_records/$RECORD \
  --zone=abc123def456 --account=pessoal --dry-run

# 3. Confirmar antes de executar
read -p "Continuar? [y/N] " CONFIRM
[ "$CONFIRM" = "y" ] && \
  $CALL DELETE /zones/:zone_id/dns_records/$RECORD \
    --zone=abc123def456 --account=pessoal
```

### Bulk delete de records obsoletos

```bash
# Listar todos os records A começando com "old-"
$CALL GET /zones/:zone_id/dns_records \
  --zone=abc123def456 --account=pessoal \
  --query="type=A" | \
  jq -r '.result[] | select(.name | startswith("old-")) | .id' > /tmp/old-ids.txt

wc -l /tmp/old-ids.txt

# Dry-run
while read ID; do
  $CALL DELETE /zones/:zone_id/dns_records/$ID \
    --zone=abc123def456 --account=pessoal --dry-run
done < /tmp/old-ids.txt

# Se OK, executar
while read ID; do
  $CALL DELETE /zones/:zone_id/dns_records/$ID \
    --zone=abc123def456 --account=pessoal
  sleep 0.5   # throttle simples
done < /tmp/old-ids.txt
```

## Troubleshooting

### "81057 DNS record already exists"

Record com mesmo `type + name + content` já existe. Atualize em vez de
criar:

```bash
# Buscar record_id
RID=$($CALL GET /zones/:zone_id/dns_records \
  --zone=abc123def456 --account=pessoal \
  --query="type=A&name=api.example.com" | jq -r '.result[0].id')

# PATCH
$CALL PATCH /zones/:zone_id/dns_records/$RID \
  --zone=abc123def456 --account=pessoal \
  --data='{"content":"203.0.113.99"}'
```

### "81058 DNS content invalid"

Formato de `content` errado:

- A record: precisa IPv4 (`203.0.113.10`)
- AAAA record: precisa IPv6 (`2001:db8::1`)
- CNAME: precisa hostname (com ou sem ponto final)
- MX: precisa hostname + separar `priority` em campo próprio
- TXT: geralmente aspas tratadas automaticamente, mas se tem `"` internas, escape

### "Zone not active"

Após criar zona, aguarde nameservers serem apontados e CF validar. Status
mudanças:

- `pending` → aguardando mudança de NS
- `active` → ok, pode receber DNS records
- `moved` / `deleted` → estados raros

Force re-check:

```bash
$CALL PUT /zones/:zone_id/activation_check \
  --zone=abc123def456 --account=pessoal
```

### SPF exceedendo 255 chars

TXT record individual aceita ≤255 chars. SPF longo precisa ser
**split-string** (múltiplas strings concatenadas):

```json
{
  "content": "v=spf1 include:a.com include:b.com include:c.com include:d.com include:e.com ~all"
}
```

Se exceder 255 chars, considere:

- Usar `redirect=` ao invés de múltiplos `include:`
- Consolidar em macro SPF (serviços como `spfplanet.com`)

### DKIM público muito longo

DKIM 2048-bit tem valor >255 chars. CF aceita split automático — nem todos
os clientes DNS entendem, mas CF resolver sim:

```bash
$CALL POST /zones/:zone_id/dns_records \
  --zone=abc123def456 --account=pessoal \
  --data='{
    "type": "TXT",
    "name": "selector._domainkey",
    "content": "v=DKIM1; k=rsa; p=MIGfMA0GCSqGS...LONG_VALUE_HERE"
  }'
```

Se provider de email exige quebra explícita:

```
"v=DKIM1; k=rsa; p=MIGfMA0..." "continuacao..."
```

Inclua as aspas internas no JSON com escape.

## Ver também

- [cloudflare.md](../guides/cloudflare.md) — guia completo
- [credentials.md](../guides/credentials.md) — gestão de credenciais
- [api-endpoint-catalog.md](../../platform-related/cloudflare-shared/references/api-endpoint-catalog.md) — mais endpoints
- [Cloudflare DNS API docs](https://developers.cloudflare.com/api/resources/dns/)
- [SPF record syntax](https://datatracker.ietf.org/doc/html/rfc7208)
- [DMARC record syntax](https://datatracker.ietf.org/doc/html/rfc7489)
