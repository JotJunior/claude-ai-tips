# language-related/typescript/

Conjunto de skills para projetos TypeScript voltados a Cloudflare Workers com Hono,
Drizzle ORM, Zod, Vitest e TS strict mode. Foco em codigo — platform bindings
via `platform-related/cloudflare-workers/`.

## Skills

| Skill | Trigger principal | O que faz |
|-------|-------------------|-----------|
| [`ts-add-component/`](./skills/ts-add-component/) | `"add component"` | Scaffold React component com shadcn/ui + Tailwind + props typed |
| [`ts-add-domain/`](./skills/ts-add-domain/) | `"add domain"` | Cria bounded context DDD (entities, repositories, services) |
| [`ts-add-migration/`](./skills/ts-add-migration/) | `"add migration"` | Gera migration D1/Postgres via Drizzle (up/down, type-safe) |
| [`ts-add-queue-consumer/`](./skills/ts-add-queue-consumer/) | `"add queue"` | Worker consumers com retry policy + DLQ configuravel |
| [`ts-add-route/`](./skills/ts-add-route/) | `"add route"` | Endpoint Hono com zValidator, JSON schema, OpenAPI annotation |
| [`ts-add-test/`](./skills/ts-add-test/) | `"add test"` | Testes Vitest AAA (Arrange-Act-Assert) com mocks tipados |
| [`ts-add-webhook/`](./skills/ts-add-webhook/) | `"add webhook"` | Webhook handler com HMAC-SHA256 verification + idempotency key |
| [`ts-commit/`](./skills/ts-commit/) | `"commit"` | Conventional commits semanticos (feat/fix/refactor/docs/test/chore/ci/build/style) |
| [`ts-deploy-check/`](./skills/ts-deploy-check/) | `"deploy check"` | Validacao pre-deploy: typecheck, lint, tests, wrangler.toml |
| [`ts-refactor-budget/`](./skills/ts-refactor-budget/) | `"refactor budget"` | Enforce limites de tamanho por arquivo/funcao (warning >250, block >400 linhas) |
| [`ts-review-pr/`](./skills/ts-review-pr/) | `"review pr"` | Checklist pre-PR: типизация, error handling, testes, bindings |
| [`ts-review-security/`](./skills/ts-review-security/) | `"security review"` | Audit PII/SQLi/XSS/JWT/CORS — relatorio categorizado com fix |
| [`ts-upgrade-zod-schema/`](./skills/ts-upgrade-zod-schema/) | `"upgrade zod"` | Migração Zod v3 para v4 (infer<> → infer, .strict() mudancas) |

## Hooks

| Hook | Quando dispara | O que valida |
|------|----------------|--------------|
| `ts-typecheck-gate.sh` | PostToolCall Write\|Edit | `tsc --noEmit` —零点 tolerancia a type errors |
| `ts-eslint-gate.sh` | PostToolCall Write\|Edit | `eslint --max-warnings=0` —zero warnings tolerated |
| `check-date-toisostring.sh` | PreToolCall Bash | Bloqueia `Date.toISOString()` sem timezone handling |
| `check-uuid-v4.sh` | PreToolCall Write | Sugere ULID ou CUID2 no lugar de UUIDv4 |
| `check-soft-delete.sh` | PreToolCall Write | Bloqueia DELETE fisico em colunas `deletedAt` |
| `check-sql-in-routes.sh` | PreToolCall Write | SQL escrito fora de repositories (acoplamento) |
| `check-pii-in-logs.sh` | PreToolCall Bash | Bloqueia PII (email/cpf/senha) em logs — truncate obrigatorio |
| `check-file-budget.sh` | PreToolCall Write | Warning >250 linhas, block >400 linhas por arquivo |
| `check-wrangler-deploy.sh` | PreToolCall Bash | Bloqueia `wrangler deploy` na branch main |
| `check-commit-to-main.sh` | PreToolCall Bash | Impede `git commit` direto na main — exige feature branches |

## Stack alvo / Conceitos

- **Runtime:** Cloudflare Workers (edge, V8 isolates)
- **Framework:** Hono v4 + zValidator + OpenAPI 3.1
- **ORM:** Drizzle ORM (D1/Postgres — type-safe, migration-first)
- **Validation:** Zod v4 + inferred types para o frontend
- **Testing:** Vitest + @cloudflare/workers-test-utils
- **Package manager:** bun ou pnpm (detecta automaticamente)
- **TypeScript:** strict mode, `"noUncheckedIndexedAccess": true`, path aliases

## Como invocar

```
"crie uma nova rota POST /users com validacao de email e password"
"add route para /products com Pydantic-like schema no Hono"
"faça um review do PR #42 focando em seguranca"
"review pr: verifique bindings de D1 e secrets no wrangler.toml"
"commit dessas mudanças — feat: adicionar entity User"
"deploy check antes de subir para production"
"refactor budget: arquivo src/services/auth.ts esta com 380 linhas"
"upgrade zod para v4 no schema de validação de usuario"
```

## Padroes-chave

- **Commits semanticos:** tipo(scope): descricao — nunca commit genérico
- **Type-first:** todo parametro de funcao tem tipo, inferido ou explícito
- **Repository pattern:** SQL-only em repositories, services só chamam métodos tipados
- **Soft delete:** deletedAt + WHERE deletedAt IS NULL — nunca DELETE
- **Bindings tipados:** wrangler.toml → D1Binding, KVNamespace, etc.
- **Idempotency:** webhooks armazenam eventId para evitar double-processing
- **DLQ:** falhas em Queue consumer vao para DLQ após 3 retries com backoff exponencial
- **Migrations:** sempre idempotentes (IF NOT EXISTS, DROP IF EXISTS)
- **PII truncado:** logs mostram `222***222` para dados pessoais
- **TS strict:** sem `any`, sem `@ts-ignore`, sem `// eslint-disable`

## Ver tambem

- [`../../platform-related/cloudflare-workers/`](../../platform-related/cloudflare-workers/) — bindings, deploy, ops
- [`../../platform-related/cloudflare-shared/`](../../platform-related/cloudflare-shared/) — cf-api-call, cf-credentials-setup
- [`../../data-related/d1/`](../../data-related/d1/) — D1 query patterns, batch, FTS5
- [`../../global/skills/cred-store/`](../../global/skills/cred-store/) — gestao de credenciais
