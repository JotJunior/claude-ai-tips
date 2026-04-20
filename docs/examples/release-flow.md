# Exemplo: Fluxo de Release Completo

Cenário comparando release via **release-please** e via **release-manual** no
mesmo projeto hipotético, mostrando a experiência end-to-end de cada um.

## Contexto

Projeto `api-core` em Node.js + TypeScript, hospedado no GitHub, com CI
Actions ativo. Trabalhado em equipe de 3 pessoas. Versão atual: `1.2.3`.

Vamos fazer o release `1.3.0` com:

- Nova feature: suporte a OAuth PKCE
- Correção: null check em handler
- Refactor: extract de helper

## Opção A — via release-please

### Setup inicial (uma vez)

```
configurar release-please neste projeto
```

A skill cria:

```
api-core/
├── release-please-config.json
├── .release-please-manifest.json
└── .github/workflows/release-please.yml
```

Conteúdo do manifest (com versão atual):

```json
{
  ".": "1.2.3"
}
```

Commit e push:

```bash
git add release-please-config.json .release-please-manifest.json .github/workflows/release-please.yml
git commit -m "chore: configure release-please automation"
git push origin main
```

### Desenvolvimento do ciclo

#### Commit 1 — feature

Dev abre branch:

```bash
git checkout -b feat/oauth-pkce
```

Implementa PKCE, commita:

```bash
git commit -m "feat(auth): add OAuth 2.1 PKCE flow

Replaces deprecated implicit flow. PKCE eliminates the need for client
secrets in public clients (browser/mobile) and is required by Anthropic's
OAuth 2.1 specification. Supports S256 challenge method only."
```

PR aberto e mergeado em `main`:

```bash
gh pr create --title "feat(auth): add OAuth PKCE flow" --body "..."
gh pr merge --squash   # ou --merge
```

#### Commit 2 — fix

Outra branch:

```bash
git checkout -b fix/null-handler
```

```bash
git commit -m "fix(handler): guard against null authorization header

Authorization header was optional but handler assumed presence. Returns
401 with \"MISSING_AUTH\" code when header is absent instead of crashing."
```

PR e merge.

#### Commit 3 — refactor

```bash
git checkout -b refactor/extract-helper
```

```bash
git commit -m "refactor(utils): extract parseAuthHeader helper

Consolidates parsing logic previously duplicated in 4 handlers. No
behavior change — pure refactor with passing tests maintained."
```

PR e merge.

### O que acontece automaticamente

Após o primeiro push a `main` com commit conventional, o workflow
`release-please` roda e **abre um PR**:

```
Title:  chore(main): release 1.3.0
Author: github-actions[bot]
Branch: release-please--branches--main--components--api-core
```

Conteúdo do PR:

- `.release-please-manifest.json`: `1.2.3` → `1.3.0`
- `package.json`: versão atualizada
- `CHANGELOG.md`: nova seção adicionada

Preview do CHANGELOG:

```markdown
# Changelog

## [1.3.0](https://github.com/owner/api-core/compare/v1.2.3...v1.3.0) (2026-04-19)

### Added

* **auth:** add OAuth 2.1 PKCE flow ([abc1234](https://github.com/owner/api-core/commit/abc1234))

### Fixed

* **handler:** guard against null authorization header ([def5678](https://github.com/owner/api-core/commit/def5678))

### Changed

* **utils:** extract parseAuthHeader helper ([ghi9012](https://github.com/owner/api-core/commit/ghi9012))
```

O PR fica aberto até ser mergeado. A cada novo push em `main` com commits
qualificados, o PR é **atualizado** (versão pode mudar se tiver feat/breaking
novo, CHANGELOG cresce).

### Auto-merge (se configurado)

Com auto-merge ativo no workflow:

```yaml
auto-merge:
  needs: release-please
  steps:
    - run: |
        PR=$(gh pr list --label "autorelease: pending" --state open \
          --json number --jq '.[0].number // empty')
        [ -n "$PR" ] && gh pr merge "$PR" --merge --auto
```

PR é **auto-mergeado** quando CI passa. Não precisa intervenção humana.

### O merge dispara

Quando release PR é mergeado:

1. **Commit de release** é criado em `main`: `chore(main): release 1.3.0`
2. **Tag anotada** `v1.3.0` é criada
3. **GitHub Release** é publicada com as notas do CHANGELOG

Evidência:

```bash
git pull origin main
git log --oneline | head -5
# xyz7890 chore(main): release 1.3.0
# ghi9012 refactor(utils): extract parseAuthHeader helper
# def5678 fix(handler): guard against null authorization header
# abc1234 feat(auth): add OAuth 2.1 PKCE flow
# 1.2.3 release commit

git tag | tail -3
# v1.2.2
# v1.2.3
# v1.3.0

gh release view v1.3.0
# https://github.com/owner/api-core/releases/tag/v1.3.0
```

### Ciclo contínuo

Para próxima release (1.4.0), mesmo fluxo:

