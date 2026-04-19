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

Escreve uma nova entrada no `CHANGELOG.md` seguindo formato [Keep a
Changelog 1.1.0](https://keepachangelog.com/en/1.1.0/). Suporta:

- Entrada em `[Unreleased]` (padrao para trabalho em progresso)
- Entrada em versao especifica (ex: `[1.2.0] - 2026-04-19`)
- Secoes padrao: Added, Fixed, Changed, Breaking Changes, Deprecated,
  Removed, Security, Performance, Tests, Documentation
- Validacao da estrutura existente antes de gravar

## Quando NAO usar

Se o projeto tem `release-please-config.json` ou `scripts/release.mjs`,
a gerencia do CHANGELOG eh **automatizada**. Edicoes manuais em
`[Unreleased]` serao:

- **release-please**: sobrescritas no proximo release PR
- **release.mjs**: concatenadas (pode causar duplicatas)

Avisar o usuario antes de proceder:

```
AVISO: release-please detectado (release-please-config.json presente).
O CHANGELOG eh gerenciado automaticamente. Editar [Unreleased] aqui
sera sobrescrito no proximo release PR. Prefira:

- Escrever commits com body rico (conventional commits)
- release-please vai popular o changelog no proximo release

Continuar mesmo assim? [y/N]
```

## Pre-requisitos

- `CHANGELOG.md` existente no projeto (ou skill pode criar se pedido)
- Formato Keep a Changelog 1.1.0 (ou 1.0.0)
- Se release automatizado: confirmacao explicita do usuario

## Fluxo

### Etapa 1: detectar contexto

```bash
test -f CHANGELOG.md && HAS_CHANGELOG=1 || HAS_CHANGELOG=0
test -f release-please-config.json && HAS_RP=1 || HAS_RP=0
test -f scripts/release.mjs && HAS_MANUAL=1 || HAS_MANUAL=0
```

Se `HAS_RP=1` ou `HAS_MANUAL=1`, emitir aviso (ver secao acima).

### Etapa 2: validar estrutura (se existe)

Se `HAS_CHANGELOG=1`, verificar:

- Primeira linha eh `# Changelog`
- Referencias KaC + SemVer no header
- Presence de `## [Unreleased]` (recomendado mas nao obrigatorio)
- Versoes em formato SemVer: `## [X.Y.Z] - YYYY-MM-DD`
- Ordem decrescente (mais recente no topo, logo apos Unreleased)

Listar violacoes como AVISO (nao bloqueia).

### Etapa 3: criar CHANGELOG se nao existe

Se `HAS_CHANGELOG=0` e usuario confirma criar:

```markdown
# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]
```

### Etapa 4: perguntar destino

Via `AskUserQuestion`:

1. **Unreleased** (recomendado para work-in-progress) OU **versao
   especifica**?
2. Se versao especifica:
   - Numero: `X.Y.Z`
   - Data: hoje (default) ou especifica `YYYY-MM-DD`
3. **Secao**:
   - Added (nova funcionalidade)
   - Fixed (correcao de bug)
   - Changed (mudanca sem quebrar)
   - Breaking Changes (mudanca incompativel)
   - Deprecated (marcado para remocao futura)
   - Removed (removido nesta release)
   - Security (vuln corrigida)
   - Performance (otimizacao)
4. **Titulo** (curto, descritivo)
5. **Descricao** (rich, explicando what + why + impact)

### Etapa 5: formatar entrada

Seguir padrao com concatenacao de paragrafos:

```markdown
- **<title>** \u2014 <description in single paragraph>
```

Ou sem body (quando titulo eh auto-explicativo):

```markdown
- **<title>**
```

### Etapa 6: inserir no lugar certo

**Unreleased:** inserir apos `## [Unreleased]\n\n### <section>\n`. Se
secao nao existe, criar antes da proxima existente (seguindo ordem
Added/Changed/Deprecated/Removed/Fixed/Security).

**Versao especifica:**
- Se versao ja existe e tem secao: append
- Se versao existe mas sem secao: inserir secao no lugar certo
- Se versao nao existe: criar linha de versao + secao

### Etapa 7: gravar

Com backup atomic:

```bash
cp CHANGELOG.md CHANGELOG.md.bak
# aplicar edicao
# validar resultado
# se falhar validacao: restore backup e abortar
```

### Etapa 8: relatorio

```
entrada adicionada no CHANGELOG.md:

destino:    [Unreleased] -> ### Added
titulo:     Add OAuth PKCE flow
resumo:     ...

proximo passo (release manual):
  npm run release             # release.mjs detecta [Unreleased]
```

## Ordem canonica de secoes (Keep a Changelog 1.1.0)

1. **Added** — nova funcionalidade
2. **Changed** — mudanca em existente (sem quebrar)
3. **Deprecated** — marcado para remocao
4. **Removed** — removido nesta release
5. **Fixed** — correcao
6. **Security** — vuln

Secoes extra observadas em projetos (usar quando projeto ja usa):

- **Breaking Changes** — antes de Added (destaque)
- **Performance** — entre Changed e Deprecated
- **Tests** — apos Fixed
- **Documentation** — apos Tests
- **Style** — apos Documentation

Template reconhece essas extras se ja presentes no CHANGELOG; caso
contrario usa apenas as 6 canonicas.

## Estrutura de uma entrada

Formato curto (sem body):

```markdown
- **Add OAuth PKCE flow**
```

Formato completo (com body concatenado):

```markdown
- **Add OAuth PKCE flow** \u2014 Replaces deprecated implicit flow. PKCE
  eliminates the need for client secrets in public clients and is
  required by Anthropic's OAuth 2.1 specification.
```

Formato alternativo (release-please style, com hash):

```markdown
* **auth:** add OAuth PKCE flow ([abc1234](https://github.com/owner/repo/commit/abc1234))
```

Skill usa formato **concatenado** por padrao (Keep a Changelog canonico).
Formato release-please eh gerado automaticamente pelo tool, nao por esta
skill.

## Convencoes de titulo

- **Imperativo presente**: "Add", "Fix", "Remove" (nao "Adds", "Fixed")
- **Primeira letra maiuscula**: "Add OAuth" (nao "add OAuth")
- **Sem ponto final**: "Add OAuth" (nao "Add OAuth.")
- **EN-US**: "Add OAuth flow" (nao "Adicionar fluxo OAuth")
- **Especifico**: "Fix null deref in auth handler" > "Fix bug"
- **Scope quando util**: "Fix cron authentication drift" > "Fix drift"

## Gotchas

### Formato da data

**`YYYY-MM-DD` sempre**. Nao usar:
- `April 19, 2026` (locale-specific)
- `2026/04/19` (ambiguo)
- `19-04-2026` (DD-MM-YYYY nao-ISO)

Hoje (UTC):

```javascript
new Date().toISOString().slice(0, 10)
```

### Ordem cronologica

Versoes em ordem **decrescente** (mais recente primeiro, logo apos
Unreleased). Inserir `[1.2.0]` entre `[Unreleased]` e `[1.1.0]` — nao
no final.

### Secao ja existe vs nao existe

Se `### Added` ja existe em `[Unreleased]`, apenas append novo item.
Nao criar segundo `### Added`.

### [Unreleased] vazio

Apos um release, `[Unreleased]` fica vazio:

```markdown
## [Unreleased]

## [1.2.0] - 2026-04-19
```

Manter a linha `## [Unreleased]` (contrato). Nao remover.

### Caractere especial em descricoes

Se descricao tem `<tag>`, `*asterisk*`, `_underscore_`: escapar
adequadamente ou usar backticks:

```markdown
- **Handle <script> injection** \u2014 uses `dompurify` to sanitize...
```

Se precisa escapar markdown literal, usar `\` antes do caractere:
`\*literal\*`.

### Links em descricoes

OK incluir links para issues, PRs ou docs externas:

```markdown
- **Fix auth drift** \u2014 see [#42](https://github.com/owner/repo/issues/42)
  for reproducer.
```

Manter dentro do mesmo paragrafo concatenado.

### Categoria duvidosa

Quando uma mudanca nao cabe claramente em nenhuma secao:

- Adicao de teste -> Tests (se projeto usa) ou Changed
- Mudanca de deps internas -> Changed
- Refactor puro -> Changed (se interface externa mudou) ou omit (se
  so interno)
- Doc update -> Documentation (se usa) ou omit
- Build/CI changes -> omit (nao relevante para usuario)

Regra: se usuario externo percebe, eh changelog. Se so dev, omit.

### Retrofit de entradas historicas

Escrever retroativo eh OK, mas marcar claramente:

```markdown
## [0.5.0] - 2025-12-01 — initial changelog baseline

Changes prior to 0.5.0 not tracked in this changelog. See git history
for details.
```

Nao tentar reconstruir versoes anteriores em detalhe.

### Commit linkagem

Quando escrever manualmente, decidir se incluir hash do commit:

- **Sem hash** (mais limpo): `- **Fix auth drift** \u2014 context`
- **Com hash** (mais rastreavel): `- **Fix auth drift** \u2014 context ([abc1234](https://github.com/owner/repo/commit/abc1234))`

Consistencia no arquivo — se primeiras entradas tem hash, novas tambem devem ter.

## Ver tambem

- [`git-methodology/references/keep-a-changelog.md`](../git-methodology/references/keep-a-changelog.md)
- [`release-please-setup`](../release-please-setup/) — automacao (evita esta skill)
- [`release-manual-setup`](../release-manual-setup/) — script gera entradas automaticamente
- [Keep a Changelog](https://keepachangelog.com/en/1.1.0/)
