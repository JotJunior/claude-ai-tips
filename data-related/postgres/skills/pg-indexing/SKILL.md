---
name: pg-indexing
description: Design and implement PostgreSQL indexing strategies including B-tree, GIN, GiST, BRIN, partial, expression, and covering indexes. Use when asked to add index postgres, index strategy, covering index, partial index, composite index, postgres index types.
allowed-tools:
  - Read
  - Glob
  - Grep
  - Bash
---

# PostgreSQL Indexing Strategies

Design and implement effective PostgreSQL indexes for query performance optimization.

## Trigger Phrases

"add index postgres", "index strategy", "covering index", "partial index", "composite index", "postgres index types", "GIN index", "BRIN index", "index performance"

## Pre-Flight Checks

1. Identify the target table: `SELECT count(*) FROM table_name;`
2. Check existing indexes: `pg_indexes` or `\d table_name`
3. Check index usage: `pg_stat_user_indexes` (idx_scan = 0 means unused)
4. Understand the query pattern: SELECT, INSERT, UPDATE, DELETE ratios
5. Identify the constraint type: PK, FK, UNIQUE, or pure performance index

## Index Types Overview

| Type | Use Case | Can't Do |
|------|----------|----------|
| **B-tree** (default) | Equality, range,排序 | Full-text search, arrays |
| **GIN** | Arrays, JSONB, full-text search | Range queries |
| **GiST** | Range types, geospatial, full-text | Equality only |
| **BRIN** | Time-series, append-only, physical order | Random access |
| **Hash** | Equality only (disk-based) | Range, sorting |

## Workflow

### Step 1: Identify Query Patterns

```sql
-- Common patterns to index:
-- 1. WHERE clause columns
WHERE status = 'pending'
WHERE customer_id = 123 AND status = 'active'
WHERE created_at > '2024-01-01'

-- 2. JOIN columns
JOIN orders ON customers.id = orders.customer_id

-- 3. ORDER BY columns
ORDER BY created_at DESC

-- 4. GROUP BY columns
GROUP BY status

-- Check frequency of each pattern
SELECT query, calls FROM pg_stat_statements ORDER BY calls DESC;
```

### Step 2: Choose the Right Index Type

```sql
-- B-tree (default): Equality and range
CREATE INDEX idx_orders_customer_id ON orders(customer_id);
CREATE INDEX idx_orders_created_at ON orders(created_at DESC);

-- GIN: Arrays and JSONB
CREATE INDEX idx_products_tags ON products USING GIN(tags);
CREATE INDEX idx_events_data ON events USING GIN(data jsonb_path_ops);

-- GiST: Range types and geospatial
CREATE INDEX idx_reservations_daterange ON reservations
    USING GIST (daterange(check_in, check_out));

-- BRIN: Time-series, append-only tables
CREATE INDEX idx_logs_created_at ON logs USING BRIN(created_at);

-- Hash: Large equality-only columns (rarely needed, use B-tree instead)
CREATE INDEX idx_sessions_token ON sessions USING HASH(token);
```

### Step 3: Design Composite Index Column Order

**Rules:**
1. Most selective column first (for equality conditions)
2. Columns used in equality comparisons before range columns
3. For ORDER BY, match index column order and direction

```sql
-- Pattern: WHERE status = 'pending' AND customer_id = 123 ORDER BY created_at DESC
-- Good: equality first, then range/sort
CREATE INDEX idx_orders_status_cid_created 
    ON orders(status, customer_id, created_at DESC);

-- Pattern: WHERE customer_id = 123 AND created_at > '2024-01-01'
-- Good: equality first, then range
CREATE INDEX idx_orders_cid_created 
    ON orders(customer_id, created_at);
```

### Step 4: Create Partial Indexes for Selective Queries

```sql
-- Index only active orders (smaller, faster)
CREATE INDEX idx_orders_pending 
    ON orders(created_at DESC) 
    WHERE status = 'pending';

-- Index only large orders
CREATE INDEX idx_orders_large_total 
    ON orders(customer_id) 
    WHERE total > 10000;

-- Index soft-deleted records (rarely accessed)
CREATE INDEX idx_members_deleted 
    ON members(deleted_at) 
    WHERE deleted_at IS NOT NULL;
```

### Step 5: Create Expression Indexes for Function Calls

```sql
-- Lowercase email lookup
CREATE INDEX idx_users_email_lower ON users(lower(email));

-- Date extraction
CREATE INDEX idx_orders_year ON orders(EXTRACT(YEAR FROM created_at));

-- JSONB extraction
CREATE INDEX idx_events_user_id ON events((data->>'user_id'));
```

### Step 6: Create Covering Indexes to Avoid Heap Access

