---
name: pg-review-schema
description: Review existing PostgreSQL schemas for issues, smells, normalization problems, missing constraints, and performance improvements. Use when asked to review schema postgres, audit schema sql, schema smell, schema check postgres, analyze postgres schema.
allowed-tools:
  - Read
  - Glob
  - Grep
  - Bash
---

# PostgreSQL Schema Review

Review existing PostgreSQL schemas for normalization issues, missing constraints, missing indexes, inappropriate types, and performance improvements.

## Trigger Phrases

"review schema postgres", "audit schema sql", "schema smell", "schema check postgres", "analyze postgres schema", "schema quality", "database review", "schema issues"

## Pre-Flight Checks

1. Identify target database: `psql -c "\l"` to list databases
2. Connect to target: `psql -d dbname -c "\dt"` for tables
3. Determine schema ownership: `\dn` for schemas
4. Check Postgres version: `SELECT version();`
5. Gather context: application framework, ORM used (Drizzle/Prisma/Sequelize)

## Workflow

### Step 1: Export Schema

```bash
# Export full schema (structure only, no data)
pg_dump -h localhost -U user -d dbname --schema-only > schema.sql

# Export specific table structure
pg_dump -h localhost -U user -d dbname -t table_name --schema-only

# In psql interactive:
\dt                    -- list tables
\d+ table_name         -- detailed table structure
\di                    -- list indexes
\df                    -- list functions
\dv                    -- list views
\ds                    -- list sequences
\dn                    -- list schemas
```

### Step 2: Check Table Structure

```sql
-- List all tables with row counts and sizes
SELECT 
    schemaname,
    tablename,
    row_estimate,
    pg_size_pretty(pg_total_relation_size(schemaname || '.' || tablename)) AS total_size
FROM pg_stat_user_tables
WHERE schemaname NOT IN ('pg_catalog', 'information_schema')
ORDER BY pg_total_relation_size DESC;

-- Check columns and types
SELECT 
    table_schema,
    table_name,
    column_name,
    data_type,
    is_nullable,
    column_default,
    character_maximum_length
FROM information_schema.columns
WHERE table_schema NOT IN ('pg_catalog', 'information_schema')
ORDER BY table_schema, table_name, ordinal_position;

-- Check constraints
SELECT 
    conrelid::regclass AS table_name,
    conname AS constraint_name,
    contype AS constraint_type,
    pg_get_constraintdef(oid) AS definition
FROM pg_constraint
WHERE conrelid::regclass::text NOT LIKE 'pg_%'
ORDER BY conrelid, contype;
```

### Step 3: Analyze Index Coverage

```sql
-- Check indexes on all tables
SELECT 
    schemaname,
    tablename,
    indexname,
    idx_scan,
    pg_size_pretty(pg_relation_size(indexrelid)) AS index_size
FROM pg_stat_user_indexes
WHERE schemaname NOT IN ('pg_catalog', 'information_schema')
ORDER BY idx_scan ASC, pg_relation_size DESC;

-- Find missing indexes on foreign keys
SELECT 
    c.relname AS table_name,
    a.attname AS column_name,
    'no index' AS issue
FROM pg_constraint AS con
JOIN pg_attribute AS a ON con.confrelid = a.attrelid AND a.attnum = ANY(con.confkey)
JOIN pg_class AS c ON con.conrelid = c.oid
WHERE con.contype = 'f'
  AND NOT EXISTS (
    SELECT 1 FROM pg_index i
    JOIN pg_index_column ic ON i.indexrelid = ic.indexrelid
    WHERE i.indrelid = con.conrelid 
      AND ic.column_num = a.attnum
  );

-- Unused indexes (can be dropped)
SELECT 
    schemaname,
    tablename,
    indexname,
    idx_scan
FROM pg_stat_user_indexes
WHERE idx_scan = 0
  AND indexrelid NOT IN (SELECT conindid FROM pg_constraint)
ORDER BY pg_relation_size(indexrelid) DESC;
```

### Step 4: Check Data Types and Defaults

