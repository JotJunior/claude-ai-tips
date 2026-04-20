# language-related/python

Skills relacionadas a desenvolvimento em **Python** — convenções, padrões, ferramentas e boas práticas para uso pelo Claude Code.

> **Status**: scaffold inicial. Skills serão adicionadas conforme demanda real dos projetos.

## Escopo

Skills nesta pasta cobrem **como código Python é escrito**, não como serviços Python são provisionados ou consumidos. Para isso, veja:

- `platform-related/` — provisionamento (containers, Lambda, etc.)
- `data-related/` — consumo de bancos/serviços a partir de Python

## Princípios

- **PEP 8** para estilo, **PEP 484** para type hints
- **SOLID** e **DRY** rigorosamente aplicados
- Type hints obrigatórios em código de produção
- `ruff` para lint, `black` para format, `mypy` para type-check
- Testes com `pytest`, mocks com `unittest.mock` ou `pytest-mock`
- Dependências gerenciadas com `pyproject.toml` (PEP 621)

## Skills planejadas

Serão adicionadas conforme necessidade. Exemplos de candidatos:

- Setup de projeto Python moderno (pyproject.toml, ruff, mypy, pytest)
- Convenções de packaging e distribuição
- Padrões de async/await com asyncio
- Estrutura de testes com pytest

## Contribuindo

Veja `docs/contributing.md` na raiz do repositório.

## Veja também

- `language-related/README.md` — visão geral da categoria
- `language-related/typescript/` — equivalente para TypeScript
- `language-related/go/` — exemplo de categoria madura
- `docs/architecture.md` — taxonomia completa
