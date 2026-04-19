# data-related/

Skills, hooks e convenções **específicas do consumo de serviços externos de dados/mensageria/busca**.

## Propósito

Agrupa o conhecimento que muda quando você troca o serviço consumido (banco,
search engine, cache, fila, vector store) — linguagem de query, DSL,
modelagem, padrões de indexação, estratégias de performance, gotchas de
consistência, clientes SDK.

## Critério de inclusão

Uma skill entra aqui quando responde à pergunta:

> **"Como meu código fala com este serviço já provisionado?"**

Exemplos: escrever query SQL, indexar em ES, modelar documento Mongo,
padrão de cache Redis, bulk operations, handling de eventual consistency,
patterns de consumer de fila.

## Quando NÃO entra aqui (vai para outra categoria)

| Se a skill é sobre... | Categoria correta |
|---|---|
| como **escrever** o código cliente | `language-related/` |
| como **provisionar** o recurso (criar DB, fila, bucket) | `platform-related/` |

## Dicotomia "ops vs consumo" — regra prática

Se o comando envolve `wrangler`, `psql -c CREATE`, `curl POST /_cluster`,
`kafka-topics.sh --create` — é **ops**, vai para `platform-related/`.

Se envolve `SELECT`, `INSERT`, query DSL, mapping, aggregate pipeline, bulk
index, pub/sub — é **consumo**, vai aqui.

## Subpastas planejadas

| Subpasta | Serviço | Status | Cobertura |
|---|---|---|---|
| [`postgres/`](./postgres/) | PostgreSQL (genérico; Neon/Supabase/RDS como variants) | planejada | schema design, indexing, JSONB, FTS, partitioning, EXPLAIN |
| [`d1/`](./d1/) | Cloudflare D1 (SQLite edge) | planejada | batch vs serial, FTS5, dialect limits, prepared statements |
| [`elasticsearch/`](./elasticsearch/) | Elasticsearch 8.x / 9.x | planejada | query DSL, aggregations, mapping, reindex zero-downtime, ILM |

### Subpastas futuras (quando houver demanda)

- `redis/` — cache, pub/sub, streams, Lua scripts
- `qdrant/` — vector search, filtering, HNSW params
- `mongo/` — schema-less patterns, aggregation pipeline
- `kafka/` — producer/consumer patterns, compaction
- `neo4j/` — Cypher, graph modeling

## Anatomia de uma subpasta

```
<servico>/
├── README.md
├── skills/
├── references/
│   ├── provider-<nome>.md   # variants (ex: provider-neon.md em postgres/)
│   ├── <dsl>-cheatsheet.md
│   └── breaking-changes.md
└── examples/
    ├── query-good.sql
    ├── query-bad.sql
    └── mapping-good.json
```

## Regras gerais para skills de consumo

1. **Credenciais via `global/skills/cred-store/`** — mesmo princípio do `platform-related/`
2. **Version awareness** obrigatória — drivers/clients mudam
   (ex: ES 7→8→9, Pydantic v1→v2, Drizzle API evolution)
3. **Provider-agnóstico no core, variants em `references/`** — evita
   explosão combinatória; ex: `postgres/skills/*` é genérico e
   `postgres/references/provider-neon.md` documenta cold start, pooler, HTTP driver
4. **Anti-patterns com exemplos `bad.md`** — consumo de dados é onde mais se erra
   em performance; catalogar erros recorrentes
5. **Sem operações destrutivas sem confirmação** — `DROP`, `DELETE FROM`
   sem `WHERE`, `DELETE_BY_QUERY` em ES, `FLUSHALL` em Redis exigem
   confirmação explícita e dry-run

## Como adicionar um novo serviço

1. Criar pasta `<servico>/` com o shape acima
2. README listando skills + variants suportadas + versões do cliente
3. Primeira skill costuma ser `<svc>-query-build` ou `<svc>-schema-design`
4. `references/<dsl>-cheatsheet.md` é o arquivo mais consultado — caprichar
5. Documentar aqui no README de categoria

## Ver também

- [`language-related/`](../language-related/) — skills por linguagem
- [`platform-related/`](../platform-related/) — skills de provisionamento
- [`global/skills/cred-store/`](../global/skills/cred-store/) — gestão agnóstica de credenciais
