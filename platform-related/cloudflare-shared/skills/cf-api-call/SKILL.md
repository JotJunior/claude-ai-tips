---
name: cf-api-call
description: |
  Use quando precisar chamar qualquer endpoint da Cloudflare REST API
  (api.cloudflare.com/client/v4) que nao tem equivalente em wrangler CLI
  — DNS records, Workers Builds triggers, Access apps, Page Rules, WAF
  custom rules, Rate Limiting, Custom Domains, Load Balancers, Pages
  advanced, Images variants, Stream, Analytics. Tambem quando mencionar
  "cloudflare api", "cf api", "chamar api cloudflare", "api rest cf".
  Resolve credenciais automaticamente via cred-store, faz retry com
  backoff exponencial, respeita Retry-After em 429, loga audit. NAO use
  para operacoes cobertas por wrangler (workers deploy, d1 migrations
  apply, secret put) — use o CLI direto.
argument-hint: "<METHOD> <PATH> [--account=<nick>] [--zone=<id>] [--data='...'] [--query='...'] [--format=json|raw|pretty]"
allowed-tools:
  - Bash
  - Read
---

# Skill: Cloudflare API Call

Wrapper generico para chamadas a Cloudflare REST API. Consumido por
outras skills de `platform-related/cloudflare-*` para evitar duplicacao
de auth, retry, rate-limit handling e audit logging.

## Quando invocar

- Endpoint CF REST nao coberto por `wrangler` CLI
- Automacao que precisa de rate-limit awareness
- Multi-account com resolucao por nickname
- Operacao que demanda audit trail

Nao invocar para:

- `wrangler deploy`, `wrangler d1 migrations apply`, `wrangler secret put`
  e outras operacoes nativas do CLI — chamar direto
- Consumo de API em codigo de aplicacao (use biblioteca cliente,
  `fetch()`, SDK oficial)

## Argumentos

`<METHOD>` obrigatorio: `GET | POST | PATCH | PUT | DELETE`
`<PATH>` obrigatorio: path relativo ao base URL (ex: `/zones`, `/zones/:id/dns_records`)

Opcoes:

| Flag | Descricao |
|------|-----------|
| `--account=<nick>` | Nickname da conta registrada via `cred-store-setup` (ex: `idcbr`). Resolve credencial e substitui `:account_id` no path |
| `--zone=<nick\|id>` | Zone ID ou nickname; substitui `:zone_id` no path |
| `--data='<json>'` | JSON body (inline) |
| `--data-file=<path>` | JSON body lido de arquivo |
| `--query='<qs>'` | Query string (ex: `per_page=50&page=1`) |
| `--format=json\|raw\|pretty` | Formato de saida (default: `json`) |
| `--retry=<n>` | Max retries com backoff exponencial (default: `3`) |
| `--timeout=<s>` | Timeout por request em segundos (default: `30`) |
| `--base=<url>` | Base URL alternativo (default: `https://api.cloudflare.com/client/v4`) |
| `--audit` | Registra operacao em audit log (default: `on` para PATCH/POST/PUT/DELETE) |
| `--dry-run` | Imprime request sem executar |

## Base URLs conhecidos

| Base | Uso |
|------|-----|
| `https://api.cloudflare.com/client/v4` | **default** — REST API geral |
| `https://api.cloudflare.com/client/v4/graphql` | Analytics via GraphQL |
| `https://dash.cloudflare.com/api/v4` | (deprecado) endpoints legacy |

Para endpoints GraphQL usar `--base=https://api.cloudflare.com/client/v4/graphql`
e `POST` com `--data` contendo query.

## Resolucao de path com account/zone

O wrapper substitui placeholders `:account_id` e `:zone_id` no path
usando metadata resolvida via `cred-store`:

```bash
call.sh GET /accounts/:account_id/workers/scripts --account=idcbr
# expande para:
# GET /accounts/1783e2ca3a473ef8334a8b17df42878e/workers/scripts
```

Se `--account` eh passado mas o path nao tem `:account_id`, o account id
nao eh injetado — respeita o path literal.

## Retry e rate limit

- **Retry default: 3 tentativas** com backoff exponencial (1s, 2s, 4s + jitter)
- **429 Too Many Requests**: respeita header `Retry-After` se presente;
  caso contrario usa backoff padrao
- **5xx**: retry com backoff
- **4xx (exceto 429)**: NAO retry — erro do cliente, falha imediata
- **Network errors** (DNS, timeout): retry com backoff

Rate limit da CF API: ~1200 req / 5min por usuario. O wrapper nao impede
estouro proativamente — so reage ao 429. Para bulk ops intensivos, o
chamador deve throttlear (ex: 200 req + sleep 60s).

## Error handling

Cloudflare retorna erros no formato:

```json
{
  "success": false,
  "errors": [{"code": 10000, "message": "Authentication error"}],
  "messages": [],
  "result": null
}
```

O wrapper:
- Parseia `.success` e emite exit != 0 quando `false`
- stderr contem `[errors]` estruturado (code + message)
- stdout continua contendo o body completo para o chamador parsear se
  quiser
