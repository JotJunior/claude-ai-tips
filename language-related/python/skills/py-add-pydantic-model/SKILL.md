---
name: py-add-pydantic-model
description: |
  Cria Pydantic v2 model com validators, Field constraints e ConfigDict.
  Use quando o usuário disser "add model", "novo schema", "pydantic model", "criar dto",
  "adicionar validação", "criar schema pydantic".
  NÃO use quando for apenas editar schema existente (use outra skill).
allowed-tools: [Read, Write, Edit, Glob, Grep, Bash]
---

# Adicionar Model Pydantic v2

Gera um Pydantic v2 model completo com validators, constraints de campo e configuração ORM.

## Intro

Pydantic v2 trouxe breaking changes significativos em relação à v1: `Config` inner
class foi substituído por `model_config = ConfigDict(...)`, validators mudaram de
nome e comportamento, e o método `dict()` foi substituído por `model_dump()`. Modelos
bem estruturados são a primeira linha de defesa contra dados inválidos — antes mesmo
de chegar ao banco de dados.

Este skill cobre tanto Request DTOs (validação de input) quanto Response DTOs
(controle de output), incluindo a configuração para integração ORM (SQLAlchemy,
SQLModel).

## Pre-flight Reads

- `app/schemas/` (ls) — verificar padrões existentes de schemas
- `app/models/` ou `app/db/` — verificar modelos de domínio/ORM se existirem
- `pyproject.toml` — verificar versão do Pydantic instalada
- Documentação oficial: https://docs.pydantic.dev/latest/

## Workflow

### 1. Identificar tipo de model

Determine se é um:
- **Request DTO** — validação de input da API (UserCreate, OrderUpdate)
- **Response DTO** — controle de output da API (UserResponse, OrderList)
- **Internal DTO** — comunicação interna entre serviços

### 2. Criar Schema Base — `app/schemas/<resource>.py`

```python
from datetime import datetime
from uuid import UUID
from typing import Annotated

from pydantic import (
    BaseModel,
    ConfigDict,
    Field,
    field_validator,
    model_validator,
    AliasChoices,
)


# ────────────────────────────────────────────────────────────────
# Request DTOs
# ────────────────────────────────────────────────────────────────

class <Resource>Create(BaseModel):
    """Schema para criação de <resource>. Valida input da API."""
    
    name: str = Field(
        min_length=1,
        max_length=255,
        description="Nome do recurso",
        examples=["Exemplo de nome"],
    )
    description: str | None = Field(
        default=None,
        max_length=1000,
    )
    category: Annotated[str, Field(min_length=1, max_length=50)]
    
    @field_validator("name", "category")
    @classmethod
    def strip_whitespace(cls, v: str) -> str:
        return v.strip()
    
    @field_validator("name")
    @classmethod
    def name_no_special_chars(cls, v: str) -> str:
        if any(c in v for c in "!@#$%^&*()_+-=[]{}|;':\",./<>?"):
            raise ValueError("Nome não pode conter caracteres especiais")
        return v


class <Resource>Update(BaseModel):
    """Schema para atualização parcial. Campos opcionais."""
    
    name: str | None = Field(default=None, min_length=1, max_length=255)
    description: str | None = Field(default=None, max_length=1000)
    
    @field_validator("name")
    @classmethod
    def name_if_provided(cls, v: str | None) -> str | None:
        if v is not None:
            v = v.strip()
            if not v:
                raise ValueError("Nome não pode ser vazio se fornecido")
        return v


# ────────────────────────────────────────────────────────────────
# Response DTOs
# ────────────────────────────────────────────────────────────────

class <Resource>Response(BaseModel):
    """Schema para resposta da API. Controla campos expostos."""
    
    model_config = ConfigDict(
        from_attributes=True,        # aceita objetos ORM
        str_strip_whitespace=True,   # strip em todos os strings
        populate_by_name=True,       # aceita alias ou nome do campo
    )
    
    id: UUID
    name: str
    description: str | None = None
    created_at: datetime
    updated_at: datetime | None = None


class <Resource>ListResponse(BaseModel):
    """Schema para listagem paginada."""
    
    model_config = ConfigDict(from_attributes=True)
    
    items: list[<Resource>Response]
    total: int
    limit: int
    offset: int
```

### 3. Adicionar ConfigDict para Settings (se necessário)

```python
from pydantic import BaseModel, SecretStr, Field


class Settings(BaseModel):
    """Configurações da aplicação via environment variables."""
    
    model_config = ConfigDict(
        env_file=".env",
        env_file_encoding="utf-8",
        case_sensitive=False,
        extra="ignore",  # ignora fields extras no .env
    )
    
    database_url: SecretStr = Field(description="Connection string do banco")
    secret_key: SecretStr
    api_key: str | None = None
    debug: bool = Field(default=False)
```

