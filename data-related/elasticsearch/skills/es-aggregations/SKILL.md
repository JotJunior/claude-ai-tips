---
name: es-aggregations
description: Use Elasticsearch aggregations (terms, date_histogram, metrics, nested, pipeline). Use when "es aggregation", "elasticsearch agg", "facet es", "stats es", "bucket aggregation".
allowed-tools:
  - Read
  - Glob
  - Grep
  - Bash
---

# Elasticsearch Aggregations

Use Elasticsearch aggregations for analytics: terms, date_histogram, metrics, nested, and pipeline.

## Trigger Phrases

"es aggregation", "elasticsearch agg", "facet es", "stats es", "bucket aggregation", "es metrics", "es terms agg"

## Pre-Flight Checks

Before building aggregations:
1. **Field types** — confirm aggregation fields are keyword, numeric, or date
2. **Index size** — large indices may need sampling or reduced precision
3. **ES Docs** — https://www.elastic.co/guide/en/elasticsearch/reference/current/search-aggregations.html

## Workflow

### 1. Aggregation Structure

```json
{
  "size": 0,
  "query": { ... },
  "aggs": {
    "my_agg_name": {
      "aggregation_type": { ... }
    }
  }
}
```

Set `size: 0` to return only aggregations (not search hits).

### 2. terms Aggregation (Group By)

```json
{
  "aggs": {
    "by_category": {
      "terms": {
        "field": "category",
        "size": 20,
        "shard_size": 50,
        "min_doc_count": 1
      },
      "aggs": {
        "avg_price": { "avg": { "field": "price" } },
        "total_revenue": { "sum": { "field": "amount" } }
      }
    }
  }
}
```

### 3. date_histogram (Time Buckets)

```json
{
  "aggs": {
    "sales_over_time": {
      "date_histogram": {
        "field": "created_at",
        "calendar_interval": "month",
        "format": "yyyy-MM",
        "min_doc_count": 0,
        "extended_bounds": {
          "min": "2024-01",
          "max": "2024-12"
        }
      },
      "aggs": {
        "revenue": { "sum": { "field": "amount" } }
      }
    }
  }
}
```

**Calendar vs Fixed intervals**:
- Calendar: minute, hour, day, week, month, quarter, year
- Fixed: 1d, 2d, 30m, etc. (not aligned to calendar)

### 4. Metrics Aggregations

```json
{
  "aggs": {
    "stats_overall": {
      "stats": { "field": "price" }
    },
    "min_price": { "min": { "field": "price" } },
    "max_price": { "max": { "field": "price" } },
    "avg_price": { "avg": { "field": "price" } },
    "sum_total": { "sum": { "field": "amount" } },
    "price_percentiles": {
      "percentiles": { 
        "field": "price",
        "percents": [25, 50, 75, 90, 95, 99]
      }
    }
  }
}
```

### 5. Nested Aggregations

For nested object fields:

```json
{
  "aggs": {
    "comments": {
      "nested": { "path": "comments" },
      "aggs": {
        "by_user": {
          "terms": { "field": "comments.user" },
          "aggs": {
            "avg_length": { "avg": { "field": "comments.length" } }
          }
        }
      }
    }
  }
}
```

### 6. Pipeline Aggregations

```json
{
  "aggs": {
    "sales_by_month": {
      "date_histogram": { "field": "date", "calendar_interval": "month" },
      "aggs": {
        "monthly_sales": { "sum": { "field": "amount" } },
        "cumulative_sales": {
          "cumulative_sum": { "buckets_path": "monthly_sales" }
        },
        "moving_avg": {
          "moving_avg": { "buckets_path": "monthly_sales", "window": 3 }
        }
      }
    }
  }
}
```

### 7. Cardinality (HyperLogLog)

```json
{
  "aggs": {
    "unique_users": {
      "cardinality": { 
        "field": "user_id",
        "precision_threshold": 100
      }
    }
  }
}
```

**precision_threshold**: 0-40000. Higher = more memory, better accuracy. Default 3000.

### 8. Composite Aggregation (Pagination)

```json
{
  "aggs": {
    "composite_buckets": {
      "composite": {
        "size": 1000,
        "sources": [
          { "category": { "terms": { "field": "category" } } },
          { "date": { "date_histogram": { "field": "created_at", "calendar_interval": "month" } } }
        ]
      },
      "aggs": {
        "total": { "sum": { "field": "amount" } }
      }
    }
  }
}
```

## Good Example

```javascript
// Dashboard aggregation query
async function getDashboard(dateFrom, dateTo) {
  const response = await esClient.search({
    index: 'orders',
    size: 0,
    query: {
      range: {
        created_at: { gte: dateFrom, lte: dateTo }
      }
    },
    aggs: {
      revenue_by_day: {
        date_histogram: {
          field: 'created_at',
          calendar_interval: 'day',
          format: 'yyyy-MM-dd'
        },
        aggs: {
          daily_revenue: { sum: { field: 'total' } },
          order_count: { value_count: { field: 'id' } },
          avg_order_value: { avg: { field: 'total' } }
        }
      },
      by_status: {
        terms: { field: 'status', size: 10 }
      },
      by_category: {
        terms: { field: 'category', size: 20 },
        aggs: {
          revenue: { sum: { field: 'total' } }
        }
      },
      percentiles_value: {
        percentiles: { field: 'total', percents: [50, 90, 99] }
      }
    }
  });

  return {
    daily: response.aggregations.revenue_by_day.buckets,
    byStatus: response.aggregations.by_status.buckets,
    byCategory: response.aggregations.by_category.buckets,
    percentiles: response.aggregations.percentiles_value.values
  };
}
```

## Bad Example

```json
{
  "aggs": {
    "by_inexistent_field": {
      "terms": { "field": "nonexistent_field" }  // Error: no mapping
    },
    "too_many_buckets": {
      "terms": { "field": "user_id", "size": 100000 }  // Too many, memory error
    }
  }
}

{
  "aggs": {
    "nested_comments": {
      "terms": { "field": "comments.user" }  // Wrong: must use nested aggregation first
    }
  }
}
```

## Gotchas

1. **terms Size Default**: Default size is 10. May miss significant terms. Set higher for accuracy (shard_size > size recommended).

2. **shard_size for Accuracy**: terms aggregation is distributed. accuracy = shard_size * number_of_shards. Increase shard_size for accuracy.

3. **date_histogram Interval**: Calendar intervals (month, quarter) round to calendar boundaries. Fixed intervals (30d) do not.

4. **Cardinality Precision**: HyperLogLog is approximate. precision_threshold controls memory vs accuracy trade-off.

5. **Nested Aggregation Cost**: Nested aggregations query separate hidden nested documents. Much slower than object fields.

6. **Pipeline Chaining**: Pipeline aggs reference `buckets_path`. Path format: `agg_name>sub_agg_name`.

7. **Composite vs search_after**: For aggregating over many values, composite provides pagination. search_after does not work with aggregations.

## When NOT to Use

- For exact counts on highly variable fields (use terms with large size, or cardinality for approximation)
- When you need real-time updates on constantly changing data (consider pre-aggregation or data frames)
- For complex multi-stage ML aggregations (use ES ML plugin or external analytics)
- When aggregations exceed memory limits (reduce scope, sample data, or use ES SQL)
