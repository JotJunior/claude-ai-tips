---
name: d1-migration-strategy
description: Strategy for D1 migrations with zero-downtime, rollback, and multi-region considerations. Use when "d1 migration strategy", "zero downtime d1", "migration d1 production", "d1 schema changes".
allowed-tools:
  - Read
  - Glob
  - Grep
  - Bash
---

# D1 Migration Strategy

Strategy for applying D1 schema migrations with zero-downtime and rollback capabilities.

## Trigger Phrases

"d1 migration strategy", "zero downtime d1", "migration d1 production", "d1 schema changes", "d1 deploy", "wrangler d1 migrations"

## Pre-Flight Checks

Before running migrations:
1. **Current schema** — `wrangler d1 migrations apply <db> --dry-run` to preview
2. **Migration history** — `wrangler d1 migrations list <db>` to see applied migrations
3. **Backup** — `wrangler d1 export <db>` before production migrations
4. **D1 Docs** — https://developers.cloudflare.com/d1/guides/database-migrations/

## Workflow

### 1. Migration File Naming

```
migrations/
├── 000_00_initial_schema.sql
├── 000_01_add_soft_delete.sql
├── 000_02_add_user_preferences.sql
└── 000_03_create_fts_index.sql
```

Use 3-digit prefix, zero-padded. Wrangler applies in lexicographic order.

### 2. Additive First Pattern

**For column additions, always additive:**

```sql
-- Migration: 000_04_add_status_column.sql
-- GOOD: Add nullable column (no data migration needed)
ALTER TABLE orders ADD COLUMN status TEXT DEFAULT 'pending';

-- Then backfill in background job, not during migration
```

**For new tables:**

```sql
-- Migration: 000_05_create_sessions_table.sql
CREATE TABLE IF NOT EXISTS sessions (
    id INTEGER PRIMARY KEY,
    user_id INTEGER NOT NULL REFERENCES users(id),
    token TEXT NOT NULL UNIQUE,
    expires_at INTEGER NOT NULL,
    created_at INTEGER NOT NULL DEFAULT (unixepoch())
) STRICT;

CREATE INDEX idx_sessions_token ON sessions(token);
CREATE INDEX idx_sessions_user_id ON sessions(user_id);
```

### 3. Zero-Downtime Deployment Sequence

```
Phase 1: Add column (nullable, no DEFAULT requiring rewrite)
    ↓ Migration applied to DB
Phase 2: Deploy code that writes new column (backward compatible)
    ↓ Code deployed
Phase 3: Backfill old rows (background job, small batches)
    ↓ Backfill complete
Phase 4: Deploy code that reads new column
    ↓ Code deployed
Phase 5: Next migration drops old column (if needed)
```

### 4. Multi-Region Consistency

D1 uses eventual consistency for read replicas:

```javascript
// For critical writes, always write to primary
await env.DB.prepare('INSERT INTO critical_table (...) VALUES (...)').bind(...).run();

// Then immediately read from primary (not replica) for confirmation
const confirmed = await env.DB.prepare('SELECT * FROM critical_table WHERE id = ?')
    .bind(id)
    .first();

// Use read replica only for non-critical reads
// const readReplica = await env.REPLICA.prepare('SELECT * FROM ...').bind(...).first();
```

### 5. Safe Column Drop Sequence

```sql
-- Phase 1: Stop writing to column (code deployment)
-- Migration 000_06: Mark column as deprecated (no DB change)

-- Phase 2: Next migration drops column
-- Migration 000_07:
ALTER TABLE orders DROP COLUMN legacy_status;  -- Only in SQLite 3.35+
```

### 6. Rollback Strategy

**D1 migrations are not automatically reversible.** Design for forward-compatibility:

```sql
-- Migration: 000_08_add_new_index.sql
-- Forward: Add new index
CREATE INDEX idx_orders_new ON orders(user_id, created_at DESC);

-- To rollback: create another migration
-- Migration: 000_09_rollback_idx_orders_new.sql
-- DROP INDEX IF EXISTS idx_orders_new;
```

