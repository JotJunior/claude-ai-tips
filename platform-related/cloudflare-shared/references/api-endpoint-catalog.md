# Cloudflare API — catalogo curado de endpoints

Catalogo nao-exaustivo de endpoints da Cloudflare REST API usados pelas
skills do toolkit. Para catalogo oficial completo, consultar
[developers.cloudflare.com/api](https://developers.cloudflare.com/api/).

Base URL padrao: `https://api.cloudflare.com/client/v4`

## Convencoes de path

Placeholders usados pelas skills (substituidos automaticamente pelo
`cf-api-call` via metadata):

| Placeholder | Origem | Exemplo |
|-------------|--------|---------|
| `:account_id` | `--account=<nick>` -> `metadata.account_id` | `1783e2ca3a473ef8334a8b17df42878e` |
| `:zone_id` | `--zone=<nick\|id>` | `abc123...` |
| `:script_tag` | ao interagir com builds | `6d0ee4c...` |
| `:trigger_uuid` | ao interagir com builds | `ed429790-...` |

## User & Tokens

| Operacao | Metodo | Path |
|----------|--------|------|
| Info do usuario atual | GET | `/user` |
| Verificar token | GET | `/user/tokens/verify` |
| Listar tokens | GET | `/user/tokens` |
| Criar token | POST | `/user/tokens` |
| Deletar token | DELETE | `/user/tokens/{id}` |
| Memberships (contas acessiveis) | GET | `/memberships` |

## Accounts

| Operacao | Metodo | Path |
|----------|--------|------|
| Listar contas | GET | `/accounts` |
| Detalhes da conta | GET | `/accounts/:account_id` |
| Members | GET | `/accounts/:account_id/members` |
| Roles | GET | `/accounts/:account_id/roles` |

## Zones

| Operacao | Metodo | Path |
|----------|--------|------|
| Listar zonas | GET | `/zones` |
| Criar zona | POST | `/zones` |
| Detalhes | GET | `/zones/:zone_id` |
| Settings (todos) | GET | `/zones/:zone_id/settings` |
| Setting especifico | GET | `/zones/:zone_id/settings/{name}` |
| Patch setting | PATCH | `/zones/:zone_id/settings/{name}` |
| Activation check | PUT | `/zones/:zone_id/activation_check` |
| Hold | POST | `/zones/:zone_id/hold` |

Settings comumente configurados:
`ssl`, `min_tls_version`, `tls_1_3`, `always_use_https`,
`automatic_https_rewrites`, `http3`, `brotli`, `0rtt`, `ipv6`,
`websockets`, `opportunistic_encryption`, `cache_level`,
`browser_cache_ttl`, `security_level`, `challenge_ttl`,
`development_mode`, `email_obfuscation`, `hotlink_protection`.

## DNS

| Operacao | Metodo | Path |
|----------|--------|------|
| Listar records | GET | `/zones/:zone_id/dns_records` |
| Criar record | POST | `/zones/:zone_id/dns_records` |
| Detalhes | GET | `/zones/:zone_id/dns_records/{id}` |
| Atualizar (total) | PUT | `/zones/:zone_id/dns_records/{id}` |
| Patch parcial | PATCH | `/zones/:zone_id/dns_records/{id}` |
| Deletar | DELETE | `/zones/:zone_id/dns_records/{id}` |
| Export BIND | GET | `/zones/:zone_id/dns_records/export` |
| Import BIND | POST | `/zones/:zone_id/dns_records/import` |
| Scan | POST | `/zones/:zone_id/dns_records/scan` |
| DNSSEC status | GET | `/zones/:zone_id/dnssec` |
| Ativar DNSSEC | PATCH | `/zones/:zone_id/dnssec` (body: `status=active`) |

Query params relevantes em `GET /dns_records`:
- `type=A|AAAA|CNAME|TXT|MX|SRV|CAA|...`
- `name=exact-name` ou `name.contains=substring`
- `content=exact-content`
- `proxied=true|false`
- `per_page=50` (max 100), `page=N`

Types suportados: `A`, `AAAA`, `CNAME`, `HTTPS`, `TXT`, `SRV`, `LOC`,
`MX`, `NS`, `CERT`, `DNSKEY`, `DS`, `NAPTR`, `SMIMEA`, `SSHFP`, `SVCB`,
`TLSA`, `URI`, `PTR`, `CAA`.

## Workers

| Operacao | Metodo | Path |
|----------|--------|------|
| Listar scripts | GET | `/accounts/:account_id/workers/scripts` |
| Detalhes | GET | `/accounts/:account_id/workers/scripts/{name}` |
| Deletar | DELETE | `/accounts/:account_id/workers/scripts/{name}` |
| Deployments | GET | `/accounts/:account_id/workers/scripts/{name}/deployments` |
| Versions | GET | `/accounts/:account_id/workers/scripts/{name}/versions` |
| Tail (websocket) | POST | `/accounts/:account_id/workers/scripts/{name}/tails` |
| Routes (zona) | GET | `/zones/:zone_id/workers/routes` |
| Custom domain | GET | `/accounts/:account_id/workers/domains` |

## Workers Builds (Git Integration)

**IMPORTANTE**: usar namespace `/builds/` — os endpoints legacy
`/workers/scripts/{name}/deployments` mostram `source: "wrangler"` mesmo
para deploys feitos via Git Integration. A verdade canonica fica em
`/builds/`.

| Operacao | Metodo | Path |
|----------|--------|------|
| Listar triggers | GET | `/accounts/:account_id/builds/workers/{script_tag}/triggers` |
| Detalhes trigger | GET | `/accounts/:account_id/builds/triggers/{trigger_uuid}` |
| Patch trigger | PATCH | `/accounts/:account_id/builds/triggers/{trigger_uuid}` |
| Patch env vars trigger | PATCH | `/accounts/:account_id/builds/triggers/{trigger_uuid}/environment_variables` |
| Disparar build manual | POST | `/accounts/:account_id/builds/triggers/{trigger_uuid}/builds` |
| Listar builds | GET | `/accounts/:account_id/builds` |
| Detalhes build | GET | `/accounts/:account_id/builds/builds/{build_uuid}` |
| Logs build | GET | `/accounts/:account_id/builds/builds/{build_uuid}/logs` |
| Account limits | GET | `/accounts/:account_id/builds/account/limits` |

`script_tag` != `script_name`. Obter via `GET /accounts/:account_id/workers/scripts/{name}` e ler `tag`.

## D1

| Operacao | Metodo | Path |
|----------|--------|------|
| Listar DBs | GET | `/accounts/:account_id/d1/database` |
| Detalhes | GET | `/accounts/:account_id/d1/database/{db_id}` |
| Criar | POST | `/accounts/:account_id/d1/database` |
| Deletar | DELETE | `/accounts/:account_id/d1/database/{db_id}` |
| Executar SQL | POST | `/accounts/:account_id/d1/database/{db_id}/query` |
| Raw (multi-statement) | POST | `/accounts/:account_id/d1/database/{db_id}/raw` |
| Export (Cloudflare internal) | POST | `/accounts/:account_id/d1/database/{db_id}/export` |

Body de `query`:
```json
{"sql": "SELECT * FROM users WHERE id = ?", "params": ["123"]}
```

## KV

| Operacao | Metodo | Path |
|----------|--------|------|
| Listar namespaces | GET | `/accounts/:account_id/storage/kv/namespaces` |
| Criar namespace | POST | `/accounts/:account_id/storage/kv/namespaces` |
| Get key | GET | `/accounts/:account_id/storage/kv/namespaces/{ns_id}/values/{key}` |
| Put key | PUT | `/accounts/:account_id/storage/kv/namespaces/{ns_id}/values/{key}` |
| Delete key | DELETE | `/accounts/:account_id/storage/kv/namespaces/{ns_id}/values/{key}` |
| List keys | GET | `/accounts/:account_id/storage/kv/namespaces/{ns_id}/keys` |
| Bulk write | PUT | `/accounts/:account_id/storage/kv/namespaces/{ns_id}/bulk` |
| Bulk delete | DELETE | `/accounts/:account_id/storage/kv/namespaces/{ns_id}/bulk` |

Bulk: body eh array de `{key, value, metadata?, expiration?, expiration_ttl?, base64?}`. Max 10.000 por request.

## R2

| Operacao | Metodo | Path |
|----------|--------|------|
| Listar buckets | GET | `/accounts/:account_id/r2/buckets` |
| Criar bucket | POST | `/accounts/:account_id/r2/buckets` |
| Deletar bucket | DELETE | `/accounts/:account_id/r2/buckets/{name}` |
| CORS config | PUT | `/accounts/:account_id/r2/buckets/{name}/cors` |
| Lifecycle | PUT | `/accounts/:account_id/r2/buckets/{name}/lifecycle` |
| Custom domains | GET | `/accounts/:account_id/r2/buckets/{name}/domains/custom` |
| Public access | GET | `/accounts/:account_id/r2/buckets/{name}/domains/managed` |

Objetos em si via S3 API (`https://{account_id}.r2.cloudflarestorage.com`).

## Queues

| Operacao | Metodo | Path |
|----------|--------|------|
| Listar | GET | `/accounts/:account_id/queues` |
| Criar | POST | `/accounts/:account_id/queues` |
| Deletar | DELETE | `/accounts/:account_id/queues/{queue_id}` |
| Consumers | GET | `/accounts/:account_id/queues/{queue_id}/consumers` |
| Message ack/retry | POST | `/accounts/:account_id/queues/{queue_id}/messages/ack` |

## Access (Zero Trust)

| Operacao | Metodo | Path |
|----------|--------|------|
| Apps | GET | `/accounts/:account_id/access/apps` |
| Criar app | POST | `/accounts/:account_id/access/apps` |
| Policies de app | GET | `/accounts/:account_id/access/apps/{app_id}/policies` |
| Identity providers | GET | `/accounts/:account_id/access/identity_providers` |
| Groups | GET | `/accounts/:account_id/access/groups` |
| Service tokens | GET | `/accounts/:account_id/access/service_tokens` |
| Users sessions | GET | `/accounts/:account_id/access/organizations/revoke_user` |

## WAF / Firewall

| Operacao | Metodo | Path |
|----------|--------|------|
| Custom rules (zona) | GET | `/zones/:zone_id/firewall/rules` |
| Custom rules (conta) | GET | `/accounts/:account_id/firewall/rules` |
| Rate limiting | GET | `/zones/:zone_id/rate_limits` |
| Managed rulesets | GET | `/zones/:zone_id/rulesets` |
| IP lists | GET | `/accounts/:account_id/rules/lists` |
| Add/remove IPs | POST/DELETE | `/accounts/:account_id/rules/lists/{list_id}/items` |

## Rules (Transform, Redirect, Origin, Cache)

Todas seguem padrao `rulesets`:

| Operacao | Metodo | Path |
|----------|--------|------|
| Listar rulesets | GET | `/zones/:zone_id/rulesets` |
| Criar ruleset | POST | `/zones/:zone_id/rulesets` |
| Detalhes | GET | `/zones/:zone_id/rulesets/{ruleset_id}` |
| Atualizar | PUT | `/zones/:zone_id/rulesets/{ruleset_id}` |
| Phase entry point | GET | `/zones/:zone_id/rulesets/phases/{phase}/entrypoint` |

`phase`: `http_request_dynamic_redirect`, `http_request_transform`,
`http_request_origin`, `http_request_cache_settings`,
`http_request_firewall_custom`, etc.

## Pages

| Operacao | Metodo | Path |
|----------|--------|------|
| Listar projects | GET | `/accounts/:account_id/pages/projects` |
| Detalhes | GET | `/accounts/:account_id/pages/projects/{name}` |
| Deployments | GET | `/accounts/:account_id/pages/projects/{name}/deployments` |
| Detalhes deploy | GET | `/accounts/:account_id/pages/projects/{name}/deployments/{dep_id}` |
| Aliases | GET | `/accounts/:account_id/pages/projects/{name}/domains` |

## Cache

| Operacao | Metodo | Path |
|----------|--------|------|
| Purge by URLs | POST | `/zones/:zone_id/purge_cache` body: `{files: [...]}` |
| Purge by tags | POST | `/zones/:zone_id/purge_cache` body: `{tags: [...]}` |
| Purge everything | POST | `/zones/:zone_id/purge_cache` body: `{purge_everything: true}` |
| Cache Reserve | GET | `/zones/:zone_id/cache/cache_reserve` |

## SSL/TLS

| Operacao | Metodo | Path |
|----------|--------|------|
| Edge certs | GET | `/zones/:zone_id/ssl/certificate_packs` |
| Custom certs | GET | `/zones/:zone_id/custom_certificates` |
| Verification | GET | `/zones/:zone_id/ssl/verification` |
| mTLS (client certs) | GET | `/zones/:zone_id/access/certificates` |

## Analytics (GraphQL)

Base URL diferente: `https://api.cloudflare.com/client/v4/graphql`
Metodo: sempre `POST` com `{"query": "..."}` ou `{"query": "...", "variables": {...}}`

Datasets comuns (como campos raiz):

| Dataset | Uso |
|---------|-----|
| `httpRequestsAdaptive` | Trafego HTTP |
| `dnsQueriesAdaptiveGroups` | DNS analytics |
| `firewallEventsAdaptive` | Eventos WAF |
| `workersInvocationsAdaptive` | Workers execucoes |
| `workersAnalyticsEngineAdaptiveGroups` | AE queries |

Exemplo de query:

```graphql
query TopHosts($accountTag: String!, $since: Time!, $until: Time!) {
  viewer {
    accounts(filter: {accountTag: $accountTag}) {
      httpRequestsAdaptiveGroups(
        filter: {datetime_geq: $since, datetime_lt: $until}
        limit: 10
        orderBy: [count_DESC]
      ) {
        count
        dimensions { clientRequestHTTPHost }
      }
    }
  }
}
```

## Observability (Workers Logs)

| Operacao | Metodo | Path |
|----------|--------|------|
| Query logs | POST | `/accounts/:account_id/workers/observability/telemetry/query` |
| Keys (listagem) | POST | `/accounts/:account_id/workers/observability/telemetry/keys` |
| Datasets | GET | `/accounts/:account_id/workers/observability/datasets` |

## Turnstile

| Operacao | Metodo | Path |
|----------|--------|------|
| Sites | GET | `/accounts/:account_id/challenges/widgets` |
| Criar site | POST | `/accounts/:account_id/challenges/widgets` |
| Rotate secret | POST | `/accounts/:account_id/challenges/widgets/{sitekey}/rotate_secret` |

## Images

| Operacao | Metodo | Path |
|----------|--------|------|
| Upload | POST | `/accounts/:account_id/images/v1` (multipart) |
| Detalhes | GET | `/accounts/:account_id/images/v1/{image_id}` |
| Variants | GET | `/accounts/:account_id/images/v1/variants` |
| Deletar | DELETE | `/accounts/:account_id/images/v1/{image_id}` |

## Stream

| Operacao | Metodo | Path |
|----------|--------|------|
| Listar videos | GET | `/accounts/:account_id/stream` |
| Upload direto | POST | `/accounts/:account_id/stream/direct_upload` |
| Detalhes | GET | `/accounts/:account_id/stream/{video_uid}` |
| Live inputs | GET | `/accounts/:account_id/stream/live_inputs` |

## Load Balancers

| Operacao | Metodo | Path |
|----------|--------|------|
| Pools | GET | `/accounts/:account_id/load_balancers/pools` |
| Monitors | GET | `/accounts/:account_id/load_balancers/monitors` |
| Load balancers (zona) | GET | `/zones/:zone_id/load_balancers` |

## Rate limits

CF API impoe ~1200 req / 5min por token. Erros 429 retornam
`Retry-After: <seconds>`. `cf-api-call` respeita automaticamente.

Burst limits adicionais em endpoints intensivos (bulk DNS import, KV
bulk, Images upload) — consultar docs oficiais por endpoint.

## Error codes comuns

| Code | Descricao |
|------|-----------|
| 10000 | Authentication error (token invalido/expirado) |
| 10001 | Account forbidden (token nao tem escopo na conta) |
| 7003 | Invalid zone identifier |
| 81057 | DNS record already exists |
| 81058 | DNS record content invalid |
| 1000 | Rate limited (alternativa a 429 em alguns endpoints legacy) |
| 9106 | Missing required parameter |
| 9109 | Invalid parameter value |

`cf-api-call` emite `.errors[].code` no stderr em formato estruturado.
