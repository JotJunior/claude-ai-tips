# language-related/

Skills, hooks e convenções **específicas de linguagem/ecossistema de programação**.

## Propósito

Agrupa o conhecimento que muda quando você troca de linguagem — padrões de
código, ferramentas de build, convenções de nomenclatura, estilos de teste,
linters e formatadores, gestão de dependências.

## Critério de inclusão

Uma skill entra aqui quando responde à pergunta:

> **"Como o código é escrito nesta linguagem/ecossistema?"**

Exemplos: scaffold de módulos, commits com convenções específicas da stack,
geração de testes idiomáticos, revisão de qualidade de código.

## Quando NÃO entra aqui (vai para outra categoria)

| Se a skill é sobre... | Categoria correta |
|---|---|
| onde o código **roda** (runtime, plataforma de execução) | `platform-related/` |
| como **consumir** um serviço externo (DB, search, cache, fila) | `data-related/` |
| pipeline SDD, processo, governança agnóstica | `global/skills/` |

## Subpastas

| Subpasta | Linguagem/Ecossistema | Status | Cobertura |
|---|---|---|---|
| [`go/`](./go/) | Go | estável | 8 skills + 4 hooks (Fiber, D1 prep, migrations, testes, PR review) |
| [`dotnet/`](./dotnet/) | .NET 10 | estável | 8 skills (hexagonal, CQRS, EF Core, testes) |
| [`typescript/`](./typescript/) | TypeScript | planejada | commits, scaffold DDD, gates lint/typecheck, review de PR |
| [`python/`](./python/) | Python 3.10+ | planejada | FastAPI, Pydantic v2, mypy strict, pytest |

## Anatomia de uma subpasta

Cada subpasta segue o mesmo shape:

```
<linguagem>/
├── README.md           # overview da cobertura
├── settings.json       # hooks registrados (PreToolCall, PostToolCall, Stop)
├── hooks/              # shell scripts de gate automático
├── skills/             # skills invocáveis (cada uma com SKILL.md)
├── references/         # catálogos/guias consultados sob demanda
└── examples/           # good.md vs bad.md por tópico
```

## Como adicionar uma nova linguagem

1. Criar pasta `<linguagem>/` com o shape acima
2. Escrever `README.md` listando skills e hooks planejados
3. Começar por `<prefix>-commit` (convenção de commits da stack) — maior ROI
4. Adicionar hooks essenciais (`typecheck-gate`, `lint-gate`) registrados em `settings.json`
5. Documentar aqui no README de categoria

## Convenções transversais

- **Frontmatter YAML** das skills segue o padrão: `name`, `description` (como
  trigger-condition, não resumo), `argument-hint`, `allowed-tools`
- **Nomenclatura de skills**: `<prefix>-<verb>-<object>` (ex: `go-add-entity`,
  `ts-commit`, `py-add-fastapi-route`); prefix alinhado à subpasta
- **Scripts POSIX** (`.sh`) para operações determinísticas (cálculo de IDs,
  scaffold, validação) — evita alucinação e economiza tokens
- **`config.json`** por skill quando parâmetros variam entre projetos

## Ver também

- [`platform-related/`](../platform-related/) — plataformas onde o código roda
- [`data-related/`](../data-related/) — serviços consumidos pelo código
- [`global/skills/`](../global/skills/) — skills agnósticas de linguagem
