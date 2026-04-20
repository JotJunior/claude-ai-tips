# Release Quality Gate

Skill **read-only** que roda 10 checks antes de release. Útil como:

- Último check antes de `npm run release`
- CI step dedicado
- Sanity check manual

> **Índice geral**: [README.md](./README.md)

## Uso

Via skill:

```
valide prontidão para release v1.2.0
```

Ou diretamente (quando implementada como script):

```bash
release-quality-gate --target-version=1.2.0 --strict
```

## 10 checks

1. **Working tree limpa** — sem staged, modified, untracked
2. **Tag alvo disponível** — `v1.2.0` não existe ainda
3. **Commits conventional** — regex passa em todos desde última tag
4. **Body quality** — feat/fix/breaking com body >= 20 chars
5. **Tests passam** — `npm test` retorna 0 (pular com `--skip-tests`)
6. **Lint passa** — `npm run lint` se script existe
7. **Typecheck passa** — `npm run typecheck` se script existe
8. **CHANGELOG entry** — `## [1.2.0]` ou `## [Unreleased]` presente
9. **Branch correta** — `main` ou `master` (warn se feature branch)
10. **Sync com remote** — não behind de `origin/main`

## Exit codes

| Code | Significado |
|------|-------------|
| 0 | Todos os checks passaram |
| 1 | Algum check bloqueante falhou |
| 2 | Warnings presentes (com `--strict`, trata como falha) |

## Flags

| Flag | Efeito |
|------|--------|
| `--target-version=<v>` | Valida tag + CHANGELOG |
| `--since=<ref>` | Override auto-detect de última tag |
| `--skip-tests` | Pula `npm test` |
| `--skip-lint` | Pula `npm run lint` |
| `--skip-typecheck` | Pula `npm run typecheck` |
| `--strict` | Warnings viram blocking |
| `--min-body=<N>` | Override MIN_BODY_LENGTH |

## Saída típica

Sucesso:

```
Release Quality Gate — PASSED

[1/10] working tree clean               ok
[2/10] target tag v1.2.0 available      ok
[3/10] conventional commits format      23 commits, 0 violations
[4/10] commit body quality              3 feat, 5 fix, 0 breaking — all passed
[5/10] tests                            ok
[6/10] lint                             ok
[7/10] typecheck                        ok
[8/10] CHANGELOG entry                  [Unreleased] found
[9/10] branch                           on main
[10/10] sync with remote                up to date

Summary:
  Detected bump:  minor (0 breaking + 3 feat + 5 fix)
  Target version: 1.2.0 (from 1.1.0)
  Ready to release.
```

Falha:

```
Release Quality Gate — FAILED

[4/10] commit body quality              2 feat need body

  abc1234  feat: add login
           missing body (required for feat >= 20 chars)

  def5678  feat: add logout
           body 15 chars (required >= 20)

  Fix with:
    git commit --amend          # for the last commit
    git rebase -i HEAD~5        # for older commits

[5/10] tests                            FAILED (3 tests failing)

Summary:
  Quality gate failed. Fix issues above before releasing.
```

## Integração nos fluxos

### Com release-manual

```bash
release-quality-gate --target-version=1.2.0 --strict && npm run release
```

### Com release-please

Adicionar como step no workflow ou como pre-requisito manual antes de fazer merge do PR de release.

## Ver também

- [README.md](./README.md) — índice e visão geral
- [release-manual.md](./release-manual.md) — quality gate embutido no script
