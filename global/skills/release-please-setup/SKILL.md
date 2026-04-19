---
name: release-please-setup
description: |
  Use quando o usuario pedir para configurar release automatizado via
  release-please (Google) em um projeto Node.js hospedado no GitHub.
  Tambem quando mencionar "setup release-please", "release automation",
  "auto changelog", "auto version bump", "release pr", "github release
  automation". Cria os 3 arquivos necessarios (release-please-config.json,
  .release-please-manifest.json, .github/workflows/release-please.yml)
  configurados com changelog-sections customizadas e extra-files. NAO use
  para projetos sem CI GitHub, projetos PHP/Python/Rust (use variante
  correspondente), ou quando o usuario quer controle fino via script
  caseiro (use release-manual-setup).
argument-hint: "[--package=<name>] [--monorepo] [--extra-files=<path1,path2>] [--auto-merge]"
allowed-tools:
  - Read
  - Write
  - Edit
  - Bash
  - AskUserQuestion
---

# Skill: Release-Please Setup

Configura automacao de releases via [release-please](https://github.com/googleapis/release-please)
em projeto Node.js hospedado no GitHub. Apos setup, cada push para `main`
abre/atualiza um PR de release que consolida commits em CHANGELOG, bumpa
versao e cria tag quando o PR eh merjeado.

## Pre-requisitos

- Projeto hospedado no GitHub (publico ou privado)
- Commits seguem Conventional Commits (use `git-hooks-install` se
  ainda nao)
- `package.json` com campo `version` valido
- Branch default `main` (adaptavel para `master`)
- Permissao para criar workflow em `.github/workflows/`

## Fluxo

### Etapa 1: validar estado

```bash
test -f package.json || { echo "package.json obrigatorio"; exit 1; }
jq -e '.version' package.json >/dev/null || { echo "package.json sem .version"; exit 1; }
git log --oneline -5 | grep -qE '^[a-f0-9]+ (feat|fix|chore|docs|refactor|perf|test|style|build|ci)' \
  || echo "AVISO: commits recentes nao parecem conventional"
```

### Etapa 2: perguntar preferencias

Via `AskUserQuestion`:

1. **Nome do pacote** para prefixo de tag (default: `.name` do package.json)
2. **Monorepo?** (default: nao)
3. **Extra-files** a versionar (HTML, JSON de i18n, constants.ts):
   exemplos em md2pdf: `index.html`, `src/i18n/en.ts`, `manual/content.json`
4. **Auto-merge** do PR de release? (recomendado: sim — evita esquecer
   releases pendentes)
5. **Branch default**: `main` ou `master`

### Etapa 3: copiar templates customizados

Copiar 3 arquivos de [`templates/`](./templates/) adaptados:

1. `release-please-config.json` -> raiz do projeto
2. `.release-please-manifest.json` -> raiz do projeto (pre-populado com
   versao atual)
3. `release-please.yml` -> `.github/workflows/release-please.yml`

### Etapa 4: customizar config

Ajustar `release-please-config.json`:

- `packages.".".release-type` — `node` (default) ou outro
  (`python`, `rust`, `go`, `php`)
- `changelog-sections` — customizar quais tipos aparecem e como
- `extra-files` — listar paths que contem versao (HTML/JSON)
- `changelog-host` — default `github.com` (pode ser GitLab)
- `include-component-in-tag` — true para monorepo

### Etapa 5: popular manifest

`.release-please-manifest.json` comeca com versao atual:

```json
{
  ".": "1.2.3"
}
```

Monorepo:

```json
{
  "packages/web": "2.0.0",
  "packages/api": "1.5.3",
  "packages/shared": "0.8.1"
}
```

### Etapa 6: configurar workflow

`release-please.yml` requer `permissions`:

```yaml
permissions:
  contents: write
  pull-requests: write
```

Auto-merge opcional (evita esquecer release PR pendente):

```yaml
auto-merge:
  needs: release-please
  steps:
    - name: Merge pending release PR
      run: |
        PR=$(gh pr list --label "autorelease: pending" --state open \
          --json number --jq '.[0].number // empty')
        if [ -n "$PR" ]; then
          gh pr merge "$PR" --merge --auto
        fi
```

### Etapa 7: commit inicial

```bash
git add release-please-config.json .release-please-manifest.json \
        .github/workflows/release-please.yml
git commit -m "chore(release): configure release-please automation"
git push origin main
```

### Etapa 8: validar

Apos push, visitar `Actions` no GitHub:

1. Workflow `Release Please` deve rodar
2. Apos rodar, verificar se:
   - PR de release foi aberto (primeira vez talvez nao — so em push com
     commit conventional)
   - Ou rodar `gh workflow run release-please`

### Etapa 9: relatorio

```
release-please configurado:
  package:       md2pdf
  manifest:      2.2.0
  tag format:    md2pdf-v2.2.0
  extra-files:   5 arquivos
  auto-merge:    habilitado
  changelog:     CHANGELOG.md (sera criado no primeiro release PR)

proxima release:
  - commits novos em main com prefixo feat/fix dispararao release PR
  - PR atualiza CHANGELOG + package.json + extra-files
  - merge do PR cria tag + GitHub Release
```

## Changelog sections customizadas

Template padrao mapeia:

| Commit type | Section |
|-------------|---------|
| `feat` | `### Added` |
| `fix` | `### Fixed` |
| `perf` | `### Performance` |
| `refactor` | `### Changed` |
| `test` | `### Tests` |
| `docs` | `### Documentation` |
| `style` | `### Style` |
| `build`, `ci`, `chore` | hidden (nao aparece no CHANGELOG) |

Ordem das secoes no CHANGELOG: igual a ordem no `changelog-sections`
array — primeiro do array aparece primeiro no CHANGELOG.

Para customizar, editar o array:

```json
"changelog-sections": [
  { "type": "feat",     "section": "### Added" },
  { "type": "fix",      "section": "### Fixed" },
  { "type": "perf",     "section": "### Performance" },
  { "type": "refactor", "section": "### Refactor" },
  { "type": "docs",     "section": "### Documentation" },
  { "type": "chore",    "section": "### Chore", "hidden": true }
]
```

## Extra-files

release-please pode atualizar versao em arquivos alem de `package.json`:

### JSON (jsonpath)

```json
{ "type": "json", "path": "manual/content.json", "jsonpath": "$.version" }
```

### Generic (primeira ocorrencia de versao)

```json
{ "type": "generic", "path": "index.html" }
```

Procura por marcador `x-release-please-version` ou padrao semver e
substitui.

Exemplo em HTML:

```html
<!-- x-release-please-start-version -->
<meta name="version" content="1.0.0">
<!-- x-release-please-end -->
```

Ou inline:

```html
<meta name="version" content="1.0.0"><!-- x-release-please-version -->
```

### Exemplos reais (md2pdf)

```json
"extra-files": [
  { "type": "generic", "path": "index.html" },
  { "type": "generic", "path": "app.html" },
  { "type": "generic", "path": "pt/index.html" },
  { "type": "generic", "path": "manual/index.html" },
  { "type": "generic", "path": "src/i18n/en.ts" },
  { "type": "generic", "path": "src/i18n/pt.ts" },
  { "type": "json",    "path": "manual/content.json", "jsonpath": "$.version" }
]
```

## Monorepo

```json
{
  "packages": {
    "packages/web": {
      "release-type": "node",
      "component": "web"
    },
    "packages/api": {
      "release-type": "node",
      "component": "api"
    },
    "packages/shared": {
      "release-type": "node",
      "component": "shared"
    }
  },
  "include-component-in-tag": true
}
```

Tags resultantes: `web-v1.2.3`, `api-v2.0.0`, `shared-v0.5.1`.

Cada pacote tem seu CHANGELOG.md em `packages/<name>/CHANGELOG.md`.

## Auto-merge do release PR

O release PR permanece aberto ate um desenvolvedor mergear. Isso pode
ser esquecido em projetos ativos.

Solucao: workflow adicional que auto-merge quando CI passa.

Snippet no `release-please.yml`:

```yaml
jobs:
  release-please:
    runs-on: ubuntu-latest
    steps:
      - uses: googleapis/release-please-action@v4

  auto-merge:
    needs: release-please
    runs-on: ubuntu-latest
    steps:
      - run: |
          PR=$(gh pr list --label "autorelease: pending" --state open \
            --json number --jq '.[0].number // empty')
          [ -n "$PR" ] && gh pr merge "$PR" --merge --auto
        env:
          GITHUB_TOKEN: ${{ secrets.GITHUB_TOKEN }}
```

Requer que o repo permita auto-merge (Settings > General > Pull Requests >
Allow auto-merge).

## Gotchas

### Primeiro release PR precisa de commits conventional

Se projeto tem 10 commits nao-conventional antes do setup, release-please
vai ignora-los no primeiro release. Considerar:

- Marcar versao atual como baseline via manifest (`{ ".": "1.0.0" }`)
- A partir do proximo commit conventional, release-please toma conta

### extra-files HTML/JSON precisam de marker ou padrao detectavel

Se `index.html` tem `<meta version="1.0.0">` sem marker, release-please
nao sabe onde trocar. Usar `<!-- x-release-please-version -->` ou comentarios
de bloco.

### changelog-host precisa estar correto

Default eh `github.com`. Se repo privado em GitHub Enterprise:

```json
"changelog-host": "https://github.enterprise.company.com"
```

GitLab, Gitea, etc: precisa customizar.

### Branches `master` vs `main`

release-please assume `main` por default. Se repo usa `master`:

```yaml
on:
  push:
    branches:
      - master

# + no action:
with:
  default-branch: master
```

### Auto-merge pode conflitar com branch protection

Se `main` tem branch protection exigindo review, auto-merge precisa ser
feito por uma GitHub App com permissao ou via PAT de admin. Default
`GITHUB_TOKEN` pode nao conseguir mergear.

### Release-type errado para projeto nao-Node

`release-type: node` assume `package.json`. Para:

- Python: `release-type: python` (usa `pyproject.toml` ou `setup.py`)
- Rust: `release-type: rust` (usa `Cargo.toml`)
- Go: `release-type: go` (nao tem version file, so tag)
- PHP: `release-type: php` (composer.json)
- Ruby: `release-type: ruby` (Gemfile ou .rb com VERSION)

### Tag prefix vs component

Sem `include-component-in-tag`, tag eh `v1.2.3`. Com, eh `<component>-v1.2.3`.

Em single package, manter sem component (prefixo limpo). Em monorepo,
ligar component (discriminar pacote).

### Commits legacy bagunçados

Se repo tem commits "fix cadastro" sem conventional prefix, release-please
ignora-os. Para release-please funcionar, ADOTAR conventional a partir de
agora — nao retroativar.

### Hidden sections nao aparecem mas somam

`chore: bump deps` com `hidden: true` nao aparece no CHANGELOG, mas CONTA
para detectar bump. Se repo tem so `chore` desde ultima tag:
release-please nao cria release PR (sem commits visiveis).

## Templates disponiveis

| Template | Destino | Descricao |
|----------|---------|-----------|
| `release-please-config.json` | raiz | Config principal |
| `.release-please-manifest.json` | raiz | Estado atual de versao |
| `release-please.yml` | `.github/workflows/` | Workflow CI |

## Ver tambem

- [`git-methodology/README.md`](../git-methodology/README.md) — escolha entre padroes
- [`release-manual-setup`](../release-manual-setup/) — alternativa caseira
- [`git-hooks-install`](../git-hooks-install/) — complementa com commit-msg validation
- [release-please docs](https://github.com/googleapis/release-please)
- [Changelog types](https://github.com/googleapis/release-please/blob/main/docs/customizing.md#changelog-types)
