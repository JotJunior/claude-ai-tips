---
name: es-mapping-design
description: Design Elasticsearch index mapping with types, analyzers, and multi-fields. Use when "es mapping", "elasticsearch schema", "design mapping es", "index mapping", "es analyzer".
allowed-tools:
  - Read
  - Glob
  - Grep
  - Bash
---

# Elasticsearch Mapping Design

Design Elasticsearch index mappings with proper types, analyzers, and multi-fields.

## Trigger Phrases

"es mapping", "elasticsearch schema", "design mapping es", "index mapping", "es analyzer", "es text vs keyword", "mapping es 8"

## Pre-Flight Checks

Before designing mapping:
1. **ES version** — `GET /` to confirm ES 8.x (some features differ from 7.x)
2. **Existing indices** — `GET /_cat/indices?v` to check current indices
3. **ES Docs** — https://www.elastic.co/guide/en/elasticsearch/reference/current/mapping.html

## Workflow

### 1. Explicit Mapping (Not Dynamic)

Always use explicit mappings to prevent field explosion:

```json
{
  "mappings": {
    "dynamic": "strict",
    "properties": {
      "id": { "type": "keyword" },
      "title": { 
        "type": "text",
        "fields": {
          "keyword": { "type": "keyword" }
        }
      },
      "content": { "type": "text" },
      "status": { "type": "keyword" },
      "views": { "type": "long" },
      "price": { "type": "scaled_float", "scaling_factor": 100 },
      "created_at": { "type": "date" },
      "updated_at": { "type": "date" }
    }
  }
}
```

### 2. text vs keyword Fields

**text**: analyzed for full-text search, NOT usable for aggregations/sort
**keyword**: exact value, usable for aggregations/sort/filter

```json
{
  "email": { "type": "keyword" },           // exact match, aggregations
  "username": { 
    "type": "text",
    "fields": {
      "keyword": { "type": "keyword" }       // search + sort/agg
    }
  },
  "bio": { "type": "text" }                  // full-text search only
}
```

### 3. Numeric Types

```json
{
  "integer_field": { "type": "integer" },           // -2^31 to 2^31-1
  "long_field": { "type": "long" },                 // most common
  "float_field": { "type": "float" },               // 32-bit
  "double_field": { "type": "double" },             // 64-bit
  "scaled_float_field": {                           // efficient storage
    "type": "scaled_float",
    "scaling_factor": 100
  }
}
```

### 4. date Type

```json
{
  "created_at": { 
    "type": "date",
    "format": "strict_date_optional_time||epoch_millis"
  },
  "scheduled_at": {
    "type": "date",
    "format": "yyyy-MM-dd'T'HH:mm:ss.SSSZ||yyyy-MM-dd||epoch_millis"
  }
}
```

### 5. object vs nested

```json
{
  "properties": {
    "user": { "type": "object" },                    // single object
    
    "addresses": { "type": "nested" },               // array of objects (preserves relationship)
    "comments": { "type": "nested" }
  }
}
```

**nested** preserves object relationships (e.g., must match both city AND country in same address). Use when querying arrays of objects.

### 6. Multi-Fields

```json
{
  "title": {
    "type": "text",
    "analyzer": "standard",
    "fields": {
      "keyword": { "type": "keyword", "ignore_above": 256 },
      "autocomplete": {
        "type": "text",
        "analyzer": "autocomplete"
      }
    }
  }
}
```

### 7. Custom Analyzers

```json
{
  "settings": {
    "analysis": {
      "analyzer": {
        "autocomplete": {
          "type": "custom",
          "tokenizer": "standard",
          "filter": ["lowercase", "autocomplete_filter"]
        },
        "portuguese": {
          "type": "custom",
          "tokenizer": "standard",
          "filter": ["lowercase", "portuguese_stemmer"]
        }
      },
      "filter": {
        "autocomplete_filter": {
          "type": "edge_ngram",
          "min_gram": 2,
          "max_gram": 20
        }
      }
    }
  }
}
```

### 8. Index Options for Performance

```json
{
  "title": {
    "type": "text",
    "norms": false,               // disable scoring (for filtering only)
    "index_options": "freqs",      // only store term frequency
    "similarity": "boolean"       // faster than default BM25
  }
}
```

## Good Example

```json
{
  "settings": {
    "number_of_shards": 3,
    "number_of_replicas": 1,
    "analysis": {
      "analyzer": {
        "content_analyzer": {
          "type": "custom",
          "tokenizer": "standard",
          "filter": ["lowercase", "portuguese_stemmer"]
        }
      }
    }
  },
  "mappings": {
    "dynamic": "strict",
    "properties": {
      "id": { "type": "keyword" },
      "title": {
        "type": "text",
        "analyzer": "content_analyzer",
        "fields": {
          "keyword": { "type": "keyword" }
        }
      },
      "body": { "type": "text", "analyzer": "content_analyzer" },
      "status": { "type": "keyword" },
      "category": { "type": "keyword" },
      "tags": { "type": "keyword" },
      "view_count": { "type": "long" },
      "rating": { "type": "float" },
      "author": {
        "type": "object",
        "properties": {
          "id": { "type": "keyword" },
          "name": { "type": "text" }
        }
      },
      "comments": {
        "type": "nested",
        "properties": {
          "user": { "type": "keyword" },
          "text": { "type": "text" },
          "created_at": { "type": "date" }
        }
      },
      "created_at": { "type": "date" },
      "updated_at": { "type": "date" }
    }
  }
}
```

## Bad Example

```json
{
  "mappings": {
    "dynamic": true,                          // DANGEROUS: creates any field
    "properties": {
      "title": { "type": "text" },            // Missing keyword sub-field for sorting
      "price": { "type": "float" },           // Should use scaled_float for currency
      "created_at": { "type": "date",         // No format specified
        "format": "strict_date_optional_time||epoch_millis||yyyy-MM-dd"  // Too many formats
      },
      "user": { "type": "object" },            // No properties defined (cannot query nested)
      "data": { "type": "object", "dynamic": true }  // Nested dynamic = field explosion
    }
  }
}
```

## Gotchas

1. **text Cannot Aggregate/Sort**: A field with only `type: "text"` cannot be used in aggregations or sorting. Add keyword sub-field.

2. **Dynamic Mapping Explosions**: With `dynamic: true`, ES creates mappings for any field, leading to thousands of fields. Use `dynamic: "strict"`.

3. **Cannot Change Mapping**: You can only add new fields to existing indices. To change mappings, must create new index and reindex.

4. **date Format Strictness**: Use strict_date_optional_time for flexibility. Custom formats must exactly match.

5. **nested Performance**: Documents in nested fields are indexed as separate hidden documents. Queries are correct but slower than object type.

6. **keyword ignore_above**: Default 256 characters. Values longer than this are ignored (not stored) in keyword aggregations.

7. **Index Options Overhead**: norms, doc_values, fielddata have memory cost. Disable what you don't need.

## When NOT to Use

- When you need geo queries (use geo_point or geo_shape types)
- When you have highly relational data (consider joining at query time or denormalizing)
- When you need strict schema validation (ES mapping is not enforced strictly)
- For small datasets that don't benefit from full-text search (use PostgreSQL instead)
