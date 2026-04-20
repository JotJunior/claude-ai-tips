---
name: d1-prepared-stmts
description: |
  Use D1 prepared statements with bind() for security and performance. Use when "d1 prepare", "prepared statement d1", "sql injection d1", "d1 bind parameters", "db.prepare".
  Use quando o usuário pedir: "prepared statement d1", "stmt parametrizado d1", "prepared stmt".
allowed-tools:
  - Read
  - Glob
  - Grep
  - Bash
---

# D1 Prepared Statements

Use prepared statements with proper parameter binding to prevent SQL injection and improve performance.

## Trigger Phrases

"d1 prepare", "prepared statement d1", "sql injection d1", "d1 bind parameters", "db.prepare", "bind query d1"

## Pre-Flight Checks

Before writing queries:
1. **User input handling** — identify all user-provided values (params, body, headers)
2. **Query patterns** — determine which queries are repeated vs one-off
3. **D1 binding docs** — https://developers.cloudflare.com/d1/build-databases/query-databases/#parameterized-queries

## Workflow

### 1. Always Use Parameter Binding

**NEVER concatenate user input into SQL strings:**

```javascript
// WRONG - SQL injection vulnerability
const result = await env.DB.prepare(`SELECT * FROM users WHERE email = '${email}'`).first();

// CORRECT - parameter binding
const result = await env.DB.prepare('SELECT * FROM users WHERE email = ?').bind(email).first();
```

### 2. Multiple Parameters

Bind parameters in order:

```javascript
const result = await env.DB.prepare(
    'SELECT * FROM orders WHERE user_id = ? AND status = ? AND created_at > ?'
).bind(userId, 'pending', thirtyDaysAgo).first();
```

### 3. Reuse Prepared Statements

For repeated queries, reuse statement references:

```javascript
// Prepare once outside handler
const selectUserById = env.DB.prepare('SELECT * FROM users WHERE id = ?');
const selectOrdersByUserId = env.DB.prepare('SELECT * FROM orders WHERE user_id = ? ORDER BY created_at DESC LIMIT ?');

// Use in handler
async function getUserWithOrders(userId) {
    const user = await selectUserById.bind(userId).first();
    const orders = await selectOrdersByUserId.bind(userId, 10).all();
    return { user, orders };
}
```

### 4. Choose Correct Method

| Method | Use Case | Returns |
|--------|----------|---------|
| `.first<T>()` | Single row or nothing | `T \| null` |
| `.all<T>()` | Multiple rows | `{ results: T[], meta: {...} }` |
| `.run()` | INSERT/UPDATE/DELETE | `{ meta: { changes, last_row_id, duration } }` |
| `.raw()` | Tuples without object mapping | Array of arrays |

```javascript
// Single row
const user = await env.DB.prepare('SELECT * FROM users WHERE id = ?').bind(userId).first();

// Multiple rows
const orders = await env.DB.prepare('SELECT * FROM orders WHERE user_id = ?').bind(userId).all();

// Write operation
const insert = await env.DB.prepare('INSERT INTO logs (user_id, action) VALUES (?, ?)').bind(userId, action).run();

// Raw tuples
const raw = await env.DB.prepare('SELECT id, email FROM users LIMIT 5').raw();
```

### 5. Access Result Metadata

```javascript
const result = await env.DB.prepare('INSERT INTO users (email, name) VALUES (?, ?)').bind(email, name).run();

console.log({
    changes: result.meta.changes,      // number of rows affected
    lastRowId: result.meta.last_row_id, // last inserted rowid
    duration: result.meta.duration     // query duration in ms
});

// First() returns null if no rows
const user = await env.DB.prepare('SELECT * FROM users WHERE id = ?').bind(id).first();
if (user === null) {
    // Handle not found
}
```

### 6. Handle Array Parameters

For IN clauses, use dynamic query building with binding:

```javascript
// WRONG - cannot bind array directly
const ids = [1, 2, 3];
await env.DB.prepare('SELECT * FROM users WHERE id IN (?)').bind(ids).all();

// CORRECT - build query with ? placeholders
const placeholders = ids.map(() => '?').join(', ');
const query = `SELECT * FROM users WHERE id IN (${placeholders})`;
const users = await env.DB.prepare(query).bind(...ids).all();
```

## Good Example

```javascript
// Repository pattern with prepared statements
class UserRepository {
    constructor(db) {
        this.db = db;
        this.stmts = {
            findById: db.prepare('SELECT id, email, name, created_at FROM users WHERE id = ? AND deleted_at IS NULL'),
            findByEmail: db.prepare('SELECT id, email, name FROM users WHERE email = ?'),
            insert: db.prepare('INSERT INTO users (id, email, name, created_at) VALUES (?, ?, ?, ?)'),
            softDelete: db.prepare('UPDATE users SET deleted_at = unixepoch() WHERE id = ?')
        };
    }

    async findById(id) {
        return this.stmts.findById.bind(id).first();
    }

    async create(user) {
        const result = await this.stmts.insert.bind(user.id, user.email, user.name, Date.now()).run();
        return { id: result.meta.last_row_id, ...user };
    }

    async delete(id) {
        await this.stmts.softDelete.bind(id).run();
    }
}

const users = new UserRepository(env.DB);
```

## Bad Example

```javascript
// NEVER: String concatenation (SQL injection)
const query = `SELECT * FROM users WHERE email = "${req.email}" AND status = "${req.status}"`;
await env.DB.prepare(query).run();

// NEVER: Blindly trust user input in any part of SQL
const search = req.query.q;
await env.DB.prepare(`SELECT * FROM posts WHERE title LIKE '%${search}%'`).all();

// NEVER: Using template literals for SQL
const { userId, role } = req.body;
await env.DB.prepare(`UPDATE users SET role = '${role}' WHERE id = ${userId}`).run();
```

## Gotchas

1. **SQL Injection via Concatenation**: Even a single concatenated value can compromise entire database. Always use `.bind()`.

2. **Positional Binding Only**: D1 prepared statements use `?` positional binding. Named parameters (`:name`) are NOT supported.

3. **`.first()` Returns null**: If query returns no rows, `.first()` returns `null` (not empty array). Always check.

4. **Type Coercion**: JavaScript types map to SQLite types: `number` → INTEGER/REAL, `string` → TEXT, `ArrayBuffer` → BLOB. Dates must be explicitly converted.

5. **Prepared Statement Scope**: Statements are prepared per-database binding. Cannot share across `env.DB1` and `env.DB2`.

6. **`.run()` Metadata**: For writes, `.run()` returns `{ meta: { changes, last_row_id, duration } }`. No `results` array.

7. **No Prepared Transaction**: Cannot prepare a transaction. Use `db.batch()` for atomic multi-statement operations.

## When NOT to Use

- For one-off administrative queries where performance is not critical
- When you need dynamic column lists (use dynamic query building with allowlist validation)
- For complex migrations (use wrangler CLI, not prepared statements)
- When binding very large arrays (split into batches of 1000)