```sql
-- Find TEXT columns that should be bounded
SELECT 
    table_name,
    column_name,
    data_type,
    character_maximum_length
FROM information_schema.columns
WHERE data_type = 'TEXT'
  AND character_maximum_length IS NULL
ORDER BY table_name;

-- Check for inappropriate types
SELECT 
    table_name,
    column_name,
    data_type
FROM information_schema.columns
WHERE (
    (data_type = 'integer' AND column_name LIKE '%_id' AND character_maximum_length > 8)
    OR (data_type = 'character varying' AND character_maximum_length > 1000)
)
ORDER BY table_name;

-- Check for SERIAL (deprecated)
SELECT 
    column_default,
    table_name,
    column_name
FROM information_schema.columns
WHERE column_default LIKE 'nextval%';

-- Check TIMESTAMP without timezone (issue)
SELECT 
    table_name,
    column_name,
    data_type
FROM information_schema.columns
WHERE data_type = 'timestamp' 
  AND datetime_precision IS NOT NULL
ORDER BY table_name;

-- Check BOOLEAN usage
SELECT 
    table_name,
    column_name,
    data_type
FROM information_schema.columns
WHERE data_type = 'integer'
  AND column_name IN ('%is_%', '%active%', '%enabled%', '%status%')
ORDER BY table_name;
```

### Step 5: Review Constraints

```sql
-- Tables without primary key
SELECT 
    schemaname,
    tablename
FROM pg_tables
WHERE schemaname NOT IN ('pg_catalog', 'information_schema')
  AND tablename NOT IN (
    SELECT DISTINCT conrelid::regclass::text 
    FROM pg_constraint 
    WHERE contype = 'p'
  )
ORDER BY schemaname, tablename;

-- Tables without any constraints
SELECT 
    schemaname,
    tablename
FROM pg_tables t
WHERE schemaname NOT IN ('pg_catalog', 'information_schema')
  AND NOT EXISTS (
    SELECT 1 FROM pg_constraint c WHERE c.conrelid = t.schemaname||'.'||t.tablename::regclass
  )
ORDER BY schemaname, tablename;

-- Check NOT NULL on important columns
SELECT 
    table_name,
    column_name
FROM information_schema.columns
WHERE is_nullable = 'YES'
  AND column_name IN ('created_at', 'updated_at', 'email', 'status')
ORDER BY table_name;

-- Find columns without CHECK constraints that should have them
SELECT 
    table_name,
    column_name,
    data_type
FROM information_schema.columns
WHERE data_type = 'character varying'
  AND character_maximum_length IS NULL
  AND column_name LIKE '%_status%'
ORDER BY table_name;
```

### Step 6: Check Audit Columns

```sql
-- Tables missing audit columns
SELECT 
    schemaname,
    tablename
FROM pg_tables t
WHERE schemaname NOT IN ('pg_catalog', 'information_schema')
  AND NOT EXISTS (
    SELECT 1 FROM information_schema.columns c
    WHERE c.table_schema = t.schemaname 
      AND c.table_name = t.tablename
      AND c.column_name = 'created_at'
  )
ORDER BY schemaname, tablename;

-- Tables missing soft delete
SELECT 
    schemaname,
    tablename
FROM pg_tables t
WHERE schemaname NOT IN ('pg_catalog', 'information_schema')
  AND tablename NOT LIKE '%_audit'
  AND NOT EXISTS (
    SELECT 1 FROM information_schema.columns c
    WHERE c.table_schema = t.schemaname 
      AND c.table_name = t.tablename
      AND c.column_name = 'deleted_at'
  )
ORDER BY schemaname, tablename;
```

### Step 7: Generate Review Report

For each table, evaluate against this checklist:

| Check | Priority | Description |
|-------|----------|-------------|
| Primary key exists | P0 | Tables without PK are problematic |
| Foreign keys indexed | P0 | Unindexed FK = slow joins and deletes |
| Appropriate types | P1 | TIMESTAMPTZ not TIMESTAMP, BOOLEAN not INT |
| NOT NULL where appropriate | P1 | Business keys should be NOT NULL |
| Constraints defined | P1 | CHECK, UNIQUE, EXCLUDE |
| Audit columns | P1 | created_at/updated_at for mutable tables |
| Soft delete | P2 | deleted_at for non-audit tables |
| Indexes for common queries | P1 | FK, WHERE clauses, ORDER BY |
| Unused indexes removed | P2 | idx_scan = 0 indicates waste |
| No TEXT without bounds | P2 | Except for truly unbounded content |
| No reserved word names | P2 | user, order, group, etc. |

## Example Review Findings

