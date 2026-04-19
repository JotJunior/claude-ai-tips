---
name: release-quality-gate
description: |
  Use quando o usuario quer validar qualidade de commits, testes e estado
  do projeto ANTES de criar um release. Tambem quando mencionar "pre
  release check", "release gate", "validar commits", "qualidade pre
  release", "release checklist", "release readiness". Executa bateria
  de validacoes: working tree limpa, commits desde ultima tag seguem
  conventional, feat/fix tem body >= 20 chars, tests passam, lint
  passa, tag proposta nao existe ainda, CHANGELOG tem entrada para
  versao alvo (opcional). NAO modifica estado do repo — apenas valida
  e reporta. Usado antes de `release-please`, `release-manual-setup`
  ou release totalmente manual.
argument-hint: "[--target-version=<v>] [--skip-tests] [--skip-lint] [--since=<ref>]"
allowed-tools:
  - Read
  - Bash
---

# Skill: Release Quality Gate

Validador **read-only** que roda bateria de checagens antes de
release. Nao modifica nada no repositorio — apenas reporta estado e
sai com exit code indicativo.

Util como:

- Ultima checagem antes de `npm run release` (manual)
- Sanity check antes de mergear release PR (release-please)
- CI step dedicado para validar prontidao de release
- Comando de habito diario em projetos com releases frequentes

## Checks executados

### 1. Working tree limpa

```bash
git status --porcelain
```

Falha se ha arquivos modificados, staged ou untracked. Razao: release
deve ser reprodutivel a partir de commits — arquivos nao-commitados
podem bagunçar versao ou deixar surprises depois do release.

### 2. Tag alvo nao existe ainda

Se `--target-version=<v>` passado:

```bash
git rev-parse "v$TARGET" >/dev/null 2>&1 && echo "tag ja existe"
```

Falha se a tag ja existe. Razao: re-release com mesma versao quebra
contrato SemVer.

### 3. Commits desde ultima tag sao conventional

Parse de cada commit via regex `^([a-z]+)(\([^)]+\))?(!)?: .+$`. Reporta:

- **Violacoes** (commits nao-conformes) — listar como WARN
- **Total de commits feat/fix/breaking** — conta
- **Bump detectado** (major/minor/patch) — informativo

Violacoes nao bloqueiam por default (projetos legacy podem ter
historico), mas com `--strict` bloqueiam.

### 4. Bodies de feat/fix/breaking >= MIN_BODY_LENGTH

Mesma logica do `clw-auth/release.mjs`:

```
checkQuality(commits) = commits.filter(c =>
  c.type && (BODY_REQUIRED_TYPES.has(c.type) || c.breaking) &&
  (!c.body || c.body.length < MIN_BODY_LENGTH)
)
```

Falha se algum commit feat/fix/breaking tem body faltando ou curto.
Output mostra cada commit problematico com:

- Hash curto
- Type + scope + bang
- Subject
- Motivo da falha
- Comandos para corrigir (`git commit --amend`, `git rebase -i`)

### 5. Tests passam

```bash
npm test  # ou comando customizado
```

Pula com `--skip-tests`. Falha bloqueia.

### 6. Lint passa (se configurado)

Detecta lint pelo `package.json`:

```bash
if jq -e '.scripts.lint' package.json >/dev/null; then
    npm run lint
fi
```

Pula com `--skip-lint`. Ausencia de script `lint` nao falha (nao existe
contrato).

### 7. Typecheck passa (se configurado)

```bash
if jq -e '.scripts.typecheck' package.json >/dev/null; then
    npm run typecheck
fi
```

Equivalente a lint. Detecta pelo script.

### 8. CHANGELOG tem entrada para versao alvo (opcional)

Se `--target-version=<v>` passado:

```bash
grep -qE "^## \[$TARGET\]" CHANGELOG.md || grep -qE "^## \[Unreleased\]" CHANGELOG.md
```

Procura:
- Entrada explicita `## [1.2.0]`
- OU `## [Unreleased]` (vai virar 1.2.0 no release)

Falha se nenhum dos dois. Bloqueia com `--strict`, WARN default.

### 9. Branch eh main/master

Release em branch feature eh incomum. Warn se branch atual nao eh
`main`/`master`. Nao bloqueia (hotfix branches sao legitimos).

### 10. Branch esta sincronizada com remote

```bash
git fetch origin
git status -sb | grep -q 'behind'
```

Warn se behind (local nao tem commits do remote — release pode perder
commits). Falha com `--strict`.

## Output

### Sucesso

```
Release Quality Gate — PASSED

[1/9] working tree clean              ok
[2/9] target tag v1.2.0 available     ok
[3/9] conventional commits format     23 commits, 0 violations
[4/9] commit body quality             3 feat, 5 fix, 0 breaking — all passed
[5/9] tests                           ok (npm test exited 0)
[6/9] lint                            ok
[7/9] typecheck                       ok
[8/9] CHANGELOG entry                 [Unreleased] found
[9/9] branch state                    on main, in sync with origin/main

Summary:
  Detected bump:  minor (0 breaking + 3 feat + 5 fix)
  Target version: 1.2.0 (from 1.1.0)
  Ready to release.
```

### Falha

