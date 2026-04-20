---
name: pg-query-optimize
description: |
  Optimize slow PostgreSQL queries using EXPLAIN ANALYZE, index analysis, and query rewriting. Use when asked to optimize query postgres, query lenta, slow query, explain analyze, improve query performance.
  Use quando o usuário pedir: "otimizar query", "explain analyze", "query lenta", "postgres lento".
allowed-tools:
  - Read
  - Glob
  - Grep
  - Bash
---

# PostgreSQL Query Optimization

Optimize slow PostgreSQL queries using EXPLAIN ANALYZE, index analysis, and query rewriting techniques.

## Trigger Phrases

"optimize query postgres", "query lenta", "slow query", "explain analyze", "melhorar query", "query performance", "postgres optimizer"

## Pre-Flight Checks

1. Identify the slow query from logs, application traces, or user reports
2. Check Postgres version: `SELECT version();` (different optimizer features in different versions)
3. Check if query involves large tables: `SELECT count(*) FROM table_name;`
4. Verify statistics are up-to-date: `ANALYZE table_name;`
5. Check current indexes: `\d table_name` or `pg_indexes`

## Workflow

### Step 1: Capture the Query Plan with EXPLAIN ANALYZE

```sql
-- Basic EXPLAIN ANALYZE
EXPLAIN (ANALYZE, BUFFERS, FORMAT JSON) 
SELECT * FROM orders 
WHERE customer_id = 123 
  AND status = 'pending' 
ORDER BY created_at DESC;

-- For human-readable output
EXPLAIN (ANALYZE, BUFFERS, FORMAT TEXT) 
SELECT * FROM orders 
WHERE customer_id = 123 
  AND status = 'pending' 
ORDER BY created_at DESC;
```

### Step 2: Analyze the Plan Output

**Key indicators to look for:**

| Indicator | Meaning | Action |
|-----------|---------|--------|
| `Seq Scan` | Full table scan | Usually bad for large tables; add index |
| `Index Scan` | Using index correctly | Good |
| `Bitmap Heap Scan` | Index scan with bitmap memory | Acceptable for large result sets |
| `Nested Loop` | Row-by-row execution | OK for small result sets, bad for large |
| `Hash Join` | Building hash table | Good for large sets |
| `Sort` | External sort (disk) | Add index or increase work_mem |
| `WindowAggregate` | Window function | Usually OK |

**Critical metric: Estimated vs Actual rows**
```sql
-- If estimated rows >> actual rows, planner makes wrong decisions
-- This means statistics are stale or data distribution is skewed
-- Fix: ANALYZE table_name; or adjust statistics target
ALTER TABLE orders ALTER COLUMN customer_id SET STATISTICS 500;
ANALYZE orders;
```

### Step 3: Identify Missing Indexes

```sql
-- Check existing indexes on the table
SELECT indexname, indexdef 
FROM pg_indexes 
WHERE tablename = 'orders';

-- Create targeted index for the slow query
CREATE INDEX CONCURRENTLY idx_orders_customer_status 
    ON orders(customer_id, status) 
    WHERE status = 'pending';  -- partial index

-- For range queries, B-tree is correct
CREATE INDEX CONCURRENTLY idx_orders_created_at 
    ON orders(created_at DESC);
```

### Step 4: Analyze JOIN Patterns

```sql
-- Check join order (optimizer should start with small tables)
EXPLAIN (ANALYZE, BUFFERS) 
SELECT o.id, o.total, c.name 
FROM orders o
JOIN customers c ON o.customer_id = c.id
WHERE o.created_at > '2024-01-01';

-- If join order is wrong, try:
-- 1. Update statistics: ANALYZE;
-- 2. Hint (if using pg_hint_plan extension)
-- 3. Rewrite query to force order
```

### Step 5: Rewrite Query if Needed

**EXISTS vs IN:**
```sql
-- IN is often slower with large subquery results
SELECT * FROM orders WHERE customer_id IN (
    SELECT id FROM customers WHERE status = 'active'
);

-- EXISTS can use semi-join optimization better
SELECT * FROM orders o WHERE EXISTS (
    SELECT 1 FROM customers c WHERE c.id = o.customer_id AND c.status = 'active'
);
```

**OR vs UNION ALL:**
```sql
-- OR can prevent index usage
SELECT * FROM orders WHERE status = 'pending' OR status = 'processing';

-- UNION ALL forces separate index scans
SELECT * FROM orders WHERE status = 'pending'
UNION ALL
SELECT * FROM orders WHERE status = 'processing';
```

**LATERAL for top-N per group:**
```sql
-- Get latest order per customer
SELECT c.id, c.name, latest_order.*
FROM customers c
CROSS JOIN LATERAL (
    SELECT id, total, created_at
    FROM orders
    WHERE customer_id = c.id
    ORDER BY created_at DESC
    LIMIT 1
) AS latest_order;
```

