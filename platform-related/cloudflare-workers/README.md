# platform-related/cloudflare-workers/

Skills para operacao de Cloudflare Workers: bindings, deploy, provisioning
de D1/KV/R2/Queue/DO/AI. Foco em OPS — codigo (rotas, handlers, testes)
vai para `language-related/typescript/`.

## Conteudo

| Recurso | Tipo | Descricao |
|---------|------|-----------|
| [`skills/cf-workers-add-route/`](./skills/cf-workers-add-route/) | skill | Adiciona route HTTP via wrangler.toml + custom_domain |
| [`skills/cf-workers-add-binding/`](./skills/cf-workers-add-binding/) | skill | Adiciona binding generico (D1/KV/R2/Queue/DO/AI) ao wrangler.toml |
| [`skills/cf-workers-create-d1/`](./skills/cf-workers-create-d1/) | skill | Cria database D1 + migration inicial via wrangler |
| [`skills/cf-workers-create-kv-namespace/`](./skills/cf-workers-create-kv-namespace/) | skill | Cria KV namespace + configura dev local com local-kv |
| [`skills/cf-workers-create-r2-bucket/`](./skills/cf-workers-create-r2-bucket/) | skill | Cria R2 bucket + CORS policy default |
| [`skills/cf-workers-add-migration/`](./skills/cf-workers-add-migration/) | skill | Gera e aplica D1 migration via wrangler d1 migrations apply |
| [`skills/cf-workers-add-queue-consumer/`](./skills/cf-workers-add-queue-consumer/) | skill | Cria Queue consumer + DLQ + retry policy |
| [`skills/cf-workers-add-webhook/`](./skills/cf-workers-add-webhook/) | skill | Webhook endpoint com HMAC-SHA256 + idempotency |
| [`skills/cf-workers-deploy-check/`](./skills/cf-workers-deploy-check/) | skill | Validacao pre-deploy (bindings, secrets, wrangler.toml) |

## Conceitos-chave

- **wrangler.toml:** arquivo de configuracao do Worker (name, main, bindings, triggers)
- **Bindings:** D1, KV, R2, Queue, DO (Durable Objects), AI (Workers AI)
- **Secrets:** `wrangler secret put <name>` — nao commitar no repo
- **CPU/duration limits:** 50ms gratis, 5min paid (CPU time, nao wall clock)
- **Observability:** Workers Analytics no dashboard + tail workers para logs

## Dependencias

- [`../cloudflare-shared/`](../cloudflare-shared/) — cf-api-call, cf-credentials-setup
- `wrangler` v4+ instalado e autenticado
- `jq` para parsing JSON nos scripts

## Stack

- **CLI:** wrangler v4 (Workers, Pages, D1, KV, R2, Queues, AI)
- **Runtime:** Cloudflare Workers (V8 isolates, edge)
- **Deploy:** `wrangler deploy` ou Git Integration ( Workers > Deployments )
- **Bindings:** tipo-safe via @cloudflare/workers-types

## Como invocar

```
"adicione um binding D1 chamado USERS_DB ao projeto"
"crie um KV namespace para cache de sessoes"
"add route /api/v1 para o worker atual com custom domain"
"deploy check antes de subir para production"
"add queue consumer para processar eventos de users"
```

## Padroes-chave

- **Bindings type-safe:** usar @cloudflare/workers-types para tipar environments
- **Secrets via CLI:** `wrangler secret put` — nunca hardcoded no wrangler.toml
- **Idempotencia:** checar se recurso existe antes de criar (--dry-run)
- **Git Integration:** workers podem ser deployados automaticamente via git push
- **DLQ configuravel:** falhas vao para Dead Letter Queue apos retries
- **Migrations D1:** sempre via wrangler (nao direto na API) para controle de versao
- **Observabilidade:** ativar tail workers para coletar logs em producao

## Ver tambem

- [`../../language-related/typescript/`](../../language-related/typescript/) — codigo (rotas, handlers)
- [`../cloudflare-shared/`](./cloudflare-shared/) — fundacao (cf-api-call, credentials)
- [`../cloudflare-dns/`](./cloudflare-dns/) — DNS records para custom domains
- [`../../data-related/d1/`](../../data-related/d1/) — D1 query patterns e otimizacao