- Devs commitam em branches, merge em `main`
- release-please atualiza PR pendente
- Auto-merge quando mantenedor decide (ou automático)
- Tag + release

Zero trabalho manual após setup inicial.

## Opção B — via release-manual

### Setup inicial (uma vez)

```
configure release manual com body minimo 20 chars
```

A skill cria:

```
api-core/
├── scripts/release.mjs
└── test/release.test.mjs
```

Adiciona em `package.json`:

```json
"scripts": {
  "release": "node scripts/release.mjs"
}
```

Commit e push:

```bash
git add scripts/release.mjs test/release.test.mjs package.json
git commit -m "chore: add manual release automation script"
git push
```

### Desenvolvimento do ciclo

Os 3 commits são **idênticos** ao fluxo A. A diferença está em como o
release é criado.

Commits:

```bash
git log --oneline origin/main..HEAD
# ghi9012 refactor(utils): extract parseAuthHeader helper
# def5678 fix(handler): guard against null authorization header
# abc1234 feat(auth): add OAuth 2.1 PKCE flow
```

### Validar qualidade antes (opcional mas recomendado)

```
valide prontidão para release v1.3.0
```

A skill `release-quality-gate` executa:

```
Release Quality Gate — PASSED

[1/10] working tree clean                ok
[2/10] target tag v1.3.0 available       ok
[3/10] conventional commits format       3 commits, 0 violations
[4/10] commit body quality               1 feat, 1 fix, 0 breaking — all passed
[5/10] tests                             ok
[6/10] lint                              ok
[7/10] typecheck                         ok
[8/10] CHANGELOG entry                   [Unreleased] found
[9/10] branch                            on main
[10/10] sync with remote                 up to date

Summary:
  Detected bump:  minor (0 breaking + 1 feat + 1 fix)
  Target version: 1.3.0 (from 1.2.3)
  Ready to release.
```

### Executar release

Dry-run primeiro:

```bash
DRY_RUN=1 npm run release
```

Saída:

```
Release v1.3.0 (minor from 1.2.3):

## [1.3.0] - 2026-04-19

### Added

- **add OAuth 2.1 PKCE flow** — Replaces deprecated implicit flow. PKCE eliminates the need for client secrets in public clients (browser/mobile) and is required by Anthropic's OAuth 2.1 specification. Supports S256 challenge method only.

### Fixed

- **guard against null authorization header** — Authorization header was optional but handler assumed presence. Returns 401 with "MISSING_AUTH" code when header is absent instead of crashing.

### Changed

- **extract parseAuthHeader helper** — Consolidates parsing logic previously duplicated in 4 handlers. No behavior change — pure refactor with passing tests maintained.

Summary:
  bump:        minor
  current:     1.2.3
  next:        1.3.0
  commits:     3
  tag:         v1.3.0

(dry-run — no files modified, no commit, no tag)
```

Executar de verdade:

```bash
npm run release
```

Saída:

```
Running tests...
ℹ pass 42
ℹ fail 0
...

Release v1.3.0 (minor from 1.2.3):
... (mesmo conteúdo do dry-run) ...

Created commit + tag v1.3.0

To publish:
  git push origin main
  git push origin v1.3.0
```

### Publicar

```bash
git push origin main
git push origin v1.3.0
```

Ou atalho:

```bash
git push origin main --tags
```

### GitHub Release (manual)

```bash
gh release create v1.3.0 \
  --title "v1.3.0 — OAuth PKCE + null header fix" \
  --notes-file <(sed -n '/^## \[1.3.0\]/,/^## \[/p' CHANGELOG.md | sed '$d')
```

## Comparação lado a lado

| Aspecto | release-please | release-manual |
|---------|----------------|----------------|
| Setup | 3 arquivos + commit | 3 arquivos + commit |
| Commits do ciclo | idênticos | idênticos |
| Quem bumpa versão | CI (auto) | Dev (manual) |
| Quem escreve CHANGELOG | CI (auto) | Script (auto) |
| Quem cria tag | CI (no merge do PR) | Script (local) |
| GitHub Release | auto | manual (`gh release create`) |
| Links no CHANGELOG | URLs compare + commit | sem URLs |
| Quality gate | extra (`release-quality-gate`) | embutido no script |
| Tempo manual por release | 0 (com auto-merge) | ~2 min |
| Rollback se errar | reverter commit + delete tag | reverter commit + delete tag |
| Funciona offline | não (precisa Actions) | sim |
| Funciona em monorepo | nativo | adaptar |
| Pre-1.0 bump mode | SemVer estrito | flex (default: major-as-minor) |

## Cenários que mostram diferença

### Cenário 1 — Você quer release HOJE mas CI está com problema

**release-please**: bloqueado — Actions down, não abre/merge PR.

**release-manual**: funciona local, cria tag, push quando CI voltar.

### Cenário 2 — Você commit errou (falta body em feat)

**release-please**: release PR é criado mesmo sem body; entrada fica vazia
`* **auth:** add OAuth flow (xxxxxx)` sem contexto.

