---
name: pg-locking
description: Handle PostgreSQL locking issues including lock types, advisory locks, deadlock detection, and contention analysis. Use when asked to postgres locking, deadlock postgres, lock contention, advisory lock, lock timeout, pg locks.
allowed-tools:
  - Read
  - Glob
  - Grep
  - Bash
---

# PostgreSQL Locking Patterns

Diagnose and resolve PostgreSQL locking issues, implement advisory locks, and prevent deadlocks.

## Trigger Phrases

"postgres locking", "deadlock postgres", "lock contention", "advisory lock", "lock timeout", "pg locks", "waiting for lock", "lock deadlock", " ExclusiveLock", "RowExclusiveLock"

## Pre-Flight Checks

1. Identify blocking sessions: `SELECT * FROM pg_stat_activity WHERE wait_event_type = 'Lock';`
2. Check lock types held: `SELECT * FROM pg_locks WHERE granted = true;`
3. Identify the blocked query
4. Check if it's a production issue (immediate action needed) or development

## Lock Types Overview

| Lock Mode | Use When | Conflicts With |
|-----------|----------|---------------|
| **ACCESS EXCLUSIVE** | ALTER TABLE, DROP TABLE, TRUNCATE | All except ACCESS SHARE |
| **ShareRowExclusive** | | |
| **RowExclusive** | INSERT, UPDATE, DELETE | ACCESS EXCLUSIVE, ROW EXCLUSIVE, SHARE ROW EXCLUSIVE |
| **RowShare** | SELECT FOR UPDATE/FOR SHARE | |
| **ShareUpdateExclusive** | VACUUM, ANALYZE, CREATE INDEX |
| **Share** | CREATE INDEX (non-concurrent) |
| **AccessShare** | SELECT (reads only) |

**Important**: `ALTER TABLE` acquires `ACCESS EXCLUSIVE` lock, blocking all reads and writes.

## Workflow

### Step 1: Identify Lock Contention

```sql
-- Find all blocking sessions
SELECT 
    blocked.pid AS blocked_pid,
    blocked.query AS blocked_query,
    blocking.pid AS blocking_pid,
    blocking.query AS blocking_query,
    blocked.locktype AS lock_type,
    blocked.relation::regclass AS table_name
FROM pg_stat_activity blocked
JOIN pg_stat_activity blocking ON blocking.pid = ANY(pg_blocking_pids(blocked.pid))
WHERE blocked.wait_event_type = 'Lock'
  AND blocking.wait_event_type IS NULL;

-- Or use pg_locks directly
SELECT 
    l.locktype,
    l.relation::regclass,
    l.mode,
    l.granted,
    a.pid,
    a.query
FROM pg_locks l
JOIN pg_stat_activity a ON l.pid = a.pid
WHERE NOT l.granted
ORDER BY l.pid;

-- Check wait events by type
SELECT 
    wait_event_type,
    wait_event,
    COUNT(*) AS count
FROM pg_stat_activity
WHERE state = 'active'
  AND wait_event_type IS NOT NULL
GROUP BY wait_event_type, wait_event
ORDER BY count DESC;
```

### Step 2: Analyze Lock Chain

```sql
-- Get detailed lock information
SELECT 
    l.locktype,
    l.relation::regclass,
    l.page,
    l.tuple,
    l.virtualxid,
    l.transactionid,
    l.classid,
    l.objid,
    l.objsubid,
    l.mode,
    l.granted,
    l.fastpath,
    a.pid,
    a.state,
    a.query,
    a.query_start,
    a.backend_start,
    a.xact_start,
    a.application_name
FROM pg_locks l
JOIN pg_stat_activity a ON l.pid = a.pid
WHERE a.state = 'active'
ORDER BY a.query_start;

-- Check for prepared transactions (can hold locks)
SELECT * FROM pg_prepared_xacts;
```

### Step 3: Use Granular Row Locks

