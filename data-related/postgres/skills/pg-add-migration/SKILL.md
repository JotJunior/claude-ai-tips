---
name: pg-add-migration
description: Create idempotent PostgreSQL migration files with up/down SQL scripts for safe database schema changes. Use when asked to add postgres migration, nova migration sql, alembic migration, migration postgres, create migration. Also when mentioning schema changes, alter table, add column, create index.
allowed-tools:
  - Read
  - Glob
  - Grep
  - Bash
---

# PostgreSQL Migration

Create properly named, idempotent PostgreSQL migration files with both up (apply) and down (rollback) scripts.

## Trigger Phrases

"add postgres migration", "nova migration sql", "alembic migration", "migration postgres", "criar migration", "add column", "create index", "alter table"

## Pre-Flight Checks

1. Identify existing migration files: `ls migrations/` or check naming convention
2. Determine the current migration version/revision
3. Identify the target schema: `search_path` or explicit schema prefix
4. Check if running against local dev, staging, or production database
5. Verify backup strategy for production changes

## Migration File Naming

```
migrations/
├── 20240101000000_create_members_table.up.sql
├── 20240101000000_create_members_table.down.sql
├── 20240102000000_add_phone_to_members.up.sql
├── 20240102000000_add_phone_to_members.down.sql
└── ...
```

Format: `{YYYYMMDDHHMMSS}_{description_in_snake_case}.up.sql` and `.down.sql`

## Workflow

### Step 1: Create the Up Migration File

Write idempotent DDL using `IF NOT EXISTS`, `CREATE OR REPLACE`:

```sql
-- {timestamp}: {description}
BEGIN;

-- Ensure extension exists (idempotent)
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- Create table
CREATE TABLE IF NOT EXISTS schema.members (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    cim VARCHAR(7) NOT NULL,
    full_name VARCHAR(255) NOT NULL,
    email VARCHAR(255) NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ,
    deleted_at TIMESTAMPTZ
);

-- Add unique constraint
DO $$ BEGIN
    ALTER TABLE schema.members ADD CONSTRAINT uk_members_cim UNIQUE (cim);
EXCEPTION
    WHEN duplicate_object THEN NULL;
END $$;

-- Create index
CREATE INDEX IF NOT EXISTS idx_members_email ON schema.members(email);

-- Add comment
COMMENT ON TABLE schema.members IS 'Member registry';

COMMIT;
```

### Step 2: Create the Down Migration File

The down migration must reverse all changes and be idempotent (running twice should not error):

```sql
-- {timestamp}: {description}
BEGIN;

-- Drop index
DROP INDEX IF EXISTS schema.idx_members_email;

-- Drop constraint
ALTER TABLE schema.members DROP CONSTRAINT IF EXISTS uk_members_cim;

-- Drop table
DROP TABLE IF EXISTS schema.members;

COMMIT;
```

### Step 3: Handle Complex Alter Operations

```sql
-- Adding a NOT NULL column with DEFAULT (Postgres 11+)
-- PG11+ adds column without rewriting table if there's a DEFAULT
ALTER TABLE schema.members 
    ADD COLUMN phone VARCHAR(20) NOT NULL DEFAULT 'unknown';

-- For PG10 and earlier, or when adding NOT NULL to existing rows:
-- Option 1: Add nullable first, backfill, then add constraint
ALTER TABLE schema.members ADD COLUMN phone VARCHAR(20);
UPDATE schema.members SET phone = 'unknown' WHERE phone IS NULL;
ALTER TABLE schema.members ALTER COLUMN phone SET NOT NULL;

-- Option 2: Use procedural migration
DO $$ 
BEGIN
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns 
                   WHERE table_schema = 'schema' AND table_name = 'members' AND column_name = 'phone') THEN
        ALTER TABLE schema.members ADD COLUMN phone VARCHAR(20);
    END IF;
END $$;
```

### Step 4: Create Index Concurrently

For production indexes that must not block reads:

```sql
-- UP: Create index without table lock
CREATE INDEX CONCURRENTLY idx_orders_customer_id 
    ON schema.orders(customer_id);

-- DOWN: Drop index (CONCURRENTLY not allowed in transaction)
-- Must run outside transaction block
DROP INDEX IF EXISTS schema.idx_orders_customer_id;
```

Note: Cannot use `CREATE INDEX CONCURRENTLY` inside a transaction block.

### Step 5: Test Locally

```bash
# Apply migration
psql -h localhost -U user -d db -f migrations/20240101000000_create_members_table.up.sql

# Verify
psql -h localhost -U user -d db -c "\d schema.members"

# Test rollback
psql -h localhost -U user -d db -f migrations/20240101000000_create_members_table.down.sql

# Verify rollback
psql -h localhost -U user -d db -c "\dt schema.members"
```