```sql
-- Include frequently accessed columns to avoid table heap lookup
CREATE INDEX idx_orders_covering 
    ON orders(customer_id) 
    INCLUDE (status, total, created_at);

-- Now this query uses only the index
SELECT status, total FROM orders WHERE customer_id = 123;
```

### Step 7: Create Unique Constraints (Auto-Indexes)

```sql
-- UNIQUE creates a unique B-tree index automatically
ALTER TABLE users ADD CONSTRAINT uk_users_email UNIQUE (email);

-- For JSONB unique on specific key
CREATE UNIQUE INDEX idx_users_external_id 
    ON users((data->>'external_id'));
```

## Index Maintenance

```sql
-- Check index usage (idx_scan = 0 means unused)
SELECT 
    schemaname,
    tablename,
    indexname,
    idx_scan,
    idx_tup_read,
    idx_tup_fetch
FROM pg_stat_user_indexes
WHERE schemaname = 'public'
ORDER BY idx_scan ASC;

-- Find bloat and reindex if needed
SELECT 
    schemaname, tablename, indexname,
    pg_size_pretty(pg_relation_size(indexrelid)) AS index_size,
    idx_scan
FROM pg_stat_user_indexes
WHERE idx_scan = 0
  AND indexrelid NOT IN (SELECT conindid FROM pg_constraint);

-- Reindex without locking (Postgres 12+)
REINDEX INDEX CONCURRENTLY idx_orders_customer_id;

-- Monitor index size
SELECT 
    indexname,
    pg_size_pretty(pg_relation_size(indexrelid))
FROM pg_stat_user_indexes
WHERE schemaname = 'public';
```

## Index Creation Best Practices

```sql
-- Concurrent index creation (no table lock) - for production
CREATE INDEX CONCURRENTLY idx_orders_new ON orders(customer_id);

-- Include table name in index for clarity
CREATE INDEX idx_members_email ON members(email);

-- Specify index tablespace for large indexes
CREATE INDEX idx_logs_data ON logs(data) TABLESPACE index_tbs;

-- Using if not exists to make idempotent
CREATE INDEX IF NOT EXISTS idx_members_email ON members(email);
```

## Common Patterns

| Pattern | Index |
|---------|-------|
| `WHERE email = '...'` | `CREATE INDEX ON users(email)` |
| `WHERE status = 'X' AND created > '...'` | `CREATE INDEX ON orders(status, created_at)` |
| `WHERE data @> '{"key":"value"}'` | `CREATE INDEX ON events USING GIN(data)` |
| `WHERE tags && ARRAY['a','b']'` | `CREATE INDEX ON products USING GIN(tags)` |
| `WHERE tsvector @@ tsquery` | `CREATE INDEX ON documents USING GIN(search_vector)` |
| `WHERE id IN (SELECT ...)` | Usually doesn't need special index; ensure FK index exists |
| `ORDER BY created_at DESC` | `CREATE INDEX ON orders(created_at DESC)` |
| `WHERE lower(email) = '...'` | `CREATE INDEX ON users(lower(email))` |

## Gotchas

1. **Each index adds write overhead**: Every INSERT/UPDATE/DELETE must update all indexes. Too many indexes = slow writes.

2. **NULL ordering with NULLS FIRST/LAST**: B-tree can order NULLs either way. `CREATE INDEX ON orders(created_at DESC NULLS LAST)`.

3. **Multi-column index more selective than single column**: A composite index on (status, customer_id) cannot replace only the customer_id index unless status is in equality queries.

4. **REINDEX CONCURRENTLY for production rebuild**: Use `REINDEX INDEX CONCURRENTLY` (PG13+) to rebuild without taking the table offline.

5. **pg_stat_user_indexes for usage analysis**: Indexes with `idx_scan = 0` are unused and should be dropped (unless they're for constraints).

6. **BRIN only works for naturally ordered data**: BRIN indexes are small but only effective for append-only tables where new rows have higher column values (like timestamps).

7. **GIN index slow build**: GIN indexes take significantly longer to build than B-tree. For large tables, consider `CONCURRENTLY` to avoid long locks.

8. **Expression indexes must match function exactly**: If you query `lower(email)`, the index must be on `lower(email)`, not on `email` alone.

9. **Unique constraint = unique index**: Adding a UNIQUE constraint creates an index. Don't add a separate duplicate index.

10. **Partial index only covers indexed rows**: If you have `WHERE status = 'pending'` and query `WHERE status = 'pending' AND customer_id = 123`, the partial index works but `WHERE customer_id = 123` alone cannot use it.

## When NOT to Use This Skill

- When you need to optimize a specific slow query (use `pg-query-optimize`)
- When you need to design a new schema (use `pg-schema-design`)
- When you need to create migrations (use `pg-add-migration`)
- When you need to review existing indexes (use `pg-review-schema`)
