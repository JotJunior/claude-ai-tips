# API Cookbook

Exemplos práticos de chamadas REST à API Cloudflare (DNS, KV, R2, Workers via API quando wrangler não cobre).

## Estrutura básica

```bash
bash .../cf-api-call/scripts/call.sh <METHOD> <PATH> [opções]
```

Exemplos simples:

```bash
# GET sem auth explícito (resolve via --account)
call.sh GET /zones --account=idcbr

# POST com body inline
call.sh POST /zones/:zone_id/dns_records \
  --zone=abc123 \
  --account=idcbr \
  --data='{"type":"A","name":"api","content":"1.2.3.4","proxied":true,"ttl":1}'

# PATCH com body de arquivo
call.sh PATCH /zones/:zone_id/dns_records/xyz \
  --zone=abc123 --account=idcbr \
  --data-file=./dns-update.json
```

### Flags disponíveis

| Flag | Descrição |
|------|-----------|
| `--account=<nick>` | Conta registrada via `cf-credentials-setup` |
| `--zone=<id>` | Zone ID; substitui `:zone_id` no path |
| `--data='<json>'` | Body JSON inline |
| `--data-file=<path>` | Body JSON lido de arquivo |
| `--query='<qs>'` | Query string (ex: `per_page=50&page=1`) |
| `--format=json\|raw\|pretty` | Formato de saída (default: `json`) |
| `--retry=<n>` | Max retries (default: `3`) |
| `--timeout=<s>` | Timeout por request (default: `30`) |
| `--base=<url>` | Base URL alternativo |
| `--audit` / `--no-audit` | Força/desativa audit log |
| `--dry-run` | Imprime request sem executar |

### Resolução automática de placeholders

O wrapper substitui `:account_id` e `:zone_id` no path:

```bash
call.sh GET /accounts/:account_id/workers/scripts --account=idcbr
# expande para:
# GET /accounts/1783e2ca3a473ef8334a8b17df42878e/workers/scripts
```

`:account_id` vem do `metadata.account_id` registrado para `--account=idcbr`.
`:zone_id` vem de `--zone=<valor>` (literal ou resolvido via registry futuramente).

### Formatos de saída

#### `json` (default)

Body completo, sem processamento:

```bash
call.sh GET /zones --account=idcbr | jq '.result[].name'
```

#### `raw`

Body puro, sem parse:

```bash
call.sh GET /zones --account=idcbr --format=raw > raw-response.json
```

Útil para endpoints que retornam non-JSON (raro em CF).

#### `pretty`

JSON pretty-printed via `jq .`:

```bash
call.sh GET /zones --account=idcbr --format=pretty
```

Ideal para leitura humana.

### Retry e rate limit

Comportamento automático:

- **Retry default**: 3 tentativas com backoff exponencial (1s, 2s, 4s + jitter)
- **429 Too Many Requests**: respeita header `Retry-After` se presente
- **5xx**: retry com backoff
- **4xx (exceto 429)**: **NÃO retry** — erro do cliente, falha imediata
- **Network errors** (DNS, timeout): retry com backoff

Rate limit da CF API: ~1200 req/5min **por usuário (token)**. Múltiplas skills
consumindo o mesmo token somam no mesmo bucket. Para bulk ops, throttlear
manualmente (ex: sleep 60s a cada 200 requests).

### Error parsing

CF retorna erros no formato:

```json
{
  "success": false,
  "errors": [{"code": 10000, "message": "Authentication error"}],
  "messages": [],
  "result": null
}
```

O wrapper:

- Parseia `.success` e emite exit ≠0 quando `false`
- stderr contém `[errors]` estruturado
- stdout mantém body completo para parse do caller

#### Exit codes

| Code | Significado |
|------|-------------|
| `0` | Sucesso (`.success == true`) |
| `1` | Erro de aplicação (auth, permission, validation — não-retriável) |
| `2` | Erro de rede/timeout após retries |
| `3` | Credencial não encontrada (via cred-store) |
| `4` | Argumento inválido |

### Dry-run

```bash
call.sh DELETE /zones/:zone_id/dns_records/abc \
  --zone=xyz123 --account=idcbr --dry-run
```

Saída:

```
DRY-RUN
DELETE https://api.cloudflare.com/client/v4/zones/xyz123/dns_records/abc
Authorization: Bearer [REDACTED]
Content-Type: application/json
```

Útil para:

- Validar path antes de op destrutiva
- Gerar `curl` equivalente para documentação
- Testar em ambiente review sem token válido

## Cookbook de operações

### Listar zonas da conta

```bash
call.sh GET /zones --account=idcbr --format=pretty
```

Com filtros:

```bash
call.sh GET /zones --account=idcbr \
  --query="status=active&per_page=50" --format=pretty
```

### Listar DNS records de uma zona

```bash
call.sh GET /zones/:zone_id/dns_records \
  --zone=ac2518a192ffd908938cffa4adac55bd \
  --account=idcbr \
  --query="per_page=100" \
  --format=pretty
```

Filtrar por tipo:

```bash
call.sh GET /zones/:zone_id/dns_records \
  --zone=<id> --account=idcbr \
  --query="type=A"
```

Filtrar por nome exato:

```bash
call.sh GET /zones/:zone_id/dns_records \
  --zone=<id> --account=idcbr \
  --query="name=api.example.com"
```

### Criar A record

```bash
call.sh POST /zones/:zone_id/dns_records \
  --zone=ac2518a192ffd908938cffa4adac55bd \
  --account=idcbr \
  --data='{
    "type": "A",
    "name": "api",
    "content": "1.2.3.4",
    "proxied": true,
    "ttl": 1,
    "comment": "API endpoint"
  }'
```

