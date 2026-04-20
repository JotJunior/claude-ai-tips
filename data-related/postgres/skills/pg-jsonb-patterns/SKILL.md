---
name: pg-jsonb-patterns
description: Work with PostgreSQL JSONB data type including storage, querying, indexing with GIN, and manipulation with jsonb_set. Use when asked to jsonb postgres, jsonb query, jsonb index, schema flexible postgres, jsonb performance, jsonb storage.
allowed-tools:
  - Read
  - Glob
  - Grep
  - Bash
---

# PostgreSQL JSONB Patterns

Design schemas and write queries using PostgreSQL JSONB for semi-structured data storage and flexible schemas.

## Trigger Phrases

"jsonb postgres", "jsonb query", "jsonb index", "schema flexible postgres", "jsonb performance", "jsonb storage", "jsonb vs json", "postgres json"

## Pre-Flight Checks

1. Confirm JSONB is the right choice: structured data with fixed fields = columns, flexible/variable fields = JSONB
2. Estimate data size: JSONB > 2KB gets TOASTed (slow to read)
3. Check existing JSONB columns: `\d+ table_name` or information_schema
4. Identify query patterns: equality, containment, path extraction, text search

## Workflow

### Step 1: Decide When to Use JSONB

**Use JSONB when:**
- Schema is truly dynamic (user-defined attributes, plugin metadata)
- Field names vary per record
- Integration with external APIs that return arbitrary JSON
- Rapid prototyping before schema is stable

**Use columns when:**
- Fields are known, stable, and consistent across all records
- You need to enforce data types with constraints
- Fields will be queried and filtered frequently
- You need foreign key relationships

### Step 2: Design JSONB Structure

```sql
-- Good: Document structure with consistent key naming
CREATE TABLE events (
    id SERIAL PRIMARY KEY,
    type VARCHAR(50) NOT NULL,
    data JSONB NOT NULL,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Insert with well-structured JSON
INSERT INTO events (type, data) VALUES (
    'user_action',
    '{"user_id": "abc123", "action": "purchase", "amount": 99.90, "items": 3}'
);

-- Design rules:
-- 1. Use snake_case keys (consistent with SQL)
-- 2. Keep nesting depth minimal (1-2 levels max)
-- 3. Use arrays for multiple values of same type
-- 4. Avoid deeply nested structures
```

### Step 3: Query JSONB Data

```sql
-- Containment operator (@>) - document contains key/value
SELECT * FROM events WHERE data @> '{"type": "purchase"}';
SELECT * FROM events WHERE data @> '{"user_id": "abc123"}';

-- Key existence (?) 
SELECT * FROM events WHERE data ? 'user_id';
SELECT * FROM events WHERE data ?& ['user_id', 'action'];  -- all must exist
SELECT * FROM events WHERE data ?| ['email', 'phone'];  -- any must exist

-- Get value as text (->>)
SELECT id, data->>'user_id' AS user_id FROM events;

-- Get value as JSON (->)
SELECT id, data->'metadata' AS metadata FROM events;

-- Path query (jsonb_path_query)
SELECT jsonb_path_query(data, '$.user.id') FROM events;

-- Nested path with default
SELECT data #>> ['metadata', 'tags', 0] FROM events;
```

### Step 4: Create GIN Indexes for JSONB

```sql
-- GIN index for containment queries
CREATE INDEX idx_events_data ON events USING GIN(data);

-- GIN index for specific path queries
CREATE INDEX idx_events_user_id ON events((data->>'user_id'));

-- jsonb_path_ops for containment-only (smaller, faster build)
CREATE INDEX idx_events_containment ON events USING GIN(data jsonb_path_ops);

-- Expression index for nested path
CREATE INDEX idx_events_action ON events((data->>'action'));
```

### Step 5: Update JSONB Data

```sql
-- jsonb_set for targeted updates (PG9.5+)
UPDATE events 
SET data = jsonb_set(data, '{amount}', '199.90'::jsonb)
WHERE id = 123;

-- Nested update
UPDATE events 
SET data = jsonb_set(data, '{metadata,tags}', '["new"]'::jsonb, true)
WHERE id = 123;

-- Append to array
UPDATE events 
SET data = jsonb_set(data, '{tags,-}', '"added"'::jsonb)
WHERE id = 123;

-- Remove key
UPDATE events 
SET data = data - 'temporary_field';

-- Remove nested key
UPDATE events 
SET data = data #- '{metadata,legacy}';

-- Concatenate JSONB
UPDATE events 
SET data = data || '{"updated": true}'::jsonb;
```

### Step 6: Use SQL/JSON Path Queries (PG12+)

