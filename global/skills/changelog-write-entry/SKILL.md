---
name: changelog-write-entry
description: |
  Use quando o usuario precisa adicionar uma entrada ao CHANGELOG.md
  manualmente (fora de tool automatizado como release-please ou
  release.mjs). Tambem quando mencionar "adicionar entrada changelog",
  "escrever changelog", "atualizar changelog", "changelog manual",
  "update changelog entry". Cria entrada no formato Keep a Changelog
  1.1.0 com secoes padrao (Added/Fixed/Changed/Breaking/Deprecated/
  Removed/Security) e valida estrutura do CHANGELOG.md antes de
  escrever. NAO use quando ha release-please ativo (o tool sobrescreve
  edicoes manuais) — verifica existencia de release-please-config.json
  e avisa.
argument-hint: "[<version>] [--unreleased] [--type=added|fixed|changed|...]"
allowed-tools:
  - Read
  - Write
  - Edit
  - Bash
  - AskUserQuestion
---

# Skill: Changelog Write Entry

Escreve nova entrada no `CHANGELOG.md` seguindo [Keep a Changelog 1.1.0](https://keepachangelog.com/en/1.1.0/).

## Quando usar

- Usuario menciona "adicionar entrada changelog", "escrever changelog",
  "atualizar changelog", "changelog manual", "update changelog entry"
- Criar entrada em `[Unreleased]` (work-in-progress) ou em versao
  especifica `X.Y.Z - YYYY-MM-DD`
- secoes: Added, Fixed, Changed, Breaking Changes, Deprecated, Removed,
  Security, Performance, Tests, Documentation

## Quando NAO usar

Se o projeto tem `release-please-config.json` ou `scripts/release.mjs`,
o CHANGELOG eh **automatizado**. Edicoes manuais em `[Unreleased]` serao
sobrescritas no proximo release PR.

Avisar o usuario:

```
AVISO: release-please detectado. O CHANGELOG eh gerado automaticamente.
Edicoes manuais serao sobrescritas. Prefira:

- Commits com conventional commits (body rico)
- release-please popula o changelog no proximo release

Continuar mesmo assim? [y/N]
```

## Pre-requisitos

- `CHANGELOG.md` existente (skill pode criar se pedido)
- Formato Keep a Changelog 1.1.0 (ou 1.0.0)
- Se release automatizado: confirmacao explicita do usuario

## Como escrever uma entrada

### Passo 1: detectar contexto

```bash
test -f CHANGELOG.md && HAS_CHANGELOG=1 || HAS_CHANGELOG=0
test -f release-please-config.json && HAS_RP=1 || HAS_RP=0
```

Emitir aviso se `HAS_RP=1` (ver secao acima).

### Passo 2: validar estrutura existente

Verificar:
- Primeira linha: `# Changelog`
- Referencia KaC + SemVer no header
- `## [Unreleased]` presente (recomendado)
- Versoes: `## [X.Y.Z] - YYYY-MM-DD` em ordem decrescente

Violacoes emitidas como AVISO (nao bloqueia).

### Passo 3: perguntar destino

Via `AskUserQuestion`:

1. `[Unreleased]` (default) ou versao especifica `X.Y.Z`
2. Secao: Added, Fixed, Changed, Breaking Changes, Deprecated,
   Removed, Security, Performance, Tests, Documentation
3. Titulo (curto, imperativo presente, ex: "Add OAuth PKCE flow")
4. Descricao (what + why + impact, pode ser omitido se titulo
   ja eh auto-explicativo)

### Passo 4: formatar entrada

```markdown
- **<title>** \u2014 <description in single paragraph>
```

ou sem body:

```markdown
- **<title>**
```

### Passo 5: inserir no lugar certo

**Unreleased:** append apos `## [Unreleased]\n\n### <section>`. Se
secao nao existe, criar seguindo ordem canonica (Added > Changed >
Deprecated > Removed > Fixed > Security).

**Versao especifica:**
- Versao ja existe + secao existe: append
- Versao existe + secao nao existe: criar secao no lugar certo
- Versao nao existe: criar linha de versao + secao

### Passo 6: gravar com backup atomic

```bash
cp CHANGELOG.md CHANGELOG.md.bak
# aplicar edicao
# validar resultado
# se falhar: restore backup e abortar
```

### Passo 7: relatorio

```
entrada adicionada no CHANGELOG.md:

destino:    [Unreleased] -> ### Added
titulo:     Add OAuth PKCE flow
resumo:     ...

proximo passo (release manual):
  npm run release
```

## Smoke test

Posicionar entrada no lugar certo (logo apos `[Unreleased]` ou antes
da versao seguinte). Secao existe? Nova entrada concatenada no mesmo
paragrafo? Data `YYYY-MM-DD` (ISO 8601)? Titulo em imperativo presente?

## Gotchas críticos

1. **Data: `YYYY-MM-DD` sempre** — nao usar `April 19, 2026`,
   `2026/04/19`, nem `19-04-2026`. Para hoje (UTC):
   `new Date().toISOString().slice(0, 10)`

2. **Ordem cronologica decrescente** — versoes mais recentes ficam
   no topo, logo apos `[Unreleased]`. Inserir `[1.2.0]` entre
   `[Unreleased]` e `[1.1.0]` — nao no final do arquivo.

3. **Nao duplicar secao** — se `### Added` ja existe em `[Unreleased]`,
   apenas append o novo item. Nao criar segundo `### Added`.

## Referencias

- [Secoes e formatos Keep a Changelog](./references/sections-and-formats.md)
