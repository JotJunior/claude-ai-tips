---
name: es-reindex-zero-downtime
description: Reindex Elasticsearch with zero-downtime via alias swap. Use when "es reindex", "elasticsearch reindex", "alias swap es", "zero downtime es", "index rotation".
allowed-tools:
  - Read
  - Glob
  - Grep
  - Bash
---

# Elasticsearch Reindex Zero-Downtime

Reindex Elasticsearch with zero-downtime using alias swap pattern.

## Trigger Phrases

"es reindex", "elasticsearch reindex", "alias swap es", "zero downtime es", "index rotation", "es remap", "reindex without downtime"

## Pre-Flight Checks

Before reindexing:
1. **Cluster health** — `GET /_cluster/health` to confirm GREEN
2. **Source index** — `GET /<source>/_mapping` to review current mapping
3. **Document count** — `GET /<source>/_count` to estimate time
4. **ES Docs** — https://www.elastic.co/guide/en/elasticsearch/reference/current_docs-reindex.html

## Workflow

### 1. Create New Index with Updated Mapping

```json
PUT /articles-v2
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
    "properties": {
      "id": { "type": "keyword" },
      "title": {
        "type": "text",
        "analyzer": "content_analyzer",
        "fields": { "keyword": { "type": "keyword" } }
      },
      "content": { "type": "text", "analyzer": "content_analyzer" },
      "author": { "type": "keyword" },
      "created_at": { "type": "date" }
    }
  }
}
```

### 2. Execute Reindex

```json
POST /_reindex
{
  "source": {
    "index": "articles",
    "size": 1000,
    "sort": { "created_at": "desc" }
  },
  "dest": {
    "index": "articles-v2"
  }
}
```

### 3. Parallel Reindex with Slices

```json
POST /_reindex
{
  "source": {
    "index": "articles",
    "size": 5000
  },
  "dest": {
    "index": "articles-v2"
  },
  "slices": "auto"
}
```

**slices**: Number of parallel slices. `auto` = number of shards. Manual: `slices: 6`.

### 4. Monitor Progress

```json
GET /_tasks?actions=*reindex&detailed=true
```

Or check completion percentage:

```json
GET /_reindex/{task_id}
```

### 5. Verify Document Count

```javascript
const sourceCount = await esClient.count({ index: 'articles' });
const destCount = await esClient.count({ index: 'articles-v2' });

console.log(`Source: ${sourceCount.count}, Dest: ${destCount.count}`);

if (sourceCount.count !== destCount.count) {
  throw new Error('Document count mismatch!');
}
```

### 6. Atomic Alias Swap

```json
POST /_aliases
{
  "actions": [
    { "remove": { "index": "articles", "alias": "articles" } },
    { "add": { "index": "articles-v2", "alias": "articles" } }
  ]
}
```

This is atomic. All queries immediately use the new index.

### 7. Delete Old Index

After confirming everything works:

```json
DELETE /articles
```

### 8. Query Consumer Pattern

Application should always use alias, never index name:

```javascript
// GOOD: uses alias (switchable)
const results = await esClient.search({
  index: 'articles',  // alias
  query: { match: { title: 'elasticsearch' } }
});

// BAD: hardcoded index name (cannot switch)
const results = await esClient.search({
  index: 'articles-v2',  // hardcoded - BAD
  query: { match: { title: 'elasticsearch' } }
});
```

## Good Example

```javascript
async function reindexWithAliasSwap(sourceIndex, destIndex, alias) {
  console.log(`Starting reindex: ${sourceIndex} -> ${destIndex}`);
  
  // 1. Create new index with new mapping
  await createIndexWithMapping(destIndex);
  
  // 2. Execute reindex with progress tracking
  const reindexResponse = await esClient.reindex({
    source: { index: sourceIndex, size: 5000 },
    dest: { index: destIndex },
    slices: 'auto',
    wait_for_completion: false
  });
  
  const taskId = reindexResponse.task;
  
  // 3. Poll for completion
  while (true) {
    const task = await esClient.tasks.get({ task_id: taskId });
    if (task.completed) break;
    
    const status = task.task.status;
    console.log(`Progress: ${status.created}/${status.total} (${Math.round(status.created/status.total*100)}%)`);
    await new Promise(r => setTimeout(r, 5000));
  }
  
  // 4. Verify counts
  const sourceCount = await esClient.count({ index: sourceIndex });
  const destCount = await esClient.count({ index: destIndex });
  
  if (sourceCount.count !== destCount.count) {
    throw new Error(`Count mismatch: ${sourceCount.count} vs ${destCount.count}`);
  }
  
  // 5. Atomic alias swap
  await esClient.indices.putAlias({
    index: destIndex,
    name: alias,
    body: { remove_index: { index: sourceIndex } }
  });
  
  console.log(`Reindex complete. Alias '${alias}' now points to ${destIndex}`);
}
```

## Bad Example

```json
// NEVER: Query hardcoded to old index (after reindex, queries still hit old)
GET /articles-v1/_search   // Old index still exists
{ "query": { "match": { "title": "test" } } }

// NEVER: Reindex without slices on large index (slow)
POST /_reindex
{
  "source": { "index": "huge-index" },
  "dest": { "index": "huge-index-v2" }
  // Missing slices - runs single-threaded
}

// NEVER: Delete old index before alias swap confirmed
DELETE /articles
// If alias swap fails, you have no index!
```

## Gotchas

1. **Reindex Copies Documents**: No transformation during reindex without Painless script. For field mapping changes, documents are copied as-is.

2. **Remote Reindex**: Can reindex from different cluster via `remote.whitelist`. Useful for version migration.

3. **slices Parallelism**: `slices: auto` creates one slice per shard. For very large indices, manually set higher.

4. **conflict: proceed vs abort**: Default `conflicts: abort`. Use `conflicts: proceed` to continue on version conflicts (old doc wins).

5. **Alias Swap is Atomic**: The `_aliases` API is atomic. Queries either see old or new index, never both during transition.

6. **Query Must Use Alias**: Applications must query by alias, not index name. Hardcoded index names prevent zero-downtime switching.

7. **Timestamp Preservation**: Reindex preserves `_version`. Internal timestamps (`@timestamp`) not affected unless you explicitly update them.

## When NOT to Use

- For simple mapping additions (can use dynamic templates or update mapping with new fields)
- When source index is being actively written to heavily (consider using _reindex with version_type: external)
- For extremely large indices requiring days to reindex (consider cross-cluster replication instead)
- When you need to transform data significantly during reindex (use Logstash or custom pipeline)
