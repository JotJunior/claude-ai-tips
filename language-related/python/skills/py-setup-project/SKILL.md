---
name: py-setup-project
description: |
  Bootstrap projeto Python moderno com uv, FastAPI, Pydantic v2, pytest, mypy strict.
  Use quando o usuário disser "setup project", "init python project", "novo projeto python",
  "bootstrap python", "iniciar projeto", "novo projeto fastapi".
  NÃO use quando for adicionar arquivos a projeto existente (use outras skills).
allowed-tools: [Read, Bash, Glob, Grep]
---

# Setup Projeto Python

Bootstrap um projeto Python moderno seguindo as melhores práticas da stack Python
moderna com uv como package manager.

## Intro

Um projeto bem estruturado desde o início evita débitos técnicos que são difíceis
de corrigir depois: type hints incompletos, testes faltando, linters mal configurados,
organização de código inconsistente. uv é o package manager moderno que substitui
pip, poetry e pyenv com performance superior e lockfiles determinísticos.

Este skill cria a estrutura base com todas as configurações de tools em pyproject.toml,
layout src, e setup inicial de testes e logging.

## Pre-flight Reads

- `.python-version` — versão do Python se existir
- `uv --version` — verificar se uv está instalado
- `ruff --version` — verificar se ruff está instalado

## Workflow

### 1. Verificar Pré-requisitos

```bash
command -v uv && uv --version
python3 --version
```

Se uv não estiver instalado:
```bash
curl -LsSf https://astral.sh/uv/install.sh | sh
```

### 2. Criar Projeto com uv init

```bash
cd /path/to/parent
uv init --no-readme --name my-project
cd my-project
```

### 3. Configurar pyproject.toml

Edite `pyproject.toml` com a stack completa:

```toml
[project]
name = "my-project"
version = "0.1.0"
description = "My FastAPI project"
readme = "README.md"
requires-python = ">=3.12"
dependencies = [
    "fastapi>=0.115.0",
    "pydantic>=2.10.0",
    "structlog>=24.0.0",
    "sqlalchemy>=2.0.0",
    "alembic>=1.13.0",
    "uvicorn[standard]>=0.32.0",
    "python-dotenv>=1.0.0",
    "httpx>=0.28.0",
]

[project.optional-dependencies]
dev = [
    "pytest>=8.3.0",
    "pytest-asyncio>=0.24.0",
    "pytest-cov>=6.0.0",
    "mypy>=1.14.0",
    "ruff>=0.8.0",
    "factory-boy>=3.3.0",
]

[tool.ruff]
line-length = 100
target-version = "py312"
indent-width = 4

[tool.ruff.lint]
select = [
    "E",      # pycodestyle errors
    "W",      # pycodestyle warnings
    "F",      # pyflakes
    "I",      # isort
    "B",      # flake8-bugbear
    "C4",     # flake8-comprehensions
    "UP",     # pyupgrade
]
ignore = [
    "E501",   # line too long (handled by formatter)
]

[tool.mypy]
python_version = "3.12"
strict = true
warn_return_any = true
warn_unused_ignores = true
disallow_untyped_defs = true
disallow_incomplete_defs = true
check_untyped_defs = true
no_implicit_optional = true
warn_redundant_casts = true
warn_unused_configs = true
disallow_untyped_decorators = true

[tool.pytest.ini_options]
asyncio_mode = "auto"
asyncio_default_fixture_loop_scope = "session"
filterwarnings = ["ignore::DeprecationWarning"]
```

### 4. Criar Layout Src

```bash
mkdir -p src/my_project/{api,models,schemas,services,repositories,dependencies,middleware}
mkdir -p tests/{fixtures,factories}
mkdir -p alembic/versions
touch src/my_project/__init__.py
touch src/my_project/api/__init__.py
touch src/my_project/models/__init__.py
touch src/my_project/schemas/__init__.py
touch src/my_project/services/__init__.py
touch src/my_project/repositories/__init__.py
touch src/my_project/dependencies/__init__.py
touch src/my_project/middleware/__init__.py
touch tests/__init__.py
touch tests/fixtures/__init__.py
touch tests/factories/__init__.py
```

### 5. Criar app/main.py

