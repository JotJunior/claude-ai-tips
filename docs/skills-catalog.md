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
| [TypeScript](#language-related--typescript-scaffold) | — | scaffold |
| [Python](#language-related--python-scaffold) | — | scaffold |
| [Categorias futuras](#categorias-futuras-sem-scaffold-ainda) | — | TBD |

**Total ativo**: 46 skills + 5 hooks + hubs de documentação.

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

## Categorias com scaffold (sem skills concretas ainda)

As categorias abaixo possuem README com escopo e princípios definidos,
mas ainda não têm skills implementadas. Skills serão adicionadas
conforme demanda real dos projetos — evitando vaporware.

### Language-related — typescript (scaffold)

Pasta `language-related/typescript/` com README definindo escopo
(Cloudflare Workers + Hono + Zod + Drizzle + TS strict, observado em
projetos de referência como unity-dash, inde-intelligence, split-ai).
Sem skills implementadas.

**README**: [`language-related/typescript/README.md`](../language-related/typescript/README.md)

### Language-related — python (scaffold)

Pasta `language-related/python/` com README definindo escopo (PEP 8/484,
ruff, black, mypy, pytest, pyproject.toml moderno). Sem skills implementadas.

**README**: [`language-related/python/README.md`](../language-related/python/README.md)

## Categorias futuras (sem scaffold ainda)

As categorias abaixo são candidatas para iteração futura. **Sem pasta
criada e sem skills planejadas em concreto** — o escopo será definido
quando houver demanda real.

- `platform-related/cloudflare-workers/` — Workers + ops D1/KV/R2/Queues
  (consumirá `cloudflare-shared/`)
- `platform-related/cloudflare-dns/` — DNS via API REST da Cloudflare
- `platform-related/neon/` — provisionamento Neon Postgres serverless
- `data-related/postgres/` — consumo Postgres (incluindo variants Neon,
  Supabase, RDS)
- `data-related/d1/` — consumo D1 (SQLite edge)
- `data-related/elasticsearch/` — consumo ES 8.x/9.x

> **Nota anti-vaporware**: este toolkit deliberadamente evita listar
> skills futuras com nomes específicos antes de implementá-las. Quando
> uma skill for criada, ela aparece aqui no catálogo principal — não na
> seção "futuras".

Para propor uma skill nova, veja [contributing.md](./contributing.md).

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
