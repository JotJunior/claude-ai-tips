---
name: es-logging-pattern
description: |
  Configure Elasticsearch index pattern for logs with time-based ILM rollover. Use when "es logs", "elasticsearch logging", "ilm pattern", "logs index es", "elastic stack logging".
  Use quando o usuário pedir: "log elasticsearch", "padrão logging es", "ingest logs es", "estrutura logs".
allowed-tools:
  - Read
  - Glob
  - Grep
  - Bash
---

# Elasticsearch Logging Pattern

Configure Elasticsearch index patterns for logs with time-based ILM (Index Lifecycle Management) rollover.

## Trigger Phrases

"es logs", "elasticsearch logging", "ilm pattern", "logs index es", "elastic stack logging", "data stream es", "log rotation es"

## Pre-Flight Checks

Before setting up log indices:
1. **ILM availability** — `GET /_ilm` to confirm ILM plugin is enabled
2. **ILM docs** — https://www.elastic.co/guide/en/elasticsearch/reference/current/index-lifecycle-management.html
3. **ECS schema** — https://www.elastic.co/guide/en/ecs/current/

## Workflow

### 1. Define ILM Policy

```json
PUT /_ilm/policy/logs-app-policy
{
  "policy": {
    "phases": {
      "hot": {
        "min_age": "0ms",
        "actions": {
          "rollover": {
            "max_primary_shard_size": "50gb",
            "max_age": "7d"
          },
          "set_priority": { "priority": 100 }
        }
      },
      "warm": {
        "min_age": "30d",
        "actions": {
          "shrink": { "number_of_shards": 1 },
          "forcemerge": { "max_num_segments": 1 },
          "set_priority": { "priority": 50 }
        }
      },
      "cold": {
        "min_age": "90d",
        "actions": {
          "set_priority": { "priority": 0 },
          "allocate": { "require": { "data": "cold" } }
        }
      },
      "delete": {
        "min_age": "365d",
        "actions": {
          "delete": {}
        }
      }
    }
  }
}
```

### 2. Create Index Template with Mapping

```json
PUT /_index_template/logs-app-template
{
  "index_patterns": ["logs-app-*"],
  "template": {
    "settings": {
      "number_of_shards": 1,
      "number_of_replicas": 1,
      "index.lifecycle.name": "logs-app-policy",
      "index.lifecycle.rollover_alias": "logs-app"
    },
    "mappings": {
      "dynamic": "strict",
      "properties": {
        "@timestamp": { "type": "date" },
        "log.level": { "type": "keyword" },
        "message": { "type": "text" },
        "service.name": { "type": "keyword" },
        "service.version": { "type": "keyword" },
        "environment": { "type": "keyword" },
        "host.name": { "type": "keyword" },
        "trace.id": { "type": "keyword" },
        "span.id": { "type": "keyword" },
        "error.type": { "type": "keyword" },
        "error.message": { "type": "text" }
      }
    }
  },
  "priority": 100
}
```

### 3. Create Data Stream (Preferred)

```json
PUT /_data_stream/logs-app-prod
{
  "name": "logs-app-prod",
  "indices": [
    {
      "index_name": ".ds-logs-app-prod-000001",
      "settings": {
        "index.number_of_shards": 1,
        "index.number_of_replicas": 1,
        "index.lifecycle.name": "logs-app-policy"
      }
    }
  ]
}
```

### 4. Create Write Index Alias

```json
PUT /logs-app-prod/_rollover
{
  "conditions": {
    "max_age": "7d",
    "max_primary_shard_size": "50gb"
  },
  "aliases": {
    "logs-app-prod-write": {}
  }
}
```

### 5. Use Index Pattern for Writes

```javascript
// Write to alias (auto-routed to current write index)
await esClient.index({
  index: 'logs-app-prod-write',
  document: {
    '@timestamp': new Date().toISOString(),
    'log.level': 'info',
    'message': 'User logged in',
    'service.name': 'auth-service',
    'environment': 'production'
  }
});
```

### 6. Query Across All Indices

```javascript
// Query using data stream (covers all rolled indices)
const response = await esClient.search({
  index: 'logs-app-prod',
  query: {
    range: {
      '@timestamp': {
        gte: 'now-7d',
        lte: 'now'
      }
    }
  },
  aggs: {
    by_level: {
      terms: { field: 'log.level' },
      aggs: {
        by_service: {
          terms: { field: 'service.name', size: 20 }
        }
      }
    }
  }
});
```

### 7. ECS (Elastic Common Schema) Compliance

```json
{
  "mappings": {
    "properties": {
      "@timestamp": { "type": "date" },
      "message": { "type": "text" },
      "ecs.version": { "type": "keyword" },
      "log.logger": { "type": "keyword" },
      "log.level": { "type": "keyword" },
      "service.name": { "type": "keyword" },
      "service.version": { "type": "keyword" },
      "service.environment": { "type": "keyword" },
      "host.name": { "type": "keyword" },
      "trace.id": { "type": "keyword" },
      "span.id": { "type": "keyword" },
      "user.id": { "type": "keyword" },
      "source.ip": { "type": "ip" },
      "destination.ip": { "type": "ip" },
      "url.path": { "type": "keyword" },
      "url.full": { "type": "text" }
    }
  }
}
```