```python
"""FastAPI application entry point."""
import logging
from contextlib import asynccontextmanager

from fastapi import FastAPI

from app.logging import setup_logging, get_logger
from app.middleware import LoggingMiddleware
from app.routers import user, health

setup_logging(log_level="INFO", json_logs=False)
log = get_logger(__name__)


@asynccontextmanager
async def lifespan(app: FastAPI):
    """Startup e shutdown events."""
    log.info("Starting application")
    yield
    log.info("Shutting down application")


app = FastAPI(
    title="My Project API",
    description="FastAPI project with Pydantic v2",
    version="0.1.0",
    lifespan=lifespan,
)

app.add_middleware(LoggingMiddleware)
app.include_router(health.router, prefix="/api")
app.include_router(user.router, prefix="/api/users")

log.info("Application configured")
```

### 6. Criar Arquivos Essenciais

#### `tests/conftest.py`

```python
"""Fixtures globais de teste."""
import pytest
from typing import AsyncGenerator
from httpx import AsyncClient, ASGITransport


@pytest.fixture(scope="session")
def anyio_backend():
    return "asyncio"


@pytest.fixture
async def async_client() -> AsyncGenerator[AsyncClient, None]:
    from app.main import app
    
    async with AsyncClient(
        transport=ASGITransport(app=app),
        base_url="http://test",
    ) as client:
        yield client
```

#### `.gitignore`

```
__pycache__/
*.py[cod]
*$py.class
*.so
.Python
.venv/
venv/
ENV/
.env
.Env
.ruff_cache/
.mypy_cache/
.pytest_cache/
.coverage
*.egg-info/
dist/
build/
*.egg
uv.lock
```

#### `.env.example`

```
# Application
APP_ENV=development
LOG_LEVEL=DEBUG
JSON_LOGS=false

# Database
DATABASE_URL=postgresql+asyncpg://user:pass@localhost:5432/myapp

# Server
HOST=0.0.0.0
PORT=8000
```

### 7. Lock e Sync

```bash
uv lock
uv sync
```

### 8. Verificar Setup

```bash
uv run python -c "from app.main import app; print('OK')"
uv run ruff check src/
uv run mypy src/
uv run pytest tests/ -v --cov=src --cov-fail-under=80
```

## Exemplo Bom

```toml
[tool.mypy]
python_version = "3.12"
strict = true
```
**Por que é bom**: mypy strict desde o dia 1 — type hints incompletos são pegos imediatamente.

```bash
uv init --no-readme --name my-project
cd my-project && uv add fastapi pydantic structlog
uv add --dev pytest pytest-asyncio mypy ruff
```
**Por que é bom**: Workflow completo com uv, todas as deps instaladas corretamente.

## Exemplo Ruim

```bash
mkdir my-project && cd my-project
pip install fastapi pydantic
```
**Por que é ruim**: Sem uv (sem lockfile), sem pyproject.toml estruturado, sem type hints, sem testes.

```toml
# Sem [tool.mypy] configurado
[tool.pytest.ini_options]
asyncio_mode = "auto"
```
**Por que é ruim**: mypy não está em modo strict — erros de tipo não são pegos.

## Gotchas

- **G1**: Layout src (src/project/) é preferido sobre layout flat — facilita importações e permite package installation sem cargo-cult.
- **G2**: Python version pin via `.python-version` file (criado por `uv init`) ou `requires-python` no pyproject.toml — não use pyenv version file.
- **G3**: `uv.lock` DEVE ser commitado — garante reprodutibilidade. Nunca use `uv sync --no-lock`.
- **G4**: ruff substitui black + isort + flake8 — não instale black ou isort separadamente.
- **G5**: mypy strict mode desde dia 1 é mais fácil do que adicionar depois — type hints são mais difíceis de adicionar retroativamente.
- **G6**: Sempre use `uv add` (que atualiza pyproject.toml e lock) ao invés de editar pyproject.toml manualmente.
- **G7**: Virtual environment é gerenciado por uv — não crie venv manualmente com `python -m venv`.

## Quando NÃO usar

- **Adicionar arquivos a projeto existente** — use skills específicas (add-route, add-model, etc.)
- **Bootstrap com frameworks específicos** (Django, Flask) — a estrutura varia, use templates dedicados
- **Migrar de pip/poetry para uv** — use py-upgrade-pkg-manager skill
