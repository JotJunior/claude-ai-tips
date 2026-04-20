# data-related/d1/

Skills para Cloudflare D1 (SQLite distribuído globalmente). Query patterns,
batch operations, FTS5 setup, prepared statements. Limites: 10GB/db,
1000ms CPU/query, 50MB/blob.

## Skills

| Skill | Trigger principal | O que faz |
|-------|-------------------|-----------|
| [`d1-schema-design/`](./skills/d1-schema-design/) | `"d1 schema"` | STRICT tables + INTEGER PK + CHECK constraints |
| [`d1-query-batch/`](./skills/d1-query-batch/) | `"batch query"` | batch() API para reduzir round-trips em multi-statement |
| [`d1-fts5-setup/`](./skills/d1-fts5-setup/) | `"fts5"` | Virtual table FTS5 + bm25 ranking +同步 |
| [`d1-prepared-stmts/`](./skills/d1-prepared-stmts/) | `"prepared stmt"` | prepare().bind() obrigatorio — anti-SQLi pattern |
| [`d1-analytics-queries/`](./skills/d1-analytics-queries/) | `"analytics query"` | CTEs + window functions + JSON1 para aggregations |
| [`d1-migration-strategy/`](./skills/d1-migration-strategy/) | `"migration strategy"` | Migrations aditivas + backfill + multi-region rollout |

## Diferencas vs Postgres

| Aspecto | D1 | Postgres |
|---------|----|----------|
| Engine | SQLite (libsqlite3) | PostgreSQL 15+ |
| Extensions | Nenhuma (stdlib only) | PostGIS, pg_vector, etc. |
| BOOLEAN | INTEGER (0/1) | native BOOLEAN |
| UUID | TEXT (store como string) | native UUID |
| TIMESTAMP | TEXT (ISO 8601) | TIMESTAMPTZ |
| Arrays | JSON array (TEXT) | native ARRAY |
| Constraints | CHECK, UNIQUE, NOT NULL | Full constraint set |
| Indexes | Partial via expression | Partial via WHERE |
| FTS | FTS5 virtual table | tsvector + GIN |
| Window functions | Sim | Sim |

## Conceitos-chave

- **STRICT tables:** modo rigoroso (type enforcement, NOT NULL)
- **INTEGER PRIMARY KEY:** RowID alias (performance)
- **batch():** executa múltiplas statements em uma chamada
- **FTS5:** virtual table para full-text search
- **JSON1:** funcoes para extrair e manipular JSON
- **Prepared statements:** params posicionais com `?` ou `?1`

## Limites

- **Database size:** 10GB max por database
- **CPU time:** 1000ms por query (edge) / 10000ms (hiper)
- **Blob size:** 50MB max por row/col
- **Request size:** 100MB max por request

## Como invocar

```
"crie schema D1 para tabela de users com soft delete"
"batch: insira 500 users de uma vez com batch()"
"fts5: configure busca em articles com ranking bm25"
"prepared stmt: query parametizada contra SQL injection"
"analytics: CTE com window function para running total"
"migration strategy: como migrar coluna sem downtime"
```

## Padroes-chave

- **STRICT tables:** sempre usar para type safety
- **INTEGER PK:** rowid alias, mais rapido que TEXT UUID
- **Prepared statements:** prepare().bind() para cada query
- **Batch para bulk:** usar batch() em vez de loop de statements
- **FTS5:** virtual table separada da tabela principal
- **No foreign keys:** D1 nao suporta FK constraints (manual enforcement)
- **Migrations aditivos:** adicionar colunas, nunca remover em v1
- **Soft delete:** deleted_at TEXT (ISO 8601), query com WHERE deleted_at IS NULL

## Ver tambem

- [`../../platform-related/cloudflare-workers/`](../../platform-related/cloudflare-workers/) — D1 bindings
- [`../../platform-related/cloudflare-shared/`](../../platform-related/cloudflare-shared/) — cf-api-call
- [`../postgres/`](../postgres/) — Postgres patterns (similarities)
