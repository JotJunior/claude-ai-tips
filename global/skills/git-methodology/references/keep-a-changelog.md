# Keep a Changelog — referencia

Especificacao: [keepachangelog.com/en/1.1.0](https://keepachangelog.com/en/1.1.0/).

## Principios

1. **Para humanos, nao maquinas** — proximo de `git log` nao serve
2. **Cada versao tem entrada** — sem exceção
3. **Mesmo tipo de mudanca agrupada** — Added, Fixed, Changed, etc.
4. **Versoes e secoes linkaveis** — `##` com ancoras estaveis
5. **Versao mais recente primeiro** (topo do arquivo)
6. **Data de release mostrada** em formato ISO `YYYY-MM-DD`
7. **SemVer** — referencia obrigatoria

## Estrutura esperada

```markdown
# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added
- Novas funcionalidades pendentes de release

## [1.2.0] - 2026-04-19

### Added
- **Brief title** — rich description explaining what and why.

### Fixed
- **Another brief title** — more context about the bug and fix.

### Changed
- **Refactor description** — impact on users.

## [1.1.0] - 2026-03-15

...
```

## Secoes padrao (ordem)

1. **Added** — nova funcionalidade (commits `feat`)
2. **Changed** — mudanca em funcionalidade existente (refactor com impacto
   externo, `refactor` + alguns `chore`)
3. **Deprecated** — funcionalidade que sera removida em release futura
4. **Removed** — funcionalidade removida nesta release
5. **Fixed** — correcoes (commits `fix`)
6. **Security** — vulnerabilidades corrigidas
7. **Breaking Changes** — mudancas incompativeis (em projetos que separam)
8. **Tests** — quando projeto considera relevante (md2pdf usa)
9. **Documentation** — quando projeto considera relevante (md2pdf usa)
10. **Performance** — otimizacoes (commits `perf`)

Nao usar secao `Miscellaneous` ou `Other` — tudo deve caber em uma das
categorias acima.

## Conventional commits -> secao Keep a Changelog

Mapeamento usado em `release-please`:

| Commit type | Section |
|-------------|---------|
| `feat` | `### Added` |
| `fix` | `### Fixed` |
| `perf` | `### Performance` |
| `refactor` | `### Changed` |
| `test` | `### Tests` |
| `docs` | `### Documentation` |
| `style` | `### Style` |
| `build` | `### Build` (hidden) |
| `ci` | `### CI` (hidden) |
| `chore` | `### Chore` (hidden) |
| `BREAKING CHANGE` | `### Breaking Changes` (top) |

`hidden: true` no release-please significa que o tipo nao aparece no
changelog final (reduz ruido). `build`, `ci`, `chore` tipicamente
ocultos.

## Formato de entrada

Duas abordagens nos projetos de referencia:

### A) clw-auth (body concat)

```markdown
- **expose openclaw export targeting options in CLI** — Add `clw-auth
  export openclaw --agent <agentId>` and `clw-auth export openclaw
  --all-configured` support so `clw-auth` can explicitly target one
  OpenClaw agent or sync all preconfigured agents without a confirmation
  loop.
```

Formato: `- **<title>** — <body concatenado em 1 paragrafo>`

### B) release-please (link-rich)

```markdown
* **print:** truncate long autolinked URLs for print display ([f2e8bc7](https://github.com/owner/repo/commit/f2e8bc7...))
```

Formato: `* **<scope>:** <description> ([<short-hash>](<commit-url>))`

Ambos validos. Escolher pelo padrao do tool. release-please usa B
sempre. Script caseiro pode usar A ou B.

## Secao [Unreleased]

Obrigatoria no topo, **logo apos o header**. Acumula mudancas desde
ultima tag. Quando release acontece:

1. Tudo em `[Unreleased]` vira `[X.Y.Z] - DATE`
2. Novo `[Unreleased]` vazio eh criado no topo
3. Links no footer atualizados (ver proxima secao)

Em projetos sem CI de release (manual), `[Unreleased]` eh opcional —
commits entre releases podem ser parseados on-demand pelo script.

## Links de versao (footer)

Formato tradicional:

```markdown
[Unreleased]: https://github.com/owner/repo/compare/v1.2.0...HEAD
[1.2.0]: https://github.com/owner/repo/compare/v1.1.0...v1.2.0
[1.1.0]: https://github.com/owner/repo/compare/v1.0.0...v1.1.0
[1.0.0]: https://github.com/owner/repo/releases/tag/v1.0.0
```

release-please inlines links no header da versao em vez de footer:

```markdown
## [1.2.0](https://github.com/owner/repo/compare/v1.1.0...v1.2.0) (2026-04-19)
```

Ambos validos — inline eh mais compacto, footer eh mais legivel em plain text.

## Gotchas comuns

### Timestamps em releases

Formato **`YYYY-MM-DD`** sempre. Nao usar:
- `April 19, 2026` (locale-specific)
- `2026/04/19` (ambiguo com padrao ingles)
- `19-04-2026` (DD-MM-YYYY — nao-ISO)

Fuso horario: UTC sempre. Em projetos Brasil: nao escrever data "BRT".

### Tamanho de entrada

Entradas longas (>2 paragrafos) indicam que a commit message deveria ter
sido dividida. Se entrada precisa de >200 chars, releazia em commits
separados.

### Linguagem

**EN-US** sempre no CHANGELOG, mesmo em projetos com README em PT-BR.
Convencao de open source + prepara o projeto para contribuidores globais.

### Secao vazia

Nao criar secoes vazias. Se nao tem `Added` nesta release, nao deixar
```markdown
### Added

### Fixed
- ...
```
Pular direto para `### Fixed`.

### [Unreleased] em projeto CI-driven

Com release-please, nunca editar `[Unreleased]` manualmente — o tool
regera a secao a partir dos commits. Qualquer edicao manual sera
sobrescrita no proximo release PR.

### Misturar patch com minor/major

Uma release = um bump type. Se tem `feat` + `fix` desde ultima tag,
bump eh MINOR. `### Added` com 1 item + `### Fixed` com 5 itens eh OK —
ainda eh bump MINOR.

### Retroactive changelog

Em projeto sem changelog: escrever retroativamente a partir do git log
eh OK, mas marcar a primeira versao como "baseline" e nao tentar
reconstruir entradas precisas pra versoes antigas. Deixar:

```markdown
## [0.5.0] - 2025-12-01 — initial changelog baseline

Changes prior to 0.5.0 not tracked in this changelog. See git history
for details.
```

## Validacao

Boa validacao verifica:

- [ ] Primeira linha eh `# Changelog`
- [ ] Referencias a Keep a Changelog e SemVer no topo
- [ ] `[Unreleased]` presente (em projetos CI-driven)
- [ ] Cada versao tem formato `## [X.Y.Z] - YYYY-MM-DD`
- [ ] Data em ordem decrescente (mais recente primeiro)
- [ ] Secoes usam `###` (nivel 3)
- [ ] Sem secoes vazias
- [ ] Versoes no formato SemVer valido
- [ ] Secoes dentro de ordem conhecida (Added, Changed, Fixed, ...)

Tool de validacao: [changelog-parser](https://github.com/hypermodules/changelog-parser)
(Node.js) ou regex manual em script de CI.

## Referencias

- [keepachangelog.com/en/1.1.0](https://keepachangelog.com/en/1.1.0/)
- [keepachangelog.com/en/1.0.0](https://keepachangelog.com/en/1.0.0/) (versao anterior, ainda valida)
- [Conventional Commits](https://www.conventionalcommits.org/)
- [release-please changelog-sections](https://github.com/googleapis/release-please/blob/main/docs/customizing.md#changelog-types)
