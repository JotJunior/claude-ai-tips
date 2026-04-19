# Documentação do claude-ai-tips

Bem-vindo à documentação completa do `claude-ai-tips` — toolkit de skills,
hooks e convenções para Claude Code.

## Por onde começar

| Você é... | Comece por |
|-----------|------------|
| **Primeira vez aqui** | [getting-started.md](./getting-started.md) — 5 min do zero ao primeiro uso |
| **Quer entender a filosofia** | [architecture.md](./architecture.md) — 3 categorias, princípio de partição, anatomia de skill |
| **Procurando skill específica** | [skills-catalog.md](./skills-catalog.md) — catálogo completo com triggers |
| **Vai contribuir** | [contributing.md](./contributing.md) — convenções, shape, commits |
| **Nunca viu o termo antes** | [glossary.md](./glossary.md) — vocabulário do projeto |

## Guias por tópico

| Guia | O que cobre |
|------|-------------|
| [guides/credentials.md](./guides/credentials.md) | `cred-store` e `cred-store-setup` — cascata env/op/keychain/file, cookbook |
| [guides/cloudflare.md](./guides/cloudflare.md) | `cloudflare-shared/` — setup de token, API REST via `cf-api-call`, Wrangler updates |
| [guides/releases.md](./guides/releases.md) | `git-methodology/` — release-please vs manual, changelog, hooks, quality gate |

## Exemplos end-to-end

Cenários completos passo-a-passo com código copy-paste:

| Exemplo | Cenário |
|---------|---------|
| [examples/new-project-bootstrap.md](./examples/new-project-bootstrap.md) | Projeto novo do zero — git init → primeira release v0.1.0 |
| [examples/cloudflare-dns-setup.md](./examples/cloudflare-dns-setup.md) | Registrar conta CF → criar zona → popular DNS via API |
| [examples/release-flow.md](./examples/release-flow.md) | Release flow completo via release-please e via script manual |

## Referência de skills

Cada skill tem `SKILL.md` próprio com frontmatter, gotchas e scripts. A documentação em
`docs/` é **complementar** — para uso prático; os `SKILL.md` são a fonte canônica
consumida pelo Claude Code na invocação.

### Skills globais (agnósticas)

```
global/skills/
├── cred-store/                  # Resolução de credenciais via cascata
├── cred-store-setup/            # Registro interativo
├── git-methodology/             # Hub (não-invocável)
├── release-please-setup/        # Automação release via release-please
├── release-manual-setup/        # Script caseiro estilo clw-auth
├── changelog-write-entry/       # CHANGELOG manual Keep a Changelog
├── git-hooks-install/           # commit-msg + pre-commit
└── release-quality-gate/        # Validador read-only pre-release
```

Skills existentes do pipeline SDD (`briefing`, `constitution`, `specify`, `clarify`,
`plan`, `checklist`, `create-tasks`, `analyze`, `execute-task`, `review-task`) e
complementares (`advisor`, `bugfix`, `create-use-case`, `image-generation`,
`initialize-docs`, `owasp-security`, `apply-insights`, `validate-documentation`,
`validate-docs-rendered`) permanecem em `global/skills/` — ver [skills-catalog.md](./skills-catalog.md).

### Skills por categoria

```
language-related/go/             # 8 skills + 4 hooks
language-related/dotnet/         # 8 skills
platform-related/cloudflare-shared/   # 3 skills + 1 hook + 3 references
data-related/                    # scaffold (sem skills ainda)
```

Futuras fases adicionarão `typescript/`, `python/`, `cloudflare-workers/`,
`cloudflare-dns/`, `neon/`, `postgres/`, `d1/`, `elasticsearch/`.

## Princípio de partição em 3 categorias

| Namespace | Pergunta que responde |
|-----------|-----------------------|
| `language-related/` | Como o código é escrito em X? |
| `platform-related/` | Como o recurso é provisionado/operado? |
| `data-related/` | Como meu código consome o serviço? |

Exemplo: `wrangler d1 create` → `platform-related/cloudflare-workers/`.
Query SQL otimizada D1 → `data-related/d1/`. Mesmo serviço, facetas separadas.

Mais em [architecture.md](./architecture.md).

## Convenções-chave

- **Skills como trigger-condition, não resumo** — `description:` no frontmatter diz
  "Use quando X ou Y. NÃO use quando Z" (não "Skill que faz X")
- **Seção Gotchas obrigatória** em toda SKILL.md — catálogo de armadilhas
- **Scripts POSIX** para operações determinísticas (evita alucinação, economiza tokens)
- **`config.json` por skill** para parametrização sem forkar
- **Conventional Commits** em EN-US para commits; docs/guides em PT-BR

## Versionamento

Projeto segue [Semantic Versioning 2.0.0](https://semver.org/spec/v2.0.0.html). Mudanças
documentadas em [CHANGELOG.md](../CHANGELOG.md).

Histórico recente:

- **2.3.0** (planejada) — documentação completa em `docs/`
- **2.2.0** (planejada) — `git-methodology/` + 5 skills de release
- **2.1.0** (planejada) — taxonomia 3 categorias + `cred-store` + `cloudflare-shared/`
- **2.0.0** — rename `insights` → `apply-insights` (breaking)
- **1.1.0** — refatoração em 5 fases (descriptions trigger-condition, skills-como-pasta,
  scripts, composição explícita, validate-docs-rendered)
- **1.0.0** — publicação inicial

## Licença

[MIT](../LICENSE) — copie, adapte, use em qualquer projeto.

## Ver também

- [README.md raiz](../README.md) — overview curto para descoberta no GitHub
- [CHANGELOG.md](../CHANGELOG.md) — histórico de mudanças
- [global/insights/usage-insights.md](../global/insights/usage-insights.md) — playbook
  empírico (134 sessões analisadas)
