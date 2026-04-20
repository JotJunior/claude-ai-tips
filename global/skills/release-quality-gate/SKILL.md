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

Validador **read-only** que roda bateria de checagens antes de release.
Nao modifica nada no repositorio — apenas reporta estado e sai com exit
code indicativo.

Util como:
- Ultima checagem antes de `npm run release` (manual)
- Sanity check antes de mergear release PR (release-please)
- CI step dedicado para validar prontidao de release
- Comando de habito diario em projetos com releases frequentes

## Quando usar / Quando NAO usar

| Context | Use | Dont Use |
|---------|-----|----------|
| Antes de `release-manual-setup` | -- | -- |
| Antes de release-please PR | -- | -- |
| Antes de `git tag && git push` manual | -- | -- |
| Apos commit, antes de push | -- | -- |
| Durante execucao de task | -- | Faltam artefatos do pipeline SDD |
| Para substituir commit-msg hook | -- | Hook valida ANTES do commit; gate valida DEPOIS |

## O que faz

Executa 10 checks read-only: working tree, tagDisponivel, conventional,
bodyQuality, tests, lint, typecheck, changelog, branchMain, remoteSync.
Saida mostra resultado por check + summary com bump detectado.

## Como invocar

```bash
/release-quality-gate                              # checks defaults
/release-quality-gate --target-version=1.2.0       # valida tag + changelog
/release-quality-gate --strict --since=v1.1.0      # modo estrito desde ref
```

## Checks executados (resumo)

1. **working-tree-clean** — `git status --porcelain` vazio
2. **tag-available** — tag `v$TARGET` ainda nao existe (SemVer)
3. **conventional-commits** — regex `^([a-z]+)(\([^)]+\))?(!)?: .+$` nos commits
4. **body-quality** — feat/fix/breaking com body >= 20 chars
5. **tests-pass** — `npm test` (pula com `--skip-tests`)
6. **lint-pass** — `npm run lint` se configurado (pula com `--skip-lint`)
7. **typecheck-pass** — `npm run typecheck` se configurado
8. **changelog-entry** — `## [$TARGET]` ou `## [Unreleased]` existe
9. **branch-main** — branch atual eh main/master (WARN se nao)
10. **remote-sync** — local esta em sync com origin (WARN se behind)

## Exit codes

| Code | Significado |
|------|-------------|
| `0` | Todos os checks passaram |
| `1` | Algum check bloqueante falhou |
| `2` | Warnings presentes (`--strict` trata WARN como blocking) |

## Flags

| Flag | Efeito |
|------|--------|
| `--target-version=<v>` | Valida tag + CHANGELOG para versao |
| `--since=<ref>` | Analisa desde `<ref>` (default: ultima tag) |
| `--skip-tests` | Pula `npm test` |
| `--skip-lint` | Pula `npm run lint` |
| `--skip-typecheck` | Pula `npm run typecheck` |
| `--strict` | Violacoes WARN viram blocking |
| `--min-body=<N>` | Override MIN_BODY_LENGTH (default 20) |
| `--body-required=<types>` | Override BODY_REQUIRED_TYPES (default feat,fix) |

## Gotchas criticos

1. **Nao confundir com commit-msg hook** — hook valida ANTES do commit,
   gate valida DEPOIS em batch. Camadas diferentes, ambas uteis.

2. **Tags legacy nao-SemVer** — tags como `v1`, `1.0`, `release-2024`
   fazem `git describe` retornar tag errada. Usar `--since=<hash>`.

3. **Monorepo com tags multiplas** — `git describe` pega mais recente
   globalmente, nao a do componente. Passar `--since` explicitamente:
   `--since=md2pdf-v2.2.0 --target-version=2.3.0`.

## Referencias

- [Checks detalhados](./references/checks-detail.md) — o que valida,
  comando interno, falhas comuns, como corrigir cada check
