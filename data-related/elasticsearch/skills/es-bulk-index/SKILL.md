---
name: es-bulk-index
description: Use Elasticsearch Bulk API for batch indexing (10MB / 5000 docs per request). Use when "es bulk", "bulk index es", "elasticsearch bulk", "bulk insert es", "bulk api".
allowed-tools:
  - Read
  - Glob
  - Grep
  - Bash
---

# Elasticsearch Bulk Index

Use Bulk API for efficient batch indexing with NDJSON format and error handling.

## Trigger Phrases

"es bulk", "bulk index es", "elasticsearch bulk", "bulk insert es", "bulk api", "bulk update es", "bulk delete es"

## Pre-Flight Checks

Before bulk indexing:
1. **Cluster health** — `GET /_cluster/health` to confirm cluster is not red/yellow
2. **Index settings** — confirm refresh_interval and replicas settings
3. **ES Docs** — https://www.elastic.co/guide/en/elasticsearch/reference/current/docs-bulk.html

## Workflow

### 1. NDJSON Format

Bulk API uses NDJSON (newline-delimited JSON):

```
{action}\n
{doc}\n
{action}\n
{doc}\n
...
```

**Actions**: `index`, `create`, `update`, `delete`

```
{"index": {"_index": "my-index", "_id": "1"}}
{"field": "value", "other": 123}
{"create": {"_index": "my-index", "_id": "2"}}
{"field": "value2"}
{"delete": {"_index": "my-index", "_id": "3"}}
```

### 2. Basic Bulk Index

```javascript
const { BulkHelper } = require('@elastic/elasticsearch');

const body = [
  { index: { _index: 'products', _id: '1' } },
  { name: 'Product A', price: 99.99, category: 'electronics' },
  { index: { _index: 'products', _id: '2' } },
  { name: 'Product B', price: 49.99, category: 'clothing' },
  // ... more documents
];

const response = await esClient.bulk({ refresh: false, body });
```

### 3. Handle Errors Per-Item

```javascript
const response = await esClient.bulk({ body });

if (response.errors) {
  const erroredDocuments = response.items.filter(item => item.index?.error);
  
  for (const item of erroredDocuments) {
    console.error('Failed to index:', item.index._id);
    console.error('Error:', item.index.error);
  }
}
```

### 4. Retry Failures

```javascript
async function bulkWithRetry(docs, options = {}) {
  const { maxRetries = 3, chunkSize = 1000 } = options;
  
  for (let i = 0; i < docs.length; i += chunkSize) {
    const chunk = docs.slice(i, i + chunkSize);
    let retries = 0;
    
    while (retries < maxRetries) {
      try {
        const response = await esClient.bulk({ body: chunk });
        if (response.errors) {
          const failed = response.items.filter(item => item.index?.error);
          console.error(`${failed.length} documents failed`);
        }
        break;
      } catch (error) {
        retries++;
        if (retries >= maxRetries) throw error;
        await new Promise(r => setTimeout(r, 1000 * retries));
      }
    }
  }
}
```

### 5. Chunk by Size and Count

```javascript
const MAX_DOCS_PER_BULK = 5000;
const MAX_SIZE_BYTES = 10 * 1024 * 1024; // 10MB

function chunkDocuments(docs) {
  const chunks = [];
  let currentChunk = [];
  let currentSize = 0;

  for (const doc of docs) {
    const docSize = JSON.stringify(doc).length;
    
    if (currentChunk.length >= MAX_DOCS_PER_BULK || 
        currentSize + docSize > MAX_SIZE_BYTES) {
      chunks.push(currentChunk);
      currentChunk = [];
      currentSize = 0;
    }
    
    currentChunk.push(doc);
    currentSize += docSize;
  }
  
  if (currentChunk.length > 0) {
    chunks.push(currentChunk);
  }
  
  return chunks;
}
```

### 6. Optimize Bulk Performance

