---
name: py-review-pr
description: |
  Revisa changes em PR Python com checklist completo: type hints, mypy strict, ruff, pytest coverage.
  Use quando o usuário disser "review pr", "revisar pr", "code review", "quality gate",
  "verificar código", "checar PR", "validar changes".
  NÃO use quando for apenas formatação pontual (use linter diretamente).
allowed-tools: [Read, Glob, Grep, Bash]
---

# Review PR Python

Realiza review de qualidade em PR Python com checklist completo, diff-aware e focando em convensões da stack.

## Intro

Um PR bem revisado captura problemas antes de chegarem à main. O review deve ser
diff-aware — apenas muda que apareceram no diff são analisadas. A checklist inclui
type hints completos, mypy strict pass, ruff pass, pytest coverage > 80%, validação
de PII em logs, async/await correto, e ausência de SQL string interpolation.

Este skill é read-only — não modifica arquivos. Apenas reporta findings.

## Pre-flight Reads

- `git diff --name-only BASE...HEAD` — arquivos modificados
- `git diff BASE...HEAD` — diff completo
- `pyproject.toml` — configuração de tools (mypy, ruff, pytest)
- `app/` (ls) — estrutura do projeto

## Workflow

### 1. Gather Diff

```bash
BASE=${1:-main}
git diff --name-only $BASE...HEAD
git diff $BASE...HEAD
git log --oneline $BASE..HEAD
```

### 2. Check: Type Hints Completos

Para cada arquivo .py modificado (excluindo tests):

```bash
grep -E "^def |^async def |^[a-zA-Z_]+: |class " <file> | grep -v "# type:" | head -20
```

**Regra**: Todo método público deve ter type hints. Exceptions documentadas com `# type: ignore` devem ser justificadas.

### 3. Check: mypy strict pass

```bash
cd /path/to/project && uv run mypy <file> 2>&1 || mypy <file> 2>&1
```

**Regra**: mypy strict mode (configured em pyproject.toml) não deve falhar. Se falhar, é FAIL.

### 4. Check: ruff pass

```bash
cd /path/to/project && uv run ruff check <file> 2>&1 || ruff check <file> 2>&1
```

**Regra**: ruff deve passar com zero warnings. Se houver autofix disponíveis, documente.

### 5. Check: pytest coverage > 80%

```bash
cd /path/to/project && uv run pytest --cov=<module> --cov-fail-under=80 <file> 2>&1
```

**Regra**: Coverage de testes para módulos novos deve estar acima de 80%.

### 6. Check: PII em Logs

```bash
grep -rE "(CPF|cpf|email|phone|senha|password).*log" app/ 2>/dev/null | grep -v "# .*log"
```

**Regra**: Campos PII não devem aparecer em claro em logs. Deve haver redaction ou o campo não deve ser logado.

### 7. Check: async/await correto

```bash
grep -nE "async def |await |sync.*def|BlockingIO" <file>
```

**Regra**:
- `async def` deve usar `await` para operações async
- Sync I/O blocking (file I/O, synchronous DB drivers) dentro de `async def` é ANTI-PATTERN
- `def` (non-async) não deve usar `await`

### 8. Check: SQL sem String Interpolation

```bash
grep -nE '".*%s.*".*%|f".*SELECT|f".*INSERT|f".*UPDATE|f".*DELETE' <file>
```

**Regra**: SQL queries nunca devem usar f-strings ou % formatting. Use parameter binding:
```python
# RUIM
cursor.execute(f"SELECT * FROM users WHERE id = {user_id}")

# BOM
cursor.execute("SELECT * FROM users WHERE id = %s", (user_id,))
```

### 9. Check: Migrations (se houver .sql)

```bash
grep -nE "CREATE TABLE|ALTER TABLE|DROP TABLE" migrations/*.sql
```

**Regra**:
- Migrations devem usar IF NOT EXISTS
- Rolling back deve ser possível
- Não deve haver dados hardcoded (seed data em arquivos separados)

## Checklist por Arquivo

| # | Check | Status | Details |
|---|-------|--------|---------|
| 1 | Type hints completos | PASS/FAIL | |
| 2 | mypy strict pass | PASS/FAIL | |
| 3 | ruff check pass | PASS/FAIL | |
| 4 | pytest coverage > 80% | PASS/FAIL | |
| 5 | Sem PII em logs | PASS/FAIL | |
| 6 | async/await correto | PASS/FAIL | |
| 7 | SQL sem interpolation | PASS/FAIL | |
| 8 | Migrations idempotentes | PASS/FAIL | |

## Output Format

```markdown
# PR Review: {branch-name}
Date: {date}
Base: {base-branch}
Files: {N} arquivos modificados

## Build & Test
| File | mypy | ruff | coverage |
|------|------|------|----------|
| app/foo.py | PASS | PASS | 85% |
| app/bar.py | FAIL | PASS | - |

## Convention Checks
| # | Check | Status | File:Ln | Details |
|---|-------|--------|---------|---------|
| 1 | Type hints | FAIL | foo.py:42 | missing return type |
| 2 | mypy | FAIL | foo.py:42 | any |
| 3 | ruff | PASS | - | |
| 4 | coverage | PASS | - | |
| 5 | PII | FAIL | bar.py:10 | email logged in clear |
| 6 | async | PASS | - | |
| 7 | SQL interp | FAIL | foo.py:55 | f-string in query |
| 8 | migrations | PASS | - | |

## Summary
- **PASS**: X checks
- **FAIL**: Y checks (must fix before merge)
- **WARNING**: Z checks (review recommended)

## Required Actions
1. [Lista de coisas que DEVEM ser corrigidas antes do merge]

## Recommendations
1. [Lista de coisas que DEVEM ser corrigidas, mas não bloqueiam merge]
```

## Exemplo Bom

```
## Convention Checks
| 1 | Type hints | PASS | foo.py | full coverage |
| 2 | mypy strict | PASS | | |
| 3 | ruff | PASS | | |
```
**Por que é bom**: Checkpoint claro, file:line references para failures, sem false positives.

## Exemplo Ruim

```
## Checks
Tudo OK!
```
**Por que é ruim**: Sem detalhes, sem references, impossível acting on.

## Gotchas

- **G1**: mypy strict pode mascarar problemas com `Any` — se um arquivo usa `Any` em excesso, é WARNING.
- **G2**: Async leaks (sync I/O dentro de async def) são difíceis de detectar em review — use `grep -nE "open\(|read\(|write\(` dentro de `async def` blocks.
- **G3**: Verificar `pyproject.toml` deps churn — dependências novas devem ser justificadas e revisadas.
- **G4**: Migrations alembic devem ter down migration funcional.
- **G5**: coverage > 80% não significa que os testes certos estão sendo feitos —抽查 test quality.
- **G6**: Ruff pode ter autofix — se houver, mencione no report com command.

## Quando NÃO usar

- **Reviews de código simples** — pode usar ruff/lint diretamente
- **Reviews de performance** — use profiling tools
- **Reviews de security** — use owasp-security skill ou specialized tools (Bandit, Safety)
- **Edição de código** — skill é read-only, use outras skills para corrections
