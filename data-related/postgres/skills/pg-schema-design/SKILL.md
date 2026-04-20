---
name: pg-schema-design
description: |
  Design PostgreSQL schemas following 3NF, naming conventions, and best practices for primary keys, foreign keys, constraints, and audit columns. Use when asked to design schema postgres, normalizar schema, schema review postgres, modelar tabela. Also when mentioning table creation, entity modeling, or database modeling.
  Use quando o usuário pedir: "desenhar schema", "modelar tabelas", "schema design postgres", "criar schema".
allowed-tools:
  - Read
  - Glob
  - Grep
  - Bash
---

# PostgreSQL Schema Design

Design or review PostgreSQL schemas following 3NF normalization, proper naming conventions, and best practices for constraints, indexes, and audit trail.

## Trigger Phrases

"design schema postgres", "normalizar schema", "schema review postgres", "modelar tabela", "criar tabela", "entity modeling", "database schema"

## Pre-Flight Checks

1. Identify all entities and their relationships from the domain model
2. Determine the cardinality of each relationship (1:1, 1:N, N:M)
3. Check for existing schema: `psql -h <host> -U <user> -d <db> -c "\dt"` or `\d+ <table>` in psql
4. Identify if this is a new project or an existing one requiring migrations

## Workflow

### Step 1: Identify Entities and Attributes

List all business entities. For each entity, document:
- Core attributes (what defines the entity)
- Optional attributes (nullable fields)
- Derived/calculated attributes (candidates for generated columns)

### Step 2: Apply 3NF Normalization

Third Normal Form requires:
- **1NF**: Atomic values, no repeating groups
- **2NF**: No partial dependencies (composite keys only depend on the whole key)
- **3NF**: No transitive dependencies (non-key attributes depend only on the key)

Example normalization issue:
```sql
-- BAD: transitive dependency (city depends on country, not directly on id)
CREATE TABLE bad_orders (
    id SERIAL PRIMARY KEY,
    customer_id INT,
    country_id INT,
    city VARCHAR(100),  -- transitive: city depends on country_id, not on id
    country_name VARCHAR(100)  -- transitive dependency
);

-- GOOD: 3NF compliant
CREATE TABLE countries (
    id SERIAL PRIMARY KEY,
    name VARCHAR(100) NOT NULL
);

CREATE TABLE cities (
    id SERIAL PRIMARY KEY,
    country_id INT REFERENCES countries(id),
    name VARCHAR(100) NOT NULL
);

CREATE TABLE orders (
    id SERIAL PRIMARY KEY,
    customer_id INT,
    city_id INT REFERENCES cities(id)  -- no transitive dependencies
);
```

### Step 3: Choose Primary Key Strategy

| Strategy | Use Case | Example |
|----------|----------|---------|
| **UUIDv7** | Distributed systems, high concurrency, need sortability | `id UUID PRIMARY KEY DEFAULT gen_random_uuid()` (generate application-side with uuid-ossp or pg extension) |
| **ULID** | Sortable, URL-safe IDs generated outside Postgres | `id TEXT PRIMARY KEY DEFAULT generate_ulid()` |
| **BIGSERIAL** | High-volume tables with sequential access patterns | `id BIGSERIAL PRIMARY KEY` (avoid if you need merge across systems) |
| **IDENTITY** | PG10+ explicit identity columns (preferred over SERIAL) | `id INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY` |

**Rule**: Never use SERIAL for new tables. Use IDENTITY (INT) or UUIDv7.

```sql
-- UUIDv7 generation (application-side or via extension)
-- Option 1: uuid-ossp extension
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE TABLE example (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4()  -- v4, not v7!
);

-- For v7, generate in application layer or use:
CREATE EXTENSION IF NOT EXISTS "pg_uuidv7";  -- third-party extension
```

### Step 4: Define Foreign Keys with ON DELETE Policy

Always specify explicit ON DELETE behavior:

```sql
CREATE TABLE orders (
    id BIGSERIAL PRIMARY KEY,
    customer_id BIGINT NOT NULL REFERENCES customers(id) ON DELETE RESTRICT,
    product_id BIGINT NOT NULL REFERENCES products(id) ON DELETE CASCADE,
    status VARCHAR(20) DEFAULT 'pending',
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- ON DELETE options:
-- RESTRICT  : Error if child rows exist (default, safest)
-- CASCADE   : Delete children when parent deleted
-- SET NULL  : Set FK to NULL when parent deleted
-- SET DEFAULT: Set FK to default value when parent deleted
-- NO ACTION : Similar to RESTRICT but deferrable
```

### Step 5: Add CHECK Constraints and EXCLUDE

```sql
CREATE TABLE reservations (
    id BIGSERIAL PRIMARY KEY,
    customer_id BIGINT NOT NULL,
    room_id BIGINT NOT NULL,
    check_in DATE NOT NULL,
    check_out DATE NOT NULL,
    
    -- CHECK constraints
    CHECK (check_out > check_in),
    CHECK (customer_id > 0),
    
    -- EXCLUDE for overlapping date ranges (no double-booking)
    EXCLUDE USING gist (
        room_id WITH =,
        daterange(check_in, check_out) WITH &&
    )
);
```

### Step 6: Design Generated Columns

Use GENERATED ALWAYS for computed columns that are queried frequently:

