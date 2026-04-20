---
name: py-add-structlog
description: |
  Configura structured logging com structlog para APIs FastAPI.
  Use quando o usuário disser "add logging", "structlog setup", "configurar log", "structured log",
  "adicionar logs", "logging configurado".
  NÃO use quando for adicionar logs pontuais (use logger direto no código).
allowed-tools: [Read, Write, Edit, Glob, Grep, Bash]
---

# Configurar structlog

Configura structured logging com structlog para projetos Python modernos, com output JSON em produção e console-friendly em desenvolvimento.

## Intro

Logs estruturados são essenciais para debugging e observabilidade em produção. structlog
permite logs em formato JSON (parseável por Logstash, Datadog, CloudWatch) enquanto mantém
legibilidade em desenvolvimento com output colorido para o console. A包装 log entries
com contexto rico (request_id, user_id, operation) facilita correlacionar eventos.

Este skill assume FastAPI como framework web e structlog como biblioteca de logging.

## Pre-flight Reads

- `app/main.py` — para ver onde registrar middleware de logging
- `pyproject.toml` — verificar se structlog está instalado
- `app/` (ls) — ver se já existe app/logging.py ou similar

## Workflow

### 1. Instalar structlog

```bash
uv add structlog
# ou se pyproject.toml manual:
# structlog>=24.0.0
```

### 2. Criar Configuração Central — `app/logging.py`

```python
"""Configuração centralizada de logging estruturado."""
import logging
import sys
from typing import Any

import structlog
from structlog.types import Processor
from structlog.stdlib import add_log_level


def setup_logging(log_level: str = "INFO", json_logs: bool = False) -> None:
    """Configure structlog com processadores apropriados para o ambiente.
    
    Args:
        log_level: DEBUG, INFO, WARNING, ERROR
        json_logs: se True, saída em JSON (produção). se False, console colorido (desenvolvimento).
    """
    
    # Processadores comuns a todos os ambientes
    shared_processors: list[Processor] = [
        structlog.contextvars.merge_contextvars,
        structlog.stdlib.add_log_level,
        structlog.stdlib.add_logger_name,
        structlog.stdlib.PositionalArgumentsFormatter(),
        structlog.processors.TimeStamper(fmt="iso", utc=True),
        structlog.processors.StackInfoProcessor(),
        structlog.processors.UnicodeDecoder(),
    ]
    
    if json_logs:
        # Produção: JSON formatado
        shared_processors.extend([
            structlog.processors.format_exc_info,
            structlog.processors.JSONRenderer(serializer="json.dumps", mixed_event_keys=True),
        ])
    else:
        # Desenvolvimento: console colorido
        shared_processors.extend([
            structlog.dev.ConsoleRenderer(colors=True, exception_formatter=structlog.dev.plain_traceback),
        ])
    
    # Configure structlog
    structlog.configure(
        processors=shared_processors,
        wrapper_class=structlog.stdlib.BoundLogger,
        context_class=dict,
        logger_factory=structlog.stdlib.LoggerFactory(),
        cache_logger_on_first_use=True,
    )
    
    # Configure stdlib logging
    logging.basicConfig(
        format="%(message)s",
        stream=sys.stdout,
        level=getattr(logging, log_level.upper()),
    )


def get_logger(name: str | None = None) -> structlog.stdlib.BoundLogger:
    """Retorna logger instanciado.
    
    Sempre prefira esta função em vez de criar logger diretamente.
    Suporta contextvars para injeção de request_id automaticamente.
    
    Args:
        name: nome do logger (geralmente __name__ do módulo)
    
    Returns:
        Logger estruturado pronto para uso
    """
    return structlog.get_logger(name)


# Re-export para conveniência
StructLogger = structlog.stdlib.BoundLogger
```

### 3. Configurar Context Variables para Request ID

```python
"""Middleware para injetar request_id em todos os logs de uma requisição."""
import uuid
from contextlib import contextmanager

import structlog
from fastapi import Request, Response
from starlette.middleware.base import BaseHTTPMiddleware


structlog.contextvars.clear_contextvars()
structlog.contextvars.bind_contextvars(request_id=None, user_id=None)


class LoggingMiddleware(BaseHTTPMiddleware):
    """Middleware que injeta request_id em cada requisição."""
    
    async def dispatch(self, request: Request, call_next) -> Response:
        # Gera request_id único
        request_id = request.headers.get("X-Request-ID", str(uuid.uuid4()))
        
        # Bind ao contexto da requisição atual
        structlog.contextvars.bind_contextvars(request_id=request_id)
        
        # Adiciona ao response header para correlação
        response = await call_next(request)
        response.headers["X-Request-ID"] = request_id
        
        return response
```