### Step 6: Apply Index and Re-analyze

```sql
-- After adding index, re-run EXPLAIN ANALYZE
-- Compare execution time and buffer hits
EXPLAIN (ANALYZE, BUFFERS, TIMING) 
SELECT * FROM orders 
WHERE customer_id = 123 
  AND status = 'pending' 
ORDER BY created_at DESC;
```

### Step 7: Update Statistics

```sql
-- If planner is still wrong, increase statistics target
ALTER TABLE orders ALTER COLUMN status SET STATISTICS 1000;
ANALYZE orders;

-- Or analyze specific columns
ANALYZE (订单, status, customer_id);
```

## Example: Optimizing a Slow Query

### Before (slow query):
```sql
SELECT o.id, o.total, o.created_at, c.name, c.email
FROM orders o
JOIN customers c ON o.customer_id = c.id
WHERE o.created_at BETWEEN '2024-01-01' AND '2024-12-31'
  AND o.total > 100
ORDER BY o.created_at DESC
LIMIT 100;
```

### Analysis with EXPLAIN:
```
->  Seq Scan on orders  (cost=0.00..150000.00 rows=50000)
    Filter: (created_at >= '2024-01-01' AND created_at <= '2024-12-31' AND total > 100)
```

### Optimization Applied:
```sql
-- Step 1: Create composite index with sort order
CREATE INDEX CONCURRENTLY idx_orders_created_total 
    ON orders(created_at DESC, total) 
    WHERE total > 0;

-- Step 2: If customers table is large, add index there too
CREATE INDEX CONCURRENTLY idx_customers_id_name_email 
    ON customers(id, name, email);

-- Step 3: Re-analyze
ANALYZE orders;
ANALYZE customers;
```

### After:
```
->  Index Scan using idx_orders_created_total on orders
    Index Cond: (created_at >= '2024-01-01' AND ...)
```

## Common Index Selection

| Query Pattern | Index Type | Example |
|---------------|------------|---------|
| Equality (`=`) | B-tree | `CREATE INDEX ON orders(customer_id)` |
| Range (`>`, `<`, `BETWEEN`) | B-tree | `CREATE INDEX ON orders(created_at)` |
| Text pattern (`LIKE 'prefix%'`) | B-tree | `CREATE INDEX ON orders(code)` |
| Full-text search | GIN + tsvector | `CREATE INDEX ON orders(search_vector)` |
| JSONB containment | GIN | `CREATE INDEX ON orders(data jsonb_path_ops)` |
| Array containment | GIN | `CREATE INDEX ON orders(tags)` |
| Geospatial | GiST | `CREATE INDEX ON orders(location)` |
| Time-series (append-only) | BRIN | `CREATE INDEX ON orders(created_at) USING BRIN` |

## Gotchas

1. **EXPLAIN without ANALYZE only shows planned cost, not actual execution**: Always use `EXPLAIN (ANALYZE)` to see real timing and row counts.

2. **Rows estimate via statistics sample**: PostgreSQL uses a sample of table data for statistics. If data is skewed (not uniform distribution), estimates can be way off. Increase statistics target for skewed columns.

3. **Missing index may help reads but hurts writes**: Each index adds overhead to INSERT/UPDATE/DELETE. Balance read performance gains against write overhead.

4. **OR can block index usage**: `WHERE status = 'pending' OR total > 100` may cause full scan even with indexes. Use `UNION ALL` instead.

5. **Function on column breaks index usage**: `WHERE lower(email) = '...'` cannot use index on `email`. Solution: expression index `CREATE INDEX ON users(lower(email))`.

6. **NULL values in B-tree indexes**: NULL is indexed. `WHERE email IS NULL` can use index. `WHERE email IS NOT NULL` typically cannot (depends on index type).

7. **Operator class matters for composite indexes**: `CREATE INDEX ON orders(customer_id, created_at DESC)` uses B-tree with DESC. For range queries, ensure proper operator class.

8. **Partial indexes only index filtered rows**: Great for reducing index size when WHERE clause is selective.

9. **Covering indexes with INCLUDE**: Add frequently accessed columns to avoid table heap lookup. `CREATE INDEX idx ON orders(customer_id) INCLUDE (status, total)`.

10. **work_mem for sorts and hashes**: Increase `work_mem` for complex queries with large sorts, but be careful — too high causes OOM. `SET work_mem = '256MB';`

## When NOT to Use This Skill

- When you need to design a new schema (use `pg-schema-design`)
- When you need to create migrations (use `pg-add-migration`)
- When you need to add indexes without query context (use `pg-indexing`)
- When you need to review schema for issues (use `pg-review-schema`)
