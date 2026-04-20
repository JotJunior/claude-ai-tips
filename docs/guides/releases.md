# Guia: Releases e Metodologia Git

Guia prático do namespace `git-methodology/` — escolha entre padrões de
release, configuração de hooks, geração de CHANGELOG, gates de qualidade.

## Visão geral

O toolkit suporta **dois padrões** de release, ambos observados em projetos
de referência do autor:

| Padrão | Projeto de referência | Skill de setup |
|--------|-----------------------|----------------|
| **release-please** (automatizado) | [md2pdf](https://github.com/4i3n6/md2pdf) | `release-please-setup` |
| **Script caseiro** (manual) | [clw-auth](https://github.com/4i3n6/clw-auth) | `release-manual-setup` |

Skills complementares agnósticas ao padrão:

- `changelog-write-entry` — entrada manual no CHANGELOG (com aviso se automação detectada)
- `git-hooks-install` — commit-msg + pre-commit customizados
- `release-quality-gate` — 10 checks read-only antes de release

## Quando usar qual padrão

### Escolha release-please se:

- Projeto hospedado no **GitHub** com Actions ativo
- **Team ≥ 2 pessoas** com PR workflow obrigatório
- **Monorepo** com pacotes versionados independentemente
- Aceita dependência de vendor (GitHub Actions + release-please)
- Quer links automáticos no CHANGELOG (compare URLs, commit URLs)
- Quer **zero trabalho manual** por release

### Escolha release-manual se:

- Projeto **solo** ou time pequeno
- Sem CI ou com CI mínimo
- Quer **controle fino** do formato do CHANGELOG e das regras
- **Pre-1.0** em iteração rápida
- Evitar vendor lock (Node.js built-in apenas)
- Release **local** via comando CLI

### Matriz rápida

| Aspecto | release-please | release-manual |
|---------|----------------|----------------|
| Automação | 100% (CI-driven) | parcial (dev invoca) |
| Dependência externa | GitHub Actions | Node.js built-in |
| Changelog | auto + links GitHub | auto local |
| Body quality gate | adicionar via `release-quality-gate` | embutido |
| Monorepo | suportado | adaptar manualmente |
| 0.x handling | minor normal | minor ou "major-as-minor" |
| Overhead inicial | baixo (copy templates) | médio (adaptar script) |
| Custo por release | 0 (auto PR) | comando manual |

### Dúvida? Comece com `release-manual`

É mais simples, sem dependências, e você entende cada peça. Migrar para
release-please depois é trivial (adicionar 3 arquivos, desligar script).

## Padrão A: release-please

### Pré-requisitos

- Projeto no GitHub (public ou private)
- `package.json` com `.version` válido
- Commits seguindo Conventional Commits (instale `git-hooks-install` antes)
- Branch default `main` (adaptável para `master`)
- Permissão para criar workflow em `.github/workflows/`

### Setup

No Claude Code:

```
configurar release-please nesse projeto
```

A skill `release-please-setup` guia:

1. Nome do pacote (default: `.name` do package.json)
2. Monorepo? (sim/não)
3. Extra-files (HTML, JSON i18n, constants.ts)
4. Auto-merge do PR? (recomendado)
5. Branch default

Arquivos criados:

```
projeto/
├── release-please-config.json          # Config principal
├── .release-please-manifest.json       # Estado de versão
└── .github/workflows/release-please.yml  # Workflow CI
```

### `release-please-config.json`

Template do toolkit ([`release-please-setup/templates/release-please-config.json`](../../global/skills/release-please-setup/templates/release-please-config.json)):

```json
{
  "$schema": "https://raw.githubusercontent.com/googleapis/release-please/main/schemas/config.json",
  "packages": {
    ".": {
      "release-type": "node",
      "changelog-sections": [
        { "type": "feat",     "section": "### Added" },
        { "type": "fix",      "section": "### Fixed" },
        { "type": "perf",     "section": "### Performance" },
        { "type": "refactor", "section": "### Changed" },
        { "type": "test",     "section": "### Tests" },
        { "type": "docs",     "section": "### Documentation" },
        { "type": "style",    "section": "### Style" },
        { "type": "build",    "section": "### Build",  "hidden": true },
        { "type": "ci",       "section": "### CI",     "hidden": true },
        { "type": "chore",    "section": "### Chore",  "hidden": true }
      ],
      "extra-files": []
    }
  }
}
```

Customize `release-type` para projeto não-Node:

| Linguagem | release-type |
|-----------|--------------|
| Node.js | `node` |
| Python | `python` |
| Rust | `rust` |
| Go | `go` |
| PHP | `php` |
| Ruby | `ruby` |

### Extra-files

Se a versão aparece em arquivos além de `package.json`, declare:

```json
"extra-files": [
  { "type": "generic", "path": "index.html" },
  { "type": "generic", "path": "src/i18n/en.ts" },
  { "type": "json",    "path": "manual/content.json", "jsonpath": "$.version" }
]
```

Para arquivos HTML/TS, adicionar marker no local da versão:

```html
<meta name="version" content="1.2.3"><!-- x-release-please-version -->
```

### Workflow

Template ([`release-please.yml`](../../global/skills/release-please-setup/templates/release-please.yml)):

```yaml
name: Release Please

on:
  push:
    branches: [main]

permissions:
  contents: write
  pull-requests: write

jobs:
  release-please:
    runs-on: ubuntu-latest
    steps:
      - uses: googleapis/release-please-action@v4
        with:
          token: ${{ secrets.GITHUB_TOKEN }}
          config-file: release-please-config.json
          manifest-file: .release-please-manifest.json

  auto-merge:
    needs: release-please
    runs-on: ubuntu-latest
    if: ${{ always() }}
    steps:
      - run: |
          PR=$(gh pr list --label "autorelease: pending" --state open \
            --json number --jq '.[0].number // empty')
          [ -n "$PR" ] && gh pr merge "$PR" --merge --auto
        env:
          GITHUB_TOKEN: ${{ secrets.GITHUB_TOKEN }}
```

Auto-merge precisa:

- Settings → General → Pull Requests → **Allow auto-merge** habilitado
- Branch protection compatível com `GITHUB_TOKEN` (senão, usar PAT ou App)

### Ciclo de release

```
1. Desenvolvedor commita: "feat(auth): add OAuth PKCE flow"
2. Push para main
3. Workflow release-please roda
4. Detecta commits feat/fix → calcula bump (minor)
5. Cria/atualiza PR: "chore(main): release 1.2.0"
   - Atualiza package.json
   - Atualiza CHANGELOG.md (seção [1.2.0] com itens)
   - Atualiza extra-files
6. (Auto-merge OU mantenedor mergeia)
7. Merge dispara criação de tag v1.2.0 + GitHub Release
```

### Saída do CHANGELOG

```markdown
## [1.2.0](https://github.com/owner/repo/compare/v1.1.0...v1.2.0) (2026-04-19)

### Added

* **auth:** add OAuth PKCE flow ([abc1234](https://github.com/owner/repo/commit/abc1234))

### Fixed

* **parser:** handle null token gracefully ([def5678](https://github.com/owner/repo/commit/def5678))
```

Cada entry tem link pro commit; cada versão tem link pro diff.

## Padrão B: release-manual (script caseiro)

### Pré-requisitos

- `package.json` com `.version` válido (inicie com `0.1.0` se novo)
- Commits Conventional (use `git-hooks-install`)
- `CHANGELOG.md` existente ou será criado
- Opcional: suite de testes (`npm test`)

### Setup

```
configure release manual nesse projeto
```

A skill `release-manual-setup` cria:

```
projeto/
├── scripts/release.mjs         # Script principal
├── test/release.test.mjs       # Test suite (node:test)
├── CHANGELOG.md                # Se não existir
└── package.json                # Adicionado "release": "node scripts/release.mjs"
```

### Uso

Release detectando bump automaticamente:

```bash
npm run release
```

Dry-run (sem escrever, sem tag):

```bash
DRY_RUN=1 npm run release
```

Forçar bump específico:

```bash
BUMP=major npm run release     # major
BUMP=minor npm run release     # minor
BUMP=patch npm run release     # patch
```

Pular tests (não recomendado):

```bash
NO_TESTS=1 npm run release
```

### Fluxo executado pelo script

```
1. Verifica working tree limpa (git status --porcelain vazio)
2. Lê commits desde última tag (git log --no-merges)
3. Parseia cada commit (regex Conventional)
4. Quality gate:
   - Commits feat/fix/breaking precisam body ≥ 20 chars
   - Falhas abortam com lista + comandos de fix
5. Roda tests (npm test) se RUN_TESTS_BEFORE=true
6. Detecta bump (breaking > feat > fix)
7. Calcula próxima versão (considerando pre-1.0 mode)
8. Atualiza package.json
9. Gera entrada CHANGELOG (Added/Fixed/Changed/Breaking)
10. Insere acima de [Unreleased] (ou cria arquivo)
11. Cria commit "chore(release): vX.Y.Z"
12. Cria tag anotada vX.Y.Z
13. (Opcional, AUTO_PUSH=true) push
14. Relatório
```

### Saída do CHANGELOG

```markdown
## [1.2.0] - 2026-04-19

### Added

- **Add OAuth PKCE flow** — Replaces deprecated implicit flow. PKCE eliminates the need for client secrets in public clients and is required by Anthropic's OAuth 2.1 specification.

### Fixed

- **Handle null token gracefully** — Empty OAuth state led to 500 when user cleared cookies. Guards against null in authorization middleware.
```

### Pre-1.0 mode

Projetos em `0.x` têm 2 convenções. O script suporta ambas via
`PRE_1_0_MAJOR_AS_MINOR` no topo:

#### `true` (default, padrão clw-auth)

Reserva `1.0.0` como marco de estabilidade. Em 0.x, mesmo `feat!:`
(breaking) vira bump MINOR:

```
0.9.5 + breaking change → 0.10.0 (MINOR em 0.x = MAJOR em 1.x+)
0.9.5 + feat            → 0.10.0
0.9.5 + fix             → 0.9.6
```

#### `false` (SemVer estrito)

Breaking change em 0.x pula para 1.0.0:

```
0.9.5 + breaking change → 1.0.0
0.9.5 + feat            → 0.10.0
0.9.5 + fix             → 0.9.6
```

Edite `scripts/release.mjs` para alternar:

```javascript
const PRE_1_0_MAJOR_AS_MINOR = true;   // ou false
```

### Quality gate embutido

Antes de criar release, valida:

#### 1. Commits conventional

Regex `^([a-z]+)(\([^)]+\))?(!)?: .+$`. Commits não-conformes são WARN
(não bloqueiam — projetos legacy têm histórico).

#### 2. Body em feat/fix/breaking

```javascript
const BODY_REQUIRED_TYPES = new Set(['feat', 'fix']);
const MIN_BODY_LENGTH = 20;
```

Se qualquer commit `feat`, `fix` ou breaking (via `!:` ou `BREAKING CHANGE:`)
tem body ausente ou `< 20` chars, aborta com:

```
Quality check failed — these commits need a body before releasing:

  abc1234  feat: add login
           ↑ feat commits require a body description (>= 20 chars)

  def5678  fix(auth)!: remove v1 endpoint
           ↑ breaking changes require a body description (>= 20 chars)

How to fix:
  git commit --amend          amend the last commit
  git rebase -i <hash>^       edit an older commit body
```

#### 3. Tests passam

`npm test` deve retornar 0. Pode pular com `NO_TESTS=1`.

#### 4. Working tree limpa

`git status --porcelain` vazio. Commits pendentes bloqueiam.

### Entrada manual adicional

Use `changelog-write-entry` se precisa adicionar entrada antes/depois do
release automatizado (ex: nota de compatibilidade não-óbvia):

```
adicionar entrada de documentação no CHANGELOG sobre compatibilidade com Node 18
```

A skill alerta se detectar `scripts/release.mjs` — entradas manuais podem
duplicar no próximo release.

## Padrão C: puro git tag (minimalista)

Para projetos muito simples (scripts pessoais, experimentos):

```bash
# 1. Atualizar CHANGELOG manualmente
code CHANGELOG.md

# 2. Bump versão manualmente
jq '.version = "0.2.0"' package.json > /tmp/p.json && mv /tmp/p.json package.json

# 3. Commit + tag
git add CHANGELOG.md package.json
git commit -m "chore(release): v0.2.0"
git tag -a v0.2.0 -m "Release v0.2.0"
git push origin main v0.2.0
```

Use `release-quality-gate` antes de criar tag para validar:

```bash
bash release-quality-gate-check.sh --target-version=0.2.0 && \
  git tag -a v0.2.0 -m "Release v0.2.0" && \
  git push origin v0.2.0
```

## Git hooks customizados

Instalar em projeto:

```
instalar git hooks neste projeto
```

Skill `git-hooks-install` cria:

```
projeto/
├── .githooks/
│   ├── commit-msg              # Valida formato + idioma
│   └── pre-commit              # Enforce identity
├── scripts/
│   └── install-hooks.sh        # Postinstall script
└── package.json                # Adiciona "postinstall"
```

Configura `git config core.hooksPath .githooks` (per-clone; postinstall
automatiza para novos contribuidores).

### `commit-msg` — Conventional + EN-US

Rejeita:

- Header fora do formato `type(scope): description`
- Verbos PT-BR (adicionar, corrigir, atualizar, etc. — lista completa no template)

Aceita commits `Merge ...` e `Revert ...` (bypass).

Exemplo de erro:

```
ERROR: Commit message appears to be in Portuguese (PT-BR).
This repository requires commit messages in English (EN-US).

Subject: 'corrigir erro no parser'

  WRONG: fix: corrigir erro no parser
  RIGHT: fix: fix parser error
```

### `pre-commit` — Identity enforcement

Rejeita commits de autores diferentes:

```sh
REQUIRED_NAME="4i3n6"
REQUIRED_EMAIL="4i3n6@pm.me"
```

Erro:

```
ERROR: Commits to this repository must be authored by 4i3n6 <4i3n6@pm.me>
Current identity: cyllas <cyllas@gmail.com>

Fix with:
  git config user.name '4i3n6'
  git config user.email '4i3n6@pm.me'
```

Útil para:

- Projetos solo com identidade obrigatória (CI enforcement)
- Equipes com lista fixa de autores (adaptar para whitelist)

### Postinstall automation

Script `install-hooks.sh`:

```sh
#!/bin/sh
git config core.hooksPath .githooks
find .githooks -type f -exec chmod +x {} \;
exit 0
```

Adicionado em `package.json`:

```json
"scripts": {
  "postinstall": "sh scripts/install-hooks.sh"
}
```

Quando contribuidor roda `npm install`, hooks são automaticamente configurados.

## Release quality gate

Skill **read-only** que roda 10 checks antes de release. Útil como:

- Último check antes de `npm run release`
- CI step dedicado
- Sanity check manual

```
valide prontidão para release v1.2.0
```

Ou diretamente (quando implementada como script):

```bash
release-quality-gate --target-version=1.2.0 --strict
```

### 10 checks

1. **Working tree limpa** — sem staged, modified, untracked
2. **Tag alvo disponível** — `v1.2.0` não existe ainda
3. **Commits conventional** — regex passa em todos desde última tag
4. **Body quality** — feat/fix/breaking com body ≥ 20 chars
5. **Tests passam** — `npm test` retorna 0 (pular com `--skip-tests`)
6. **Lint passa** — `npm run lint` se script existe
7. **Typecheck passa** — `npm run typecheck` se script existe
8. **CHANGELOG entry** — `## [1.2.0]` ou `## [Unreleased]` presente
9. **Branch correta** — `main` ou `master` (warn se feature branch)
10. **Sync com remote** — não behind de `origin/main`

### Exit codes

| Code | Significado |
|------|-------------|
| 0 | Todos os checks passaram |
| 1 | Algum check bloqueante falhou |
| 2 | Warnings presentes (com `--strict`, trata como falha) |

### Flags

| Flag | Efeito |
|------|--------|
| `--target-version=<v>` | Valida tag + CHANGELOG |
| `--since=<ref>` | Override auto-detect de última tag |
| `--skip-tests` | Pula `npm test` |
| `--skip-lint` | Pula `npm run lint` |
| `--skip-typecheck` | Pula `npm run typecheck` |
| `--strict` | Warnings viram blocking |
| `--min-body=<N>` | Override MIN_BODY_LENGTH |

### Saída típica

Sucesso:

```
Release Quality Gate — PASSED

[1/10] working tree clean               ok
[2/10] target tag v1.2.0 available      ok
[3/10] conventional commits format      23 commits, 0 violations
[4/10] commit body quality              3 feat, 5 fix, 0 breaking — all passed
[5/10] tests                            ok
[6/10] lint                             ok
[7/10] typecheck                        ok
[8/10] CHANGELOG entry                  [Unreleased] found
[9/10] branch                           on main
[10/10] sync with remote                up to date

Summary:
  Detected bump:  minor (0 breaking + 3 feat + 5 fix)
  Target version: 1.2.0 (from 1.1.0)
  Ready to release.
```

Falha:

```
Release Quality Gate — FAILED

[4/10] commit body quality              2 feat need body

  abc1234  feat: add login
           missing body (required for feat >= 20 chars)

  def5678  feat: add logout
           body 15 chars (required >= 20)

  Fix with:
    git commit --amend          # for the last commit
    git rebase -i HEAD~5        # for older commits

[5/10] tests                            FAILED (3 tests failing)

Summary:
  Quality gate failed. Fix issues above before releasing.
```

## Gotchas e anti-patterns

### Commits legacy não-conventional

Se projeto tem 50 commits "fix cadastro", `release-please` **ignora-os**
(não aparecem no CHANGELOG). `release.mjs` **emite warning**. Ambos **não**
retroagem.

**Estratégia**: baseline mark. Adicionar entry no CHANGELOG:

```markdown
## [0.5.0] - 2025-12-01 — initial changelog baseline

Changes prior to 0.5.0 not tracked in this changelog. See git history
for details.
```

Daqui pra frente, conventional commits obrigatórios.

### Entrada manual em projeto com release-please

release-please **sobrescreve** edições manuais em `[Unreleased]`. A skill
`changelog-write-entry` detecta e avisa — você decide se prossegue
(ciente que será sobrescrito).

### Auto-merge + branch protection

Se `main` tem branch protection exigindo PR review, o `GITHUB_TOKEN` default
pode não conseguir mergear. Soluções:

1. Usar PAT de admin (secret `AUTO_MERGE_TOKEN`)
2. Configurar branch protection para aceitar GitHub App de release-please
3. Desabilitar auto-merge (aceitar release PR manual)

### Tag legacy não-SemVer

Tags antigas tipo `v1`, `1.0`, `release-2024` quebram `git describe`.
Skills passam `--since=<hash>` explicitamente ou usam primeiro commit
como baseline.

### Monorepo com tags mistas

Em monorepo com `md2pdf-v2.2.0` + `api-v1.5.0`, `git describe` pode pegar
tag errada. release-please resolve com `include-component-in-tag: true`.
Script manual precisa adaptar para filtrar por prefix.

### BUMP=major em 0.x

Com `PRE_1_0_MAJOR_AS_MINOR=true`, `BUMP=major` em 0.9.5 vira 0.10.0.
Para ir de 0.x para 1.0, editar `package.json` manual + tag manual:

```bash
jq '.version = "1.0.0"' package.json > /tmp/p.json && mv /tmp/p.json package.json
git add package.json CHANGELOG.md
git commit -m "chore(release): v1.0.0 — API stability milestone"
git tag -a v1.0.0 -m "Release v1.0.0"
```

### Tests flaky

Flakiness causa falso-negativo em `release-quality-gate`. Soluções:

- Curto prazo: retry 1 vez antes de falhar (adicionar lógica custom)
- Longo prazo: corrigir testes

### Signed commits e tags

Se projeto exige `gpg.sign` ou `tag.gpgSign`:

```javascript
// scripts/release.mjs — adaptar git() helper
git(['commit', '-S', '-m', `chore(release): ${tagName}`]);
git(['tag', '-s', '-a', tagName, '-m', `Release ${tagName}`]);
```

GPG/SSH key configurado previamente.

### Release em CI mode

`release.mjs` não deve rodar em CI (é ferramenta de dev). Detectar:

```javascript
if (process.env.CI === 'true') {
  console.error('release.mjs should not run in CI. Use release-please workflow.');
  process.exit(1);
}
```

## Estratégia recomendada por maturidade

### Fase 1 — projeto novo

1. Inicializar repo + `git init`
2. `git-hooks-install` — enforce conventional desde o início
3. Primeiro commit: `feat: initial scaffold`
4. Escolher: `release-manual-setup` (mais simples) OU `release-please-setup`
5. Tag inicial `v0.1.0`

### Fase 2 — projeto em crescimento

- Adicionar `release-quality-gate` como verificação extra
- Documentar CHANGELOG retroativo se aplicável
- Considerar auto-merge se team cresceu

### Fase 3 — projeto maduro (v1.0+)

- SemVer estrito
- Tests obrigatórios no quality gate
- GitHub Releases com notas detalhadas
- Deprecation policy documentada
- LTS strategy para majors

## Ver também

- [`git-methodology/README.md`](../../global/skills/git-methodology/README.md)
- [`git-methodology/references/`](../../global/skills/git-methodology/references/) — 4 references técnicas
- [`release-please-setup/SKILL.md`](../../global/skills/release-please-setup/SKILL.md)
- [`release-manual-setup/SKILL.md`](../../global/skills/release-manual-setup/SKILL.md)
- [`changelog-write-entry/SKILL.md`](../../global/skills/changelog-write-entry/SKILL.md)
- [`git-hooks-install/SKILL.md`](../../global/skills/git-hooks-install/SKILL.md)
- [`release-quality-gate/SKILL.md`](../../global/skills/release-quality-gate/SKILL.md)
- [Keep a Changelog](https://keepachangelog.com/en/1.1.0/)
- [Semantic Versioning](https://semver.org/spec/v2.0.0.html)
- [Conventional Commits](https://www.conventionalcommits.org/)
- [release-please](https://github.com/googleapis/release-please)
