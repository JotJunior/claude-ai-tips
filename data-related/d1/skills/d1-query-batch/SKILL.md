---
name: d1-query-batch
description: Batch multiple D1 queries to reduce latency via db.batch(). Use when "d1 batch", "batch query d1", "d1 prepare batch", "multiple queries d1", "atomic queries d1".
allowed-tools:
  - Read
  - Glob
  - Grep
  - Bash
---

# D1 Query Batch

Reduce latency by batching multiple queries into a single round-trip using D1's batch API.

## Trigger Phrases

"d1 batch", "batch query d1", "d1 prepare batch", "multiple queries d1", "atomic queries d1", "db.batch"

## Pre-Flight Checks

Before using batch:
1. **D1 Database binding** — confirm `env.DB` is available in worker
2. **Query count** — verify you have 2+ independent queries that can run in parallel
3. **D1 Docs** — https://developers.cloudflare.com/d1/build-databases/query-databases/#batch-statements

## Workflow

### 1. Identify Serial Query Pattern

Common case: sequential queries where one depends on another:

```javascript
// BEFORE: 3 round-trips
const user = await env.DB.prepare('SELECT * FROM users WHERE id = ?').bind(userId).first();
const orders = await env.DB.prepare('SELECT * FROM orders WHERE user_id = ?').bind(userId).all();
const prefs = await env.DB.prepare('SELECT * FROM preferences WHERE user_id = ?').bind(userId).first();
```

### 2. Batch Independent Queries

If queries are independent, batch them:

```javascript
// AFTER: 1 round-trip for all 3
const [user, orders, prefs] = await env.DB.batch([
    env.DB.prepare('SELECT * FROM users WHERE id = ?').bind(userId),
    env.DB.prepare('SELECT * FROM orders WHERE user_id = ?').bind(userId),
    env.DB.prepare('SELECT * FROM preferences WHERE user_id = ?').bind(userId)
]);
```

### 3. Use Transactions for Atomicity

For writes that must succeed/fail together:

```javascript
const stmt1 = env.DB.prepare('INSERT INTO orders (id, user_id, total) VALUES (?, ?, ?)').bind(orderId, userId, total);
const stmt2 = env.DB.prepare('UPDATE inventory SET stock = stock - 1 WHERE product_id = ?').bind(productId);

const result = await env.DB.batch([stmt1, stmt2]);
// Atomic: if stmt2 fails, stmt1 is rolled back
```

### 4. Extract Results

```javascript
const [userResult, ordersResult, prefsResult] = await env.DB.batch([...]);

// Access data
const user = userResult.results?.[0];
const orders = ordersResult.results;
const prefs = prefsResult.results?.[0];

// Check for errors
if (userResult.error || ordersResult.error || prefsResult.error) {
    throw new Error('Batch query failed');
}
```

### 5. Separate SELECT from WRITE

**Important**: D1 batch cannot mix SELECT statements that return data with INSERT/UPDATE/DELETE in the same call:

```javascript
// WRONG - mixing read and write in batch
await env.DB.batch([
    env.DB.prepare('SELECT * FROM users WHERE id = ?').bind(userId),  // returns data
    env.DB.prepare('INSERT INTO logs (user_id) VALUES (?)').bind(userId)  // write
]);

// CORRECT - separate calls
const user = await env.DB.prepare('SELECT * FROM users WHERE id = ?').bind(userId).first();
await env.DB.prepare('INSERT INTO logs (user_id) VALUES (?)').bind(userId).run();
```

### 6. Handle Errors Per-Item

Batch does not fail entirely if one statement fails. Check each result:

```javascript
const results = await env.DB.batch([stmt1, stmt2, stmt3]);

for (const result of results) {
    if (result.error) {
        console.error('Statement failed:', result.error);
    }
}
```

## Good Example

```javascript
// Fetch dashboard data in single round-trip
async function getDashboard(userId) {
    const queries = [
        env.DB.prepare('SELECT * FROM users WHERE id = ?').bind(userId),
        env.DB.prepare('SELECT SUM(total) as revenue FROM orders WHERE user_id = ?').bind(userId),
        env.DB.prepare('SELECT COUNT(*) as count FROM orders WHERE user_id = ? AND created_at > ?').bind(userId, thirtyDaysAgo),
        env.DB.prepare('SELECT * FROM notifications WHERE user_id = ? ORDER BY created_at DESC LIMIT 10').bind(userId)
    ];

    const [user, revenue, orderCount, notifications] = await env.DB.batch(queries);

    return {
        user: user.results?.[0],
        revenue: revenue.results?.[0]?.revenue ?? 0,
        orderCount: orderCount.results?.[0]?.count ?? 0,
        notifications: notifications.results ?? []
    };
}
```

## Bad Example

```javascript
// NEVER: SQL injection via concatenation in batch
const batch = [
    env.DB.prepare(`SELECT * FROM users WHERE email = '${email}'`),  // SQL injection!
    env.DB.prepare(`SELECT * FROM orders WHERE user_id = ${userId}`)  // SQL injection!
];
await env.DB.batch(batch);

// NEVER: Exceed batch size limit
const manyStatements = Array.from({length: 1005}, (_, i) =>
    env.DB.prepare('INSERT INTO logs (msg) VALUES (?)').bind(`log-${i}`)
);
await env.DB.batch(manyStatements);  // Fails: max 1000 statements per batch
```

## Gotchas

1. **Batch Limit**: Maximum 1000 statements per `db.batch()` call. Split larger batches.

2. **Latency Trade-off**: Batch reduces round-trips but still has ~1 RTT latency. For true parallel execution, you need Promise.all with individual queries (but more RTTs).

3. **No Nested Batches**: Cannot call `db.batch()` inside another `db.batch()`.

4. **PRAGMA Not Allowed in Batch**: PRAGMA statements must be executed separately.

5. **Index Correspondence**: Results array corresponds to statement array order. If statement order changes, result order changes.

6. **Atomicity Scope**: A single `db.batch()` is atomic (all or none), but multiple sequential batches are independent.

7. **No SELECT + WRITE Mix**: Cannot combine data-returning SELECTs with INSERT/UPDATE/DELETE in same batch.

8. **Prepared Statements Reuse**: Prepare statements once and reuse with `.bind()` for efficiency.

## When NOT to Use

- When you have only 1-2 queries (overhead not worth it)
- When queries have dependencies (use sequential await, not batch)
- When mixing reads and writes (use separate calls)
- When you need PRAGMA statements (not supported in batch)
