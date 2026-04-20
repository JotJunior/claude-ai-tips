---
name: ts-add-migration
description: |
  Create Drizzle ORM migration files for Cloudflare D1 or Neon Postgres
  Use quando o usuário pedir: "criar migration drizzle", "nova migration ts", "add migration typescript".
allowed-tools:
  - Read
  - Glob
  - Grep
  - Bash
---

# ts-add-migration

Create Drizzle ORM migration files for Cloudflare Workers projects following all project conventions.

## Trigger Phrases

"add migration", "nova migration", "drizzle migration", "criar migration", "schema change"

## Arguments

$ARGUMENTS should specify:
- **Schema file** — which `src/schema.ts` or `src/db/schema.ts` contains the entity
- **Migration type** (create_table, add_column, create_index, alter_table, seed) — inferred from description
- **Description** — what the migration does (e.g., "add email column to users", "create notifications table")

## Pre-Flight Checks

Before generating migration code, read:

1. **Schema file** — `src/db/schema.ts` or `src/schema.ts` to understand current structure
2. **Existing migrations** — `drizzle/**/*`.sql` sorted by timestamp to avoid duplicate versions
3. **wrangler.toml** — check `[[d1_databases]]` or `[[postgres_databases]]` binding name
4. **drizzle.config.ts** — verify migration folder path and schema export
5. **Existing seed files** — `scripts/seed.ts` or `drizzle/seed/` for seed conventions

## Workflow

### Step 1: Identify Changes

Parse the user request to determine:
- **Table name** — which table is being modified
- **Change type** — create, add column, add index, alter, seed
- **Column definition** — name, type, constraints, defaults

### Step 2: Edit Schema First

Before running `drizzle-kit generate`, edit the TypeScript schema file:

```typescript
// src/db/schema.ts
import { sql } from 'drizzle-orm';
import { text, timestamp, varchar } from 'drizzle-orm/cloudflare-schema';

// Adicionar nova coluna no schema primeiro
export const users = mysqlTable('users', {
  id: varchar('id', { length: 36 }).primaryKey(),
  email: varchar('email', { length: 255 }).notNull().unique(),
  createdAt: timestamp('created_at').default(sql`CURRENT_TIMESTAMP`),
  updatedAt: timestamp('updated_at').onUpdate(sql`CURRENT_TIMESTAMP`),
  deletedAt: timestamp('deleted_at'), // soft-delete
});
```

### Step 3: Generate Migration

Run `drizzle-kit generate` to auto-generate the SQL migration file:

```bash
npx drizzle-kit generate
```

The migration file will be created in the configured `out` folder with timestamp prefix.

### Step 4: Review Generated SQL

Open the generated migration file and verify:
- **Naming** — snake_case for columns/tables
- **IF NOT EXISTS** — present for idempotent migrations
- **Idempotent down** — DROP statements use IF EXISTS
- **Soft-delete** — uses `deleted_at TIMESTAMP NULL` pattern

### Step 5: Apply Migration

**Development (local D1)**:
```bash
npx drizzle-kit push
```

**Production D1**:
```bash
wrangler d1 migrations apply <database-name> --local
# ou
wrangler d1 migrations apply <database-name> --remote
```

**Production Postgres (Neon)**:
```bash
npx drizzle-kit migrate
```

## Migration Templates

### create_table

```sql
-- 20240101000000: Create {table_name} table
CREATE TABLE IF NOT EXISTS `{table_name}` (
  `id` varchar(36) PRIMARY KEY,
  `name` varchar(255) NOT NULL,
  `created_at` timestamp DEFAULT CURRENT_TIMESTAMP,
  `updated_at` timestamp ON UPDATE CURRENT_TIMESTAMP,
  `deleted_at` timestamp NULL
);

-- Indexes
CREATE INDEX IF NOT EXISTS `idx_{table_name}_name` ON `{table_name}`(`name`);
```

### add_column (additive, safe)

```sql
-- 20240101000000: Add {column_name} to {table_name}
ALTER TABLE `{table_name}` ADD COLUMN IF NOT EXISTS `{column_name}` {type};
```

### create_index

```sql
-- 20240101000000: Create index on {table_name}.{column}
CREATE INDEX IF NOT EXISTS `idx_{table_name}_{column}` ON `{table_name}`(`{column}`);
```

### alter_table (dangerous — prefer additive)

```sql
-- 20240101000000: Rename column in {table_name} (D1 SQLite < 3.35 workaround)
CREATE TABLE `{table_name}_new` AS SELECT * FROM `{table_name}`;
ALTER TABLE `{table_name}` RENAME TO `{table_name}_backup`;
ALTER TABLE `{table_name}_new` RENAME TO `{table_name}`;
```

## Example: Good Migration (Additive)

**Scenario**: Adding a `phone` column to `members` table.

```sql
-- 20240101120000: Add phone to members
ALTER TABLE `members` ADD COLUMN IF NOT EXISTS `phone` varchar(20);
```

This is safe because:
- No data loss risk
- No downtime
- No breaking changes to existing queries
- Reversible: `ALTER TABLE DROP COLUMN` (D1 SQLite >= 3.35)

## Example: Bad Migration (Destructive)

**Scenario**: User asks to "remove" the `email` column.

```sql
-- RUIM: Não usar em produção D1 SQLite < 3.35
ALTER TABLE `members` DROP COLUMN `email`;
```

**Why it's bad**:
- D1 SQLite does NOT support DROP COLUMN before version 3.35
- Even in newer versions, data is permanently lost
- No rollback path
- Breaks all queries referencing that column

**Correct approach**: Use soft-delete
```sql
-- BOM: Soft-delete via deleted_at
ALTER TABLE `members` ADD COLUMN `email_deleted_at` timestamp NULL;
-- Atualizar aplicação para ignorar registros onde email_deleted_at IS NOT NULL
```

## Gotchas

1. **D1 DROP COLUMN limitation**: SQLite in D1 does not support `DROP COLUMN` until Cloudflare upgrades to SQLite 3.35+. Always use soft-delete instead.

2. **Timestamp prefix**: Use format `YYYYMMDDHHMMSS` for migration filenames (e.g., `20240101120000_*`). This ensures correct ordering.

3. **IF NOT EXISTS**: All CREATE statements must be idempotent. Running twice should not error.

4. **Soft-delete convention**: All business tables must have `deleted_at TIMESTAMP NULL`. Never use hard DELETE.

5. **Multi-tenant prefix**: If using multi-tenant schema, prefix tables with tenant identifier (e.g., `tenant_members`).

6. **Local testing**: Always test migrations locally with `wrangler d1 create <name> --local` before pushing to production.

7. **Down migrations**: Must be idempotent. Use `IF EXISTS` and test that running down twice does not error.

## When NOT to Use

- **Database already exists with legacy schema**: Use manual ALTER with backup table strategy instead
- **Large table restructure**: Consider zero-downtime approach with shadow table (see alter_table template)
- **Emergency hotfix**: This skill is for planned migrations. For emergency column additions, still apply same conventions
