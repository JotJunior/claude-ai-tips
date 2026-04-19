# API REST vs Wrangler CLI — o que usar quando

Cloudflare expoe duas interfaces primarias para operacoes programaticas:

1. **Wrangler CLI** (`wrangler`) — cobertura focada em Workers + recursos
   bindados (D1, KV, R2, Queues), deploy, dev
2. **REST API** (`api.cloudflare.com/client/v4`) — cobertura completa,
   incluindo recursos que Wrangler nao toca

Esta referencia documenta qual interface usar para cada caso e por que.

## Regra geral

Preferir Wrangler quando cobre a operacao — e mais idiomatico, trata
auth via `wrangler login`, integra com `wrangler.toml`, recebe fixes
rapidos da CF. Recorrer a REST API somente quando:

1. A operacao nao existe em Wrangler (maioria dos casos listados abaixo)
2. Automacao precisa controle fino (retry, rate limit, batch)
3. Integracao CI/CD com auth por token (Wrangler tambem aceita, mas
   skills de toolkit padronizam via `cf-api-call`)

## Tabela de cobertura

| Dominio | Wrangler | REST API | Recomendacao |
|---------|----------|----------|---------------|
| **Workers** | | | |
| Deploy script | ✅ `wrangler deploy` | ✅ | **Wrangler** |
| Tail logs | ✅ `wrangler tail` | ❌ | Wrangler |
| Local dev | ✅ `wrangler dev` | n/a | Wrangler |
| Versions upload | ✅ `wrangler versions upload` | ✅ | Wrangler |
| Secret put/list/delete | ✅ `wrangler secret *` | ✅ | **Wrangler** |
| Custom domains | ⚠️ parcial (`wrangler deployments domains`) | ✅ | API para configuracao avancada |
| Workers Routes | ⚠️ `wrangler deployments` (limitado) | ✅ | **API** para CRUD completo |
| Workers Builds triggers | ❌ | ✅ | **API apenas** |
| Cron triggers | ✅ via `wrangler.toml [triggers]` | ✅ | Wrangler |
| **D1** | | | |
| Criar DB | ✅ `wrangler d1 create` | ✅ | Wrangler |
| Aplicar migrations | ✅ `wrangler d1 migrations apply` | ❌ | **Wrangler apenas** |
| Executar SQL ad-hoc | ✅ `wrangler d1 execute` | ✅ | Wrangler |
| Export | ✅ `wrangler d1 export` | ✅ | Wrangler |
| **KV** | | | |
| Criar namespace | ✅ `wrangler kv:namespace create` | ✅ | Wrangler |
| Put/get/list keys | ✅ `wrangler kv:key *` | ✅ | Ambos |
| Bulk operations | ⚠️ limitado | ✅ | **API** para bulk |
| **R2** | | | |
| Criar bucket | ✅ `wrangler r2 bucket create` | ✅ | Wrangler |
| CORS policy | ❌ | ✅ | **API apenas** |
| Lifecycle policy | ❌ | ✅ | **API apenas** |
| Public access / custom domain | ⚠️ `wrangler r2 bucket domain` | ✅ | API para configuracao completa |
| Upload/list/delete objects | ✅ `wrangler r2 object *` | ✅ | Ambos |
| **Queues** | | | |
| Criar queue | ✅ `wrangler queues create` | ✅ | Wrangler |
| Producer/consumer binding | ✅ via `wrangler.toml` | ✅ | Wrangler |
| Dead letter queue | ✅ via `wrangler.toml` | ✅ | Wrangler |
| **DNS** | | | |
| Criar/editar record | ❌ | ✅ | **API apenas** |
| Listar records | ❌ | ✅ | **API apenas** |
| DNSSEC | ❌ | ✅ | **API apenas** |
| Dynamic DNS | ❌ | ✅ | **API apenas** |
| Import/export zone | ❌ | ✅ | **API apenas** |
| **Zones** | | | |
| Criar zona | ❌ | ✅ | **API apenas** |
| Settings (SSL, cache, etc.) | ❌ | ✅ | **API apenas** |
| Zone hold | ❌ | ✅ | **API apenas** |
| **Access** | | | |
| Apps | ❌ | ✅ | **API apenas** |
| Policies | ❌ | ✅ | **API apenas** |
| Identity providers | ❌ | ✅ | **API apenas** |
| Groups | ❌ | ✅ | **API apenas** |
| Service tokens | ❌ | ✅ | **API apenas** |
| **WAF** | | | |
| Custom rules | ❌ | ✅ | **API apenas** |
| Managed rulesets | ❌ | ✅ | **API apenas** |
| Rate limiting rules | ❌ | ✅ | **API apenas** |
| IP lists | ❌ | ✅ | **API apenas** |
| **Page Rules / Transform** | | | |
| Page Rules (legado) | ❌ | ✅ | **API apenas** |
| Transform Rules | ❌ | ✅ | **API apenas** |
| Redirect Rules | ❌ | ✅ | **API apenas** |
| Origin Rules | ❌ | ✅ | **API apenas** |
| **Cache** | | | |
| Cache Rules | ❌ | ✅ | **API apenas** |
| Purge by URL | ⚠️ via dashboard | ✅ | **API** |
| Purge by tag | ❌ | ✅ | **API apenas** |
| Cache Reserve | ❌ | ✅ | **API apenas** |
| **SSL/TLS** | | | |
| Settings | ❌ | ✅ | **API apenas** |
| Edge Certificates | ❌ | ✅ | **API apenas** |
| Custom Certificates | ❌ | ✅ | **API apenas** |
| Client Certificates (mTLS) | ❌ | ✅ | **API apenas** |
| **Pages** | | | |
| Deploy | ✅ `wrangler pages deploy` | ✅ | Wrangler |
| Project settings avancadas | ❌ | ✅ | **API** |
| Deploy hooks | ❌ | ✅ | **API apenas** |
| Custom domain alias | ⚠️ | ✅ | API para config completa |
| **Images** | | | |
| Upload | ❌ | ✅ | **API apenas** |
| Variants | ❌ | ✅ | **API apenas** |
| **Stream** | | | |
| Upload video | ❌ | ✅ | **API apenas** |
| Playback settings | ❌ | ✅ | **API apenas** |
| **Workers AI / Vectorize** | | | |
| Listar modelos | ⚠️ | ✅ | API |
| Vectorize indexes | ✅ `wrangler vectorize create` | ✅ | Wrangler |
| **Hyperdrive** | | | |
| Criar connector | ✅ `wrangler hyperdrive create` | ✅ | Wrangler |
| Rotate password | ⚠️ | ✅ | API |
| **Load Balancers** | | | |
| Pools, origins, monitors | ❌ | ✅ | **API apenas** |
| Health checks | ❌ | ✅ | **API apenas** |
| **Turnstile** | | | |
| Site management | ❌ | ✅ | **API apenas** |
| **Tunnels (cloudflared)** | | | |
| Criar/gerenciar | ❌ (usar `cloudflared` CLI) | ✅ | **`cloudflared`** ou API |
| **Analytics** | | | |
| DNS, Firewall, HTTP, Workers | ❌ | ✅ (GraphQL) | **API apenas** (`POST /graphql`) |
| Logpush | ❌ | ✅ | **API apenas** |
| **Observability** | | | |
| Workers Observability query | ⚠️ dashboard | ✅ | API |

