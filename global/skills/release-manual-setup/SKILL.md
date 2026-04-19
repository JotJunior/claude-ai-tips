---
name: release-manual-setup
description: |
  Use quando o usuario quer configurar release MANUAL (sem GitHub Actions)
  via script caseiro em Node.js — controle fino sobre parse de commits,
  bump de versao, geracao de changelog, quality gates. Tambem quando
  mencionar "release manual", "script release", "release.mjs", "release
  caseiro", "controle fino release". Copia template do release.mjs (baseado
  no padrao clw-auth), cria scripts/release.mjs + test/release.test.mjs +
  atualiza package.json com npm script. NAO use para projetos que ja tem
  CI GitHub (prefira release-please-setup) ou para times grandes (prefira
  automacao CI).
argument-hint: "[--pre-1.0] [--body-min=<N>] [--no-tests]"
allowed-tools:
  - Read
  - Write
  - Edit
  - Bash
  - AskUserQuestion
---

# Skill: Release Manual Setup

Configura script caseiro `scripts/release.mjs` que:

1. Le commits desde ultima tag
2. Parseia conventional commits
3. Enforca quality gate (body obrigatorio em feat/fix/breaking)
4. Detecta tipo de bump (major/minor/patch)
5. Atualiza package.json version
6. Gera entrada no CHANGELOG.md (formato Keep a Changelog)
7. Opcionalmente roda tests (release quality gate)
8. Cria commit `chore(release): vX.Y.Z`
9. Cria tag anotada `vX.Y.Z`
10. Push tag + commit (opcional)

Baseado no padrao `clw-auth/scripts/release.mjs`.

## Quando usar este vs release-please-setup

| Use este (manual) | Use release-please |
|-------------------|---------------------|
| Projeto pessoal/solo | Time >1 pessoa com PR workflow |
| Sem CI ou CI minimo | GitHub Actions ativo |
| Quer controle fino de formato | OK com formato padrao |
| Pre-1.0 em iteracao rapida | Monorepo ou pacote npm publicado |
| Zero dependencias externas | OK com vendor lock no CI |
| Release local via CLI | Release automatizado PR-based |

## Pre-requisitos

- `package.json` com `version` valido (inicio: `0.1.0` se projeto novo)
- Commits seguem Conventional Commits (use `git-hooks-install`)
- `CHANGELOG.md` existente (ou sera criado — skill suporta ambos)
- Opcional: suite de testes executavel via `npm test`

## Fluxo

### Etapa 1: validar estado

```bash
test -f package.json || { echo "package.json obrigatorio"; exit 1; }
jq -e '.version' package.json
node --version  # >=18 recomendado
```

### Etapa 2: perguntar preferencias

Via `AskUserQuestion`:

1. **Versao inicial** se `package.json` tem `0.0.0` (sugerir `0.1.0`)
2. **Pre-1.0 bump mode**: tratar `feat!:` como MAJOR ou MINOR em 0.x?
   (clw-auth pattern: MINOR — reserva 1.0.0 como marco de estabilidade)
3. **Body minimo**: `MIN_BODY_LENGTH` default 20 chars
4. **Rodar tests**: incluir `npm test` antes do release?
5. **Auto-push**: push tag + commit apos release, ou deixar manual?
6. **Commit separator**: default `---CLW-COMMIT-END---` (customizavel
   se projeto ja usa outro)

### Etapa 3: copiar template

```bash
mkdir -p scripts test
cp templates/release.mjs ~/projeto/scripts/release.mjs
cp templates/release.test.mjs ~/projeto/test/release.test.mjs
chmod +x ~/projeto/scripts/release.mjs
```

### Etapa 4: customizar parametros

Editar topo de `scripts/release.mjs`:

```javascript
const BODY_REQUIRED_TYPES = new Set(['feat', 'fix']);  // ajustar
const MIN_BODY_LENGTH = 20;                             // ajustar
const PRE_1_0_MAJOR_AS_MINOR = true;                    // false para SemVer estrito
const RUN_TESTS_BEFORE = true;                          // false para pular
const AUTO_PUSH = false;                                // true para push automatico
```