```sql
-- FOR UPDATE (exclusive, blocks others from FOR UPDATE/SHARE)
SELECT * FROM orders WHERE id = 123 FOR UPDATE;

-- FOR UPDATE with NOWAIT (fail immediately if locked)
SELECT * FROM orders WHERE id = 123 FOR UPDATE NOWAIT;

-- FOR UPDATE with SKIP LOCKED (for job queuing, work stealing)
SELECT * FROM orders 
WHERE status = 'pending' 
ORDER BY created_at 
LIMIT 1 
FOR UPDATE SKIP LOCKED;

-- FOR SHARE (shared, blocks FOR UPDATE)
SELECT * FROM orders WHERE id = 123 FOR SHARE;

-- NO KEY UPDATE (for reading without blocking key updates)
SELECT * FROM orders WHERE id = 123 FOR NO KEY UPDATE;
```

### Step 4: Implement Advisory Locks

For application-level mutex/semaphore:

```sql
-- Simple advisory lock (session-level, released on disconnect)
SELECT pg_advisory_lock(12345);  -- lock with key 12345
-- ... critical section ...
SELECT pg_advisory_unlock(12345);  -- must unlock explicitly

-- With timeout (will wait up to 5 seconds)
SELECT pg_advisory_lock(12345);
-- or use:
SELECT pg_try_advisory_lock(12345);  -- returns true/false immediately

-- Transaction-scoped advisory lock (auto-released on commit/rollback)
SELECT pg_advisory_xact_lock(12345);  -- released at end of transaction

-- Named advisory lock (text key)
SELECT pg_advisory_lock(hashtext('my_resource'));

-- Check if advisory lock is held
SELECT * FROM pg_locks WHERE locktype = 'advisory' AND objid = 12345;
```

### Step 5: Prevent Deadlocks with Consistent Lock Order

```sql
-- BAD: Different order in different transactions causes deadlock
-- Transaction 1: lock order (A, B)
BEGIN;
SELECT * FROM orders WHERE id = 1 FOR UPDATE;  -- lock A
SELECT * FROM products WHERE id = 1 FOR UPDATE;  -- try lock B
COMMIT;

-- Transaction 2: lock order (B, A) - DEADLOCK if both run concurrently
BEGIN;
SELECT * FROM products WHERE id = 1 FOR UPDATE;  -- lock B
SELECT * FROM orders WHERE id = 1 FOR UPDATE;  -- try lock A - DEADLOCK!
COMMIT;

-- GOOD: Always lock in same order across all transactions
-- Both transactions lock A first, then B
```

### Step 6: Set Lock Timeout

```sql
-- Set lock timeout for session (5 seconds)
SET lock_timeout = '5s';

-- Set statement timeout (30 seconds for entire statement)
SET statement_timeout = '30s';

-- In application connection string (for Pooler like PgBouncer)
-- Add: options=-c lock_timeout=5s

-- For specific operation
BEGIN;
SET local lock_timeout = '5s';
ALTER TABLE orders ADD COLUMN IF NOT EXISTS status VARCHAR(20);
COMMIT;
```

### Step 7: Handle Deadlocks

PostgreSQL deadlock detector automatically kills one victim:

```sql
-- After deadlock, check logs
-- PostgreSQL will log: "deadlock detected while waiting for lock"
-- The victim transaction is rolled back

-- Application should:
-- 1. Catch the error (SQLSTATE '40P01')
-- 2. Retry the transaction (exponential backoff)
-- 3. Log for monitoring

-- Example retry logic (pseudocode):
let retries = 0
while retries < 3:
    try:
        execute_transaction()
        break
    except deadlock:
        retries++
        sleep(2^retries * 100)  // exponential backoff
```

## Lock Monitoring Queries

