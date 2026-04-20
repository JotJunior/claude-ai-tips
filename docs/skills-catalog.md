# Catálogo de Skills

Referência completa de todas as skills do toolkit com triggers, argumentos e
links para `SKILL.md`.

## Sumário por categoria

| Categoria | Skills | Status |
|-----------|--------|--------|
| [Global — Pipeline SDD](#global--pipeline-sdd) | 10 | estável |
| [Global — Complementares](#global--complementares) | 9 | estável |
| [Global — Credenciais](#global--credenciais) | 2 | 2.1.0 |
| [Global — Release & Git Methodology](#global--release--git-methodology) | 6 | 2.2.0 |
| [Go](#language-related--go) | 8 + 4 hooks | estável |
| [.NET](#language-related--dotnet) | 8 | estável |
| [Cloudflare Shared](#platform-related--cloudflare-shared) | 3 + 1 hook | 2.1.0 |
| [TypeScript](#language-related--typescript) | 13 + 10 hooks | 2.3.0 |
| [Python](#language-related--python) | 8 + 2 hooks | 2.3.0 |
| [Cloudflare Workers](#platform-related--cloudflare-workers) | 9 | 2.3.0 |
| [Cloudflare DNS](#platform-related--cloudflare-dns) | 7 | 2.3.0 |
| [Neon](#platform-related--neon) | 7 | 2.3.0 |
| [Postgres](#data-related--postgres) | 10 | 2.3.0 |
| [D1](#data-related--d1) | 6 | 2.3.0 |
| [Elasticsearch](#data-related--elasticsearch) | 7 | 2.3.0 |

**Total ativo**: 113 skills + 17 hooks + hubs de documentação.

---

## Global — Pipeline SDD

Pipeline linear para Spec-Driven Development. Cada skill consome artefatos da anterior.

### `briefing`

Entrevista interativa (max 10 perguntas, uma por vez) que captura contexto de
produto, usuários, restrições.

- **Invocação**: "iniciar briefing", "começar discovery", "entrevista de requisitos"
- **Saída**: `docs/01-briefing-discovery/briefing.md`
- **Próximo passo**: `constitution`
- **SKILL.md**: [`global/skills/briefing/SKILL.md`](../global/skills/briefing/SKILL.md)

### `constitution`

Extrai princípios arquiteturais (MUST/SHOULD imutáveis) do briefing.

- **Invocação**: "criar constitution", "definir princípios", "extrair constraints"
- **Entrada**: briefing + contexto
- **Saída**: `docs/constitution.md`
- **SKILL.md**: [`global/skills/constitution/SKILL.md`](../global/skills/constitution/SKILL.md)

### `specify`

Converte descrição em linguagem natural em spec estruturada (user stories,
FRs, success criteria).

- **Invocação**: "criar spec", "especificar feature", "escrever user stories"
- **Saída**: `spec.md`
- **SKILL.md**: [`global/skills/specify/SKILL.md`](../global/skills/specify/SKILL.md)

### `clarify`

Refina spec removendo ambiguidades (taxonomia de 10 tipos, máx 5 perguntas).

- **Invocação**: "clarificar spec", "remover ambiguidades", "refinar requisitos"
- **SKILL.md**: [`global/skills/clarify/SKILL.md`](../global/skills/clarify/SKILL.md)

### `plan`

Gera plano de implementação a partir da spec.

- **Saída**: `plan.md` + `research.md` + `data-model.md` + `contracts/`
- **SKILL.md**: [`global/skills/plan/SKILL.md`](../global/skills/plan/SKILL.md)

### `checklist`

Gera checklists de UX/API/Security/Performance ("unit tests for English").

- **Saída**: `checklists/{ux,api,security,performance}.md`
- **SKILL.md**: [`global/skills/checklist/SKILL.md`](../global/skills/checklist/SKILL.md)

### `create-tasks`

Quebra plano em backlog hierárquico por fases.

- **Saída**: `tasks.md`
- **Script**: `scripts/next-task-id.sh`
- **SKILL.md**: [`global/skills/create-tasks/SKILL.md`](../global/skills/create-tasks/SKILL.md)

### `analyze`

Relatório read-only de consistência cross-artifact.

- **SKILL.md**: [`global/skills/analyze/SKILL.md`](../global/skills/analyze/SKILL.md)

### `execute-task`

Executa uma task do backlog (workflow obrigatório de 9 etapas).

- **Invocação**: `/execute-task <task-id>`
- **SKILL.md**: [`global/skills/execute-task/SKILL.md`](../global/skills/execute-task/SKILL.md)

### `review-task`

Métricas de progresso do backlog (tabela + JSON via `metrics.sh`).

- **SKILL.md**: [`global/skills/review-task/SKILL.md`](../global/skills/review-task/SKILL.md)
- **Script**: `scripts/metrics.sh`

---

## Global — Complementares

### `advisor`

Conselheiro brutalmente honesto — avalia ideias, planos, decisões com
feedback direto. Ignora tarefas puramente técnicas.

- **Invocação**: "avaliar essa ideia", "o que acha dessa decisão", "feedback honesto"
- **SKILL.md**: [`global/skills/advisor/SKILL.md`](../global/skills/advisor/SKILL.md)

### `bugfix`

Protocolo stack-agnostic de 8 etapas para bugs multi-camada. Baseado em
análise de 71 bugs reais. Mapeia fluxo de dados **antes** de tocar código.

- **Invocação**: "vou consertar esse bug", "debug", "investigar falha"
- **SKILL.md**: [`global/skills/bugfix/SKILL.md`](../global/skills/bugfix/SKILL.md)

### `create-use-case`

Gera UC formal com template de 15 seções + Mermaid. ID `UC-{DOMINIO}-{NNN}`.

- **Argumento**: `--domain=<dominio>` (opcional; lê `config.json` ou infere)
- **Script**: `scripts/next-uc-id.sh`
- **SKILL.md**: [`global/skills/create-use-case/SKILL.md`](../global/skills/create-use-case/SKILL.md)

### `image-generation`

Aprimora prompts de geração de imagem com estrutura Subject-Context-Style.

- **SKILL.md**: [`global/skills/image-generation/SKILL.md`](../global/skills/image-generation/SKILL.md)

### `initialize-docs`

Cria hierarquia `docs/01-09/` com scaffold idempotente.

- **Flags**: `--dry-run`, `--force`, `--no-move`, `--dir=<path>`
- **Script**: `scripts/scaffold.sh`
- **SKILL.md**: [`global/skills/initialize-docs/SKILL.md`](../global/skills/initialize-docs/SKILL.md)

### `apply-insights`

Aplica playbook empírico (`usage-insights.md`) ao `CLAUDE.md`/hooks do projeto.

- **SKILL.md**: [`global/skills/apply-insights/SKILL.md`](../global/skills/apply-insights/SKILL.md)

### `owasp-security`

Cobertura OWASP Top 10:2025 + ASVS 5.0 + AI Agent Security 2026 (570 linhas).

- **SKILL.md**: [`global/skills/owasp-security/SKILL.md`](../global/skills/owasp-security/SKILL.md)

### `validate-documentation`

Valida docs individuais contra padrões estruturais.

- **SKILL.md**: [`global/skills/validate-documentation/SKILL.md`](../global/skills/validate-documentation/SKILL.md)

### `validate-docs-rendered`

Verifica que Markdown renderiza corretamente (Mermaid parseável, links sem
404, YAML frontmatter válido, tabelas bem-formadas).

- **Script**: `scripts/validate.sh`
- **SKILL.md**: [`global/skills/validate-docs-rendered/SKILL.md`](../global/skills/validate-docs-rendered/SKILL.md)

---

## Global — Credenciais

### `cred-store`

Resolução de credenciais via cascata env → 1Password → Keychain → arquivo.
Leitura apenas.

- **Invocação**: "resolver credencial", "ler token", "carregar secret"
- **Argumentos**: `<credential-key> [--format=raw|env|json] [--with-metadata]`
- **Scripts**: `init-store.sh`, `resolve.sh`, `list.sh`
- **Guia completo**: [credentials.md](./guides/credentials/README.md)
- **SKILL.md**: [`global/skills/cred-store/SKILL.md`](../global/skills/cred-store/SKILL.md)

### `cred-store-setup`

Registro interativo de credenciais (wrapper sobre armazenamento em
op/keychain/file).

- **Invocação**: "registrar credencial", "setup token", "adicionar api key"
- **Argumentos**: `[<key>] [--source=op|keychain|file] [--validate-cmd=<cmd>]`
- **SKILL.md**: [`global/skills/cred-store-setup/SKILL.md`](../global/skills/cred-store-setup/SKILL.md)

---

## Global — Release & Git Methodology

### `git-methodology/` (hub documental)

Não é skill invocável. Hub com README + 4 references:

- `conventional-commits.md`
- `keep-a-changelog.md`
- `semver.md`
- `commit-body-quality.md`

**Path**: [`global/skills/git-methodology/`](../global/skills/git-methodology/)

### `release-please-setup`

Configura release automatizado via release-please (Google) em projeto
Node.js no GitHub.

- **Invocação**: "setup release-please", "automação de release"
- **Templates**: `release-please-config.json`, `.release-please-manifest.json`, `release-please.yml`
- **Guia**: [releases.md](./guides/releases/release-please.md)
- **SKILL.md**: [`global/skills/release-please-setup/SKILL.md`](../global/skills/release-please-setup/SKILL.md)

### `release-manual-setup`

Script caseiro `scripts/release.mjs` + test/release.test.mjs. Zero deps.
Padrão clw-auth.

- **Invocação**: "release manual", "script release", "release caseiro"
- **Templates**: `release.mjs` (310 linhas), `release.test.mjs` (155 linhas)
- **Guia**: [releases.md](./guides/releases/release-manual.md)
- **SKILL.md**: [`global/skills/release-manual-setup/SKILL.md`](../global/skills/release-manual-setup/SKILL.md)

### `changelog-write-entry`

Escreve entrada manual no CHANGELOG.md (Keep a Changelog 1.1.0). Avisa se
detectar automação.

- **Invocação**: "adicionar entrada changelog", "escrever changelog"
- **Argumentos**: `[<version>] [--unreleased] [--type=added|fixed|changed|...]`
- **SKILL.md**: [`global/skills/changelog-write-entry/SKILL.md`](../global/skills/changelog-write-entry/SKILL.md)

### `git-hooks-install`

Instala hooks `.githooks/commit-msg` + `.githooks/pre-commit` + postinstall.

- **Invocação**: "instalar git hooks", "setup commit-msg", "enforce en-us commits"
- **Argumentos**: `[--commit-msg-lang=en|pt] [--identity=<name>:<email>]`
- **Templates**: `commit-msg`, `pre-commit`, `install-hooks.sh`
- **SKILL.md**: [`global/skills/git-hooks-install/SKILL.md`](../global/skills/git-hooks-install/SKILL.md)

### `release-quality-gate`

Validador read-only com 10 checks pré-release.

- **Invocação**: "validar prontidão de release", "release quality check"
- **Argumentos**: `[--target-version=<v>] [--strict] [--skip-tests] [--skip-lint]`
- **Exit codes**: 0/1/2
- **SKILL.md**: [`global/skills/release-quality-gate/SKILL.md`](../global/skills/release-quality-gate/SKILL.md)

---

## Language-related — Go

8 skills idiomáticas para Go + 4 hooks de validação automática.

### Hooks

| Hook | Momento | Valida |
|------|---------|--------|
| `check-route-order.sh` | PreToolCall Write em `*_handler.go` | Ordem de rotas em Fiber (evita trie conflicts) |
| `check-schema-prefix.sh` | PreToolCall Write em repos SQL | SQL sem prefixo de schema |
| `go-build-gate.sh` | PostToolCall Write | `go build ./...` no serviço afetado |
| `check-uncommitted.sh` | Stop | Lembra de commitar staged changes |

**Path**: [`language-related/go/hooks/`](../language-related/go/hooks/)

### Skills

| Skill | Propósito |
|-------|-----------|
| `commit` | Commits Go seguindo convenções do toolkit (submodules, detecta .env, kebab-scope) |
| `create-report` | Gera relatório técnico de feature/bug/investigação |
| `go-add-entity` | Scaffold entidade Go com repository + service + handler |
| `go-add-migration` | Migration SQL sequencial com safety check |
| `go-add-test` | Testes Go idiomáticos (table-driven, subtests) |
| `go-add-consumer` | Consumer de fila (RabbitMQ, Kafka, CF Queue) |
| `go-review-pr` | Quality gate: lint + typecheck + tests + architecture |
| `go-review-service` | Review estrutural de serviço Go |

**Path**: [`language-related/go/skills/`](../language-related/go/skills/)

---

## Language-related — .NET

8 skills para .NET 10 (C#) com arquitetura hexagonal + CQRS.

| Skill | Propósito |
|-------|-----------|
| `dotnet-create-entity` | Entidade com EF Core + FluentValidation + Mapster |
| `dotnet-create-feature` | Feature CQRS completa (command + handler + validator + test) |
| `dotnet-create-project` | Solução .NET com estrutura hexagonal |
| `dotnet-create-test` | Testes xUnit + NSubstitute + FluentAssertions |
| `dotnet-hexagonal-architecture` | Review de aderência a hexagonal |
| `dotnet-infrastructure` | Setup de PostgreSQL + RabbitMQ + gRPC + ETCD |
| `dotnet-review-code` | Quality gate estilo .NET |
| `dotnet-testing` | Padrões de teste, fixtures, mocks |

**Path**: [`language-related/dotnet/skills/`](../language-related/dotnet/skills/)

---

## Platform-related — Cloudflare Shared

Fundação para skills CF. Wrapper REST + credentials + version check.

### Hook

| Hook | Momento | Valida |
|------|---------|--------|
| `check-wrangler-version.sh` | PreToolCall Bash contendo `wrangler` | Versão local vs latest npm (avisa, não bloqueia) |

**Path**: [`platform-related/cloudflare-shared/hooks/`](../platform-related/cloudflare-shared/hooks/)

### Skills

### `cf-api-call`

Wrapper REST workhorse para Cloudflare API.

- **Invocação**: "chamar API Cloudflare", "cf api", "endpoint cloudflare que não tem em wrangler"
- **Argumentos**: `<METHOD> <PATH> [--account=<nick>] [--zone=<id>] [--data='...'] [--format=json|raw|pretty] [--retry=<n>] [--dry-run]`
- **Script**: `scripts/call.sh` (301 linhas)
- **Guia**: [cloudflare.md](./guides/cloudflare/api-cookbook.md)
- **SKILL.md**: [`platform-related/cloudflare-shared/skills/cf-api-call/SKILL.md`](../platform-related/cloudflare-shared/skills/cf-api-call/SKILL.md)

### `cf-credentials-setup`

Onboarding interativo de API token CF. Wrapper pré-configurado sobre
`cred-store-setup`.

- **Invocação**: "configurar credenciais cloudflare", "setup cf account"
- **Argumentos**: `[<nickname>] [--source=op|keychain|file]`
- **Valida**: via `GET /user/tokens/verify` antes de gravar
- **SKILL.md**: [`platform-related/cloudflare-shared/skills/cf-credentials-setup/SKILL.md`](../platform-related/cloudflare-shared/skills/cf-credentials-setup/SKILL.md)

### `cf-wrangler-update`

Upgrade explícito do Wrangler no PM detectado (bun/pnpm/yarn/npm).

- **Invocação**: "atualizar wrangler", "bump wrangler"
- **Argumentos**: `[--global] [--check-only] [--target-version=<v>] [--no-confirm]`
- **SKILL.md**: [`platform-related/cloudflare-shared/skills/cf-wrangler-update/SKILL.md`](../platform-related/cloudflare-shared/skills/cf-wrangler-update/SKILL.md)

### References (3)

- `api-vs-wrangler.md` — tabela de cobertura por domínio
- `api-endpoint-catalog.md` — endpoints curados (~ 340 linhas)
- `credential-storage.md` — convenções CF-específicas

**Path**: [`platform-related/cloudflare-shared/references/`](../platform-related/cloudflare-shared/references/)

---

## Language-related — typescript

13 skills + 10 hooks + settings.json para Cloudflare Workers + Hono +
Drizzle + Zod + Vitest + TS strict. Stack observada em projetos de
referência (unity-dash, inde-intelligence, split-ai).

**README**: [`language-related/typescript/README.md`](../language-related/typescript/README.md)

| Skill | Trigger | Descrição |
|-------|---------|-----------|
| **ts-add-component** | "add component", "novo componente" | React + shadcn/ui + Tailwind + design tokens |
| **ts-add-domain** | "add domain", "criar bounded context" | Scaffold DDD (controller/service/repo/mapper) |
| **ts-add-migration** | "add migration", "drizzle migration" | Drizzle migration D1/Postgres idempotente |
| **ts-add-queue-consumer** | "add queue", "queue consumer" | CF Queue + retry + DLQ + idempotency |
| **ts-add-route** | "add route", "novo endpoint" | Hono + zValidator + service delegation |
| **ts-add-test** | "add test", "vitest test" | Vitest AAA + mocks de bindings CF |
| **ts-add-webhook** | "add webhook", "webhook handler" | HMAC SHA256 + idempotency + replay protection |
| **ts-commit** | "commit", "atomic commit" | Conventional commits PT-BR atômicos |
| **ts-deploy-check** | "deploy check", "pre-deploy" | Validação bindings/secrets/migrations pré-deploy |
| **ts-refactor-budget** | "refactor budget", "file too big" | Enforcement file (250) + function (50) size budget |
| **ts-review-pr** | "review pr", "code review" | Checklist Workers (CPU, security, types) |
| **ts-review-security** | "security review", "audit security" | PII/SQLi/XSS/JWT/CORS/rate-limit audit |
| **ts-upgrade-zod-schema** | "upgrade zod", "zod v4" | Migração Zod v3 → v4 |

### Hooks (10)

| Hook | Disparo | Validação |
|------|---------|-----------|
| **ts-typecheck-gate.sh** | PostToolCall Write\|Edit | `tsc --noEmit` |
| **ts-eslint-gate.sh** | PostToolCall | ESLint com auto-detect PM |
| **check-date-toisostring.sh** | PostToolCall | Bloqueia `Date.toISOString` sem timezone |
| **check-uuid-v4.sh** | PostToolCall | Sugere ULID/CUID2 onde aplicável |
| **check-soft-delete.sh** | PostToolCall | Bloqueia hard delete em entidades com `deletedAt` |
| **check-sql-in-routes.sh** | PostToolCall | SQL fora de routes (repository pattern) |
| **check-pii-in-logs.sh** | PostToolCall | Bloqueia PII em logs |
| **check-file-budget.sh** | PostToolCall | Warning > 250, block > 400 linhas |
| **check-wrangler-deploy.sh** | PreToolCall Bash | Bloqueia `wrangler deploy` em main |
| **check-commit-to-main.sh** | PreToolCall Bash | Força feature branches |

---

## Language-related — python

8 skills + 2 hooks + settings.json para FastAPI + Pydantic v2 + structlog +
ruff + pytest + uv + mypy strict.

**README**: [`language-related/python/README.md`](../language-related/python/README.md)

| Skill | Trigger | Descrição |
|-------|---------|-----------|
| **py-add-fastapi-route** | "add route", "fastapi route" | FastAPI + Pydantic + Depends + response_model |
| **py-add-pydantic-model** | "add model", "pydantic model" | Pydantic v2 + ConfigDict + field_validator |
| **py-add-structlog** | "add logging", "structlog setup" | Structured JSON + contextvars + middleware |
| **py-add-test** | "add test", "pytest test" | pytest async + httpx AsyncClient + fixtures |
| **py-commit** | "commit" | Conventional commits PT-BR atômicos |
| **py-review-pr** | "review pr" | Checklist mypy strict + ruff + coverage |
| **py-setup-project** | "setup project", "init python" | Bootstrap moderno (uv + ruff + mypy) |
| **py-upgrade-pkg-manager** | "migrate to uv" | Migração pip/poetry → uv |

### Hooks (2)

| Hook | Disparo | Validação |
|------|---------|-----------|
| **py-typecheck-gate.sh** | PostToolCall Write\|Edit | `uv run mypy <file>` |
| **py-lint-gate.sh** | PostToolCall | `uv run ruff check <file>` |

---

## Platform-related — cloudflare-workers

9 skills focadas em platform layer (wrangler.toml, bindings, CPU/duration
limits, observability). Diferente de `language-related/typescript/` (que
cobre código). Depende de `cloudflare-shared/` (cf-api-call, credentials).

**README**: [`platform-related/cloudflare-workers/README.md`](../platform-related/cloudflare-workers/README.md)

| Skill | Trigger | Descrição |
|-------|---------|-----------|
| **cf-workers-add-route** | "add cloudflare route" | Route ou custom_domain (DNS + zone) |
| **cf-workers-add-binding** | "add binding", "bind d1" | Binding genérico (D1/KV/R2/Queue/DO/AI/Vectorize) |
| **cf-workers-create-d1** | "create d1", "init d1" | D1 database + binding + initial migration |
| **cf-workers-create-kv-namespace** | "create kv" | KV namespace + dev local |
| **cf-workers-create-r2-bucket** | "create r2" | R2 bucket + CORS |
| **cf-workers-add-migration** | "add d1 migration" | D1 migration via wrangler migrations |
| **cf-workers-add-queue-consumer** | "add queue consumer" | Queue consumer + retry + DLQ |
| **cf-workers-add-webhook** | "add cf webhook" | Webhook HMAC + idempotency D1/KV |
| **cf-workers-deploy-check** | "cf deploy check" | Validação pré-deploy (bindings, secrets) |

---

## Platform-related — cloudflare-dns

7 skills para Cloudflare DNS via API v4 + wrangler. CRUD records
(A/AAAA/CNAME/MX/TXT/SRV/CAA), bulk operations, audit, migration zone.

Auth: Bearer token com scope `Zone:DNS:Edit`. Rate limit: 1200 req/5min.

**README**: [`platform-related/cloudflare-dns/README.md`](../platform-related/cloudflare-dns/README.md)

| Skill | Trigger | Descrição |
|-------|---------|-----------|
| **dns-list-records** | "list dns" | Lista paginada com filtros |
| **dns-add-record** | "add dns", "add a record" | Cria record único (todos tipos) |
| **dns-update-record** | "update dns" | PATCH parcial / PUT total |
| **dns-delete-record** | "delete dns" | Remove com confirmação + audit log |
| **dns-bulk-import** | "bulk import dns", "import zone file" | CSV ou BIND zone file (rate-limited) |
| **dns-audit** | "audit dns" | SPF/DKIM/DMARC/CAA/DNSSEC review |
| **dns-migrate-zone** | "migrate zone" | Migração entre Cloudflare accounts |

---

## Platform-related — neon

7 skills para Neon Postgres serverless (branching Git-like, scale-to-zero).
Conceitos: project, branch (CoW), endpoint, pooler.

CLI: `neonctl`. API: `console.neon.tech/api/v2`. Auth: `NEON_API_KEY` (rotate 90d).

**README**: [`platform-related/neon/README.md`](../platform-related/neon/README.md)

| Skill | Trigger | Descrição |
|-------|---------|-----------|
| **neon-credentials-setup** | "setup neon" | NEON_API_KEY + connection strings |
| **neon-create-project** | "create neon project" | Bootstrap project (region, pg_version) |
| **neon-create-branch** | "create neon branch" | Branch CoW para dev/test |
| **neon-merge-branch** | "merge neon branch" | Schema diff + apply via migrations |
| **neon-list-connections** | "neon connections" | pg_stat_activity + cancel/terminate |
| **neon-configure-pooler** | "neon pooler" | pgbouncer transaction mode (serverless) |
| **neon-anonymize-branch** | "anonymize branch" | PII redaction safe staging |

---

## Data-related — postgres

10 skills focadas em PostgreSQL 15+ (agnóstico de framework). Schema,
queries, performance, JSONB, FTS, locking, partitioning.

**README**: [`data-related/postgres/README.md`](../data-related/postgres/README.md)

| Skill | Trigger | Descrição |
|-------|---------|-----------|
| **pg-schema-design** | "design schema postgres" | 3NF + naming + types + audit cols |
| **pg-add-migration** | "add postgres migration" | SQL idempotente up/down + lock_timeout |
| **pg-query-optimize** | "optimize query postgres" | EXPLAIN ANALYZE + indexes + rewrite |
| **pg-indexing** | "add index postgres" | B-tree/GIN/GiST/BRIN/Hash + partial + covering |
| **pg-jsonb-patterns** | "jsonb postgres" | Operadores + GIN index + jsonb_path_query |
| **pg-fts-setup** | "fts postgres", "tsvector" | tsvector + GENERATED + GIN + bm25 |
| **pg-locking** | "postgres locking", "deadlock" | Lock types + advisory + SKIP LOCKED |
| **pg-partitioning** | "partition postgres" | RANGE/LIST/HASH + pg_partman + pruning |
| **pg-audit-query** | "audit postgres", "history table" | Trigger + history JSONB + role tracking |
| **pg-review-schema** | "review schema postgres" | Smell detection + checklist + priority |

---

## Data-related — d1

6 skills para Cloudflare D1 (SQLite distribuído globalmente). Limites: 10GB/db,
1000ms CPU/query, 50MB/blob. Sem extensões (apenas SQLite stdlib).

**README**: [`data-related/d1/README.md`](../data-related/d1/README.md)

| Skill | Trigger | Descrição |
|-------|---------|-----------|
| **d1-schema-design** | "d1 schema design" | STRICT tables + INTEGER PK + CHECK + GENERATED |
| **d1-query-batch** | "d1 batch", "batch query d1" | `db.batch()` para reduzir round-trips |
| **d1-fts5-setup** | "d1 fts", "fts5 cloudflare" | FTS5 virtual table + bm25 + highlight |
| **d1-prepared-stmts** | "d1 prepare", "sql injection d1" | `prepare().bind()` obrigatório (anti-SQLi) |
| **d1-analytics-queries** | "d1 analytics", "window function d1" | CTE + window functions + JSON1 + cache KV |
| **d1-migration-strategy** | "d1 migration strategy" | Aditivo + backfill + zero-downtime + multi-region |

---

## Data-related — elasticsearch

7 skills para Elasticsearch 8.x. Mapping, query DSL, aggregations, bulk,
reindex zero-downtime, version migration, logging com ILM/data streams.

Auth: API key (basic auth deprecated). Conceitos: index, mapping, document,
query DSL, aggs, alias, ILM.

**README**: [`data-related/elasticsearch/README.md`](../data-related/elasticsearch/README.md)

| Skill | Trigger | Descrição |
|-------|---------|-----------|
| **es-mapping-design** | "es mapping" | text/keyword + multi-fields + analyzers |
| **es-query-build** | "es query", "query dsl es" | bool query (must/should/filter/must_not) |
| **es-aggregations** | "es aggregation" | terms + date_histogram + metrics + pipeline |
| **es-bulk-index** | "es bulk", "bulk index es" | NDJSON + retry per-item + throttle |
| **es-reindex-zero-downtime** | "es reindex", "alias swap es" | Reindex + alias swap atomic |
| **es-version-migrate** | "es upgrade" | 7→8/8→9 + rolling upgrade + breaking changes |
| **es-logging-pattern** | "es logs", "ilm pattern" | Data stream + ILM + ECS schema + ingest pipeline |

---

## Como contribuir com skills novas

Ver [contributing.md](./contributing.md) para workflow completo.

Resumo:

1. Escolher categoria via [architecture.md](./architecture.md#decisão-onde-adicionar-nova-skill)
2. Criar shape padrão (`SKILL.md` + subpastas)
3. Frontmatter YAML como trigger-condition (não resumo)
4. Seção Gotchas obrigatória
5. Scripts POSIX com header de documentação
6. Validar (`sh -n`, shellcheck)
7. Atualizar este catálogo + README da categoria
8. Commits atômicos com body rico
9. PR com descrição completa

## Busca rápida

Precisa de skill para...

| Tarefa | Skill |
|--------|-------|
| Começar feature nova (pipeline SDD) | `briefing` → `specify` → `plan` |
| Arrumar bug multi-camada | `bugfix` |
| Escrever UC formal | `create-use-case` |
| Validar commits antes de release | `release-quality-gate` |
| Configurar release automatizado | `release-please-setup` |
| Configurar release manual | `release-manual-setup` |
| Instalar hooks git | `git-hooks-install` |
| Registrar token CF | `cf-credentials-setup` |
| Chamar API CF qualquer | `cf-api-call` |
| Atualizar Wrangler | `cf-wrangler-update` |
| Registrar credencial genérica | `cred-store-setup` |
| Adicionar entrada CHANGELOG | `changelog-write-entry` |
| Review de segurança | `owasp-security` |
| Aplicar playbook do autor no projeto | `apply-insights` |
| Avaliar decisão brutalmente | `advisor` |
| Scaffold docs/01-09 | `initialize-docs` |
| Validar docs renderizam | `validate-docs-rendered` |

## Ver também

- [architecture.md](./architecture.md) — filosofia + princípio de partição
- [getting-started.md](./getting-started.md) — quickstart
- [contributing.md](./contributing.md) — como adicionar skill nova
- [glossary.md](./glossary.md) — vocabulário do projeto