### Etapa 5: adicionar npm script

```bash
jq '.scripts.release = "node scripts/release.mjs"' package.json > /tmp/pkg.json
mv /tmp/pkg.json package.json
```

Resultado em `package.json`:

```json
"scripts": {
  "release": "node scripts/release.mjs",
  "test": "node --test test/*.test.mjs"
}
```

### Etapa 6: inicializar CHANGELOG.md

Se nao existir, criar:

```markdown
# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]
```

### Etapa 7: commit inicial

```bash
git add scripts/release.mjs test/release.test.mjs CHANGELOG.md package.json
git commit -m "chore(release): add manual release automation

Adds scripts/release.mjs with conventional commit parsing, SemVer bump
detection, Keep a Changelog generation, and quality gate for commit
bodies. Test suite in test/release.test.mjs validates parser logic."
```

### Etapa 8: validar

Testar o release em modo dry (sem criar tag):

```bash
DRY_RUN=1 npm run release
```

Deve:
- Listar commits desde tag zero ou ultima tag
- Reportar quality issues (commits sem body)
- Mostrar bump detectado
- Imprimir entrada CHANGELOG que seria adicionada
- Imprimir tag que seria criada

### Etapa 9: relatorio

```
release manual configurado:
  script:        scripts/release.mjs
  test:          test/release.test.mjs
  package:       my-project (versao atual: 0.1.0)
  body min:      20 chars
  test gate:     habilitado (npm test antes do release)
  auto-push:     desabilitado
  changelog:     CHANGELOG.md (Keep a Changelog 1.1.0)

uso:
  npm run release             # interativo (confirma bump detectado)
  DRY_RUN=1 npm run release   # dry run (sem tag nem commit)
  BUMP=major npm run release  # forca tipo especifico
```

## Flags do script gerado

| Flag / env | Descricao |
|-----------|-----------|
| `DRY_RUN=1` | Mostra o que seria feito sem criar tag/commit |
| `BUMP=major\|minor\|patch` | Forca tipo de bump ignorando detecao automatica |
| `NO_TESTS=1` | Pula `npm test` gate |
| `NO_PUSH=1` | Nao faz push apos criar tag |
| `--amend` | Amenda ultimo commit ao inves de criar novo `chore(release)` |

## Quality gate

Antes de criar release, o script valida:

### 1. Commits desde ultima tag sao conventional

Regex `^([a-z]+)(\([^)]+\))?(!)?: .+$`. Commits nao-conformes sao
listados como WARN (nao bloqueia — projetos legacy tem historico).

### 2. feat/fix/breaking tem body >= MIN_BODY_LENGTH

```javascript
if (BODY_REQUIRED_TYPES.has(c.type) && (!c.body || c.body.length < MIN_BODY_LENGTH)) {
  failing.push(c);
}
```

Se qualquer commit falha, script **aborta** com lista detalhada e
comandos de fix (`git commit --amend`, `git rebase -i <hash>^`).

### 3. Tests passam

Se `RUN_TESTS_BEFORE=true`, roda `npm test`. Falha aborta.

### 4. Working tree limpa

`git status --porcelain` deve ser vazio. Uncommitted changes bloqueiam
release.

## Changelog generation

Script usa mesma logica do `clw-auth/scripts/release.mjs`:

### groupCommits()

Agrupa commits em 4 buckets:

- **breaking** — qualquer com `!:` ou `BREAKING CHANGE:` no body
- **feat** — tipo `feat`
- **fix** — tipo `fix`
- **chore** — qualquer outro tipo conventional

### buildEntry()

Gera secoes na ordem:

```markdown
## [1.2.0] - 2026-04-19

### Breaking Changes

- **Brief description** — rich body.

### Added

- **New feature** — explanation.

### Fixed

- **Bug fix** — context.

### Changed

- **Refactor** — impact.
```

