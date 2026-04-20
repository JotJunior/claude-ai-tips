---
name: py-upgrade-pkg-manager
description: |
  Migra projeto Python de pip/poetry/pipenv para uv com lockfile determinístico.
  Use quando o usuário disser "upgrade pkg manager", "migrate to uv", "from poetry to uv",
  "modernize python", "converter para uv", "uv migration".
  NÃO use quando for apenas adicionar uma dependência (use uv add diretamente).
allowed-tools: [Read, Write, Edit, Glob, Grep, Bash]
---

# Migrar para uv

Migre um projeto Python existente de pip, poetry ou pipenv para uv.

## Intro

uv é um package manager moderno written in Rust que é 10-100x mais rápido que pip
e poetry, com lockfiles determinísticos e gestão virtual environment integrada. Migrar
para uv reduz tempo de CI, elimina problemas de dependências inconsistentes, e padroniza
o workflow de desenvolvimento.

Este skill cobre migração de pip (requirements.txt), poetry ([tool.poetry]), e pipenv (Pipfile).
O processo é: identificar manager atual → extrair dependências → criar pyproject.toml →
gerar lock → validar.

## Pre-flight Reads

- `pyproject.toml` — verificar se já existe configuração
- `requirements*.txt` — listar arquivos de requirements
- `Pipfile` ou `Pipfile.lock` — se existir
- `poetry.lock` — se existir (indica projeto poetry)
- `.python-version` — versão do Python usada
- `uv --version` — verificar se uv está instalado

## Workflow

### 1. Identificar Manager Atual

```bash
# Verificar qual manager está em uso
if [ -f "poetry.lock" ]; then
    echo "poetry"
elif [ -f "Pipfile.lock" ]; then
    echo "pipenv"
elif ls requirements*.txt 2>/dev/null | head -1 | grep -q .; then
    echo "pip"
else
    echo "unknown"
fi
```

### 2. Fazer Backup

```bash
mkdir -p .migration-backup
cp pyproject.toml .migration-backup/ 2>/dev/null || true
cp poetry.lock .migration-backup/ 2>/dev/null || true
cp requirements*.txt .migration-backup/ 2>/dev/null || true
cp Pipfile* .migration-backup/ 2>/dev/null || true
cp -r .venv .migration-backup/ 2>/dev/null || true
git add .migration-backup
```

### 3. Converter de poetry para pyproject.toml

De `[tool.poetry]` para `[project]` + `[project.dependencies]`:

```toml
# ANTES (poetry)
[tool.poetry]
name = "my-project"
version = "0.1.0"
description = "My project"
authors = ["Name <email@example.com>"]

[tool.poetry.dependencies]
python = "^3.12"
fastapi = "^0.115.0"
pydantic = "^2.10.0"

[tool.poetry.group.dev.dependencies]
pytest = "^8.3.0"
mypy = "^1.14.0"

# DEPOIS (uv/pyproject)
[project]
name = "my-project"
version = "0.1.0"
description = "My project"
requires-python = ">=3.12"
dependencies = [
    "fastapi>=0.115.0",
    "pydantic>=2.10.0",
]

[project.optional-dependencies]
dev = [
    "pytest>=8.3.0",
    "mypy>=1.14.0",
]
```

**Conversão de poetry groups**:
```toml
# poetry
[tool.poetry.group.dev.dependencies]
pytest = "^8.3.0"

# uv equivalent
[project.optional-dependencies]
dev = [
    "pytest>=8.3.0",
]
```

### 4. Converter de requirements.txt

```bash
# poetry
uv init --no-readme

# requirements.txt → pyproject.toml
# Leia cada requirements*.txt e adicione ao [project.dependencies]
# Exemplo:
uv add fastapi pydantic structlog httpx

# dev deps
uv add --dev pytest pytest-asyncio mypy ruff factory-boy pytest-cov
```

### 5. Converter Scripts (poetry scripts)

```toml
# poetry
[tool.poetry.scripts]
myapp = "my_project.main:app"

# uv equivalent
[project.scripts]
myapp = "my_project.main:app"
```

### 6. Configurar pyproject.toml com Tools

