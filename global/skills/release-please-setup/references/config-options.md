# Opcoes de Configuracao do release-please-config.json

Todas as opcoes disponiveis para `release-please-config.json`, exceto extra-files (que tem arquivo proprio).

Vide tambem: [`../SKILL.md`](../SKILL.md)

## release-type

Define o tipo de release do projeto. Afeta como o release-please detecta versao e gera changelog.

| release-type | Uso |
|---|---|
| `node` | projetos com `package.json` (default) |
| `python` | `pyproject.toml` ou `setup.py` |
| `rust` | `Cargo.toml` |
| `go` | sem version file, apenas tag |
| `php` | `composer.json` |
| `ruby` | `Gemfile` ou `.rb` com VERSION |
| `dotnet` | `.csproj` com `Version` property |
| `java` | `pom.xml` ou `build.gradle` |
| `terraform` | `.tf` files |

## package-name

Override do nome do pacote para prefixo de tag:

```json
"package-name": "my-awesome-lib"
```

Tag resultante: `my-awesome-lib-v1.2.3` em vez de `v1.2.3`.

## changelog-sections

Mapeia tipos de commit para secoes do CHANGELOG. Ordem do array = ordem no arquivo.

```json
"changelog-sections": [
  { "type": "feat",     "section": "### Added" },
  { "type": "fix",      "section": "### Fixed" },
  { "type": "perf",     "section": "### Performance" },
  { "type": "refactor", "section": "### Changed" },
  { "type": "docs",     "section": "### Documentation" },
  { "type": "chore",    "section": "### Chore", "hidden": true }
]
```

Types que aparecem: `feat`, `fix`, `perf`, `refactor`, `docs`, `style`, `test`, `build`, `ci`, `chore`.

A flag `hidden: true` faz a secao nao aparecer no CHANGELOG mas ainda detectar commits.

## bootstrap-sha

SHA inicial para calcular changelog. Útil quando ha commits antes da migracao.

```json
"bootstrap-sha": "a1b2c3d4e5f6"
```

## changelog-host

Host do repositorio para links no CHANGELOG. Default: `github.com`.

```json
"changelog-host": "https://github.enterprise.company.com"
```

Para GitLab, Gitea ou outros: ajustar URL base dos links.

## include-component-in-tag

boolean — quando `true`, inclui component no nome da tag.

Sem: `v1.2.3`
Com: `web-v1.2.3` (monorepo)

```json
"include-component-in-tag": true
```

## monorepo (multi-pacote)

Nao confundir com arquivo separado `references/monorepo.md`. Aqui esta a opcao inline.

```json
"packages": {
  "packages/web": { "release-type": "node", "component": "web" },
  "packages/api": { "release-type": "node", "component": "api" }
},
"include-component-in-tag": true
```

## extra-files (resumo)

Sintaxe completa no arquivo `references/extra-files.md`. Resumo rapido:

```json
"extra-files": [
  { "type": "json", "path": "manual/content.json", "jsonpath": "$.version" },
  { "type": "generic", "path": "index.html" }
]
```

## Outras opcoes

| Opcao | Tipo | Descricao |
|---|---|---|
| `versioning` | string | `default` ou `bump-only` |
| `draft` | boolean | cria release como draft |
| `prerelease` | boolean | marca release como prerelease |
| `initial-version` | string | versao inicial se nenhuma encontrada (default: `0.0.1`) |
| `bump-minor-pre-major` | boolean | faz minor bump antes de major breaking change |
| `bump-patch-for-minor-pre-major` | boolean | faz patch bump antes de minor que contenha major |
