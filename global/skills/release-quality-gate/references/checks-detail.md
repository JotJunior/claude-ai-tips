# Reference: Release Quality Gate — Checks Detalhados

Documentacao completa dos 10 checks executados pelo `/release-quality-gate`.
Cada secao cobre: o que valida, comando interno, falhas comuns, como corrigir.

> Volta para: [../SKILL.md](../SKILL.md)

---

## 1. working-tree-clean

**O que valida:** Nenhum arquivo modificado, staged ou untracked no working tree.

**Comando interno:**
```bash
git status --porcelain
```
Saida vazia = clean. Qualquer output = dirty.

**Falhas comuns:**
- Arquivos de build gerados nao-commitados (dist/, build/, *.js.map)
- Arquivos de ambiente (.env.local, .env.production)
- Arquivos temporarios de editor (*.swp, *~)

**Como corrigir:**
```bash
git add . && git commit -m "chore: commit pending changes"  # se legitimo
git stash                               # se temporario
git checkout -- <file>                  # se indesejado
```

**Regra:** Release deve ser **reprodutivel a partir de commits**. Arquivos
nao-commitados podem baguncar versao ou deixar surprises depois do release.

---

## 2. tag-available

**O que valida:** Tag `v$TARGET` ainda nao existe no repositorio.

**Comando interno:**
```bash
git rev-parse "v$TARGET" >/dev/null 2>&1 && echo "tag ja existe" || echo "ok"
```

**Falhas comuns:**
- Release anterior com mesma versao ja foi feita
- Confusion entre `v` prefix e versao raw (v1.2.0 vs 1.2.0)
- Tag em outro namespace (release-1.2.0 nao conflitacon v1.2.0)

**Como corrigir:**
```bash
# Ver todas as tags
git tag -l

# Se tag existe e eh erro:
git tag -d v1.2.0                    # remover local
git push origin :refs/tags/v1.2.0    # remover remote
# OU incrementar versao no SKILL.md / target
```

**Regra:** Re-release com mesma versao quebra contrato SemVer.

---

## 3. conventional-commits

**O que valida:** Commits desde `--since` seguem formato conventional commit.

**Regex usada:**
```
^([a-z]+)(\([^)]+\))?(!)?: .+$
```
Grupos: type, (scope), !, subject.

**Falhas comuns:**
- Commit sem tipo: `git commit -m "update readme"`
- Tipo invalido: `git commit -m "updated readme"` (ingles, past tense)
- Falta espaco apos colon: `feat:update readme`
- Subject vazio: `feat:`

**Output reporting:**
```
[3/9] conventional commits format     23 commits, 0 violations
```
commits nao-conformes geram WARN (nao block por default).

**Como corrigir:**
```bash
# Ultimo commit
git commit --amend -m "feat: add readme"

# Commits antigos
git rebase -i HEAD~N
# No editor interativo, trocar `pick` por `reword` nos commits problemáticos
```

**Com `--strict`:** violacoes bloqueiam release.

---

## 4. body-quality

**O que valida:** Commits feat, fix e breaking tem body com pelo menos
MIN_BODY_LENGTH caracteres (default: 20).

**Logica:**
```javascript
commits.filter(c =>
  c.type && (BODY_REQUIRED_TYPES.has(c.type) || c.breaking) &&
  (!c.body || c.body.length < MIN_BODY_LENGTH)
)
```

**Falhas comuns:**
- Commit sem body: `feat: add login`
- Body curto: `feat: add login` (5 chars)
- Body com whitespace: `feat: add login` seguido de linha vazia (0 chars efetiva)

**Output quando falha:**
```
abc1234  feat: add login
         missing body (required for feat >= 20 chars)

def5678  feat: add logout
         body 15 chars (required >= 20)
```

**Como corrigir:**
```bash
# Ultimo commit
git commit --amend -m "feat: add login

Added OAuth2 flow with PKCE support for CLI authentication.
Implements authorization code flow with local redirect server."

# Commits antigos
git rebase -i HEAD~N
# pick → edit no commit problematico, depois git commit --amend
```

---

## 5. tests-pass

**O que valida:** Suite de testes passa (exit code 0).

**Comando interno:**
```bash
npm test  # ou bun test / pnpm test / yarn test baseado em lockfile
```

**Detecao de test runner:**
```bash
# lockfile detection
if [ -f bun.lockb ]; then bun test
elif [ -f pnpm-lock.yaml ]; then pnpm test
elif [ -f yarn.lock ]; then yarn test
else npm test
fi
```

**Falhas comuns:**
- Teste quebrado no codigo recente
- Teste flaky (passa/falha nondeterministicamente)
- Dependencia faltando no ambiente de CI
- Timeout em suite lenta

**Como corrigir:**
```bash
# Executar localmente para debug
npm test 2>&1 | tail -50

# Se flaky: retry 1x
npm test || npm test
```

**Pula com:** `--skip-tests`

---

## 6. lint-pass

**O que valida:** Lint passa (exit code 0).

**Comando interno:**
```bash
if jq -e '.scripts.lint' package.json >/dev/null 2>&1; then
    npm run lint
fi
```

**Nota:** Ausencia de script `lint` NAO falha (nao existe contrato).