- Exit codes:
  - `0` sucesso (`.success == true`)
  - `1` erro de aplicacao (auth, permission, validation — nao-retriavel)
  - `2` erro de rede / timeout (apos retries)
  - `3` credencial nao encontrada (via cred-store)
  - `4` argumento invalido

## Audit log

Quando `--audit` ativo (ligado por default para metodos de escrita),
registra em `~/.claude/credentials/cloudflare/<account>/audit.log`:

```
2026-04-19T20:32:11Z POST /zones/abc/dns_records account=idcbr status=200 success=true
2026-04-19T20:33:02Z DELETE /zones/abc/dns_records/xyz account=idcbr status=200 success=true
```

**Nunca loga body nem headers** — apenas metodo, path, conta, status, success.

## Dry-run

`--dry-run` imprime a request completa (URL, method, headers redacted,
body) sem executar. Util para:

- Validar path e query antes de operacao destrutiva
- Gerar comando curl equivalente para documentacao
- Testar em ambiente de review (sem token)

Header `Authorization` sempre aparece como `Bearer [REDACTED]`.

## Saida

### Formato `json` (default)

```json
{"success": true, "result": {...}, "errors": [], "messages": []}
```

### Formato `raw`

Body puro, sem processamento. Util para endpoints que retornam
non-JSON (raro em CF API, mas existe).

### Formato `pretty`

JSON pretty-printed via `jq .`. Ideal para leitura humana.

## Exemplos

### Listar zonas da conta `idcbr`

```bash
call.sh GET /zones --account=idcbr --format=pretty
```

### Criar DNS record

```bash
call.sh POST /zones/:zone_id/dns_records \
  --zone=inde-intel.tkto.app \
  --data='{"type":"A","name":"novo","content":"1.2.3.4","proxied":true,"ttl":1}' \
  --account=idcbr
```

### Trigger Workers Build

```bash
call.sh POST /accounts/:account_id/builds/triggers/:trigger_uuid/builds \
  --account=idcbr \
  --data='{"trigger_type":"manual"}'
```

### Dry-run antes de delete

```bash
call.sh DELETE /zones/:zone_id/dns_records/abc123 \
  --zone=inde-intel.tkto.app --account=idcbr --dry-run
```

### GraphQL Analytics

```bash
call.sh POST /graphql \
  --base=https://api.cloudflare.com/client/v4/graphql \
  --account=idcbr \
  --data-file=./analytics-query.graphql.json
```

## Gotchas

### `.success == true` nao garante 200 OK em todas as rotas

Algumas rotas legacy (Workers scripts antigos, endpoints v3) retornam
201/202 com schema diferente. O wrapper prioriza `.success` quando o
response eh JSON com esse campo; caso contrario usa status HTTP.

### Header `Authorization` sempre enviado; CF auth fallback

O wrapper sempre envia `Authorization: Bearer <token>`. Para auth
legacy com `X-Auth-Key` + `X-Auth-Email`, o cred-store entry precisa
ter source=env com ref apontando para vars separadas, OU o chamador
usa `--base` com URL pre-autenticada. API tokens sao o padrao moderno.

### Retry eh idempotent-friendly

Metodos idempotentes (GET, PUT, DELETE) retry libremente. POST eh
retriado apenas em 429/5xx/network (assumindo que o handler server-side
protege idempotencia). Se o endpoint POST for nao-idempotente
(rare em CF — maioria aceita), passar `--retry=0`.

### Path sem `:account_id` nao recebe injecao automatica

Endpoints tipo `/user/tokens/verify` nao tem account no path — o
wrapper respeita o path literal. `--account` ainda eh usado para
resolver o token a enviar, mas nao altera o path.

### Cache de metadata do cred-store

O wrapper chama `cred-store resolve --with-metadata` a cada invocacao.
Para bulk operations (centenas de chamadas), cachear o token/metadata
em variavel local e passar via `--base` + `Authorization` manual nao
eh suportado — por design, para preservar audit trail por request.

### `.errors[].code` eh estavel, `.errors[].message` nao eh

Codigos de erro da CF API (ex: 10000 auth, 7003 invalid zone) sao
contratos publicos e podem ser parseados. Mensagens sao human-friendly
e mudam entre versoes — nao parsear por regex em mensagem.

### Rate limit por user vs por ip

CF aplica rate limit por user (token). Multiplas skills consumindo o
mesmo token somam no mesmo bucket. Se bulk ops batem 429, dividir o
trabalho entre contas/tokens distintos se aplicavel, ou throttlear.

### Audit log nao rotaciona automaticamente

`audit.log` cresce indefinidamente. Limpar periodicamente:

```bash
tail -n 10000 ~/.claude/credentials/cloudflare/idcbr/audit.log > /tmp/rotated.log
mv /tmp/rotated.log ~/.claude/credentials/cloudflare/idcbr/audit.log
```

## Scripts disponiveis

| Script | Uso |
|--------|-----|
| `scripts/call.sh` | Entrada principal — CLI que faz a chamada |

## Ver tambem

- [`global/skills/cred-store/`](../../../../global/skills/cred-store/) — gestao de credenciais
- [`references/api-endpoint-catalog.md`](../../references/api-endpoint-catalog.md) — catalogo de endpoints
- [`references/api-vs-wrangler.md`](../../references/api-vs-wrangler.md) — o que so existe na API