## Quando ambos cobrem — criterios de desempate

Quando tanto Wrangler quanto API resolvem, preferir Wrangler **exceto** em:

1. **Automacao/CI** com auth por token — `cf-api-call` + `cred-store`
   padroniza melhor que `wrangler login` em ambiente sem terminal
2. **Batch operations** — API aceita bulk; Wrangler geralmente serializa
3. **Multi-account** — API troca conta por request; Wrangler precisa
   re-login
4. **Rate limit / retry customizado** — `cf-api-call` ja implementa;
   Wrangler nao expoe config

## Auth: os dois planos

| Interface | Auth default | Auth alternativa |
|-----------|--------------|------------------|
| Wrangler | OAuth via `wrangler login` | `CLOUDFLARE_API_TOKEN` + `CLOUDFLARE_ACCOUNT_ID` |
| REST API | `Authorization: Bearer <token>` | `X-Auth-Key` + `X-Auth-Email` (legacy, evitar) |

`cf-credentials-setup` registra API Token que funciona para **ambos**
quando exposto via env vars. Assim skills de toolkit nao se preocupam
com re-auth.

## Endpoints canonicos

| Base URL | Uso |
|----------|-----|
| `https://api.cloudflare.com/client/v4` | REST padrao |
| `https://api.cloudflare.com/client/v4/graphql` | Analytics GraphQL |
| `https://dash.cloudflare.com/` | Dashboard (somente browser) |

Endpoints legacy como `/workers/scripts/{name}/settings` existem mas
retornam dados obsoletos quando deploy eh via Git Integration. Preferir
namespace `/builds/` para observabilidade de deploys automatizados
(ver `references/api-endpoint-catalog.md`).

## Checklist ao adicionar nova skill CF

1. A operacao existe em Wrangler? Usar Wrangler (skill `.sh` chama direto)
2. Nao existe em Wrangler? Usar `cf-api-call`
3. Precisa credencial? `cf-credentials-setup` pre-configurou o token
4. Afeta recurso em producao? Incluir `--dry-run` default + confirmacao
5. Muitas requisicoes em sequencia? Respeitar rate limit (1200 req/5min)