```sql
-- jsonb_path_query for extracting arrays
SELECT jsonb_path_query(data, '$.items[*]') FROM events;

-- jsonb_path_exists for checking paths
SELECT * FROM events WHERE jsonb_path_exists(data, '$.user.age ? (@ > 18)');

-- jsonb_path_match for boolean conditions
SELECT * FROM events WHERE jsonb_path_match(data, '$.status == "active"');

-- With parameters
SELECT * FROM events 
WHERE jsonb_path_query_first(data, '$.items ? (@.price > $threshold)', 
    '{"threshold": 100}') IS NOT NULL;
```

## JSONB Operators Reference

| Operator | Description | Example |
|----------|-------------|---------|
| `->` | Get JSONB field as JSONB | `data->'metadata'` |
| `->>` | Get JSONB field as TEXT | `data->>'name'` |
| `@>` | Contains JSONB | `data @> '{"a":1}'` |
| `<@` | Is contained by | `'{"a":1}' <@ data` |
| `?` | Key exists (string) | `data ? 'user_id'` |
| `?&` | All keys exist | `data ?& ['a', 'b']` |
| `?\|` | Any key exists | `data ?\| ['a', 'b']` |
| `#>` | Get nested JSONB | `data #> ['a', 'b']` |
| `#>>` | Get nested as TEXT | `data #>> ['a', 'b']` |

## JSONB Functions Reference

| Function | Description |
|----------|-------------|
| `jsonb_set(target, path, value)` | Set value at path |
| `jsonb_insert(target, path, value)` | Insert at path |
| `jsonb_pretty(target)` | Formatted JSON for debugging |
| `jsonb_array_length(target)` | Length of array |
| `jsonb_each(target)` | Key-value pairs as set |
| `jsonb_object_keys(target)` | All keys as set |
| `jsonb_typeof(target)` | Type: object, array, string, number, boolean, null |

## Example: Event Store Schema with JSONB

```sql
CREATE TABLE events (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    aggregate_id UUID NOT NULL,
    aggregate_type VARCHAR(100) NOT NULL,
    event_type VARCHAR(100) NOT NULL,
    data JSONB NOT NULL,
    metadata JSONB,  -- optional metadata (correlation_id, causation_id)
    version INT NOT NULL DEFAULT 1,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    
    -- Constraints
    CONSTRAINT uk_events_aggregate_version UNIQUE (aggregate_id, version)
);

-- Indexes
CREATE INDEX idx_events_aggregate ON events(aggregate_id, version DESC);
CREATE INDEX idx_events_type ON events(event_type);
CREATE INDEX idx_events_data_user ON events((data->>'user_id'));
CREATE INDEX idx_events_data ON events USING GIN(data);

-- Query: Get all events for an aggregate
SELECT id, event_type, data, created_at
FROM events
WHERE aggregate_id = '123e4567-e89b-12d3-a456-426614174000'
ORDER BY version ASC;

-- Query: Find events by user_id in JSONB
SELECT * FROM events WHERE data @> '{"user_id": "abc123"}';

-- Query: Get event counts by type
SELECT event_type, count(*) 
FROM events 
GROUP BY event_type;
```

## Gotchas

1. **JSONB > 2KB gets TOASTed**: Large JSONB documents are stored out-of-line in TOAST tables. Reading them requires extra I/O. Keep JSONB documents small or use columns for large fields.

2. **UPDATE rewrites entire JSONB**: JSONB is not stored in-place. Updating a single key requires reading and rewriting the entire document. For frequently updated fields, use separate columns.

3. **GIN index slow build**: Building GIN indexes on large tables takes significant time. Use `CONCURRENTLY` for production and be aware of increased disk usage during build.

4. **Type coercion: ->> vs ->**: `->>` returns TEXT, `->` returns JSONB. When comparing, ensure types match: `data->>'count' = '5'` (text comparison) vs `(data->>'count')::int = 5` (numeric comparison).

5. **JSON null vs SQL NULL**: `null` in JSONB is different from SQL NULL. `jsonb_typeof('null'::jsonb)` returns 'null', while NULL is absence of value. Use `jsonb_typeof` to distinguish.

6. **Unique constraint on JSONB key**: Use expression index: `CREATE UNIQUE INDEX ON events((data->>'external_id'))`.

7. **jsonb_path_ops only supports @> containment**: If you need key existence or other operators, use default GIN index (without jsonb_path_ops).

8. **Storing arrays vs separate tables**: If you need to query individual array elements frequently (filtering, aggregation), consider separate normalized table with FK, not JSONB arrays.

9. **jsonb_pretty for debugging only**: Never use in production; it's for development/logging only.

10. **Query planner and JSONB**: Complex JSONB queries may not use indexes efficiently. Test with `EXPLAIN (ANALYZE)` and ensure statistics are up-to-date.

## When NOT to Use This Skill

- When you need to design normalized relational schema (use `pg-schema-design`)
- When you need full-text search (use `pg-fts-setup`)
- When you need to create migrations (use `pg-add-migration`)
- When you need to review schema (use `pg-review-schema`)