```sql
-- Long-running transactions holding locks
SELECT 
    pid,
    now() - xact_start AS duration,
    query,
    mode,
    granted
FROM pg_stat_activity a
JOIN pg_locks l ON a.pid = l.pid
WHERE xact_start IS NOT NULL
  AND now() - xact_start > interval '5 minutes'
ORDER BY duration DESC;

-- Tables with most locks
SELECT 
    relation::regclass,
    COUNT(*) AS lock_count,
    MAX(mode) AS max_mode
FROM pg_locks
WHERE relation IS NOT NULL
GROUP BY relation
ORDER BY lock_count DESC;

-- Find idle transactions holding locks
SELECT 
    pid,
    now() - state_change AS idle_time,
    query
FROM pg_stat_activity
WHERE state = 'idle in transaction'
  AND state_change < now() - interval '5 minutes';
```

## Common Patterns

### Job Queue with SKIP LOCKED

```sql
-- Producer: Insert jobs
INSERT INTO jobs (payload, status) VALUES ('task data', 'pending');

-- Worker: Claim job (work stealing pattern)
UPDATE jobs
SET status = 'processing', worker_id = $1, started_at = NOW()
WHERE id = (
    SELECT id FROM jobs 
    WHERE status = 'pending' 
    ORDER BY created_at 
    LIMIT 1 
    FOR UPDATE SKIP LOCKED
)
RETURNING *;
```

### Bidirectional Updates with Retry

```sql
-- Application-level retry for deadlocks
function transfer_funds(from_id, to_id, amount):
    for attempt in range(3):
        try:
            BEGIN
            -- Always lock in same order: lower ID first
            first_id = min(from_id, to_id)
            second_id = max(from_id, to_id)
            
            EXECUTE "SELECT ... FROM accounts WHERE id = $1 FOR UPDATE", first_id
            EXECUTE "SELECT ... FROM accounts WHERE id = $1 FOR UPDATE", second_id
            
            UPDATE accounts SET balance = balance - $3 WHERE id = from_id
            UPDATE accounts SET balance = balance + $3 WHERE id = to_id
            
            COMMIT
            return success
        except deadlock:
            ROLLBACK
            sleep(attempt * 100)
    return error
```

## Gotchas

1. **ALTER TABLE = ACCESS EXCLUSIVE**: Any ALTER TABLE acquires ACCESS EXCLUSIVE lock, blocking ALL reads and writes. Use `ALTER TABLE ... SET (lock_timeout = '5s')` to limit wait time.

2. **VACUUM FULL = ACCESS EXCLUSIVE**: VACUUM FULL rewrites the table and blocks everything. Use `VACUUM` (lazy) or `VACUUM ANALYZE` instead.

3. **CREATE INDEX CONCURRENTLY uses weaker lock**: Normal CREATE INDEX blocks writes. CONCURRENTLY uses ShareUpdateExclusive, allowing reads but slower.

4. **SELECT FOR UPDATE can deadlock**: When two transactions hold locks and each tries to acquire the other's lock, deadlock occurs. Always lock in consistent order across transactions.

5. **Deadlock detector kills the victim**: PostgreSQL automatically detects deadlocks and rolls back the smallest transaction. Check logs for deadlock messages and implement retry logic.

6. **Advisory locks survive disconnection**: `pg_advisory_lock` is session-scoped and survives even if the application process dies. Use `pg_terminate_backend(pid)` to clean up stuck advisory locks.

7. **Advisory lock with transaction**: `pg_advisory_xact_lock` auto-releases on commit/rollback — prefer this in most cases.

8. **SKIP LOCKED for work stealing**: Use SKIP LOCKED in queue processing to avoid contention when multiple workers process the same queue.

9. **lock_timeout vs statement_timeout**: `lock_timeout` only waits for locks; `statement_timeout` aborts the entire statement. Use both for safety.

10. **Idle in transaction holding locks**: Transactions left idle with open statements hold locks. Set `idle_in_transaction_session_timeout` to auto-terminate.

## When NOT to Use This Skill

- When you need to design schema (use `pg-schema-design`)
- When you need to create migrations (use `pg-add-migration`)
- When you need to optimize queries (use `pg-query-optimize`)
- When you need to review schema (use `pg-review-schema`)