**Falhas comuns:**
- Erro de sintaxe em arquivo modificado
- Regra nova ativada que projetos antigos nao seguem
- ESLint深深地 configurado com `max-warnings: 0`

**Como corrigir:**
```bash
npm run lint 2>&1  # ver erros completos

# Correcao automatica se configurado
npm run lint -- --fix
```

**Pula com:** `--skip-lint`

---

## 7. typecheck-pass

**O que valida:** Typecheck passa (exit code 0).

**Comando interno:**
```bash
if jq -e '.scripts.typecheck' package.json >/dev/null 2>&1; then
    npm run typecheck
fi
```

**Equivalente a lint.** Detecta pelo script em package.json.

**Scripts comuns:**
- `tsc --noEmit` (TypeScript)
- `flow` (Flow)
- `pyright` / `mypy` (Python)

**Pula com:** `--skip-typecheck`

---

## 8. changelog-entry

**O que valida:** CHANGELOG.md contem entrada para versao alvo.

**Comando interno:**
```bash
grep -qE "^## \[$TARGET\]" CHANGELOG.md || grep -qE "^## \[Unreleased\]" CHANGELOG.md
```

**Aceita dois formatos:**
- Entrada especifica: `## [1.2.0]`
- Entrada generic: `## [Unreleased]` (vai virar 1.2.0 no release)

**Falhas comuns:**
- CHANGELOG nao existe
- Entrada nao foi escrita ainda
- Entrada escrita mas em formato diferente (espacos, case)

**Como corrigir:**
```bash
# Gerar entrada com skill changelog-write-entry
/changelog-write-entry --version 1.2.0 --type minor

# OU escrita manual em CHANGELOG.md:
## [Unreleased]
### Added
- Descricao da feature
```

**Nota:** Com release-please, `[Unreleased]` NAO existe entre releases —
proximo release PR gera. nesse caso, adicionar check跳过 ou usar flag.

**Bloqueia com:** `--strict`; WARN default.

---

## 9. branch-main

**O que valida:** Branch atual eh `main` ou `master`.

**Comando interno:**
```bash
git branch --show-current
```

**Falhas comuns:**
- Release em branch feature/xyz
- Branch topic/hotfix (sem ser release branch)
- Working tree dirty (afeta outros checks primeiro)

**Regra:** Release em branch feature eh **incomum mas legitimo** para
hotfixes. Nao bloqueia — apenas WARN.

**Como corrigir:**
```bash
git checkout main
# OU: git checkout master
```

---

## 10. remote-sync

**O que valida:** Local esta sincronizado com remote (nao esta behind).

**Comando interno:**
```bash
git fetch origin
git status -sb | grep -q 'behind'
```

**Falhas comuns:**
- Commits feitos localmente que ainda nao foram pushados
- Outro desenvolvedor pushou depois do ultimo fetch
- Rede offline impede fetch

**Output:**
```
[9/9] branch state                    on main, in sync with origin/main
# OU
[9/9] branch state                    on main, behind origin/main by 2 (WARN)
```

**Como corrigir:**
```bash
git pull --rebase   # se commits locais devem ser mantidos
# OU
git push origin HEAD # se commits locais devem ir
```

**Com `--strict`:** behind bloqueia release. Sem `--strict`: WARN.

---

## Tabela Resumo

| Check | Bloqueante? | Falha Comum | Remedio Rapido |
|-------|-------------|-------------|----------------|
| working-tree-clean | Sim | dirty files | commit/stash/checkout |
| tag-available | Sim | tag duplicada | deletar tag ou bump versao |
| conventional-commits | WARN (block com --strict) | formato invalido | rebase --interactive |
| body-quality | WARN (block com --strict) | body ausente/curto | commit --amend |
| tests-pass | Sim | teste quebrado | corrigir teste |
| lint-pass | Sim | lint errors | npm run lint -- --fix |
| typecheck-pass | Sim | type error | corrigir tipos |
| changelog-entry | WARN (block com --strict) | falta entrada | escrever entrada |
| branch-main | WARN | branch errada | git checkout main |
| remote-sync | WARN (block com --strict) | local behind | git pull/push |

---

## Integracao: Validacao de Todos Checks

Para debug completo, rodar todos os checks sequencialmente:

```bash
#!/bin/bash
echo "=== Release Quality Gate ==="
echo ""

echo "[1] working-tree-clean"
git status --porcelain || { echo "FAIL"; exit 1; }

echo "[2] tag-available"
git rev-parse "v$TARGET" >/dev/null 2>&1 && { echo "tag ja existe"; exit 1; }

echo "[3] conventional-commits"
git log --format="%s" $SINCE..HEAD | grep -vE '^([a-z]+)(\([^)]+\))?(!)?: .+$' || echo "has violations"

echo "[4] body-quality"
# ... etc

echo "All checks passed."
```

---

## Ver tambem

- [`release-manual-setup`](../release-manual-setup/) — quality gate embutido
- [`release-please-setup`](../release-please-setup/) — sem gate embutido
- [`changelog-write-entry`](../changelog-write-entry/) — escreve entrada Unreleased
- [`git-hooks-install`](../git-hooks-install/) — gate em commit time (complementar)