```
Release Quality Gate — FAILED

[1/9] working tree clean              ok
[2/9] target tag v1.2.0 available     ok
[3/9] conventional commits format     23 commits, 2 violations (WARN)
[4/9] commit body quality             2 feat need body

  abc1234  feat: add login
           missing body (required for feat >= 20 chars)

  def5678  feat: add logout
           body 15 chars (required >= 20)

  Fix with:
    git commit --amend          # for the last commit
    git rebase -i HEAD~5        # for older commits

[5/9] tests                           FAILED (3 tests failing)
[6/9] lint                            3 errors
[7/9] typecheck                       ok
[8/9] CHANGELOG entry                 [Unreleased] found
[9/9] branch state                    on main, behind origin/main by 2

Summary:
  Quality gate failed. Fix issues above before releasing.
```

## Exit codes

| Code | Significado |
|------|-------------|
| `0` | Todos os checks passaram |
| `1` | Algum check bloqueante falhou |
| `2` | Warnings presentes (com `--strict`, trata como falha) |

## Flags

| Flag | Efeito |
|------|--------|
| `--target-version=<v>` | Valida que tag nao existe + CHANGELOG menciona |
| `--since=<ref>` | Analisa commits desde `<ref>` (default: ultima tag) |
| `--skip-tests` | Pula `npm test` |
| `--skip-lint` | Pula `npm run lint` |
| `--skip-typecheck` | Pula `npm run typecheck` |
| `--strict` | Violacoes WARN viram blocking |
| `--min-body=<N>` | Override MIN_BODY_LENGTH (default 20) |
| `--body-required=<types>` | Override BODY_REQUIRED_TYPES (default feat,fix) |

## Integracao

### Com release-manual-setup

`scripts/release.mjs` ja inclui quality gate embutido. Esta skill eh
complementar — pode rodar ANTES do release.mjs em modo diagnostico:

```bash
# Validar sem releasar
/release-quality-gate --target-version=1.2.0

# Se OK:
npm run release
```

### Com release-please

Release-please nao tem gate embutido. Adicionar como step em CI:

```yaml
jobs:
  gate:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
        with: { fetch-depth: 0 }
      - name: Release Quality Gate
        run: /path/to/skill/check.sh
  release-please:
    needs: gate
    # ...
```

### Com release totalmente manual

Quando release eh `git tag v1.2.3 && git push --tags`, rodar skill
antes como habito:

```bash
/release-quality-gate --target-version=1.2.3 --strict && \
  git tag -a v1.2.3 -m "Release v1.2.3" && \
  git push origin v1.2.3
```

## Implementacao

Esta skill eh primariamente orquestradora — logica executa via:

- `git status`, `git log`, `git rev-parse`, `git fetch` (builtin)
- `jq` para parse de package.json
- `npm run <script>` para tests/lint/typecheck
- Regex de parse identica ao release.mjs

SKILL.md descreve as 10 checagens, mas implementacao e inline em Bash
(sem script separado — logica eh essencialmente uma pipeline de
checagens sequenciais).

## Gotchas

### Nao confundir com commit-msg hook

`commit-msg` valida **antes** do commit entrar no repo. Esta skill
valida commits **ja no repo**, em batch, antes de release. Camadas
diferentes, ambas uteis.

### Tags legacy nao-SemVer

Se projeto tem tags `v1`, `1.0`, `release-2024`: `git describe` pode
retornar tag errada. Passar `--since=<hash>` manualmente em vez de
deixar detecao automatica.

### Monorepo com tags multiplas

Com `md2pdf-v2.2.0` + `api-v1.5.0` co-existindo, `git describe` pega
a mais recente globalmente, nao a do componente. Passar `--since`
explicitamente:

```bash
/release-quality-gate --since=md2pdf-v2.2.0 --target-version=2.3.0
```

### Submodule changes

`git status --porcelain` nao sinaliza bem alteracoes de submodule.
Se projeto tem submodules, adicionar check explicito:

```bash
git submodule status | grep -vE '^ '  # linhas com + ou - sao dirty
```

### npm test vs outro test runner

Se projeto usa `bun test`, `pnpm test`, `yarn test`, detectar pelo
lockfile e usar o comando certo. `--skip-tests` pula todos.

### Rede instavel durante --strict

`git fetch origin` pode falhar offline. `--strict` trataria como
bloqueio. Solucao: retry com backoff ou `--skip-remote-sync` (nao
implementado — adicionar se demandar).

### Lint com warnings

Se `lint --max-warnings 0` eh estrito e projeto tem warnings
legitimos, releases serao bloqueados sempre. Aceitar warnings nao-
bloqueantes via `--skip-lint` ou corrigir antes.

### Tests flaky

Test flakiness causa falso-negativo no gate. Solucao a longo prazo:
corrigir testes. A curto prazo: retry 1 vez automatica antes de
falhar (nao implementado — adicionar se demandar).

### CHANGELOG gerado pelo release-please

Com release-please, [Unreleased] nao existe no CHANGELOG entre
releases — o proximo release PR gera. Skill deve saber disso:

```bash
if [ -f release-please-config.json ]; then
    # release-please controla CHANGELOG — pular check 8
fi
```

## Ver tambem

- [`release-manual-setup`](../release-manual-setup/) — quality gate embutido
- [`release-please-setup`](../release-please-setup/) — sem gate embutido
- [`changelog-write-entry`](../changelog-write-entry/) — escreve entrada Unreleased
- [`git-hooks-install`](../git-hooks-install/) — gate em commit time (complementar)
- [`git-methodology/references/commit-body-quality.md`](../git-methodology/references/commit-body-quality.md)