**release-manual**: Quality gate **aborta** com mensagem detalhada:

```
Quality check failed — these commits need a body before releasing:

  abc1234  feat(auth): add OAuth flow
           ↑ feat commits require a body description (>= 20 chars)

How to fix:
  git commit --amend
  git rebase -i <hash>^
```

Você amenda, retenta. Release-please não tem esse gate por default
(precisa adicionar `release-quality-gate` no workflow).

### Cenário 3 — Monorepo com 3 packages

**release-please**: nativo. Config:

```json
{
  "packages": {
    "packages/web": { "release-type": "node", "component": "web" },
    "packages/api": { "release-type": "node", "component": "api" },
    "packages/shared": { "release-type": "node", "component": "shared" }
  },
  "include-component-in-tag": true
}
```

Tags resultantes: `web-v1.2.3`, `api-v2.0.0`, `shared-v0.5.1`. Cada um
com CHANGELOG próprio.

**release-manual**: precisa adaptar o script para detectar package
alterado pelo path dos commits, filtrar por prefix, escrever CHANGELOG em
`packages/<name>/CHANGELOG.md`. Implementação não-trivial.

### Cenário 4 — Team de 5 pessoas com PR workflow

**release-please**: perfeito. Cada dev merge PR normalmente, release-please
acumula commits em PR pendente, auto-merge quando acumula suficiente.

**release-manual**: um dev roda `npm run release` por vez. Se dois rodam
simultaneamente, há conflito (tag duplicada, CHANGELOG divergente).
Precisa coordenação humana.

### Cenário 5 — Projeto pessoal em fase de prototipagem

**release-please**: overhead de setup (3 arquivos, workflow, permissões).
Release a cada push pode ser excessivo.

**release-manual**: simples. Roda quando você quiser. Pre-1.0 mode evita
0.x virar 1.0.0 acidentalmente.

## Qual escolher?

Árvore de decisão:

```
Tem GitHub Actions ativo + team ≥ 2?
├─ SIM → release-please
└─ NÃO →
    Projeto pessoal ou solo?
    ├─ SIM → release-manual
    └─ NÃO →
        Quer links automáticos no CHANGELOG?
        ├─ SIM → release-please
        └─ NÃO → release-manual (controle fino)
```

## Híbrido — possível mas raro

Rodar os dois no mesmo projeto:

- release-please como padrão oficial (CHANGELOG + tag)
- `release-manual.mjs` reservado para **releases emergenciais locais**
  (quando CI down, hotfix fora de horário)

Trade-off: overhead duplo de manutenção. Preferir escolher um.

## Migração entre padrões

### De release-manual → release-please

```
migre este projeto para release-please
```

A skill `release-please-setup` cria os 3 arquivos. Opções:

- **Manter** `scripts/release.mjs` (fallback)
- **Remover** (recomendado dali pra frente)

`.release-please-manifest.json` deve refletir versão atual:

```json
{ ".": "1.3.0" }
```

CHANGELOG existente é preservado — release-please só adiciona novas
entradas no topo.

### De release-please → release-manual

```
migre este projeto para release manual
```

A skill `release-manual-setup` cria `scripts/release.mjs`. Remove workflow
release-please:

```bash
rm .github/workflows/release-please.yml
rm release-please-config.json
rm .release-please-manifest.json
```

Commit:

```bash
git add -A
git commit -m "chore: migrate from release-please to manual release.mjs"
```

Versão atual continua no `package.json`; script detecta daí.

## Troubleshooting

### release-please não abre PR

Possíveis causas:

- Nenhum commit conventional desde última tag (só `chore:`, `ci:`, etc.)
- Commits de merge (release-please ignora)
- Workflow falhou — verificar Actions tab

Forçar execução:

```bash
gh workflow run release-please.yml
```

### release.mjs aborta "working tree not clean"

```bash
git status
# commitar, stashar ou descartar mudanças
```

### "tag v1.3.0 already exists"

Alguma release anterior já criou. Opções:

1. Deletar tag (se release não foi publicada):

```bash
git tag -d v1.3.0
git push origin :refs/tags/v1.3.0
```

2. Ir para próxima (bump patch):

```bash
BUMP=patch npm run release   # vira 1.3.1
```

### Release-please ignora commits antigos não-conventional

Por design. Soluções:

- Adicionar baseline entry no CHANGELOG (ver [releases.md](../guides/releases/README.md))
- Reescrever commits antigos via `git rebase -i` (cuidado — reescreve histórico)

## Ver também

- [releases.md](../guides/releases/README.md) — detalhes completos dos padrões
- [git-methodology/](../../global/skills/git-methodology/) — hub + references
- [release-please-setup/SKILL.md](../../global/skills/release-please-setup/SKILL.md)
- [release-manual-setup/SKILL.md](../../global/skills/release-manual-setup/SKILL.md)
- [release-quality-gate/SKILL.md](../../global/skills/release-quality-gate/SKILL.md)
- [new-project-bootstrap.md](./new-project-bootstrap.md) — do zero à primeira release