### 4. Registrar Middleware no FastAPI — `app/main.py`

```python
from fastapi import FastAPI
from app.logging import setup_logging, get_logger
from app.middleware import LoggingMiddleware

# Configure logging no startup
setup_logging(log_level="INFO", json_logs=False)  # mudar para True em produção

app = FastAPI()
app.add_middleware(LoggingMiddleware)

log = get_logger(__name__)
```

### 5. Exemplo de Uso em Serviços

```python
"""Exemplo de uso em um serviço."""
import structlog
from app.logging import get_logger

log = get_logger(__name__)


class UserService:
    def __init__(self, repo: UserRepository):
        self._repo = repo
    
    async def create(self, data: UserCreate) -> User:
        log.info("Creating user", email=data.email)
        
        try:
            user = await self._repo.create(data)
            log.info("User created", user_id=str(user.id))
            return user
        except Exception as e:
            log.error("Failed to create user", email=data.email, error=str(e))
            raise
```

### 6. PII Redaction Processor

```python
"""Processor para redigir PII de logs."""
import re
from typing import Any

import structlog


PII_PATTERNS = {
    "cpf": re.compile(r"\b\d{3}\.\d{3}\.\d{3}-\d{2}\b"),
    "email": re.compile(r"\b[\w.-]+@[\w.-]+\.\w+\b"),
    "phone": re.compile(r"\b\d{2}[-.\s]?\d{4,5}[-.\s]?\d{4}\b"),
}


def redact_pii(value: str) -> str:
    """Redact PII patterns from a string value."""
    result = value
    for pii_type, pattern in PII_PATTERNS.items():
        result = pattern.sub(f"[REDACTED_{pii_type}]", result)
    return result


def pii_redaction_processor(
    logger: structlog.stdlib.Logger,
    method_name: str,
    event_dict: dict[str, Any],
) -> dict[str, Any]:
    """Processor que redige PII de todos os valores de event_dict."""
    redacted = {}
    for key, value in event_dict.items():
        if isinstance(value, str):
            redacted[key] = redact_pii(value)
        elif isinstance(value, dict):
            redacted[key] = {k: redact_pii(v) if isinstance(v, str) else v 
                           for k, v in value.items()}
        else:
            redacted[key] = value
    return redacted
```

Adicione à lista de processors:
```python
shared_processors.append(pii_redaction_processor)
```

## Exemplo Bom

```python
log.info(
    "user.created",
    user_id=str(user.id),
    email_domain=user.email.split("@")[1],
    operation="create",
)
# Output em dev: 2024-01-15 10:30:00 [info] user.created user_id=abc123 email_domain=example.com operation=create
# Output em prod: {"event": "user.created", "user_id": "abc123", "email_domain": "example.com", "operation": "create", "timestamp": "2024-01-15T10:30:00Z"}
```
**Por que é bom**: Keys consistentes em snake_case, estruturado, inclui contexto operacional.

## Exemplo Ruim

```python
print(f"[INFO] Creating user {data.email}")
# ou
logging.info(f"User created: {user}")
```
**Por que é ruim**: Output não-estruturado, impossível de parsear em produção, não inclui contexto correlacionável.

## Gotchas

- **G1**: Nunca criar logger no top-level do módulo com `logger = logging.getLogger(__name__)` — use `get_logger(__name__)` que retorna logger estruturado.
- **G2**: Em produção (JSON logs), NUNCA logue PII (CPF, email, phone) — use o processor de redação.
- **G3**: `structlog.contextvars.bind_contextvars()` é thread-safe e task-safe em asyncio — use para request_id, user_id.
- **G4**: `get_logger()` deve ser chamado após `setup_logging()` no main.py — chame no startup event.
- **G5**: Em testes, fixtures de logging podem capturar logs — use `caplog` fixture do pytest para assertions.
- **G6**: Log level deve ser configurável via environment variable (`LOG_LEVEL`, `JSON_LOGS`) para 不同 environments.
- **G7**: `structlog.stdlib.BoundLogger` é compatível com logging padrão — qualquer library que use `logging.getLogger()` funciona.

## Quando NÃO usar

- **Logs pontuais de debug** — logger direto com `log.debug()` é suficiente
- **Aplicações sem framework web** — configuração pode variar, mas princípios是一样的
- **Edição de logging existente** — modifique diretamente app/logging.py ou o serviço
- **Logging em bibliotecas** — bibliotecas devem usar `logging.getLogger()` padrão (sem structlog configurado)
