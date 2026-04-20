# data-related/postgres/

Skills para PostgreSQL 15+ (agnostico de framework). Schema design, queries,
performance tuning, JSONB patterns, Full-Text Search, locking, partitioning.
Foco em COMO CONSUMIR dados — provisionamento via `platform-related/neon/`.

## Skills

| Skill | Trigger principal | O que faz |
|-------|-------------------|-----------|
| [`pg-schema-design/`](./skills/pg-schema-design/) | `"schema design"` | Modelo 3NF + tipos apropriados + colunas de auditoria |
| [`pg-add-migration/`](./skills/pg-add-migration/) | `"add migration"` | Migration SQL idempotente (up/down, IF EXISTS) |
| [`pg-query-optimize/`](./skills/pg-query-optimize/) | `"optimize query"` | EXPLAIN ANALYZE + sugere indexes + rewrites |
| [`pg-indexing/`](./skills/pg-indexing/) | `"add index"` | B-tree/GIN/GiST/BRIN/Hash + partial + covering indexes |
| [`pg-jsonb-patterns/`](./skills/pg-jsonb-patterns/) | `"jsonb"` | Operadores, GIN index, jsonb_path_query, update strategies |
| [`pg-fts-setup/`](./skills/pg-fts-setup/) | `"full-text search"` | tsvector + GENERATED COLUMN + bm25 ranking |
| [`pg-locking/`](./skills/pg-locking/) | `"lock"` | Lock types + advisory locks + SKIP LOCKED |
| [`pg-partitioning/`](./skills/pg-partitioning/) | `"partition"` | RANGE/LIST/HASH partitioning + pg_partman |
| [`pg-audit-query/`](./skills/pg-audit-query/) | `"audit query"` | Trigger + history table (JSONB diff) |
| [`pg-review-schema/`](./skills/pg-review-schema/) | `"review schema"` | Smell detection + checklist de melhores praticas |

## Stack / Conceitos

- **Postgres:** 15+ (JSONB, GENERATED COLUMNS, MERGE)
- **ORM patterns:** agnostic (Drizzle, Prisma, sqlalchemy, raw)
- **Migrations:** Alembic ou raw SQL (versioned, reversible)
- **Benchmarks:** pgbench, EXPLAIN ANALYZE, pg_stat_statements
- **Index types:** B-tree (default), Hash, GIN, GiST, BRIN, partial, covering

## Como invocar

```
"crie schema para tabela de pedidos com audit cols"
"add migration para adicionar index composed em orders(user_id, created_at)"
"optimize query: SELECT com JOINs lentos em analytics"
"jsonb: extraia campo nested e faca agregacao por ключ"
"full-text search: configure busca em conteudo de artigos"
"partitioning: divida tabela de logs por mes"
"audit query: trigger para historico de mudancas em cliente"
"review schema: verifica normalized ate 3NF e indexes"
```

## Padroes-chave

- **UUIDv7 como PK:** nunca auto-increment ou UUIDv4
- **Soft delete:** deleted_at IS NOT NULL — nunca DELETE
- **Audit columns:** created_at, updated_at obrigatorios em toda tabela
- **Idempotent migrations:** IF NOT EXISTS, DROP IF EXISTS
- **Index por query:** analisar com EXPLAIN antes de criar
- **JSONB:** usar ->> para extrair, nao -> (text vs json)
- **FTS:** tsvector com GENERATED COLUMN para atualizacao automatica
- **Locking:** usar SKIP LOCKED para producers/consumers
- **Partitioning:** RANGE por mes para logs/pedidos, LIST por tenant

## Ver tambem

- [`../../platform-related/neon/`](../../platform-related/neon/) — provisionamento
- [`../../language-related/typescript/`](../../language-related/typescript/) — Drizzle
- [`../../language-related/python/`](../../language-related/python/) — SQLAlchemy/Alembic
