# Padrão A: release-please

Fluxo automatizado via GitHub Actions. Ideal para projetos com equipe >= 2
pessoas, PR workflow obrigatório, e desejo de zero trabalho manual por release.

> **Índice geral**: [README.md](./README.md)

## Pré-requisitos

- Projeto no GitHub (public ou private)
- `package.json` com `.version` válido
- Commits seguindo Conventional Commits (instale `git-hooks-install` antes)
- Branch default `main` (adaptável para `master`)
- Permissão para criar workflow em `.github/workflows/`

## Setup

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

## `release-please-config.json`

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

### Customize release-type

| Linguagem | release-type |
|-----------|--------------|
| Node.js | `node` |
| Python | `python` |
| Rust | `rust` |
| Go | `go` |
| PHP | `php` |
| Ruby | `ruby` |

## Extra-files

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

## Workflow

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

### Auto-merge precisa:

- Settings -> General -> Pull Requests -> **Allow auto-merge** habilitado
- Branch protection compatível com `GITHUB_TOKEN` (senão, usar PAT ou App)

## Ciclo de release

```
1. Desenvolvedor commita: "feat(auth): add OAuth PKCE flow"
2. Push para main
3. Workflow release-please roda
4. Detecta commits feat/fix -> calcula bump (minor)
5. Cria/atualiza PR: "chore(main): release 1.2.0"
   - Atualiza package.json
   - Atualiza CHANGELOG.md (seção [1.2.0] com itens)
   - Atualiza extra-files
6. (Auto-merge OU mantenedor mergeia)
7. Merge dispara criação de tag v1.2.0 + GitHub Release
```

## Saída do CHANGELOG

```markdown
## [1.2.0](https://github.com/owner/repo/compare/v1.1.0...v1.2.0) (2026-04-19)

### Added

* **auth:** add OAuth PKCE flow ([abc1234](https://github.com/owner/repo/commit/abc1234))

### Fixed

* **parser:** handle null token gracefully ([def5678](https://github.com/owner/repo/commit/def5678))
```

Cada entry tem link pro commit; cada versão tem link pro diff.

## Ver também

- [README.md](./README.md) — índice e visão geral
- [quality-gate.md](./quality-gate.md) — adicionar quality gate ao fluxo
