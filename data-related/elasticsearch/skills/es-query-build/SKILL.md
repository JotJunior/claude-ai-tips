---
name: es-query-build
description: Build Elasticsearch bool queries with must, should, filter, must_not clauses. Use when "es query", "elasticsearch query", "query dsl es", "search query es", "bool query".
allowed-tools:
  - Read
  - Glob
  - Grep
  - Bash
---

# Elasticsearch Query Build

Build Elasticsearch bool queries using must, should, filter, and must_not clauses correctly.

## Trigger Phrases

"es query", "elasticsearch query", "query dsl es", "search query es", "bool query", "es match query", "es term query"

## Pre-Flight Checks

Before building queries:
1. **Index mapping** — `GET /<index>/_mapping` to confirm field types
2. **Query context** — determine if query is for search (scoring) or filtering (no score)
3. **ES Docs** — https://www.elastic.co/guide/en/elasticsearch/reference/current/query-dsl.html

## Workflow

### 1. Bool Query Template

```json
{
  "query": {
    "bool": {
      "must": [],        // scored clauses (relevance)
      "should": [],      // scored, minimum should match optional
      "filter": [],       // non-scored (cached, faster)
      "must_not": []      // non-scored exclusion
    }
  }
}
```

### 2. filter vs query Context

**filter context** (no scoring, cached):
```json
{
  "bool": {
    "filter": [
      { "term": { "status": "active" } },
      { "range": { "created_at": { "gte": "2024-01-01" } } }
    ]
  }
}
```

**query context** (scoring):
```json
{
  "bool": {
    "must": [
      { "match": { "title": "elasticsearch tutorial" } }
    ]
  }
}
```

### 3. match vs term

**term**: exact value on keyword field
```json
{ "term": { "status": "published" } }
```

**match**: analyzed text on text field
```json
{ "match": { "title": "elasticsearch guide" } }
```

### 4. Common Query Types

```json
{
  "query": {
    "bool": {
      "must": [
        { "match": { "title": "search engine" } }
      ],
      "filter": [
        { "term": { "status": "published" } },
        { "range": { "price": { "gte": 10, "lte": 100 } } },
        { "exists": { "field": "author" } }
      ],
      "must_not": [
        { "term": { "category": "archived" } },
        { "terms": { "tags": ["spam", "deleted"] } }
      ],
      "should": [
        { "match": { "content": "tutorial" } }
      ],
      "minimum_should_match": 1
    }
  }
}
```

### 5. Pagination

**from/size** (max 10000 results):
```json
{
  "query": { ... },
  "from": 20,
  "size": 10
}
```

**search_after** (deep pagination):
```json
{
  "query": { ... },
  "sort": [
    { "created_at": "desc" },
    { "_id": "asc" }
  ],
  "search_after": ["2024-01-15T10:30:00Z", "doc_id_123"]
}
```

### 6. _source Filtering

```json
{
  "_source": ["id", "title", "status", "created_at"]
}

{
  "_source": {
    "excludes": ["content", "*.raw"]
  }
}
```

### 7. Wildcard Queries (Use Carefully)

```json
{
  "wildcard": { "title": "elast*search" }
}

{
  "wildcard": { "email": "*@elastic.co" }
}
```

**Warning**: Leading wildcards (`*search`) are very slow. Use edge n-gram tokenizer instead.

## Good Example

```javascript
// Build search query with filters
async function searchArticles(params) {
  const { q, status, category, minPrice, maxPrice, from = 0, size = 20 } = params;

  const must = [];
  const filter = [];

  if (q) {
    must.push({ match: { title: { query: q, operator: "and" } } });
  }

  filter.push({ term: { status: status || "published" } });

  if (category) {
    filter.push({ term: { category } });
  }

  if (minPrice !== undefined || maxPrice !== undefined) {
    const range = {};
    if (minPrice !== undefined) range.gte = minPrice;
    if (maxPrice !== undefined) range.lte = maxPrice;
    filter.push({ range: { price: range } });
  }

  const query = {
    bool: {
      must: must.length > 0 ? must : [{ match_all: {} }],
      filter
    }
  };

  const response = await esClient.search({
    index: 'articles',
    query,
    from,
    size,
    sort: [{ created_at: 'desc' }]
  });

  return {
    hits: response.hits.hits.map(h => ({ id: h._id, ...h._source })),
    total: response.hits.total.value
  };
}
```

## Bad Example

```json
{
  "query": {
    "bool": {
      "must": [
        { "term": { "status": "published" } },     // term on text field (no analysis)
        { "match": { "id": "123" } },               // match on keyword field
        { "wildcard": { "title": "*tutorial*" } }   // leading wildcard (very slow)
      ],
      "filter": [
        { "match": { "title": "elasticsearch" } }  // match in filter context (wastes cache)
      ]
    }
  }
}

{
  "query": { "match_all": {} },
  "from": 100000,        // WARNING: from > 10000 needs search_after
  "size": 100
}

{
  "query": { "match": { "title": "ELASTICSEARCH" } }  // Case insensitive by default (ok for text)
}
```

## Gotchas

1. **filter vs query Performance**: filter context results are cached and don't affect scoring. Always use filter for exact matches and ranges.

2. **match on keyword**: A match query on a keyword field does not analyze the query string, so exact matches may fail. Use term instead.

3. **Wildcard Performance**: Leading wildcards (`*term`) scan entire index. Avoid or use edge n-gram analyzer.

4. **terms Set Limit**: Maximum 65,536 items in terms query. For larger sets, use a filter with terms_agg or match.

5. **Deep Pagination**: `from` > 10,000 requires search_after. from/size is limited by `index.max_result_window` (default 10,000).

6. **Sort on text**: Cannot sort on text field (analyzed). Use keyword sub-field or another numeric/date field.

7. **match Operator**: Default `operator: "or"` splits query into terms. Use `operator: "and"` when all terms must match.

## When NOT to Use

- For simple exact match lookups by ID (use GET /index/_id instead)
- When you need SQL-like JOINs (denormalize or use application-side joins)
- For real-time aggregations on constantly updating data (consider pre-aggregation)
- When you need full SQL expressiveness (use ES SQL plugin or different DB)
