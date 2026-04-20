---
name: pg-audit-query
description: Implement PostgreSQL audit trails using triggers and history tables for immutable logging of INSERT, UPDATE, DELETE operations. Use when asked to audit postgres, audit trail sql, history table postgres, trigger audit, log changes postgres.
allowed-tools:
  - Read
  - Glob
  - Grep
  - Bash
---

# PostgreSQL Audit Trail

Implement audit trail using triggers and history tables for immutable logging of INSERT, UPDATE, DELETE operations on sensitive or business-critical tables.

## Trigger Phrases

"audit postgres", "audit trail sql", "history table postgres", "trigger audit", "log changes postgres", "change tracking", "data history", "who changed"

## Pre-Flight Checks

1. Identify tables requiring audit (financial, user permissions, sensitive data)
2. Check for existing audit tables or audit extension (pgaudit)
3. Identify user context mechanism (session variable, application setting)
4. Understand data retention requirements for audit logs
5. Check for LGPD/GDPR implications (right to erasure, data minimization)

## Workflow

### Step 1: Create Audit Table Structure

```sql
-- Audit table schema
CREATE TABLE members_audit (
    audit_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    audit_op CHAR(1) NOT NULL,  -- 'I', 'U', 'D'
    audit_ts TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    audit_user_id UUID,  -- nullable for system changes
    
    -- Table identification
    table_name VARCHAR(255) NOT NULL,
    record_id UUID NOT NULL,  -- references members.id
    
    -- Old/new data snapshot (JSONB for flexibility)
    old_data JSONB,
    new_data JSONB,
    
    -- Additional context
    session_id VARCHAR(100),
    application_name VARCHAR(100),
    client_addr INET,
    transaction_id BIGINT,  -- xactid for correlation
    
    -- Constraints
    CONSTRAINT chk_audit_op CHECK (audit_op IN ('I', 'U', 'D'))
);

-- Index for common queries
CREATE INDEX idx_members_audit_record ON members_audit(record_id);
CREATE INDEX idx_members_audit_ts ON members_audit(audit_ts DESC);
CREATE INDEX idx_members_audit_op ON members_audit(audit_op);
CREATE INDEX idx_members_audit_user ON members_audit(audit_user_id);
```

### Step 2: Create Audit Trigger Function

```sql
CREATE OR REPLACE FUNCTION audit_trigger_func()
RETURNS TRIGGER AS $$
DECLARE
    audit_row members_audit%ROWTYPE;
    user_id UUID;
BEGIN
    -- Get current user from application setting
    -- Use: SET app.current_user_id = 'uuid';
    -- Or: SELECT current_setting('app.user_id', true)::UUID;
    BEGIN
        user_id := NULLIF(current_setting('app.user_id', true), '')::UUID;
    EXCEPTION WHEN OTHERS THEN
        user_id := NULL;
    END;
    
    -- Determine operation
    IF TG_OP = 'INSERT' THEN
        audit_row := ROW(
            gen_random_uuid(),
            'I',
            NOW(),
            user_id,
            TG_TABLE_NAME,
            NEW.id,
            NULL,
            row_to_json(NEW),
            current_setting('app.session_id', true),
            current_setting('app.application_name', true),
            NULLIF(current_setting('app.client_addr', true), '')::INET,
            txid_current(),
            NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL
        );
        -- Set specific fields
        audit_row.old_data = NULL;
        audit_row.new_data = row_to_json(NEW);
        
    ELSIF TG_OP = 'UPDATE' THEN
        audit_row := ROW(
            gen_random_uuid(),
            'U',
            NOW(),
            user_id,
            TG_TABLE_NAME,
            OLD.id,
            row_to_json(OLD),
            row_to_json(NEW),
            current_setting('app.session_id', true),
            current_setting('app.application_name', true),
            NULLIF(current_setting('app.client_addr', true), '')::INET,
            txid_current(),
            NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL
        );
        
    ELSIF TG_OP = 'DELETE' THEN
        audit_row := ROW(
            gen_random_uuid(),
            'D',
            NOW(),
            user_id,
            TG_TABLE_NAME,
            OLD.id,
            row_to_json(OLD),
            NULL,
            current_setting('app.session_id', true),
            current_setting('app.application_name', true),
            NULLIF(current_setting('app.client_addr', true), '')::INET,
            txid_current(),
            NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL
        );
    END IF;
    
    -- Insert audit record (immutable - no UPDATE/DELETE)
    INSERT INTO members_audit (audit_id, audit_op, audit_ts, audit_user_id, table_name, record_id, old_data, new_data, session_id, application_name, client_addr, transaction_id)
    VALUES (audit_row.audit_id, audit_row.audit_op, audit_row.audit_ts, audit_row.audit_user_id, audit_row.table_name, audit_row.record_id, audit_row.old_data, audit_row.new_data, audit_row.session_id, audit_row.application_name, audit_row.client_addr, audit_row.transaction_id);
    
    RETURN NULL;  -- For triggers, return value ignored for AFTER triggers
END;
$$ LANGUAGE plpgsql;
```

### Step 3: Create Triggers on Target Table

```sql
-- Trigger for INSERT
CREATE TRIGGER members_audit_insert
    AFTER INSERT ON members
    FOR EACH ROW
    EXECUTE FUNCTION audit_trigger_func();

-- Trigger for UPDATE
CREATE TRIGGER members_audit_update
    AFTER UPDATE ON members
    FOR EACH ROW
    EXECUTE FUNCTION audit_trigger_func();

-- Trigger for DELETE
CREATE TRIGGER members_audit_delete
    AFTER DELETE ON members
    FOR EACH ROW
    EXECUTE FUNCTION audit_trigger_func();
```

### Step 4: Set Application Context