```sql
CREATE TABLE employees (
    id SERIAL PRIMARY KEY,
    first_name VARCHAR(100) NOT NULL,
    last_name VARCHAR(100) NOT NULL,
    salary DECIMAL(12, 2),
    
    -- Full name as generated column (stored)
    full_name TEXT GENERATED ALWAYS AS (first_name || ' ' || last_name) STORED,
    
    -- Annual salary (virtual - computed on read)
    annual_salary DECIMAL(12, 2) GENERATED ALWAYS AS (salary * 12) STORED
);
```

### Step 7: Add Audit Columns

```sql
CREATE TABLE products (
    id BIGSERIAL PRIMARY KEY,
    name VARCHAR(255) NOT NULL,
    price DECIMAL(10, 2) NOT NULL,
    is_active BOOLEAN DEFAULT true,
    
    -- Audit columns
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ,  -- nullable until first update
    deleted_at TIMESTAMPTZ,  -- soft delete
    created_by UUID,
    updated_by UUID
);

-- Trigger to auto-update updated_at
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER products_updated_at
    BEFORE UPDATE ON products
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();
```

### Step 8: Add Indexes for Foreign Keys and Common Queries

```sql
-- FK indexes (automatic in Postgres but explicit is clearer)
CREATE INDEX idx_orders_customer_id ON orders(customer_id);
CREATE INDEX idx_orders_product_id ON orders(product_id);

-- Composite index for common query pattern
CREATE INDEX idx_orders_status_created ON orders(status, created_at DESC);

-- Partial index for active records only
CREATE INDEX idx_products_active ON products(name) WHERE is_active = true;
```

## Example: Complete CREATE TABLE

```sql
CREATE TABLE IF NOT EXISTS members (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    cim VARCHAR(7) NOT NULL,  -- 7-digit zero-padded
    full_name VARCHAR(255) NOT NULL,
    email VARCHAR(255) NOT NULL,
    phone VARCHAR(20),
    lodge_id UUID REFERENCES lodges(id) ON DELETE SET NULL,
    status VARCHAR(20) DEFAULT 'active' CHECK (status IN ('active', 'inactive', 'suspended')),
    membership_date DATE DEFAULT CURRENT_DATE,
    
    -- Audit
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ,
    deleted_at TIMESTAMPTZ,
    
    -- Constraints
    CONSTRAINT uk_members_cim UNIQUE (cim),
    CONSTRAINT uk_members_email UNIQUE (email)
);

-- Indexes
CREATE INDEX idx_members_lodge_id ON members(lodge_id);
CREATE INDEX idx_members_status ON members(status);
CREATE INDEX idx_members_created_at ON members(created_at DESC);

-- Comment
COMMENT ON TABLE members IS 'Membership registry with audit trail';
```

## Example: What NOT to Do

```sql
-- BAD EXAMPLES:

-- 1. No explicit PK type
CREATE TABLE bad1 (id SERIAL PRIMARY KEY);  -- SERIAL is deprecated

-- 2. Missing ON DELETE policy
CREATE TABLE bad2 (customer_id INT REFERENCES customers);  -- implicit RESTRICT is unclear

-- 3. TIMESTAMP without timezone (ambiguous)
CREATE TABLE bad3 (created_at TIMESTAMP);  -- is this UTC? local time?

-- 4. VARCHAR without length for short fields
CREATE TABLE bad4 (status VARCHAR);  -- unbounded, unclear intent

-- 5. TEXT vs appropriate bounded type
CREATE TABLE bad5 (phone TEXT);  -- TEXT for a phone number is wasteful

-- 6. Missing audit columns
CREATE TABLE bad6 (id SERIAL PRIMARY KEY, name VARCHAR(100));  -- where is created_at?

-- 7. Avoiding proper constraints
CREATE TABLE bad7 (price NUMERIC);  -- no precision/scale, no CHECK for positive values

-- 8. JSON for structured data that should be normalized
CREATE TABLE bad8 (data JSONB);  -- storing address fields in JSON instead of columns
```

## Gotchas

1. **SERIAL gap problem**: ROLLBACK does not reuse SERIAL values. If you insert and rollback 1000 times, you have 1000 gaps. Use IDENTITY for gaps-free sequential keys.

2. **UUIDv4 is bad for B-tree indexes**: UUIDv4 is random, causing index bloat and poor locality. Use UUIDv7 (sortable) or generate UUIDv7 in your application.

3. **Always use TIMESTAMPTZ**: TIMESTAMP without timezone is ambiguous and timezone-naive. TIMESTAMPTZ stores UTC internally and converts to session timezone on read.

4. **TEXT vs VARCHAR**: PostgreSQL treats them identically for storage and performance. Prefer TEXT for unbounded columns. VARCHAR(n) is only useful for application-side validation.

5. **DECIMAL vs NUMERIC**: They are synonyms. NUMERIC(precision, scale) is preferred for clarity.

6. **Avoid reserved words as names**: `user`, `order`, `group`, `check`, `status` are reserved. Use `user_account`, `order_status`, `user_group`.

7. **JSONB vs JSON**: Always use JSONB. It has a binary representation, supports indexing, and is faster for querying.

8. **BOOLEAN vs INT**: Use BOOLEAN for true/false fields. Do not store as 0/1 integers.

9. **Enums in Postgres**: Prefer VARCHAR with CHECK constraint over PostgreSQL ENUM type. ENUMs require migration to add values and are not enforced in constraints across schemas.

10. **Naming convention**: snake_case for everything. Plural table names (`members`), singular column names (`member_id`).

## When NOT to Use This Skill

- When you need to add a column to an existing table (use `pg-add-migration`)
- When you need to optimize slow queries (use `pg-query-optimize`)
- When you need to add indexes (use `pg-indexing`)
- When reviewing an existing schema for issues (use `pg-review-schema`)