```toml
[tool.ruff]
line-length = 100
target-version = "py312"

[tool.ruff.lint]
select = ["E", "W", "F", "I", "B", "C4", "UP"]
ignore = ["E501"]

[tool.mypy]
python_version = "3.12"
strict = true

[tool.pytest.ini_options]
asyncio_mode = "auto"
```

### 7. Lock e Sync

```bash
uv lock
uv sync
```

### 8. Atualizar CI/CD

```yaml
# .github/workflows/ci.yml
- name: Install uv
  uses: astral-sh/setup-uv@v4

- name: Sync dependencies
  run: uv sync --dev

- name: Type check
  run: uv run mypy src/

- name: Lint
  run: uv run ruff check src/

- name: Test
  run: uv run pytest tests/ -v --cov=src
```

### 9. Atualizar Dockerfile (se existir)

```dockerfile
# ANTES (pip)
RUN pip install -r requirements.txt

# DEPOIS (uv)
COPY --from=ghcr.io/astral-sh/uv:latest /uv /usr/local/bin/uv
RUN uv sync --no-dev --frozen
```

### 10. Remover Arquivos Antigos

```bash
rm -f poetry.lock requirements.txt requirements-dev.txt Pipfile Pipfile.lock
rm -rf .venv  # uv gerencia seu próprio venv
```

### 11. Validar

```bash
uv run python -c "from app.main import app; print('OK')"
uv run ruff check src/
uv run mypy src/
uv run pytest tests/ -v --cov=src
```

## Exemplo Bom

```bash
# poetry → uv
uv init --no-readme
# Migrar [tool.poetry.dependencies] → [project.dependencies]
uv add fastapi pydantic structlog
uv add --dev pytest pytest-asyncio mypy ruff
uv lock
uv sync
```
**Por que é bom**: Migration completa preservando todas as dependências.

```toml
[project]
name = "my-project"
requires-python = ">=3.12"
dependencies = [
    "fastapi>=0.115.0",
    "pydantic>=2.10.0",
]

[project.optional-dependencies]
dev = [
    "pytest>=8.3.0",
    "mypy>=1.14.0",
]
```
**Por que é bom**: Formato padrão [project] em vez de [tool.poetry], compatível com uv.

## Exemplo Ruim

```bash
# Não fazer backup
rm poetry.lock requirements.txt
```
**Por que é ruim**: Sem backup, não há como reverter se a migração falhar.

```toml
# poetry group não convertido
[tool.poetry.group.test.dependencies]
pytest = "^8.3.0"

# Sem equivalente uv — testes não funcionam
```
**Por que é ruim**: poetry groups não têm equivalente direto em uv. Devem ser convertidos para [project.optional-dependencies].

```dockerfile
# Ainda usando pip
RUN pip install poetry
RUN poetry install
```
**Por que é ruim**: CI não migrado, tempo de CI仍将慢。

## Gotchas

- **G1**: **SEMPRE fazer backup antes** — arquivos velhos podem ser necessários para rollback.
- **G2**: poetry groups (`[tool.poetry.group.dev.dependencies]`) não têm equivalente direto — usar `[project.optional-dependencies]` comextras.
- **G3**: uv lockfile é diferente do poetry lock — não tentar reutilizar poetry.lock. Regenerar com `uv lock`.
- **G4**: uv oferece lockfile hashing opcional (`uv lock --no-hashes`) — pode ser necessário para private repos.
- **G5**: Scripts em `[project.scripts]` em vez de `[tool.poetry.scripts]`.
- **G6**: Private repos via `UV_INDEX_URL` environment variable — não usar `[[tool.poetry.source]]`.
- **G7**: Se o projeto usar `.venv` separado, remova antes — uv gerencia seu próprio venv em `.venv` por padrão.

## Quando NÃO usar

- **Apenas adicionar uma dependência** — use `uv add` diretamente
- **Inicializar novo projeto** — use `uv init` ou py-setup-project skill
- **Migrar apenas CI** — CI pode ser migrado independentemente do projeto
- **Migrar apenas Dockerfile** — pode ser feito independentemente
