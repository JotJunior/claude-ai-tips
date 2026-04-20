# Padrão B: release-manual (script caseiro)

Fluxo manual via script `release.mjs`. Ideal para projetos solo, times
pequenos, ou quando se deseja controle fino sobre o formato do CHANGELOG.

> **Índice geral**: [README.md](./README.md)

## Pré-requisitos

- `package.json` com `.version` válido (inicie com `0.1.0` se novo)
- Commits Conventional (use `git-hooks-install`)
- `CHANGELOG.md` existente ou será criado
- Opcional: suite de testes (`npm test`)

## Setup

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

## Uso

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

## Fluxo executado pelo script

```
1. Verifica working tree limpa (git status --porcelain vazio)
2. Lê commits desde última tag (git log --no-merges)
3. Parseia cada commit (regex Conventional)
4. Quality gate:
   - Commits feat/fix/breaking precisam body >= 20 chars
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

## Saída do CHANGELOG

```markdown
## [1.2.0] - 2026-04-19

### Added

- **Add OAuth PKCE flow** — Replaces deprecated implicit flow. PKCE eliminates the need for client secrets in public clients and is required by Anthropic's OAuth 2.1 specification.

### Fixed

- **Handle null token gracefully** — Empty OAuth state led to 500 when user cleared cookies. Guards against null in authorization middleware.
```

## Pre-1.0 mode

Projetos em `0.x` têm 2 convenções. O script suporta ambas via
`PRE_1_0_MAJOR_AS_MINOR` no topo:

### `true` (default, padrão clw-auth)

Reserva `1.0.0` como marco de estabilidade. Em 0.x, mesmo `feat!:`
(breaking) vira bump MINOR:

```
0.9.5 + breaking change -> 0.10.0 (MINOR em 0.x = MAJOR em 1.x+)
0.9.5 + feat            -> 0.10.0
0.9.5 + fix             -> 0.9.6
```

### `false` (SemVer estrito)

Breaking change em 0.x pula para 1.0.0:

```
0.9.5 + breaking change -> 1.0.0
0.9.5 + feat            -> 0.10.0
0.9.5 + fix             -> 0.9.6
```

Edite `scripts/release.mjs` para alternar:

```javascript
const PRE_1_0_MAJOR_AS_MINOR = true;   // ou false
```

## Quality gate embutido

Antes de criar release, valida:

### 1. Commits conventional

Regex `^([a-z]+)(\([^)]+\))?(!)?: .+$`. Commits não-conformes são WARN
(não bloqueiam — projetos legacy têm histórico).

### 2. Body em feat/fix/breaking

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

### 3. Tests passam

`npm test` deve retornar 0. Pode pular com `NO_TESTS=1`.

### 4. Working tree limpa

`git status --porcelain` vazio. Commits pendentes bloqueiam.

## Entrada manual adicional

Use `changelog-write-entry` se precisa adicionar entrada antes/depois do
release automatizado (ex: nota de compatibilidade não-óbvia):

```
adicionar entrada de documentação no CHANGELOG sobre compatibilidade com Node 18
```

A skill alerta se detectar `scripts/release.mjs` — entradas manuais podem
duplicar no próximo release.

## Integração com quality-gate

Para adicionar camada extra de validação antes do release manual:

```bash
release-quality-gate --target-version=1.2.0 --strict && npm run release
```

Ou via skill:

```
valide prontidão para release v1.2.0
```

Ver [quality-gate.md](./quality-gate.md) para detalhes dos 10 checks.

## Ver também

- [README.md](./README.md) — índice e visão geral
- [quality-gate.md](./quality-gate.md) — 10 checks read-only
