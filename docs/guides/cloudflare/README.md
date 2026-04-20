# Cloudflare

Guia prático do namespace `platform-related/cloudflare-shared/` — uso de
Wrangler CLI + Cloudflare REST API via skills do toolkit.

## Visão geral

A Cloudflare expõe dois planos de integração programática:

| Plano | Cobre | Limitações |
|-------|-------|------------|
| **Wrangler CLI** | Workers deploy/dev/tail, secret management, D1 migrations, bindings (D1/KV/R2/Queue) | Não cobre DNS, Access, WAF, Workers Builds triggers, Page Rules, Rate Limiting, etc. |
| **REST API** (`api.cloudflare.com/client/v4`) | **Tudo** — superconjunto do Wrangler | Mais verboso; requer auth explícito; rate limit 1200 req/5min |

O toolkit oferece:

- **Hook** `check-wrangler-version` — avisa quando Wrangler local está desatualizado
- **Skill** `cf-wrangler-update` — atualiza no PM detectado (bun/pnpm/yarn/npm)
- **Skill** `cf-credentials-setup` — onboarding interativo de API token
- **Skill** `cf-api-call` — wrapper para REST API com retry, audit, rate-limit

## Estrutura deste guia

| Arquivo | Conteúdo |
|---------|----------|
| [setup.md](./setup.md) | Pré-requisitos, criação de API Token, registro de credenciais, validação |
| [wrangler.md](./wrangler.md) | Wrangler CLI, hook de versão, comandos comuns, deploy via Git Integration |
| [api-cookbook.md](./api-cookbook.md) | Exemplos práticos de chamadas REST (DNS, KV, R2, Workers, GraphQL) |
| [multi-account.md](./multi-account.md) | Nicknames, troca de conta por request, permissões granulares, audit trail |
| [troubleshooting.md](./troubleshooting.md) | Códigos de erro, diagnósticos, dry-run, debug |

## Ver também

- [`cf-api-call/SKILL.md`](../../platform-related/cloudflare-shared/skills/cf-api-call/SKILL.md)
- [`cf-credentials-setup/SKILL.md`](../../platform-related/cloudflare-shared/skills/cf-credentials-setup/SKILL.md)
- [`cf-wrangler-update/SKILL.md`](../../platform-related/cloudflare-shared/skills/cf-wrangler-update/SKILL.md)
- [`api-vs-wrangler.md`](../../platform-related/cloudflare-shared/references/api-vs-wrangler.md) — tabela de cobertura
- [`api-endpoint-catalog.md`](../../platform-related/cloudflare-shared/references/api-endpoint-catalog.md) — endpoints curados
- [`credential-storage.md`](../../platform-related/cloudflare-shared/references/credential-storage.md) — convenções CF
- [Cloudflare API docs](https://developers.cloudflare.com/api/)
- [Wrangler CLI docs](https://developers.cloudflare.com/workers/wrangler/)
- [Workers Builds](https://developers.cloudflare.com/workers/ci-cd/builds/)

---

[Voltar para índice principal](../guides/cloudflare/README.md)