```javascript
// Before bulk: disable replicas for initial load
await esClient.indices.putSettings({
  index: 'products',
  body: {
    "index.refresh_interval": "-1",
    "index.number_of_replicas": 0
  }
});

// Bulk index documents...

// After bulk: re-enable settings
await esClient.indices.putSettings({
  index: 'products',
  body: {
    "index.refresh_interval": "1s",
    "index.number_of_replicas": 1
  }
});

// Force refresh to make documents searchable
await esClient.indices.refresh({ index: 'products' });
```

### 7. Bulk Update and Delete

```javascript
const body = [
  // Update
  { update: { _index: 'products', _id: '1' } },
  { doc: { price: 89.99, updated_at: new Date().toISOString() } },
  
  // Delete
  { delete: { _index: 'products', _id: '2' } }
];

const response = await esClient.bulk({ body });
```

## Good Example

```javascript
const https = require('https');

async function bulkIndexProducts(products) {
  const esHost = process.env.ES_HOST;
  const indexName = 'products';
  
  // Prepare NDJSON payload
  let payload = '';
  
  for (const product of products) {
    const action = { index: { _index: indexName, _id: product.id } };
    payload += JSON.stringify(action) + '\n';
    payload += JSON.stringify({
      name: product.name,
      description: product.description,
      price: product.price,
      category: product.category,
      stock: product.stock,
      updated_at: new Date().toISOString()
    }) + '\n';
  }
  
  const options = {
    hostname: esHost,
    port: 443,
    path: '/_bulk',
    method: 'POST',
    headers: {
      'Content-Type': 'application/x-ndjson',
      'Content-Length': Buffer.byteLength(payload)
    }
  };
  
  return new Promise((resolve, reject) => {
    const req = https.request(options, (res) => {
      let data = '';
      res.on('data', chunk => data += chunk);
      res.on('end', () => {
        const response = JSON.parse(data);
        if (response.errors) {
          const errors = response.items.filter(i => i.index?.error);
          console.error(`${errors.length} items failed`);
          resolve({ indexed: response.items.length - errors.length, errors });
        } else {
          resolve({ indexed: response.items.length });
        }
      });
    });
    
    req.on('error', reject);
    req.write(payload);
    req.end();
  });
}
```

## Bad Example

```javascript
// NEVER: Forget newline at end
const body = [
  { index: { _index: 'test', _id: '1' } },
  { field: 'value' }
  // Missing final newline
];

// NEVER: Mixed action types incorrectly
{ index: { ... } }
{ field: 'value' }
{ create: { ... } }      // Missing doc after index action!
{ delete: { ... } }     // Delete should not have doc

// NEVER: refresh: true during large bulk (extremely slow)
await esClient.bulk({ body: docs, refresh: true });  // Waits for refresh every batch

// NEVER: Exceed 10MB limit without chunking
await esClient.bulk({ body: hugeArrayOfDocs });  // May fail or timeout
```

## Gotchas

1. **10MB Request Limit**: Each bulk request capped at ~10MB. Chunk large datasets.

2. **Per-Item Errors**: Bulk continues on error. Check `response.errors` boolean and iterate `response.items`.

3. **refresh: true is Slow**: Default `refresh: false`. Only use true for small, critical datasets that must be immediately searchable.

4. **Thread Pool Size**: Default bulk thread pool size is 200. If queue full, requests rejected. Monitor with `_cat/thread_pool?v`.

5. **Explicit IDs for Idempotency**: Use explicit `_id` for index/update to enable retry. Auto-generated IDs change on retry.

6. **NDJSON Trailing Newline**: Final line must end with newline `\n`. Missing newline = parse error.

7. **Delete Has No Body**: Only `{ "delete": { "_index": "...", "_id": "..." } }`. No document body.

## When NOT to Use

- For < 1000 documents (individual index calls are simpler)
- When you need real-time indexing (use normal index API with refresh)
- For documents with complex dependencies (bulk doesn't handle transactions)
- When cluster is red or overloaded (bulk will fail or worsen situation)