```sql
-- In application code, set user context before operations
-- PostgreSQL session variable
SET app.user_id = '123e4567-e89b-12d3-a456-426614174000';
SET app.session_id = 'session-abc-123';
SET app.application_name = 'admin-panel';
SET app.client_addr = '192.168.1.100';

-- After setting, INSERT/UPDATE/DELETE will automatically log
INSERT INTO members (name, email) VALUES ('John', 'john@example.com');
-- This will create an audit entry with user_id = '123e4567...'
```

### Step 5: Query Audit Trail

```sql
-- Get all changes for a record
SELECT 
    audit_id,
    audit_op,
    audit_ts,
    audit_user_id,
    old_data,
    new_data
FROM members_audit
WHERE record_id = '123e4567-e89b-12d3-a456-426614174000'
ORDER BY audit_ts DESC;

-- Get all changes by user
SELECT 
    m.email,
    ma.audit_op,
    ma.audit_ts,
    ma.old_data,
    ma.new_data
FROM members_audit ma
JOIN members m ON ma.audit_user_id = m.id
WHERE ma.audit_user_id = '123e4567-e89b-12d3-a456-426614174000'
ORDER BY ma.audit_ts DESC;

-- Get all deletes in date range
SELECT * FROM members_audit
WHERE audit_op = 'D'
  AND audit_ts BETWEEN '2024-01-01' AND '2024-12-31';

-- Get change history for specific columns
SELECT 
    audit_ts,
    (new_data->>'email') AS new_email,
    (old_data->>'email') AS old_email
FROM members_audit
WHERE record_id = '123e4567-e89b-12d3-a456-426614174000'
  AND audit_op = 'U'
  AND new_data ? 'email'  -- email was changed
ORDER BY audit_ts DESC;

-- Get transaction correlation
SELECT 
    audit_ts,
    audit_op,
    record_id,
    transaction_id
FROM members_audit
WHERE transaction_id = 12345;  -- specific transaction
```

## Partition Audit Table for Performance

```sql
-- For high-volume audit tables, partition by month
CREATE TABLE members_audit (
    audit_id UUID NOT NULL DEFAULT gen_random_uuid(),
    audit_op CHAR(1) NOT NULL,
    audit_ts TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    audit_user_id UUID,
    table_name VARCHAR(255) NOT NULL,
    record_id UUID NOT NULL,
    old_data JSONB,
    new_data JSONB,
    session_id VARCHAR(100),
    application_name VARCHAR(100),
    client_addr INET,
    transaction_id BIGINT,
    CONSTRAINT chk_members_audit_op CHECK (audit_op IN ('I', 'U', 'D'))
) PARTITION BY RANGE (audit_ts);

-- Create monthly partitions
CREATE TABLE members_audit_2024_01 PARTITION OF members_audit
    FOR VALUES FROM ('2024-01-01') TO ('2024-02-01');

CREATE TABLE members_audit_2024_02 PARTITION OF members_audit
    FOR VALUES FROM ('2024-02-01') TO ('2024-03-01');

-- Automation: use pg_partman or cron scripts
```

## Alternative: pgaudit Extension

```sql
-- Install pgaudit extension
CREATE EXTENSION pgaudit;

-- Configure in postgresql.conf
-- pgaudit.log = 'write, ddl'  -- log write operations and DDL
-- pgaudit.role = 'audit_role';

-- Create audit role
CREATE ROLE audit_role;
GRANT SELECT ON pg_stat_activity TO audit_role;

-- Log specific commands
ALTER TABLE orders SET (pgaudit.log = 'all');

-- pgaudit captures:
-- - READ: SELECT, COPY
-- - WRITE: INSERT, UPDATE, DELETE, TRUNCATE
-- - DDL: CREATE, ALTER, DROP
-- - OTHER: VACUUM, CREATE INDEX, etc.
```

## Gotchas

1. **Audit table grows fast**: Partition by month and implement retention policy. Consider compressing old partitions with pg_partman or archival to separate storage.

2. **JSONB null vs missing key**: `row_to_json(OLD)` includes all columns. If a column is NULL, it shows `null`. If column doesn't exist in old row (after DROP COLUMN), it's absent. Use `jsonb_typeof` to distinguish.

3. **PII in audit (LGPD/GDPR right to erasure)**: Audit tables may contain personal data. Plan for: 1) masking/anonymization in old partitions, 2) retention limits, 3) extraction/deletion capabilities for data subject requests.

4. **Trigger overhead in high-write tables**: Audit triggers add ~10-30% overhead per DML operation. For very high-volume tables, consider async logging via LISTEN/NOTIFY or queue-based approach.

5. **pgaudit vs custom triggers**: pgaudit provides SQL-level audit (all statements) but not row-level data changes. Custom triggers provide row-level before/after values. Use both for comprehensive audit.

6. **Transaction ID correlation**: `txid_current()` allows correlating audit entries with other operations in the same transaction. Useful for debugging and forensics.

7. **Immutability**: Audit table should not allow UPDATE or DELETE (enforced via revoked permissions or trigger). Only INSERT.

8. **NULL user_id**: System operations (like database migrations) may not have user context. Handle NULL in queries appropriately.

9. **Sensitive data in new_data/old_data**: If audit logs PII (email changes, address changes), consider redacting in trigger function before storing.

10. **application_name setting**: Set via connection string or `SET application_name`. Helps identify source of changes in multi-application environments.

## When NOT to Use This Skill

- When you need simple change tracking (use row-level triggers with simpler schema)
- When you need to design schema (use `pg-schema-design`)
- When you need to create migrations (use `pg-add-migration`)
- When you need to optimize queries (use `pg-query-optimize`)
- When you need to review schema (use `pg-review-schema`)
