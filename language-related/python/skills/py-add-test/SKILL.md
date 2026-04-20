---
name: py-add-test
description: |
  Cria teste pytest com pytest-asyncio e httpx AsyncClient para APIs FastAPI.
  Use quando o usuário disser "add test", "novo teste", "pytest test", "criar teste",
  "testar endpoint", "coverage", "escrever testes".
  NÃO use quando for testar lógica de negócio pura sem API (use skill de test específica).
allowed-tools: [Read, Write, Edit, Glob, Grep, Bash]
---

# Adicionar Teste pytest

Gera testes de API com pytest, pytest-asyncio e httpx AsyncClient para aplicações FastAPI.

## Intro

Testes bem estruturados são a rede de segurança do código. pytest é o framework
padrão para projetos Python, e pytest-asyncio permite testar código assíncrono
(FastAPI endpoints) de forma natural. O padrão AAA (Arrange-Act-Assert) com fixtures
reutilizáveis e mocks estratégicos é o caminho para testes legíveis e rápidos.

Este skill assume FastAPI como framework web, pytest-asyncio para testes async,
httpx para client HTTP, e factory_boy ou pytest-factoryboy para fixture generation.

## Pre-flight Reads

Antes de gerar QUALQUER código de teste, leia em paralelo:
- `app/main.py` — para entender a app e seus exception handlers
- `tests/conftest.py` — fixtures existentes, AsyncClient setup
- `tests/` (ls) — ver estrutura de testes existentes
- O módulo que será testado — entenda toda a superfície de API

## Workflow

### 1. Configurar conftest.py (primeira vez ou atualizar)

Se `tests/conftest.py` não existir, crie:

```python
import pytest
from typing import AsyncGenerator
from httpx import AsyncClient, ASGITransport
from app.main import app
from app.db.session import get_db, engine
from app.models import Base


@pytest.fixture(scope="session")
def anyio_backend():
    return "asyncio"


@pytest.fixture(scope="session")
async def _setup_db():
    """Cria todas as tabelas uma vez por sessão de teste."""
    async with engine.begin() as conn:
        await conn.run_sync(Base.metadata.create_all)
    yield
    async with engine.begin() as conn:
        await conn.run_sync(Base.metadata.drop_all)


@pytest.fixture
async def async_client(_setup_db) -> AsyncGenerator[AsyncClient, None]:
    """AsyncClient configurado para a app FastAPI.
    
    Cada teste recebe um cliente isolado. O _setup_db fixture
    garante que o banco está preparado antes do primeiro teste.
    """
    async with AsyncClient(
        transport=ASGITransport(app=app),
        base_url="http://test",
    ) as client:
        yield client


@pytest.fixture
async def async_client_with_db(async_client: AsyncClient, _setup_db) -> AsyncClient:
    """Alias para async_client quando banco de teste é necessário."""
    return async_client
```

### 2. Adicionar Fixtures de Dados ( factories ou fixtures inline)

```python
# tests/factories.py
import uuid
from datetime import datetime, timezone

import pytest
from factory import Factory, Faker, LazyAttribute
from app.models.user import User


class UserFactory(Factory):
    """Factory para criar usuários de teste."""
    
    class Meta:
        model = User
    
    id: uuid.UUID = LazyAttribute(lambda _: uuid.uuid4())
    email: str = Faker("email")
    name: str = Faker("name")
    created_at: datetime = LazyAttribute(lambda: datetime.now(timezone.utc))
```

Ou como fixture direta:

```python
@pytest.fixture
def sample_user_data() -> dict:
    """Dados mínimos para criar um usuário."""
    return {
        "name": "João Silva",
        "email": "joao@example.com",
    }
```

### 3. Criar Test File — `tests/test_<module>.py`

```python
import pytest
from httpx import AsyncClient
from fastapi import status


pytestmark = pytest.mark.asyncio


class Test<Module>API:
    """Testes para endpoints de <module>."""
    
    async def test_create_success(self, async_client: AsyncClient, sample_data: dict):
        """Deve criar <resource> e retornar 201."""
        response = await async_client.post(
            "/api/<resources>/",
            json=sample_data,
        )
        
        assert response.status_code == status.HTTP_201_CREATED
        data = response.json()
        assert data["name"] == sample_data["name"]
        assert "id" in data
        assert "created_at" in data
    
    async def test_create_validation_error(self, async_client: AsyncClient):
        """Deve retornar 422 para payload inválido."""
        response = await async_client.post(
            "/api/<resources>/",
            json={"name": ""},  # name vazio viola constraint
        )
        
        assert response.status_code == status.HTTP_422_UNPROCESSABLE_ENTITY
        errors = response.json()["detail"]
        assert any(e["loc"] == ("body", "name") for e in errors)
    
    async def test_get_not_found(self, async_client: AsyncClient):
        """Deve retornar 404 para ID inexistente."""
        fake_id = "00000000-0000-0000-0000-000000000000"
        response = await async_client.get(f"/api/<resources>/{fake_id}")
        
        assert response.status_code == status.HTTP_404_NOT_FOUND
    
    async def test_list_pagination(self, async_client: AsyncClient):
        """Deve retornar lista paginada."""
        response = await async_client.get("/api/<resources>/?limit=10&offset=0")
        
        assert response.status_code == status.HTTP_200_OK
        data = response.json()
        assert "items" in data
        assert "total" in data
        assert "limit" in data
        assert "offset" in data
```

