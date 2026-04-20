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

## Quando usar / Quando NAO usar

**Use quando:**
- Projeto Node.js no GitHub precisa de release automatico
- Commits seguem Conventional Commits
- Usuario menciona release-please, release automation, auto changelog

**NAO use quando:**
- Projeto sem CI GitHub
- PHP/Python/Rust (use skill correspondente)
- Usuario quer script caseiro (use `release-manual-setup`)
- Projeto ja tem pipeline de release customizado

## Pre-requisitos

- Projeto hospedado no GitHub (publico ou privado)
- Commits seguem Conventional Commits (use `git-hooks-install` se ainda nao)
- `package.json` com campo `version` valido
- Branch default `main` (adaptavel para `master`)
- Permissao para criar workflow em `.github/workflows/`

## Setup passo-a-passo

### 1. Validar estado do projeto

```bash
test -f package.json || { echo "package.json obrigatorio"; exit 1; }
jq -e '.version' package.json >/dev/null || { echo "package.json sem .version"; exit 1; }
git log --oneline -5 | grep -qE '^[a-f0-9]+ (feat|fix|chore|docs|refactor|perf|test|style|build|ci)' \
  || echo "AVISO: commits recentes nao parecem conventional"
```

### 2. Perguntar preferencias (via `AskUserQuestion`)

- **Nome do pacote** para prefixo de tag (default: `.name` do package.json)
- **Monorepo?** (default: nao)
- **Extra-files** a versionar (HTML, JSON de i18n, constants.ts)
- **Auto-merge** do PR de release? (recomendado: sim)
- **Branch default**: `main` ou `master`

### 3. Copiar templates de [`templates/`](./templates/)

Copiar 3 arquivos adaptados:

1. `release-please-config.json` -> raiz do projeto
2. `.release-please-manifest.json` -> raiz do projeto (pre-populado com versao atual)
3. `release-please.yml` -> `.github/workflows/release-please.yml`

### 4. Customizar `release-please-config.json`

Ajustar conforme preferencias coletadas:

- `packages.".".release-type` — `node` (default)
- `changelog-sections` — customizar secoes e ordem
- `extra-files` — listar paths com versao
- `changelog-host` — `github.com` (default) ou custom
- `include-component-in-tag` — true para monorepo

### 5. Popular `.release-please-manifest.json`

Single package:

```json
{ ".": "1.2.3" }
```

Monorepo:

```json
{
  "packages/web": "2.0.0",
  "packages/api": "1.5.3",
  "packages/shared": "0.8.1"
}
```

### 6. Configurar permissions no workflow

O workflow requer:

```yaml
permissions:
  contents: write
  pull-requests: write
```

### 7. Opcional: auto-merge do release PR

Evita esquecer PRs de release pendentes:

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

### 8. Commit e push

```bash
git add release-please-config.json .release-please-manifest.json \
        .github/workflows/release-please.yml
git commit -m "chore(release): configure release-please automation"
git push origin main
```

### 9. Validar

Apos push, verificar no GitHub Actions:

1. Workflow `Release Please` deve aparecer e rodar
2. PR de release aberto (primeira vez talvez nao — so em push conventional)

## Smoke test

```bash
gh workflow run release-please
gh run watch
```

## Changelog sections padrao

O template padrao mapeia:

| Commit type | Section |
|-------------|---------|
| `feat` | `### Added` |
| `fix` | `### Fixed` |
| `perf` | `### Performance` |
| `refactor` | `### Changed` |
| `test` | `### Tests` |
| `docs` | `### Documentation` |
| `style` | `### Style` |
| `build`, `ci`, `chore` | hidden (nao aparece) |

Ordem no CHANGELOG = ordem no array de `changelog-sections`. Customizar em `release-please-config.json`.

## Gotchas criticos

### 1. Primeiro release PR precisa de commits conventional

Se projeto tem commits nao-conventional antes do setup, release-please
vai ignora-los no primeiro release. Considerar marcar versao atual como
baseline via manifest: `{ ".": "1.0.0" }`.

### 2. extra-files precisam de marker ou padrao detectavel

Se `index.html` tem `<meta version="1.0.0">` sem marker, release-please
nao sabe onde trocar. Usar `<!-- x-release-please-version -->` ou comentarios
de bloco.

### 3. Release-type errado para projeto nao-Node

`node` assume `package.json`. Para:
- Python: `release-type: python`
- Rust: `release-type: rust`
- Go: `release-type: go`
- PHP: `release-type: php`
- Ruby: `release-type: ruby`

Ver `references/config-options.md` para lista completa.

## Templates disponiveis

| Template | Destino | Descricao |
|----------|---------|-----------|
| `release-please-config.json` | raiz | Config principal |
| `.release-please-manifest.json` | raiz | Estado atual de versao |
| `release-please.yml` | `.github/workflows/` | Workflow CI |

## Referencias

- [`references/config-options.md`](./references/config-options.md) — configuracao detalhada de release-please-config.json
- [`references/extra-files.md`](./references/extra-files.md) — atualizacao de versao em arquivos customizados
- [`references/monorepo.md`](./references/monorepo.md) — configuracao multi-pacote
- [`references/gotchas.md`](./references/gotchas.md) — gotchas adicionais e problemas comuns

## Ver tambem

- [`../git-methodology/README.md`](../git-methodology/README.md) — escolha entre padroes
- [`../release-manual-setup/`](../release-manual-setup/) — alternativa caseira
- [`../git-hooks-install/`](../git-hooks-install/) — complementa com commit-msg validation
- [release-please docs](https://github.com/googleapis/release-please)
- [Changelog types](https://github.com/googleapis/release-please/blob/main/docs/customizing.md#changelog-types)