### formatEntry()

Concatena body em 1 paragrafo (remove quebras internas):

```javascript
function formatEntry(commit) {
  const title = `**${commit.description}**`;
  if (!commit.body) return `- ${title}`;
  const bodyText = commit.body.split('\n').map(l => l.trim()).filter(Boolean).join(' ');
  return `- ${title} — ${bodyText}`;
}
```

## Test suite gerada

`test/release.test.mjs` testa:

- `parseCommit` — regex de conventional commits (feat/fix/chore, com/sem
  scope, com `!`, com `BREAKING CHANGE` no body, commits nao-conformes)
- `detectBumpType` — major > minor > patch (ordem de precedencia)
- `checkQuality` — body ausente, body curto, body valido, breaking
  requer body
- `formatEntry` — entrada com body, sem body, body multilinha
- `groupCommits` — separacao correta em breaking/feat/fix/chore

Usa Node.js built-in test runner (`node --test`), zero dependencias.

## Gotchas

### ESM vs CommonJS

Template usa ESM (`import`/`export`). Se projeto eh CommonJS:

```javascript
// Adaptar topo
const { spawnSync } = require('node:child_process');
const { readFileSync, writeFileSync } = require('node:fs');
```

Ou manter `.mjs` (ESM) mesmo em projeto CJS — Node.js aceita.

### BUMP=major em 0.x

Com `PRE_1_0_MAJOR_AS_MINOR=true`, `BUMP=major` em 0.9.5 resulta em 0.10.0
(nao 1.0.0). Para ir pra 1.0.0, rodar `BUMP=major` com flag explicita
`FORCE_1_0=1` ou editar `package.json` manualmente antes.

### git log entre tags

Primeiro release (sem tags ainda) usa `--max-count=1000` como limite
artificial. Projeto com mais de 1000 commits sem tag precisa ajustar.

### Commits de merge

Script usa `--no-merges` para ignorar commits de merge (GitHub PR merge
normalmente nao eh conventional).

### Tag prefix

Default: `v0.1.0`. Para monorepo ou customizacao:

```javascript
const TAG_PREFIX = 'my-package-v';  // resulta em my-package-v0.1.0
```

### Timestamps em CHANGELOG

Sempre UTC (`new Date().toISOString().slice(0, 10)` = `YYYY-MM-DD`).
Nao usar timezone local.

### Amend vs new commit

Default eh criar novo commit `chore(release): v0.1.0`. Se prefere amend
(menos ruido no log): `AMEND=1 npm run release`. Risco: amend sobrescreve
autor se config mudou.

### Push automatico arriscado

`AUTO_PUSH=true` + rede instavel = commit + tag criados mas push falha.
Solucao: deixar `AUTO_PUSH=false` por default, fazer push manual apos
verificar:

```bash
npm run release
git push origin main
git push origin v0.1.0  # ou: git push --tags
```

### Signed commits/tags

Se projeto exige `gpg.sign`/`tag.gpgSign`, adicionar:

```javascript
git(['tag', '-a', tagName, '-m', message, '-s']);  // -s para signed
git(['commit', '-S', '-m', commitMsg]);             // -S para signed commit
```

## Ver tambem

- [`git-methodology/references/commit-body-quality.md`](../git-methodology/references/commit-body-quality.md)
- [`release-please-setup`](../release-please-setup/) — alternativa automatizada
- [`release-quality-gate`](../release-quality-gate/) — validador isolado
- [`git-hooks-install`](../git-hooks-install/) — commit-msg validation
- [clw-auth release.mjs](https://github.com/4i3n6/clw-auth/blob/master/scripts/release.mjs)

## Templates

| Template | Destino | Descricao |
|----------|---------|-----------|
| `release.mjs` | `scripts/release.mjs` | Script principal (conventional parse + bump + changelog + tag) |
| `release.test.mjs` | `test/release.test.mjs` | Test suite via node:test |