### 4. Testar Camada de Serviço (lógica de negócio)

```python
import pytest
from unittest.mock import AsyncMock, MagicMock
from app.services.<module>_service import <Module>Service
from app.schemas.<module> import <Module>Create


pytestmark = pytest.mark.asyncio


async def test_service_create_valid():
    """Service.create deve retornar domain model em sucesso."""
    mock_repo = AsyncMock()
    mock_repo.create.return_value = <DomainModel>(id=uuid.uuid4(), name="Test")
    
    service = <Module>Service(repo=mock_repo)
    data = <Module>Create(name="Test")
    
    result = await service.create(data)
    
    assert result.name == "Test"
    mock_repo.create.assert_awaited_once()


async def test_service_create_repo_error():
    """Service.create deve propagar erro do repositório."""
    mock_repo = AsyncMock()
    mock_repo.create.side_effect = Exception("DB connection failed")
    
    service = <Module>Service(repo=mock_repo)
    data = <Module>Create(name="Test")
    
    with pytest.raises(Exception, match="DB connection failed"):
        await service.create(data)
```

### 5. Usar Mock com pytest-mock (stub de dependências)

```python
async def test_handler_with_mocked_service(
    async_client: AsyncClient,
    mock_<module>_service: MagicMock,
):
    """Testa handler com service mockado."""
    mock_<module>_service.create = AsyncMock(return_value=<DomainModel>(...))
    
    response = await async_client.post(
        "/api/<resources>/",
        json={"name": "Test"},
    )
    
    assert response.status_code == status.HTTP_201_CREATED
```

### 6. Parametrize para Múltiplos Cenários

```python
import pytest

@pytest.mark.parametrize(
    "payload,expected_status",
    [
        ({"name": "Valid Name"}, status.HTTP_201_CREATED),
        ({"name": ""}, status.HTTP_422_UNPROCESSABLE_ENTITY),
        ({"name": "A" * 300}, status.HTTP_422_UNPROCESSABLE_ENTITY),
        ({}, status.HTTP_422_UNPROCESSABLE_ENTITY),
    ],
)
async def test_create_various_inputs(
    async_client: AsyncClient,
    payload: dict,
    expected_status: int,
):
    """Valida comportamento para diferentes inputs."""
    response = await async_client.post("/api/<resources>/", json=payload)
    assert response.status_code == expected_status
```

## Configuração pytest.toml

```toml
[tool.pytest.ini_options]
asyncio_mode = "auto"
asyncio_default_fixture_loop_scope = "session"
filterwarnings = [
    "ignore::DeprecationWarning",
]
```

## Exemplo Bom

```python
@pytest.mark.asyncio
async def test_get_user_returns_200_with_user_data(async_client: AsyncClient, user_factory):
    """Deve retornar dados do usuário em sucesso."""
    user = user_factory()
    
    response = await async_client.get(f"/api/users/{user.id}")
    
    assert response.status_code == 200
    assert response.json()["email"] == user.email
```
**Por que é bom**: Nome descritivo, usa factory para dados consistentes, assertion específica.

## Exemplo Ruim

```python
async def test_create():
    r = await client.post("/users/", json={"name": "test"})
    assert r.status_code == 201
```
**Por que é ruim**: Sem pytest.mark.asyncio (pode não rodar), nome vago, sem type hints, sem dados de setup organizados.

```python
def test_something():
    client = SyncClient(app=app)  # usando sync client em código async
    assert True
```
**Por que é ruim**: FastAPI endpoints são async — usar sync client perde a async nature e pode causar problemas de event loop.

## Gotchas

- **G1**: Sempre marque funções de teste com `@pytest.mark.asyncio` — sem isso, pytest-asyncio não executa como async.
- **G2**: Para isolar o banco de teste, use `_setup_db` com `async with engine.begin()` para create/drop tables. Use `async with AsyncClient(transport=ASGITransport(app=app))` para клиент.
- **G3**: `AsyncClient` com `ASGITransport` é preferível a `app.dependency_overrides[get_db]` — mais rápido e isolado.
- **G4**: Fixtures assíncronas devem usar `async def` e ser consumidas com `await`. pytest-asyncio mode="auto" remove necessidade de `await` explícito em muitos casos.
- **G5**: Use `factory_boy` ou `Factory` para dados consistentes e aleatórios — mais flexível que fixtures manuais.
- **G6**: Sempre cleanup recursos em `yield` dentro de fixtures — conexões de banco, arquivos temporários.
- **G7**: `parametrize` é seu amigo — evite duplicar testes para cada variação de input.

## Quando NÃO usar

- **Testes unitários puros de lógica de domínio** — pode usar unittest ou pytest direto sem AsyncClient
- **Edits em testes existentes** — modifique diretamente os arquivos de teste
- **Testes de performance/load** — use skill ou ferramenta específica (locust, pytest-benchmark)
- **Testes de integração com banco real** — prefira Testcontainers ou banco in-memory
