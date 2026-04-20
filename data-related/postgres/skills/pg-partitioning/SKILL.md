---
name: pg-partitioning
description: Implement PostgreSQL declarative partitioning for large tables using RANGE, LIST, and HASH strategies. Use when asked to partition postgres, particionar tabela, table partitioning postgres, pg partition, partition maintenance.
allowed-tools:
  - Read
  - Glob
  - Grep
  - Bash
---

# PostgreSQL Table Partitioning

Implement declarative partitioning for large tables using RANGE, LIST, or HASH strategies for improved query performance and data management.

## Trigger Phrases

"partition postgres", "particionar tabela", "table partitioning postgres", "pg partition", "partition maintenance", "partition strategy", "list partition", "range partition"

## Pre-Flight Checks

1. Identify large tables (> 100GB or > 100 million rows)
2. Analyze query patterns for partition key candidates
3. Check PostgreSQL version: partitioning features evolved (PG10+ has declarative partitioning)
4. Review disk space for partition maintenance
5. Check application compatibility with partition-aware queries

## Partition Types

| Type | Use Case | Example |
|------|----------|---------|
| **RANGE** | Time-series data, sequential values | Partition by month, by year |
| **LIST** | Categorical data, discrete values | Partition by region, by status |
| **HASH** | Even distribution, no logical key | Partition by user_id modulo |

## Workflow

### Step 1: Choose Partition Strategy

```sql
-- RANGE: Best for time-series or sequential data
-- Partition key: DATE, TIMESTAMP, or integer ranges
CREATE TABLE orders (
    id UUID NOT NULL,
    customer_id UUID NOT NULL,
    total DECIMAL(10,2) NOT NULL,
    status VARCHAR(20) NOT NULL,
    created_at TIMESTAMPTZ NOT NULL
) PARTITION BY RANGE (created_at);

-- LIST: Best for categorical data with few distinct values
CREATE TABLE events (
    id SERIAL,
    event_type VARCHAR(50) NOT NULL,
    payload JSONB NOT NULL,
    created_at TIMESTAMPTZ NOT NULL
) PARTITION BY LIST (event_type);

-- HASH: Best for evenly distributing writes across partitions
-- Use when no logical partition key exists
CREATE TABLE sessions (
    id UUID NOT NULL,
    user_id UUID NOT NULL,
    token VARCHAR(255) NOT NULL,
    created_at TIMESTAMPTZ NOT NULL,
    expires_at TIMESTAMPTZ NOT NULL
) PARTITION BY HASH (user_id);
```

### Step 2: Create Parent Table

```sql
-- Parent table with partition key
CREATE TABLE orders (
    id UUID NOT NULL DEFAULT gen_random_uuid(),
    customer_id UUID NOT NULL,
    total DECIMAL(10,2) NOT NULL,
    status VARCHAR(20) NOT NULL DEFAULT 'pending',
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ,
    
    -- Primary key MUST include partition key in PG < 12
    -- PG12+: Primary key can be independent of partition key
    PRIMARY KEY (id, created_at)
) PARTITION BY RANGE (created_at);

-- Add constraints at parent level (propagate to partitions)
ALTER TABLE orders 
    ADD CONSTRAINT chk_orders_status 
    CHECK (status IN ('pending', 'processing', 'shipped', 'delivered', 'cancelled'));

-- Index on parent (auto-propagates to partitions in PG11+)
CREATE INDEX idx_orders_customer ON orders(customer_id);
CREATE INDEX idx_orders_status ON orders(status);
```

### Step 3: Create Child Partitions

```sql
-- RANGE: Monthly partitions for time-series
CREATE TABLE orders_2024_01 PARTITION OF orders
    FOR VALUES FROM ('2024-01-01') TO ('2024-02-01');

CREATE TABLE orders_2024_02 PARTITION OF orders
    FOR VALUES FROM ('2024-02-01') TO ('2024-03-01');

-- Continue for other months...

-- LIST: Partition by category
CREATE TABLE events_user_actions PARTITION OF events
    FOR VALUES IN ('user_created', 'user_updated', 'user_deleted');

CREATE TABLE events_transactions PARTITION OF events
    FOR VALUES IN ('purchase', 'refund', 'subscription');

-- HASH: 8 partitions for user_id distribution
CREATE TABLE sessions_p0 PARTITION OF sessions
    FOR VALUES WITH (MODULUS 8, REMAINDER 0);

CREATE TABLE sessions_p1 PARTITION OF sessions
    FOR VALUES WITH (MODULUS 8, REMAINDER 1);

-- ... continue for p2-p7
```

### Step 4: Insert Data (Partition-Aware)

```sql
-- Insert into parent automatically routes to correct partition
INSERT INTO orders (customer_id, total, status, created_at)
VALUES ('uuid-here', 99.90, 'pending', NOW());

-- Bulk insert
INSERT INTO orders (customer_id, total, status, created_at)
SELECT customer_id, total, 'pending', created_at
FROM external_orders
WHERE created_at >= '2024-01-01';
```

### Step 5: Query with Partition Pruning

```sql
-- Pruning happens automatically when partition key is constant
EXPLAIN SELECT * FROM orders WHERE created_at = '2024-06-15';

-- Must include partition key in WHERE for pruning
-- GOOD: Partition key used
SELECT * FROM orders WHERE created_at > '2024-06-01';

-- BAD: Partition key not used (scans all partitions)
SELECT * FROM orders WHERE customer_id = 'uuid-here';

-- Use partition key in UPDATE/DELETE for efficiency
DELETE FROM orders WHERE id = 'uuid-here' AND created_at = '2024-06-15';
UPDATE orders SET status = 'shipped' WHERE id = 'uuid-here' AND created_at = '2024-06-15';
```

