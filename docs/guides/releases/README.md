# Releases e Metodologia Git

Guia prático do namespace `git-methodology/` — escolha entre padrões de
release, configuração de hooks, geração de CHANGELOG, gates de qualidade.

## Índice

| Arquivo | Conteúdo |
|---------|----------|
| [release-please.md](./release-please.md) | Fluxo automatizado via release-please (GitHub Actions) |
| [release-manual.md](./release-manual.md) | Fluxo manual via script `release.mjs` |
| [quality-gate.md](./quality-gate.md) | 10 checks read-only antes de release |
| [git-hooks.md](./git-hooks.md) | Hooks commit-msg + pre-commit |

## Visão geral

O toolkit suporta **dois padrões** de release, ambos observados em projetos
de referência do autor:

| Padrão | Projeto de referência | Skill de setup |
|--------|-----------------------|----------------|
| **release-please** (automatizado) | [md2pdf](https://github.com/4i3n6/md2pdf) | `release-please-setup` |
| **Script caseiro** (manual) | [clw-auth](https://github.com/4i3n6/clw-auth) | `release-manual-setup` |

Skills complementares agnósticas ao padrão:

- `changelog-write-entry` — entrada manual no CHANGELOG (com aviso se automação detectada)
- `git-hooks-install` — commit-msg + pre-commit customizados
- `release-quality-gate` — 10 checks read-only antes de release

## Quando usar qual padrão

### Escolha release-please se:

- Projeto hospedado no **GitHub** com Actions ativo
- **Team >= 2 pessoas** com PR workflow obrigatório
- **Monorepo** com pacotes versionados independentemente
- Aceita dependência de vendor (GitHub Actions + release-please)
- Quer links automáticos no CHANGELOG (compare URLs, commit URLs)
- Quer **zero trabalho manual** por release

### Escolha release-manual se:

- Projeto **solo** ou time pequeno
- Sem CI ou com CI mínimo
- Quer **controle fino** do formato do CHANGELOG e das regras
- **Pre-1.0** em iteração rápida
- Evitar vendor lock (Node.js built-in apenas)
- Release **local** via comando CLI

### Matriz rápida

| Aspecto | release-please | release-manual |
|---------|----------------|----------------|
| Automação | 100% (CI-driven) | parcial (dev invoca) |
| Dependência externa | GitHub Actions | Node.js built-in |
| Changelog | auto + links GitHub | auto local |
| Body quality gate | adicionar via `release-quality-gate` | embutido |
| Monorepo | suportado | adaptar manualmente |
| 0.x handling | minor normal | minor ou "major-as-minor" |
| Overhead inicial | baixo (copy templates) | médio (adaptar script) |
| Custo por release | 0 (auto PR) | comando manual |

### Dúvida? Comece com `release-manual`

É mais simples, sem dependências, e você entende cada peça. Migrar para
release-please depois é trivial (adicionar 3 arquivos, desligar script).

## Estratégia recomendada por maturidade

### Fase 1 — projeto novo

1. Inicializar repo + `git init`
2. `git-hooks-install` — enforce conventional desde o início
3. Primeiro commit: `feat: initial scaffold`
4. Escolher: `release-manual-setup` (mais simples) OU `release-please-setup`
5. Tag inicial `v0.1.0`

### Fase 2 — projeto em crescimento

- Adicionar `release-quality-gate` como verificação extra
- Documentar CHANGELOG retroativo se aplicável
- Considerar auto-merge se team cresceu

### Fase 3 — projeto maduro (v1.0+)

- SemVer estrito
- Tests obrigatórios no quality gate
- GitHub Releases com notas detalhadas
- Deprecation policy documentada
- LTS strategy para majors

## Padrão C: puro git tag (minimalista)

Para projetos muito simples (scripts pessoais, experimentos):

```bash
# 1. Atualizar CHANGELOG manualmente
code CHANGELOG.md

# 2. Bump versão manualmente
jq '.version = "0.2.0"' package.json > /tmp/p.json && mv /tmp/p.json package.json

# 3. Commit + tag
git add CHANGELOG.md package.json
git commit -m "chore(release): v0.2.0"
git tag -a v0.2.0 -m "Release v0.2.0"
git push origin main v0.2.0
```

Use `release-quality-gate` antes de criar tag para validar:

```bash
bash release-quality-gate-check.sh --target-version=0.2.0 && \
  git tag -a v0.2.0 -m "Release v0.2.0" && \
  git push origin v0.2.0
```

## Gotchas e anti-patterns

### Commits legacy não-conventional

Se projeto tem 50 commits "fix cadastro", `release-please` **ignora-os**
(não aparecem no CHANGELOG). `release.mjs` **emite warning**. Ambos **não**
retroagem.

**Estratégia**: baseline mark. Adicionar entry no CHANGELOG:

```markdown
## [0.5.0] - 2025-12-01 — initial changelog baseline

Changes prior to 0.5.0 not tracked in this changelog. See git history
for details.
```

Daqui pra frente, conventional commits obrigatórios.

### Entrada manual em projeto com release-please

release-please **sobrescreve** edições manuais em `[Unreleased]`. A skill
`changelog-write-entry` detecta e avisa — você decide se prossegue
(ciente que será sobrescrito).

### Auto-merge + branch protection

Se `main` tem branch protection exigindo PR review, o `GITHUB_TOKEN` default
pode não conseguir mergear. Soluções:

1. Usar PAT de admin (secret `AUTO_MERGE_TOKEN`)
2. Configurar branch protection para aceitar GitHub App de release-please
3. Desabilitar auto-merge (aceitar release PR manual)

### Tag legacy não-SemVer

Tags antigas tipo `v1`, `1.0`, `release-2024` quebram `git describe`.
Skills passam `--since=<hash>` explicitamente ou usam primeiro commit
como baseline.

### Monorepo com tags mistas

Em monorepo com `md2pdf-v2.2.0` + `api-v1.5.0`, `git describe` pode pegar
tag errada. release-please resolve com `include-component-in-tag: true`.
Script manual precisa adaptar para filtrar por prefix.

### BUMP=major em 0.x

Com `PRE_1_0_MAJOR_AS_MINOR=true`, `BUMP=major` em 0.9.5 vira 0.10.0.
Para ir de 0.x para 1.0, editar `package.json` manual + tag manual:

```bash
jq '.version = "1.0.0"' package.json > /tmp/p.json && mv /tmp/p.json package.json
git add package.json CHANGELOG.md
git commit -m "chore(release): v1.0.0 — API stability milestone"
git tag -a v1.0.0 -m "Release v1.0.0"
```

### Tests flaky

Flakiness causa falso-negativo em `release-quality-gate`. Soluções:

- Curto prazo: retry 1 vez antes de falhar (adicionar lógica custom)
- Longo prazo: corrigir testes

### Signed commits e tags

Se projeto exige `gpg.sign` ou `tag.gpgSign`:

```javascript
// scripts/release.mjs — adaptar git() helper
git(['commit', '-S', '-m', `chore(release): ${tagName}`]);
git(['tag', '-s', '-a', tagName, '-m', `Release ${tagName}`]);
```

GPG/SSH key configurado previamente.

### Release em CI mode

`release.mjs` não deve rodar em CI (é ferramenta de dev). Detectar:

```javascript
if (process.env.CI === 'true') {
  console.error('release.mjs should not run in CI. Use release-please workflow.');
  process.exit(1);
}
```

## Ver também

- [`git-methodology/README.md`](../../global/skills/git-methodology/README.md)
- [`git-methodology/references/`](../../global/skills/git-methodology/references/) — 4 references técnicas
- [`release-please-setup/SKILL.md`](../../global/skills/release-please-setup/SKILL.md)
- [`release-manual-setup/SKILL.md`](../../global/skills/release-manual-setup/SKILL.md)
- [`changelog-write-entry/SKILL.md`](../../global/skills/changelog-write-entry/SKILL.md)
- [`git-hooks-install/SKILL.md`](../../global/skills/git-hooks-install/SKILL.md)
- [`release-quality-gate/SKILL.md`](../../global/skills/release-quality-gate/SKILL.md)
- [Keep a Changelog](https://keepachangelog.com/en/1.1.0/)
- [Semantic Versioning](https://semver.org/spec/v2.0.0.html)
- [Conventional Commits](https://www.conventionalcommits.org/)
- [release-please](https://github.com/googleapis/release-please)
