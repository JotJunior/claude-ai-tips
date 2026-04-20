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
- Node.js >= 18

## Setup passo-a-passo

### 1. Validar estado do projeto

```bash
test -f package.json || { echo "package.json obrigatorio"; exit 1; }
jq -e '.version' package.json
node --version  # >=18 recomendado
```

### 2. Perguntar preferencias (via AskUserQuestion)

1. **Versao inicial** se `package.json` tem `0.0.0` (sugerir `0.1.0`)
2. **Pre-1.0 bump mode**: tratar `feat!:` como MAJOR ou MINOR em 0.x?
   (clw-auth pattern: MINOR — reserva 1.0.0 como marco de estabilidade)
3. **Body minimo**: `MIN_BODY_LENGTH` default 20 chars
4. **Rodar tests**: incluir `npm test` antes do release?
5. **Auto-push**: push tag + commit apos release, ou deixar manual?
6. **Commit separator**: default `---COMMIT-END---` (customizavel)

### 3. Copiar templates

```bash
mkdir -p scripts test
cp templates/release.mjs scripts/release.mjs
cp templates/release.test.mjs test/release.test.mjs
chmod +x scripts/release.mjs
```

### 4. Customizar parametros no topo de `scripts/release.mjs`

```javascript
const BODY_REQUIRED_TYPES = new Set(['feat', 'fix']);  // ajustar
const MIN_BODY_LENGTH     = 20;                          // ajustar
const PRE_1_0_MAJOR_AS_MINOR = true;                     // false para SemVer estrito
const RUN_TESTS_BEFORE    = true;                         // false para pular
const AUTO_PUSH           = false;                        // true para push automatico
const TAG_PREFIX          = 'v';                          // 'my-package-v' para monorepo
```

### 5. Adicionar npm script

```bash
jq '.scripts.release = "node scripts/release.mjs"' package.json > /tmp/pkg.json
mv /tmp/pkg.json package.json
```

### 6. Inicializar CHANGELOG.md (se nao existir)

```markdown
# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]
```

### 7. Commit inicial

```bash
git add scripts/release.mjs test/release.test.mjs CHANGELOG.md package.json
git commit -m "chore(release): add manual release automation"
```

### 8. Smoke test (dry run)

```bash
DRY_RUN=1 npm run release
```

Deve listar commits desde ultima tag, mostrar bump detectado,
imprimir entrada CHANGELOG e tag que seria criada.

## Flags do script

| Flag / env | Descricao |
|-----------|-----------|
| `DRY_RUN=1` | Mostra o que seria feito sem criar tag/commit |
| `BUMP=major\|minor\|patch` | Forca tipo de bump ignorando detecao automatica |
| `NO_TESTS=1` | Pula `npm test` gate |
| `NO_PUSH=1` | Nao faz push apos criar tag |
| `AMEND=1` | Amenda ultimo commit ao inves de criar novo |

## Smoke test esperado

```bash
DRY_RUN=1 npm run release
```

Saida esperada:

```
Release v0.2.0 (minor from 0.1.0):

## [0.2.0] - 2026-04-19

### Added

- **new feature** — description here.

Summary:
  bump:        minor
  current:     0.1.0
  next:        0.2.0
  commits:     3
  tag:         v0.2.0

(dry-run — no files modified, no commit, no tag)
```

## Gotchas criticos

### AUTO_PUSH=false por default

`AUTO_PUSH=true` + rede instavel = commit + tag criados localmente
mas push falha, deixando estado inconsistente. **Sempre usar
`AUTO_PUSH=false`** e fazer push manual apos verificar:

```bash
npm run release
git push origin main
git push origin v0.1.0
```

### BUMP=major em 0.x rera como minor

Com `PRE_1_0_MAJOR_AS_MINOR=true` (default), `BUMP=major` em 0.9.5
resulta em `0.10.0`, nao `1.0.0`. Para forcar 1.0.0: editar
`package.json` manualmente para `1.0.0` antes de rodar release.

### Working tree deve estar limpa

Release aborta se houver changes uncommitted. Faca `git stash` ou
commite antes. Isso protege contra releases que capturam apenas
parte das mudancas.

## Referencias

- **[Script walkthrough](./references/script-walkthrough.md)** — funcoes do release.mjs, fluxo, exit codes, parsing de CHANGELOG
- **[Quality gate](./references/quality-gate.md)** — 4 checks executados, ordem, falhas comuns
- **[Gotchas detalhados](./references/gotchas.md)** — todos os gotchas e limitacoes

## Ver tambem

- [`release-quality-gate`](../release-quality-gate/) — validador isolado
- [`release-please-setup`](../release-please-setup/) — alternativa automatizada
- [`git-hooks-install`](../git-hooks-install/) — commit-msg validation
- [clw-auth release.mjs](https://github.com/4i3n6/clw-auth/blob/master/scripts/release.mjs)

## Templates

| Template | Destino | Descricao |
|----------|---------|-----------|
| `release.mjs` | `scripts/release.mjs` | Script principal |
| `release.test.mjs` | `test/release.test.mjs` | Test suite via node:test |
