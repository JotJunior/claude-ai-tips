---
name: py-add-fastapi-route
description: |
  Adiciona uma nova rota FastAPI com Pydantic schema, dependency injection e response_model.
  Use quando o usuário disser "add route", "nova rota", "criar endpoint", "novo endpoint",
  "adicionar rota fastapi", "novo recurso".
  NÃO use quando for apenas editar rota existente (use outra skill).
allowed-tools: [Read, Write, Edit, Glob, Grep, Bash]
---

# Adicionar Rota FastAPI

Gera uma rota FastAPI completa seguindo padrões Python modernos com Pydantic v2, injeção de dependências e structured logging.

## Intro

Adicionar uma rota em FastAPI não é apenas criar um endpoint — é criar uma fatia
vertical completa: schema de request/response, serviço, handler, exception handlers
e testes. Uma rota bem estruturada protege contra vazamento de PII, é testável,
usa dependency injection para reusable logic, e segue a convenção de status codes
explícitos.

Este skill assume estrutura `app/routers/`, `app/schemas/`, `app/services/`,
`app/dependencies/` — o padrão de "vertical slice" idiomatic para FastAPI
modular. Se a estrutura do projeto for diferente, adapte os caminhos.

## Pre-flight Reads

Antes de gerar QUALQUER código, leia em paralelo:
- `app/main.py` — para ver como routers são registrados e middleware configurado
- `app/routers/` (ls) — para ver padrões de routers existentes
- `app/schemas/` (ls) — para ver padrões de Pydantic schemas
- `app/services/` (ls) — para ver padrões de serviços
- `app/dependencies/` (ls) — se existir, para padrões de DI
- `tests/conftest.py` — fixtures existentes
- `pyproject.toml` —确认依赖已安装

## Workflow

### 1. Analisar o recurso

Determine:
- **Nome do recurso**: singular (ex: `user`, `product`, `order`)
- **Operações CRUD**: quais dos quatro (Create, Read, Update, Delete) serão expostas
- **Escopo de listagem**: filtros, paginação, ordenação
- **Relações**: outros recursos que este depende

### 2. Criar Schema Pydantic — `app/schemas/<resource>.py`

```python
from datetime import datetime
from uuid import UUID

from pydantic import BaseModel, ConfigDict, Field, field_validator


class <Resource>Base(BaseModel):
    """Schema base com campos comuns."""
    model_config = ConfigDict(str_strip_whitespace=True)


class <Resource>Create(<Resource>Base):
    """Schema para POST /<resources>."""
    name: str = Field(min_length=1, max_length=255)
    description: str | None = None


class <Resource>Update(<Resource>Base):
    """Schema para PUT /<resources>/{id}."""
    name: str | None = Field(default=None, min_length=1, max_length=255)
    description: str | None = None


class <Resource>Response(<Resource>Base):
    """Schema para GET /<resources>/{id} e GET /<resources>."""
    id: UUID
    created_at: datetime
    updated_at: datetime | None = None

    model_config = ConfigDict(from_attributes=True)
```

### 3. Criar Serviço — `app/services/<resource>_service.py`

```python
import logging
from uuid import UUID

from app.schemas.<resource> import (<Resource>Create, <Resource>Update)
from app.repositories.<resource>_repository import <Resource>Repository

logger = logging.getLogger(__name__)


class <Resource>Service:
    def __init__(self, repo: <Resource>Repository):
        self._repo = repo

    async def create(self, data: <Resource>Create) -> <Resource>:
        # TODO: implementar lógica de criação
        ...

    async def get_by_id(self, id: UUID) -> <Resource> | None:
        ...

    async def list(self, limit: int = 20, offset: int = 0) -> list[<Resource>]:
        ...

    async def update(self, id: UUID, data: <Resource>Update) -> <Resource> | None:
        ...

    async def delete(self, id: UUID) -> bool:
        ...
```

### 4. Criar Router — `app/routers/<resource>.py`