### 4. Model com Frozen (Imutabilidade)

```python
class <Resource>Summary(BaseModel):
    """Schema imutável para dados que não devem ser modificados."""
    
    model_config = ConfigDict(frozen=True)  # não pode ser modificado após criação
    
    id: UUID
    name: str
    created_at: datetime
```

### 5. Model com Alias Generator (camelCase output)

```python
def to_camel(string: str) -> str:
    """Converte snake_case para camelCase."""
    components = string.split("_")
    return components[0] + "".join(x.title() for x in components[1:])


class <Resource>CamelCase(BaseModel):
    """Response com camelCase para APIs que esperam JS-style keys."""
    
    model_config = ConfigDict(
        from_attributes=True,
        alias_generator=to_camel,
        populate_by_name=True,
    )
    
    id: UUID
    first_name: str = Field(alias="firstName")
    last_name: str = Field(alias="lastName")
    created_at: datetime = Field(alias="createdAt")
```

### 6. Model Validator para Lógica Cross-Field

```python
class OrderCreate(BaseModel):
    """Order com validação que depende de múltiplos campos."""
    
    product_id: UUID
    quantity: int = Field(gt=0, le=1000)
    unit_price: Decimal = Field(ge=0)
    discount_percent: float = Field(default=0, ge=0, le=100)
    
    @model_validator(mode="after")
    def validate_discount(self) -> "OrderCreate":
        """Aplica discount apenas se quantity >= 10."""
        if self.quantity < 10:
            self.discount_percent = 0.0
        elif self.discount_percent > 50:
            raise ValueError("Desconto máximo de 50% para pedidos")
        return self
    
    @property
    def total_amount(self) -> Decimal:
        subtotal = self.quantity * self.unit_price
        discount = subtotal * Decimal(str(self.discount_percent / 100))
        return subtotal - discount
```

## Exemplo Bom

```python
class UserCreate(BaseModel):
    """Schema para criação de usuário."""
    
    email: str = Field(min_length=5, max_length=255)
    name: str = Field(min_length=1, max_length=100)
    
    @field_validator("email")
    @classmethod
    def email_lowercase(cls, v: str) -> str:
        v = v.strip().lower()
        if "@" not in v:
            raise ValueError("Email inválido")
        return v
```
**Por que é bom**: Validação semântica do email (lowercase, @ check), constraints numéricos claros, documentation com Field description.

## Exemplo Ruim

```python
class UserCreate(BaseModel):
    email: str  # sem validação, sem constraints
    name: str
```
**Por que é ruim**: Sem `Field()` constraints, sem validator, aceita qualquer string ("", whitespace, uppercase email).

```python
class Config:
    str_strip_whitespace = True

class UserCreate(BaseModel):
    Config = Config  # Pydantic v1 syntax — não funciona em v2
```
**Por que é ruim**: `Config` inner class é Pydantic v1. Em v2 deve usar `model_config = ConfigDict(...)`.

```python
@field_validator("email")
def email_lowercase(v: str) -> str:  # missing @classmethod
    return v.lower()
```
**Por que é ruim**: Field validators em Pydantic v2 devem ser decorados com `@classmethod` ou `@staticmethod`.

## Gotchas

- **G1**: `Config` inner class é Pydantic v1 — em v2 use `model_config = ConfigDict(...)`.
- **G2**: `dict()` é Pydantic v1 — em v2 use `model_dump()` para dict e `model_dump_json()` para JSON string.
- **G3**: `validator()` é Pydantic v1 — em v2 use `@field_validator()` (para campo único) ou `@model_validator()` (cross-field).
- **G4**: `@field_validator` deve ter `@classmethod` (exceto se `@staticmethod` com `mode="after"`).
- **G5**: `from_attributes=True` é necessário para aceitar objetos ORM (SQLAlchemy models) como entrada.
- **G6**: `populate_by_name=True` permite que o campo seja preenchido tanto pelo nome real quanto pelo alias.
- **G7**: `frozen=True` no ConfigDict torna o model imutável — útil para Response DTOs que não devem ser modificados.

## Quando NÃO usar

- **Models simples sem validação** — um dataclass ou TypedDict pode ser suficiente
- **Configurações de aplicação** — use `pydantic_settings.BaseSettings` com `pydantic-settings` package
- **Modelos de domínio puros** — considere SQLModel ou SQLAlchemy models diretamente
- **Edição de schema existente** — modifique diretamente o arquivo do schema