### Step 6: Apply to Staging

```bash
# Set lock timeout to prevent indefinite locks
export PGCONNECT_TIMEOUT=10
psql -h staging-db -U user -d db -v ON_ERROR_STOP=1 -f migrations/20240101000000_create_members_table.up.sql
```

### Step 7: Apply to Production

```bash
# Run during low-traffic window
# Always set lock_timeout
SET lock_timeout = '5s';
SET statement_timeout = '30s';

\i migrations/20240101000000_create_members_table.up.sql
```

## Common Migration Patterns

### Add Column

```sql
-- UP
ALTER TABLE schema.table_name ADD COLUMN IF NOT EXISTS column_name TYPE;
UPDATE schema.table_name SET column_name = 'default' WHERE column_name IS NULL;
ALTER TABLE schema.table_name ALTER COLUMN column_name SET NOT NULL;

-- DOWN
ALTER TABLE schema.table_name DROP COLUMN IF EXISTS column_name;
```

### Create Table

```sql
-- UP
CREATE TABLE IF NOT EXISTS schema.table_name (...);

-- DOWN
DROP TABLE IF EXISTS schema.table_name CASCADE;
```

### Create Index

```sql
-- UP (normal)
CREATE INDEX IF NOT EXISTS idx_table_column ON schema.table_name(column);

-- UP (concurrent, for production)
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_table_column ON schema.table_name(column);

-- DOWN
DROP INDEX IF EXISTS schema.idx_table_column;
```

### Add Constraint

```sql
-- UP
ALTER TABLE schema.table_name ADD CONSTRAINT constraint_name UNIQUE (column);
ALTER TABLE schema.table_name ADD CONSTRAINT constraint_name CHECK (condition);

-- DOWN
ALTER TABLE schema.table_name DROP CONSTRAINT IF EXISTS constraint_name;
```

### Rename Column

```sql
-- UP
ALTER TABLE schema.table_name RENAME COLUMN old_name TO new_name;

-- DOWN
ALTER TABLE schema.table_name RENAME COLUMN new_name TO old_name;
```

## Example: Complete Migration Pair

**migrations/20240115120000_add_status_to_orders.up.sql:**
```sql
-- 20240115120000: Add status column to orders table
BEGIN;

ALTER TABLE orders ADD COLUMN IF NOT EXISTS status VARCHAR(20) 
    NOT NULL DEFAULT 'pending';

CREATE INDEX IF NOT EXISTS idx_orders_status ON orders(status);

COMMENT ON COLUMN orders.status IS 'Order status: pending, processing, shipped, delivered, cancelled';

COMMIT;
```

**migrations/20240115120000_add_status_to_orders.down.sql:**
```sql
-- 20240115120000: Remove status column from orders table
BEGIN;

DROP INDEX IF EXISTS idx_orders_status;
ALTER TABLE orders DROP COLUMN IF EXISTS status;

COMMIT;
```

## Gotchas

1. **ALTER TABLE with NOT NULL DEFAULT before PG11**: Full table rewrite. On large tables, this causes downtime. Upgrade to PG11+ or use procedural approach with separate steps.

2. **CREATE INDEX CONCURRENTLY cannot run inside a transaction**: Must be the only statement in its transaction or run outside transaction blocks. In down migrations, use `DROP INDEX` without `CONCURRENTLY`.

3. **Always set lock_timeout**: Prevents production locks from blocking indefinitely. `SET lock_timeout = '5s';`

4. **statement_timeout for long operations**: Set reasonable timeout for migrations. `SET statement_timeout = '30s';` for DDL.

5. **Always backup before production**: Use `pg_dump --schema-only` or have Point-In-Time Recovery configured.

6. **Idempotency is mandatory**: Use `IF NOT EXISTS`, `CREATE OR REPLACE`, `DROP IF EXISTS`. Running a migration twice must not fail.

7. **Wrap in BEGIN/COMMIT**: Every migration should be a transaction. If any statement fails, all changes rollback.

8. **Down migrations must be truly reversible**: Not just undo the DDL, but ensure data integrity. If up migration backfilled data, down migration should preserve original data.

9. **Sensitive data in migrations**: If migration touches PII (LGPD/GDPR relevant), ensure audit trail and consider masking in logs.

10. **Schema prefix**: Always use explicit schema prefix (`schema.table_name`), never rely on `search_path`.

## When NOT to Use This Skill

- When you need to design a new schema from scratch (use `pg-schema-design`)
- When you need to optimize slow queries (use `pg-query-optimize`)
- When you need to add indexes (use `pg-indexing`)
- When reviewing an existing migration for issues (use `pg-review-schema`)
