# language-related/python/

Conjunto de skills para projetos Python com FastAPI, Pydantic v2, structlog,
ruff e pytest. Foco em código — provisionamento de infraestrutura via
`platform-related/neon/` para Postgres serverless.

## Skills

| Skill | Trigger principal | O que faz |
|-------|-------------------|-----------|
| [`py-add-fastapi-route/`](./skills/py-add-fastapi-route/) | `"add route"` | Endpoint FastAPI com dependencia de injeção, response model, OpenAPI |
| [`py-add-pydantic-model/`](./skills/py-add-pydantic-model/) | `"add model"` | Modelo Pydantic v2 com validators, serializers, json_schema_options |
| [`py-add-structlog/`](./skills/py-add-structlog/) | `"add logging"` | Structured logging com structlog + contextvars (request_id, user_id) |
| [`py-add-test/`](./skills/py-add-test/) | `"add test"` | Testes pytest async com httpx AsyncClient + fixtures para FastAPI |
| [`py-commit/`](./skills/py-commit/) | `"commit"` | Conventional commits semânticos (feat/fix/refactor/docs/test/chore) |
| [`py-review-pr/`](./skills/py-review-pr/) | `"review pr"` | Checklist: mypy strict, ruff check, coverage >80%, test paths |
| [`py-setup-project/`](./skills/py-setup-project/) | `"setup project"` | Bootstrap projeto moderno com uv, ruff, mypy, pytest-asyncio |
| [`py-upgrade-pkg-manager/`](./skills/py-upgrade-pkg-manager/) | `"migrate to uv"` |Migração pip/poetry/pyenv → uv (lockfile, pyproject.toml, install) |

## Hooks

| Hook | Quando dispara | O que valida |
|------|----------------|--------------|
| `py-typecheck-gate.sh` | PostToolCall Write\|Edit | `uv run mypy` —零点 tolerancia a type errors |
| `py-lint-gate.sh` | PostToolCall Write\|Edit | `uv run ruff check` — zero warnings, F541 proibido |

## Stack alvo / Conceitos

- **Framework:** FastAPI + Pydantic v2 (model_validate, ConfigDict)
- **Logging:** structlog + stdlib logging bridge + JSON output
- **Linter:** ruff (F/E/W rules, pyproject.toml config)
- **Type checker:** mypy strict (disallow-any-decorated, disallow-untyped-defs)
- **Testing:** pytest + pytest-asyncio + httpx AsyncClient
- **Package manager:** uv (fast, deterministic, lockfile universal)
- **Migrations:** Alembic (branch-based, revision IDs)
- **Async:** uvloop + httpx (somente bibliotecas compatíveis)

## Como invocar

```
"crie uma rota GET /users/{user_id} com Pydantic response model"
"add route POST /orders com validacao de itens e cálculo de total"
"adicione logging estruturado com request_id para o modulo de checkout"
"add test para o endpoint de listagem de produtos com pagination"
"commit dessas mudanças — fix: corrigir timezone em created_at"
"review pr: verifique se todos os validators Pydantic estão cobertos"
"setup project com uv — precisa de pyproject.toml, ruff, mypy, pytest"
```

## Padroes-chave

- **Commits semânticos:** tipo(scope): descricao — nunca commit genérico
- **Pydantic v2 only:** model_validate_json, ConfigDict, model_validator
- **Dependency injection:** FastAPI Depends() com typing, nunca globals
- **Structured logs:** JSON com context fields (request_id, user_id, service)
- **Async-first:** tutte funzioni che accedono a DB/redis sono async
- **Ruff over flake8/isort:** .ruff.toml ou [tool.ruff] no pyproject.toml
- **Mypy strict:** --disallow-untyped-defs, --disallow-any-decorated
- **Test fixtures:** scoped por module, reuse em conftest.py
- **Soft delete:** deleted_at IS NOT NULL — nunca DELETE
- **PII truncado:** logs mostram `***` para dados pessoais sensíveis

## Ver tambem

- [`../../platform-related/neon/`](../../platform-related/neon/) — Postgres Neon (provisionamento)
- [`../../data-related/postgres/`](../../data-related/postgres/) — Postgres queries e padrões
- [`../../global/skills/cred-store/`](../../global/skills/cred-store/) — gestao de credenciais