### Step 6: Automate Partition Creation

For time-based partitions, automate creation using pg_partman or cron:

```sql
-- Using pg_partman (recommended for production)
-- Install: CREATE EXTENSION pg_partman;
-- Configure:
SELECT partman.create_parent(
    p_parent_table => 'public.orders',
    p_control => 'created_at',
    p_type => 'range',
    p_interval => 'monthly',
    p_premake => 4  -- create 4 months ahead
);

-- Or use a manual cron approach in application layer:
-- 1. Check if partition for next month exists
-- 2. If not, CREATE TABLE ... PARTITION OF ...

-- Example procedure for automated RANGE partition creation:
CREATE OR REPLACE FUNCTION create_monthly_partition()
RETURNS void AS $$
DECLARE
    next_month DATE;
    partition_name TEXT;
    start_date DATE;
    end_date DATE;
BEGIN
    next_month := date_trunc('month', CURRENT_DATE + interval '1 month');
    partition_name := 'orders_' || to_char(next_month, 'YYYY_MM');
    start_date := next_month;
    end_date := next_month + interval '1 month';
    
    -- Check if exists
    IF NOT EXISTS (
        SELECT 1 FROM pg_tables 
        WHERE tablename = partition_name
    ) THEN
        EXECUTE format(
            'CREATE TABLE IF NOT EXISTS %I PARTITION OF orders 
             FOR VALUES FROM (%L) TO (%L)',
            partition_name, start_date, end_date
        );
        RAISE NOTICE 'Created partition: %', partition_name;
    END IF;
END;
$$ LANGUAGE plpgsql;
```

### Step 7: Detach and Archive Old Partitions

```sql
-- Detach old partition (becomes standalone table)
ALTER TABLE orders DETACH PARTITION orders_2023_01;

-- Optional: Rename for clarity
ALTER TABLE orders_2023_01 RENAME TO archived_orders_2023_01;

-- Move to archive tablespace or different storage
ALTER TABLE archived_orders_2023_01 SET TABLESPACE archive_tbs;

-- Attach back if needed
ALTER TABLE orders ATTACH PARTITION archived_orders_2023_01 
    FOR VALUES FROM ('2023-01-01') TO ('2023-02-01');

-- Drop old partition (permanent!)
DROP TABLE orders_2023_01;  -- Danger: data is gone!
```

## Partition Management Queries

```sql
-- List all partitions
SELECT 
    parent.relname AS parent_table,
    child.relname AS partition_name,
    pg_get_expr(child.relpartbound, child.oid) AS partition_range
FROM pg_inherits
JOIN pg_class parent ON inhparent = parent.oid
JOIN pg_class child ON inhrelid = child.oid
WHERE parent.relname = 'orders'
ORDER BY child.relname;

-- Check partition sizes
SELECT 
    child.relname AS partition,
    pg_size_pretty(pg_total_relation_size(child.oid)) AS total_size
FROM pg_inherits
JOIN pg_class parent ON inhparent = parent.oid
JOIN pg_class child ON inhrelid = child.oid
WHERE parent.relname = 'orders'
ORDER BY pg_total_relation_size(child.oid) DESC;

-- Check row counts
SELECT 
    child.relname AS partition,
    reltuples::bigint AS row_count
FROM pg_inherits
JOIN pg_class parent ON inhparent = parent.oid
JOIN pg_class child ON inhrelid = child.oid
WHERE parent.relname = 'orders'
ORDER BY reltuples DESC;
```

## Gotchas

1. **Primary key must include partition key (PG < 12)**: In PG10/11, PK and unique constraints must include the partition key. PG12+ allows PK independent of partition key.

2. **Foreign keys to partitioned tables**: FK references from non-partitioned tables to partitioned tables are supported in PG11+. FK from partitioned table to another is limited.

3. **Indexes on parent don't cascade automatically (PG < 11)**: In PG10, you must create indexes on each child. PG11+ propagates indexes.

4. **Partition pruning only with constant WHERE**: If the partition key is not in WHERE clause or uses functions, all partitions are scanned. Always include partition key with direct comparison.

5. **Too many small partitions cause overhead**: Each partition has metadata overhead. 100 partitions of 1MB each is wasteful. Minimum practical size: 1GB per partition.

6. **pg_partman for automation**: Use pg_partman extension for automated partition creation, dropping, and maintenance. Manual cron scripts are error-prone.

7. **UPDATE must include partition key**: To move a row between partitions via UPDATE, you must include the partition key in the WHERE clause.

8. **Detach is instant but needs cleanup**: ALTER TABLE DETACH PARTITION is fast, but the detached table remains as standalone. Remember to DROP or archive it.

9. **Partitioned table statistics**: Run ANALYZE on each partition after bulk loads. Parent table statistics may not reflect child data accurately.

10. **TRUNCATE on partitioned table**: TRUNCATE affects all partitions. Use TRUNCATE ONLY partition_name to truncate specific partition.

## When NOT to Use This Skill

- When tables are small (< 10GB) with simple queries
- When you need to design schema (use `pg-schema-design`)
- When you need to create migrations (use `pg-add-migration`)
- When you need to optimize queries (use `pg-query-optimize`)
- When you need to review schema (use `pg-review-schema`)