```sql
-- Finding 1: SERIAL primary key (P2 - should use UUID or IDENTITY)
-- Problem:
CREATE TABLE orders (
    id SERIAL PRIMARY KEY,  -- SERIAL is deprecated
    ...
);

-- Recommendation:
ALTER TABLE orders ALTER COLUMN id DROP DEFAULT;
ALTER TABLE orders ALTER COLUMN id TYPE UUID;
ALTER TABLE orders ALTER COLUMN id SET DEFAULT gen_random_uuid();
-- Or use IDENTITY:
-- id INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY

-- Finding 2: TIMESTAMP without timezone (P1)
-- Problem:
created_at TIMESTAMP  -- Ambiguous!

-- Recommendation:
created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()

-- Finding 3: Foreign key without index (P0)
-- Problem:
CREATE TABLE orders (
    customer_id BIGINT REFERENCES customers(id)  -- No index!
);

-- Recommendation:
CREATE INDEX idx_orders_customer_id ON orders(customer_id);

-- Finding 4: Status as VARCHAR without constraint (P1)
-- Problem:
status VARCHAR(20)  -- Can be 'pendding', 'pending', 'PENDING', etc.

-- Recommendation:
status VARCHAR(20) CHECK (status IN ('pending', 'processing', 'shipped', 'delivered'))

-- Finding 5: Unused index (P2)
-- Problem:
idx_scan = 0 for months

-- Recommendation:
DROP INDEX idx_orders_unused;
```

## Schema Quality Report Template

```markdown
# Schema Review Report

## Summary
- Database: {db_name}
- Version: PostgreSQL {version}
- Tables: {count}
- Issues Found: {P0} critical, {P1} important, {P2} hygiene

## Critical Issues (P0)

### FK without index on orders.customer_id
**Impact**: Slow JOINs, slow DELETE on customers
**Recommendation**: CREATE INDEX idx_orders_customer_id ON orders(customer_id);

## Important Issues (P1)

### 1. Table "config" uses SERIAL PK
**Current**: id SERIAL PRIMARY KEY
**Issue**: SERIAL creates gaps on rollback; deprecated
**Recommendation**: Use UUID or IDENTITY

### 2. Column orders.created_at uses TIMESTAMP
**Current**: created_at TIMESTAMP
**Issue**: No timezone info; ambiguous interpretation
**Recommendation**: created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()

## Hygiene Issues (P2)

### 1. Table "logs" has no audit columns
### 2. Index idx_events_data has idx_scan=0 for 30 days
### 3. Column users.phone uses TEXT (should be VARCHAR(20))
```

## Gotchas

1. **FK without index = slow JOIN and slow DELETE**: When deleting from parent table with many children, unindexed FK causes sequential scans. Always index FK columns.

2. **BOOLEAN vs INT**: Use BOOLEAN for status fields. `is_active` INT with values 0/1 is confusing and error-prone.

3. **TIMESTAMPTZ always (TIMESTAMP is trap)**: TIMESTAMP without timezone is ambiguous. PostgreSQL interprets it as session timezone, which causes subtle bugs.

4. **NUMERIC without precision = unbounded**: `NUMERIC` without precision/scale can hold any size number, causing performance issues. Use `NUMERIC(12,2)` for currency.

5. **SERIAL deprecated (use IDENTITY)**: PG10+ supports `GENERATED ALWAYS AS IDENTITY`. More explicit and gap-free.

6. **Unused indexes**: `pg_stat_user_indexes.idx_scan = 0` means index never used. Drop to reduce write overhead.

7. **TEXT vs VARCHAR**: PostgreSQL stores them identically. VARCHAR(n) only useful for application-side validation. TEXT is preferred.

8. **Soft delete with NULL vs boolean**: `deleted_at TIMESTAMPTZ` is better than `is_deleted BOOLEAN` because it captures when, not just if.

9. **Reserved words**: `user`, `order`, `group`, `check`, `status` are SQL reserved. Use `user_account`, `order_status`, `user_group`.

10. **No CHECK constraint on status columns**: VARCHAR status without CHECK allows invalid values like 'activ' or 'ACTIVE'.

## When NOT to Use This Skill

- When you need to design a new schema (use `pg-schema-design`)
- When you need to create migrations (use `pg-add-migration`)
- When you need to optimize slow queries (use `pg-query-optimize`)
- When you need to add indexes (use `pg-indexing`)
