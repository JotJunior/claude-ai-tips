# typescript/

Skills, hooks e convenções específicas de TypeScript. **Categoria scaffold** —
estrutura criada, skills concretas serão adicionadas em fase futura.

## Status

🚧 **Em planejamento** — pasta criada, sem skills/hooks ainda.

## Stack alvo (observada nos projetos de referência)

Padrão convergente em projetos do autor (unity-dash, inde-intelligence, split-ai):

- **Runtime**: Cloudflare Workers
- **Server framework**: Hono
- **TypeScript**: strict + noUncheckedIndexedAccess + verbatimModuleSyntax
- **DB + ORM**: Drizzle (D1, Postgres)
- **Validação**: Zod
- **Testes**: Vitest + @cloudflare/vitest-pool-workers
- **Frontend**: React 19 (Next 15 App Router OU Vite SPA)
- **UI**: Tailwind 4 + shadcn/ui + Radix
- **Forms**: react-hook-form + Zod resolver
- **Data client**: TanStack Query v5
- **Package manager**: bun (preferido) | pnpm | npm

## Skills planejadas

Lista não-vinculante. Será ajustada conforme necessidade real:

- `ts-commit` — conventional commits + commitlint + detecta submodules
- `ts-add-domain` — scaffold bounded context (DDD pattern do split-ai)
- `ts-add-route` — handler Hono com Zod + service delegation
- `ts-add-test` — Vitest + vitest-pool-workers (CF Workers env)
- `ts-review-pr` — gate completo (lint, typecheck, tests, architecture)

## Hooks planejados

- `ts-typecheck-gate` — PostToolCall: tsc --noEmit no package afetado
- `ts-eslint-gate` — PostToolCall: eslint --max-warnings 0
- `check-date-toisostring` — bloqueia new Date().toISOString() fora de utils
- `check-uuid-v4` — sugere UUID v7
- `check-sql-in-routes` — bloqueia SQL literal em route handlers

## Padrões-chave (a serem codificados)

Observados em código real e candidatos a virar regras automatizadas:

1. Arquitetura por bounded context (DDD)
2. Naming kebab-case.{role}.ts (pix.controller.ts)
3. Testes co-localizados em __tests__/
4. AppError hierarchy com toResponse()
5. UUIDv7 obrigatório (UUIDv4 proibido)
6. Soft-delete via deleted_at
7. Timezone discipline (helpers; sem Date.toISOString direto)
8. PII masking em logs
9. Idempotência em webhooks
10. Queue-first (cron só enfileira)

## Como contribuir

Esta pasta está pronta para receber skills. Ver
[../../docs/contributing.md](../../docs/contributing.md).

## Ver também

- [../README.md](../README.md) — overview da categoria language-related/
- [../go/](../go/) — referência de skills de linguagem já implementadas
- [../dotnet/](../dotnet/) — outra referência