### 8. Ingest Pipeline for Parsing

```json
PUT /_ingest/pipeline/logs-app-pipeline
{
  "processors": [
    {
      "timestamp": {
        "field": "message",
        "formats": ["ISO8601", "yyyy-MM-dd'T'HH:mm:ss.SSSZ"]
      }
    },
    {
      "grok": {
        "field": "message",
        "patterns": ["%{LOGLEVEL:log.level} - %{MESSAGE:message}"]
      }
    },
    {
      "json": {
        "field": "message",
        "target_field": "parsed"
      }
    }
  ]
}
```

## Good Example

```javascript
// Setup ILM policy programmatically
async function setupLogIndex(esClient, indexName, env) {
  const policyName = `${indexName}-policy`;
  const templateName = `${indexName}-template`;
  const aliasName = `${indexName}-write`;
  
  // 1. Create ILM policy
  await esClient.ilm.putLifecycle({
    name: policyName,
    policy: {
      phases: {
        hot: {
          min_age: '0ms',
          actions: {
            rollover: { max_age: '7d', max_primary_shard_size: '50gb' },
            set_priority: { priority: 100 }
          }
        },
        warm: {
          min_age: '30d',
          actions: {
            shrink: { number_of_shards: 1 },
            forcemerge: { max_num_segments: 1 },
            set_priority: { priority: 50 }
          }
        },
        delete: {
          min_age: '365d',
          actions: { delete: {} }
        }
      }
    }
  });
  
  // 2. Create index template
  await esClient.indices.putIndexTemplate({
    name: templateName,
    index_patterns: [`${indexName}-*`],
    template: {
      settings: {
        'index.lifecycle.name': policyName
      },
      mappings: {
        properties: {
          '@timestamp': { type: 'date' },
          'log.level': { type: 'keyword' },
          'message': { type: 'text' },
          'service.name': { type: 'keyword' }
        }
      }
    }
  });
  
  console.log(`Log index ${indexName} configured with ILM policy`);
}

// Write log entry
async function writeLog(esClient, indexName, level, message, metadata = {}) {
  await esClient.index({
    index: `${indexName}-write`,
    document: {
      '@timestamp': new Date().toISOString(),
      'log.level': level,
      message,
      'service.name': metadata.service || 'unknown',
      environment: metadata.env || 'production',
      ...metadata
    }
  });
}
```

## Bad Example

```json
// NEVER: No ILM policy (indices never deleted, disk fills up)
PUT /logs-app
{
  "mappings": { ... }
}
// No lifecycle = infinite growth

// NEVER: Too many fields without ECS
{
  "mappings": {
    "properties": {
      "level": { "type": "keyword" },        // Should be log.level
      "msg": { "type": "text" },             // Should be message
      "svc": { "type": "keyword" },          // Should be service.name
      "timestamp": { "type": "date" }        // Should be @timestamp
    }
  }
}

// NEVER: Total field limit explosion (PII flattened)
{
  "dynamic": true,  // Dangerous for logs!
}
// Creates fields for every unique JSON key = thousands of fields

// NEVER: ILM policy with conflicting settings
{
  "hot": {
    "actions": {
      "rollover": { "max_age": "1d" },
      "set_priority": { "priority": 0 }  // Hot should be highest priority
    }
  }
}
```

## Gotchas

1. **Data Streams > Raw Indices**: Data streams automatically manage rollover, retention, and querying across indices. Use data streams for time-series data.

2. **ILM Phase Lifecycle**: ILM moves indices through phases. Configure hot → warm → cold → delete. Not all phases required.

3. **Mapping in Template**: Index template mapping is applied when index is created. Cannot change mapping on existing indices without reindex.

4. **ECS Schema**: Elastic Common Schema standardizes field names. Improves compatibility with Beats, Logstash, and SIEM integrations.

5. **Ingest Pipeline Overhead**: Parsing processors consume CPU. For high-volume logs, parse only what's needed.

6. **Total Field Limit**: Default 1000 fields per index. Flattening deeply nested PII can exceed limit. Use nested objects or flatten carefully.

7. **keyword.ignore_above**: Default 256 characters. Long paths/URLs truncated in keyword aggregations. Use text for full content search.

## When NOT to Use

- For relational data or complex joins (use separate indices with JOIN at query time)
- When you need real-time (< 1s) alerting on every log (use ingest pipelines with watchers instead)
- For data exceeding 10GB/day per index (shard sizing issues; consider sampling or tiered ingestion)
- When you need schema changes without reindex (ILM cannot modify mappings; must reindex)