`ttl: 1` = Auto quando `proxied: true`. Para não-proxied, use TTL em segundos
(60, 300, 3600, etc.).

### Criar CNAME proxied

```bash
call.sh POST /zones/:zone_id/dns_records \
  --zone=<id> --account=idcbr \
  --data='{
    "type": "CNAME",
    "name": "blog",
    "content": "myblog.platform.com",
    "proxied": true,
    "ttl": 1
  }'
```

### Criar TXT (SPF/DKIM/DMARC)

SPF:

```bash
call.sh POST /zones/:zone_id/dns_records \
  --zone=<id> --account=idcbr \
  --data='{
    "type": "TXT",
    "name": "@",
    "content": "v=spf1 include:_spf.google.com include:amazonses.com ~all",
    "ttl": 3600
  }'
```

DKIM:

```bash
call.sh POST /zones/:zone_id/dns_records \
  --zone=<id> --account=idcbr \
  --data='{
    "type": "TXT",
    "name": "selector1._domainkey",
    "content": "v=DKIM1; k=rsa; p=MIGfMA0...",
    "ttl": 3600
  }'
```

DMARC:

```bash
call.sh POST /zones/:zone_id/dns_records \
  --zone=<id> --account=idcbr \
  --data='{
    "type": "TXT",
    "name": "_dmarc",
    "content": "v=DMARC1; p=reject; rua=mailto:dmarc@example.com; pct=100",
    "ttl": 3600
  }'
```

### Atualizar record (PATCH)

Parcial (só campos alterados):

```bash
call.sh PATCH /zones/:zone_id/dns_records/abc123 \
  --zone=<id> --account=idcbr \
  --data='{"content":"5.6.7.8","comment":"updated 2026-04-19"}'
```

Total (PUT substitui tudo):

```bash
call.sh PUT /zones/:zone_id/dns_records/abc123 \
  --zone=<id> --account=idcbr \
  --data='{
    "type": "A",
    "name": "api",
    "content": "5.6.7.8",
    "proxied": true,
    "ttl": 1
  }'
```

### Deletar record (com confirmação)

Sempre com dry-run primeiro:

```bash
# 1. Ver o que seria feito
call.sh DELETE /zones/:zone_id/dns_records/abc123 \
  --zone=<id> --account=idcbr --dry-run

# 2. Executar (irreversível)
call.sh DELETE /zones/:zone_id/dns_records/abc123 \
  --zone=<id> --account=idcbr
```

Resposta:

```json
{"result": {"id": "abc123"}, "success": true}
```

### Trigger Workers Build manual

Requer conhecer `trigger_uuid` (ver dashboard ou `/builds/workers/:tag/triggers`):

```bash
call.sh POST /accounts/:account_id/builds/triggers/ed429790-6a5c-4412-bb78-3093c82619b2/builds \
  --account=idcbr \
  --data='{}'
```

### Purge cache por URLs

```bash
call.sh POST /zones/:zone_id/purge_cache \
  --zone=<id> --account=idcbr \
  --data='{
    "files": [
      "https://example.com/style.css",
      "https://example.com/app.js"
    ]
  }'
```

### Purge cache por tags

Requer Cache Tags configuradas via Workers ou Page Rules:

```bash
call.sh POST /zones/:zone_id/purge_cache \
  --zone=<id> --account=idcbr \
  --data='{"tags": ["homepage", "blog-post-42"]}'
```

### Purge cache total (último recurso)

```bash
call.sh POST /zones/:zone_id/purge_cache \
  --zone=<id> --account=idcbr \
  --data='{"purge_everything": true}'
```

Cuidado: invalida tudo, origem vai receber carga pesada.

### GraphQL Analytics

Top 10 hostnames por tráfego nas últimas 24h:

```bash
cat > /tmp/top-hosts.json <<'EOF'
{
  "query": "query TopHosts($accountTag: string!, $since: Time!, $until: Time!) { viewer { accounts(filter: {accountTag: $accountTag}) { httpRequestsAdaptiveGroups(filter: {datetime_geq: $since, datetime_lt: $until}, limit: 10, orderBy: [count_DESC]) { count dimensions { clientRequestHTTPHost } } } } }",
  "variables": {
    "accountTag": "1783e2ca3a473ef8334a8b17df42878e",
    "since": "2026-04-18T00:00:00Z",
    "until": "2026-04-19T00:00:00Z"
  }
}
EOF

call.sh POST /graphql \
  --base=https://api.cloudflare.com/client/v4/graphql \
  --account=idcbr \
  --data-file=/tmp/top-hosts.json \
  --format=pretty
```

### Listar Access apps

```bash
call.sh GET /accounts/:account_id/access/apps \
  --account=idcbr --format=pretty
```

### Configurar setting de zona (SSL)

```bash
call.sh PATCH /zones/:zone_id/settings/ssl \
  --zone=<id> --account=idcbr \
  --data='{"value": "full_strict"}'
```

Settings comuns:

| Setting | Valores típicos |
|---------|------------------|
| `ssl` | `off`, `flexible`, `full`, `full_strict` |
| `min_tls_version` | `1.0`, `1.1`, `1.2`, `1.3` |
| `always_use_https` | `on`, `off` |
| `automatic_https_rewrites` | `on`, `off` |
| `brotli` | `on`, `off` |
| `http3` | `on`, `off` |
| `0rtt` | `on`, `off` |
| `security_level` | `off`, `essentially_off`, `low`, `medium`, `high`, `under_attack` |

---

[Voltar para índice](../guides/cloudflare/README.md)