### 7. Apply Migrations via CLI

```bash
# Local development
wrangler d1 migrations apply <db-name> --local

# Staging (test before production)
wrangler d1 migrations apply <db-name> --env staging

# Production (with backup first)
wrangler d1 export <db-name> --output ./backups/prod-$(date +%Y%m%d%H%M%S).sql
wrangler d1 migrations apply <db-name> --env production

# Dry run (preview)
wrangler d1 migrations apply <db-name> --dry-run
```

### 8. Monitor During Migration

```bash
# Watch for errors
wrangler tail --format pretty | grep -i error

# Check query latency
wrangler d1 execute <db> --command "SELECT * FROM orders LIMIT 1" --verbose
```

## Good Example

```sql
-- Migration: 000_10_add_exports_table.sql
-- Zero-downtime: Create table first (additive)

CREATE TABLE IF NOT EXISTS exports (
    id INTEGER PRIMARY KEY,
    user_id INTEGER NOT NULL REFERENCES users(id),
    status TEXT NOT NULL DEFAULT 'pending' CHECK (status IN ('pending', 'processing', 'completed', 'failed')),
    format TEXT NOT NULL CHECK (format IN ('pdf', 'csv', 'json')),
    file_url TEXT,
    error_message TEXT,
    created_at INTEGER NOT NULL DEFAULT (unixepoch()),
    completed_at INTEGER,
    deleted_at INTEGER
) STRICT;

CREATE INDEX idx_exports_user_id ON exports(user_id);
CREATE INDEX idx_exports_status ON exports(status) WHERE deleted_at IS NULL;
```

```javascript
// Application code: backward compatible
async function createExport(userId, format) {
    // Code works BEFORE migration (status column has DEFAULT)
    // Code works AFTER migration (new fields available)
    const result = await env.DB.prepare(`
        INSERT INTO exports (user_id, format) VALUES (?, ?)
    `).bind(userId, format).run();
    
    return { id: result.meta.last_row_id, status: 'pending' };
}
```

## Bad Example

```sql
-- NEVER: Non-additive migration in single step
-- Migration: 000_bad_rename.sql
ALTER TABLE users RENAME COLUMN name TO full_name;  -- Fails on older SQLite

-- NEVER: DEFAULT with expression requiring table rewrite
ALTER TABLE orders ADD COLUMN total_with_tax REAL DEFAULT (subtotal * 1.1);  -- Table lock!

-- NEVER: DROP COLUMN without ensuring no code reads it
ALTER TABLE orders DROP COLUMN legacy_field;  -- Runtime errors if code still references it

-- NEVER: Migration without backup
wrangler d1 migrations apply production-db;  -- No backup = no rollback
```

## Gotchas

1. **No Multi-Statement Transaction Across Migrations**: Each migration file runs as separate transaction, but atomicity across multiple migration files is not guaranteed.

2. **ALTER ADD COLUMN with DEFAULT**: SQLite rewrites entire table when adding column with non-constant DEFAULT. Can cause brief lock.

3. **No CREATE INDEX CONCURRENTLY**: D1/Wrangler does not support concurrent index creation. Index creation locks table briefly.

4. **ALTER COLUMN Limitations**: SQLite (including D1) does not support ALTER COLUMN until version 3.35+. Avoid relying on column modifications.

5. **Eventual Consistency**: Read replicas may lag. For critical reads after write, read from primary explicitly.

6. **Always Backup Before Production**: Use `wrangler d1 export` before applying migrations to production.

7. **UTC Timestamps Only**: Always use `unixepoch()` or integer UTC timestamps. Never store local time.

## When NOT to Use

- For emergency hotfixes requiring immediate schema changes (requires proper migration pipeline)
- When you need true DDL transactions across multiple files (not supported)
- For tables with > 10GB data requiring long-running migrations (split into smaller batches)
- When you need instant rollback to previous schema (not supported; must redeploy)