```python
from uuid import UUID

from fastapi import APIRouter, Depends, HTTPException, status
from app.dependencies import get_<resource>_service
from app.schemas.<resource> import (<Resource>Create, <Resource>Update, <Resource>Response)
from app.services.<resource>_service import <Resource>Service

router = APIRouter(prefix="/<resources>", tags=["<resources>"])


@router.post(
    "/",
    response_model=<Resource>Response,
    status_code=status.HTTP_201_CREATED,
    summary="Criar <resource>",
)
async def create_<resource>(
    data: <Resource>Create,
    service: <Resource>Service = Depends(get_<resource>_service),
):
    """Cria um novo <resource>."""
    result = await service.create(data)
    return result


@router.get(
    "/{id}",
    response_model=<Resource>Response,
    summary="Obter <resource> por ID",
)
async def get_<resource>(
    id: UUID,
    service: <Resource>Service = Depends(get_<resource>_service),
):
    """Obtém um <resource> pelo ID."""
    result = await service.get_by_id(id)
    if result is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="<resource> não encontrado")
    return result


@router.get(
    "/",
    response_model=list[<Resource>Response],
    summary="Listar <resources>",
)
async def list_<resources>(
    limit: int = 20,
    offset: int = 0,
    service: <Resource>Service = Depends(get_<resource>_service),
):
    """Lista <resources> com paginação."""
    return await service.list(limit=limit, offset=offset)


@router.delete(
    "/{id}",
    status_code=status.HTTP_204_NO_CONTENT,
    summary="Remover <resource>",
)
async def delete_<resource>(
    id: UUID,
    service: <Resource>Service = Depends(get_<resource>_service),
):
    """Remove um <resource> pelo ID."""
    success = await service.delete(id)
    if not success:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="<resource> não encontrado")
```

### 5. Registrar Router no Main — `app/main.py`

```python
from fastapi import FastAPI
from app.routers import <resource>

app = FastAPI(title="My API")

app.include_router(<resource>.router)
# ... outros routers
```

### 6. Criar Exception Handler (se necessário)

Adicione em `app/main.py`:
```python
from fastapi.exceptions import RequestValidationError
from fastapi.responses import JSONResponse

@app.exception_handler(RequestValidationError)
async def validation_exception_handler(request, exc):
    return JSONResponse(
        status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
        content={"error": "validation_error", "details": exc.errors()},
    )
```

### 7. Criar Testes — `tests/test_<resource>_api.py`

```python
import pytest
from httpx import AsyncClient, ASGITransport
from app.main import app


@pytest.mark.asyncio
async def test_create_<resource>(async_client: AsyncClient):
    response = await async_client.post(
        "/api/<resources>/",
        json={"name": "Test <resource>"},
    )
    assert response.status_code == status.HTTP_201_CREATED
    data = response.json()
    assert data["name"] == "Test <resource>"
    assert "id" in data


@pytest.mark.asyncio
async def test_get_<resource>_not_found(async_client: AsyncClient):
    response = await async_client.get("/api/<resources>/00000000-0000-0000-0000-000000000000")
    assert response.status_code == status.HTTP_404_NOT_FOUND
```

## Exemplo Bom

```python
@router.post(
    "/",
    response_model=UserResponse,
    status_code=status.HTTP_201_CREATED,
    summary="Criar usuário",
)
async def create_user(
    data: UserCreate,
    service: UserService = Depends(get_user_service),
):
    """Cria um novo usuário no sistema."""
    return await service.create(data)
```
**Por que é bom**: response_model define exactly what is returned (avoids PII leak), status_code explícito, dependency injection, docstring.

## Exemplo Ruim

```python
@router.post("/users")
async def create_user(data: dict):
    return await service.create(data)
```
**Por que é ruim**: Usa `dict` em vez de Pydantic schema — sem validação, sem type hints, expõe tudo que vier no body. Sem response_model, sem status_code explícito.

```python
@router.post("/users", status_code=201)
async def create_user(data: UserCreate):
    user = await service.create(data)
    return user.dict()
```
**Por que é ruim**: `user.dict()` é Pydantic v1 syntax. Em v2 deve ser `model_dump()`. Sem docstring, sem dependency injection para service.

## Gotchas

- **G1**: Sempre use `response_model=<Schema>` para definir exactly what is returned — evita vazamento de campos internos ou PII. O FastAPI usa o schema para filtrar a saída.
- **G2**: Use `async def` por padrão — FastAPI roda em asyncio. Se precisar de sync I/O (blocking DB driver), use `def` normal e considere migrar para async driver.
- **G3**: Use `Depends()` para injeção de dependências — facilita testabilidade com override de dependências no pytest.
- **G4**: Sempre defina `status_code` explícito — especialmente para POST (201), DELETE (204). Default 200 pode ser confuso.
- **G5**: Em Pydantic v2, use `model_dump()` em vez de `dict()`, `model_validate()` em vez de `parse_obj()`.
- **G6**: Exception handlers customizados devem ser registrados ANTES de `app.include_router()`.
- **G7**: Routers devem ser registrados com `prefix` e `tags` para documentação OpenAPI limpa.

## Quando NÃO usar

- **Edição de rota existente** — modifique diretamente o arquivo do router
- **Endpoints simples de health check** — podem ser definidos inline no main.py
- **Webhooks** — use skill específica se houver para webhook handling
