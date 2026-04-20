---
name: d1-analytics-queries
description: Write analytics queries using window functions, CTEs, and aggregates in D1. Use when "d1 analytics", "window function d1", "aggregate query d1", "report d1", "sql analytics d1".
allowed-tools:
  - Read
  - Glob
  - Grep
  - Bash
---

# D1 Analytics Queries

Write analytics queries using window functions, CTEs, and aggregates in D1.

## Trigger Phrases

"d1 analytics", "window function d1", "aggregate query d1", "report d1", "sql analytics d1", "sqlite analytics", "group by d1"

## Pre-Flight Checks

Before writing analytics queries:
1. **Query complexity** — D1 has 1000ms CPU limit per query. Profile with `.run().meta.duration`
2. **Data volume** — estimate row counts for involved tables
3. **Cache strategy** — if query > 100ms, consider caching result in KV
4. **D1 Docs** — https://developers.cloudflare.com/d1/build-databases/query-databases/#window-functions

## Workflow

### 1. Use CTEs for Readability

Common Table Expressions (WITH clause) structure complex queries:

```sql
WITH 
    monthly_orders AS (
        SELECT 
            strftime('%Y-%m', created_at/1000, 'unixepoch') as month,
            user_id,
            SUM(total) as revenue,
            COUNT(*) as order_count
        FROM orders
        WHERE created_at > ?
        GROUP BY month, user_id
    ),
    user_stats AS (
        SELECT 
            month,
            COUNT(DISTINCT user_id) as unique_customers,
            SUM(revenue) as total_revenue,
            AVG(order_count) as avg_orders_per_user
        FROM monthly_orders
        GROUP BY month
    )
SELECT * FROM user_stats ORDER BY month DESC;
```

### 2. Window Functions for Rankings

```sql
-- ROW_NUMBER for dense ranking
SELECT 
    user_id,
    total_spent,
    ROW_NUMBER() OVER (ORDER BY total_spent DESC) as rank
FROM (
    SELECT user_id, SUM(total) as total_spent
    FROM orders
    GROUP BY user_id
);

-- RANK with partition
SELECT
    category,
    product_name,
    sales,
    RANK() OVER (PARTITION BY category ORDER BY sales DESC) as category_rank
FROM product_sales;
```

### 3. Date Truncation with strftime

SQLite has no native `date_trunc`. Use strftime:

```sql
-- Monthly truncation
strftime('%Y-%m', created_at/1000, 'unixepoch') as month

-- Daily truncation  
strftime('%Y-%m-%d', created_at/1000, 'unixepoch') as day

-- Hourly truncation (custom)
strftime('%Y-%m-%d %H:00', created_at/1000, 'unixepoch') as hour

-- Quarter
strftime('%Y-', created_at/1000, 'unixepoch') || 
    CAST((CAST(strftime('%m', created_at/1000, 'unixepoch') AS INTEGER) + 2) / 3 AS TEXT) || 'Q' as quarter
```

### 4. Aggregates with Having

```sql
SELECT 
    user_id,
    COUNT(*) as order_count,
    SUM(total) as lifetime_value
FROM orders
GROUP BY user_id
HAVING COUNT(*) >= 5 AND SUM(total) > 1000
ORDER BY lifetime_value DESC
LIMIT 100;
```

### 5. JSON1 Extension for Nested Data

D1 includes JSON1 extension:

```sql
-- Extract from JSON column
SELECT 
    id,
    json_extract(metadata, '$.plan') as plan,
    json_extract(metadata, '$.settings.theme') as theme
FROM users
WHERE json_extract(metadata, '$.plan') = 'premium';

-- Array iteration
SELECT value
FROM users, json_each(users.emails);
```

### 6. Cache Expensive Results in KV

For queries > 100ms, cache in KV:

```javascript
const CACHE_KEY = `analytics:monthly-revenue:${currentMonth}`;
const cached = await env.KV.get(CACHE_KEY);

if (cached) {
    return JSON.parse(cached);
}

const result = await env.DB.prepare(`
    WITH monthly_orders AS (...)
    SELECT * FROM user_stats
`).all();

// Cache for 1 hour
await env.KV.put(CACHE_KEY, JSON.stringify(result.results), { expirationTtl: 3600 });

return result.results;
```

## Good Example

```sql
-- Monthly revenue report with growth metrics
WITH 
    monthly_revenue AS (
        SELECT 
            strftime('%Y-%m', created_at/1000, 'unixepoch') as month,
            SUM(total) as revenue,
            COUNT(*) as orders
        FROM orders
        WHERE status = 'completed'
        GROUP BY month
    ),
    revenue_with_growth AS (
        SELECT 
            month,
            revenue,
            orders,
            LAG(revenue) OVER (ORDER BY month) as prev_revenue,
            revenue - LAG(revenue) OVER (ORDER BY month) as revenue_growth,
            ROUND(
                (CAST(revenue AS REAL) / CAST(LAG(revenue) OVER (ORDER BY month) AS REAL) - 1) * 100,
                2
            ) as growth_pct
        FROM monthly_revenue
    )
SELECT 
    month,
    revenue,
    orders,
    prev_revenue,
    revenue_growth,
    growth_pct || '%' as growth_pct
FROM revenue_with_growth
WHERE month >= '2024-01'
ORDER BY month DESC
LIMIT 12;
```

## Bad Example

```sql
-- NEVER: Missing index on GROUP BY column (full table scan)
SELECT 
    DATE(created_at/1000, 'unixepoch') as day,
    COUNT(*)
FROM events  -- No index on created_at
GROUP BY day
ORDER BY day;

-- NEVER: Cartesian JOIN for "pivot" (exponential explosion)
SELECT * FROM sales, categories;  -- Creates N*M rows!

-- NEVER: Complex calculation in SELECT (recalculated for every row)
SELECT 
    name,
    (SELECT SUM(amount) FROM orders WHERE user_id = users.id) * 0.1 
FROM users;  -- Subquery executed per row

-- NEVER: Missing LIMIT on large aggregates
SELECT * FROM huge_table, another_huge_table;  -- Could be billions of rows
```

## Gotchas

1. **D1 CPU Limit**: 1000ms per query. Heavy aggregates on large tables may timeout. Profile with `.run().meta.duration`.

2. **strftime Performance**: `strftime('%Y-%m', col, 'unixepoch')` is slower than integer arithmetic for large datasets.

3. **No PIVOT**: SQLite has no PIVOT. Use `CASE WHEN` with `SUM()` or `COUNT()` for column transposition.

4. **JSON1 Extension**: Available in D1. Use `json_extract()`, `json_each()`, `json_group_array()` for JSON operations.

5. **Window Function ORDER BY**: Many window functions require `ORDER BY` inside `OVER()`. Without it, results may be unpredictable.

6. **No Materialized Views**: SQLite/D1 does not support materialized views. Cache query results in KV for expensive analytics.

7. **Timezone Handling**: Always store timestamps as UTC unixepoch. Apply timezone conversion in application layer, not SQL.

## When NOT to Use

- For real-time queries on > 1M rows (consider pre-aggregation)
- When you need complex joins across multiple large tables (timeout risk)
- For ML/analytics workloads (consider external OLAP database)
- When you need sliding windows with variable frame bounds (limited window function support)
