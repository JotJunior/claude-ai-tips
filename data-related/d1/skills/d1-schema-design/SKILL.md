---
name: d1-schema-design
description: Design SQLite schema optimized for Cloudflare D1 (STRICT tables, INTEGER PK, GENERATED columns, B-tree indexes). Use when "d1 schema design", "design d1 table", "sqlite schema cloudflare", "create table d1".
allowed-tools:
  - Read
  - Glob
  - Grep
  - Bash
---

# D1 Schema Design

Design SQLite schema optimized for Cloudflare D1 constraints and SQLite quirks.

## Trigger Phrases

"d1 schema design", "design d1 table", "sqlite schema cloudflare", "create table d1", "sqlite strict mode"

## Pre-Flight Checks

Before designing schema, read:
1. **D1 Limits** — `wrangler d1 info <db>` to confirm database exists
2. **Existing schema** — `wrangler d1 execute <db> --command ".schema"` to inspect current tables
3. **D1 Docs** — https://developers.cloudflare.com/d1/build-databases/query-databases/ (type affinity, constraints)

## Workflow

### 1. Choose Table Type

Prefer **STRICT tables** for new D1 schemas:

```sql
CREATE TABLE IF NOT EXISTS users (
    id INTEGER PRIMARY KEY,           -- rowid alias (auto-increment)
    email TEXT NOT NULL UNIQUE,
    name TEXT,
    created_at INTEGER NOT NULL,      -- unix epoch (UTC)
    updated_at INTEGER,
    deleted_at INTEGER,               -- soft delete
    metadata TEXT                     -- JSON blob
) STRICT;
```

### 2. Use Appropriate Column Types

SQLite type affinity rules (D1 uses standard SQLite):

| Declared Type | Becomes |
|---------------|---------|
| INTEGER | INTEGER |
| TEXT | TEXT |
| REAL | REAL |
| BLOB | BLOB |
| VARCHAR(100) | TEXT (affinity) |
| BOOLEAN | INTEGER (no native BOOLEAN) |
| UUID | TEXT (no native UUID) |
| TIMESTAMP | INTEGER or TEXT (no native) |

### 3. Primary Key Strategy

**INTEGER PRIMARY KEY = rowid alias** (recommended for D1):

```sql
-- AUTOINCREMENT-like behavior, efficient
id INTEGER PRIMARY KEY
```

**TEXT PRIMARY KEY** (when needed, e.g., UUID):

```sql
-- No autoincrement; must generate externally
id TEXT PRIMARY KEY
```

### 4. Use Generated Columns for Computed Values

```sql
CREATE TABLE orders (
    id INTEGER PRIMARY KEY,
    subtotal REAL NOT NULL,
    tax_rate REAL NOT NULL DEFAULT 0.1,
    total REAL GENERATED ALWAYS AS (subtotal * (1 + tax_rate)) STORED
);
```

### 5. Add CHECK Constraints for Data Integrity

```sql
CREATE TABLE products (
    id INTEGER PRIMARY KEY,
    price REAL NOT NULL CHECK (price >= 0),
    status TEXT NOT NULL CHECK (status IN ('active', 'inactive', 'draft')),
    category TEXT CHECK (category IS NULL OR category IN ('electronics', 'clothing', 'food'))
);
```

### 6. Create Indexes for Query Patterns

```sql
-- B-tree only (SQLite standard)
CREATE INDEX idx_users_email ON users(email);
CREATE INDEX idx_orders_user_id ON orders(user_id);
CREATE INDEX idx_orders_created ON orders(created_at DESC);

-- Partial index (D1 supports)
CREATE INDEX idx_active_users ON users(email) WHERE deleted_at IS NULL;
```

### 7. Enable Foreign Keys with PRAGMA

```sql
-- Run as separate statement (not in batch with other SQL)
PRAGMA foreign_keys = ON;

-- FK example
CREATE TABLE orders (
    id INTEGER PRIMARY KEY,
    user_id INTEGER NOT NULL REFERENCES users(id)
);
```

### 8. Naming Conventions

- Tables: `snake_case` plural (e.g., `users`, `order_items`)
- Columns: `snake_case` (e.g., `created_at`, `user_id`)
- Indexes: `idx_{table}_{column}` (e.g., `idx_orders_user_id`)
- Foreign keys: explicit ON DELETE behavior

## Good Example

```sql
-- Migration: 001_create_users_table
CREATE TABLE IF NOT EXISTS users (
    id INTEGER PRIMARY KEY,
    email TEXT NOT NULL UNIQUE,
    name TEXT,
    role TEXT NOT NULL DEFAULT 'user' CHECK (role IN ('user', 'admin')),
    created_at INTEGER NOT NULL DEFAULT (unixepoch()),
    updated_at INTEGER,
    deleted_at INTEGER
) STRICT;

CREATE INDEX idx_users_email ON users(email);
CREATE INDEX idx_users_role ON users(role) WHERE deleted_at IS NULL;
```

## Bad Example

```sql
-- NEVER do this:
CREATE TABLE users (
    id TEXT PRIMARY KEY,              -- UUID as TEXT (ok), but no CHECK constraint
    email VARCHAR(255),                -- VARCHAR becomes TEXT affinity, no validation
    is_active BOOLEAN,                 -- BOOLEAN becomes INTEGER (confusing naming)
    created_at TIMESTAMP,             -- No native TIMESTAMP, stored as TEXT without format enforcement
    data TEXT                          -- No CHECK on JSON structure
);                                     -- No STRICT mode, type coercion chaos
```

## Gotchas

1. **Type Affinity**: Without STRICT mode, any value can be stored in any column type. A column declared `age BOOLEAN` will happily accept "hello" string.

2. **No Native UUID/ULID**: Use TEXT with explicit validation or generate in application code.

3. **No Native TIMESTAMP**: Use INTEGER unix epoch (seconds since 1970-01-01) or TEXT ISO8601 (`2024-01-15T10:30:00Z`). INTEGER is faster for range queries.

4. **No ENUM Type**: SQLite has no ENUM. Use CHECK constraint with explicit values list.

5. **ALTER COLUMN Limitations**: Before SQLite 3.35.0, you cannot DROP or rename columns. D1 may use older SQLite versions. Stick to ADD COLUMN only.

6. **Max Page Size**: 65536 bytes. Most D1 tables use default 4096.

7. **DETACH Not Supported**: D1 does not support `DETACH` database (multi-database queries).

8. **FK PRAGMA Required**: Foreign keys are disabled by default. Run `PRAGMA foreign_keys = ON` per session/query batch.

## When NOT to Use

- When you need PostGIS or spatial extensions (D1 has no geometry types)
- When you need window functions optimization (D1 CPU limit 1000ms per query)
- When you need sub-second aggregate queries on 10M+ rows
- When you need real-time concurrent writes with strong consistency guarantees
