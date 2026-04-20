---
name: es-version-migrate
description: |
  Migrate Elasticsearch between major versions (7 to 8, 8 to 9). Use when "es upgrade", "elasticsearch migration version", "es 7 to 8", "es upgrade major", "es version upgrade".
  Use quando o usuário pedir: "migrar versão es", "upgrade elasticsearch", "atualizar elasticsearch".
allowed-tools:
  - Read
  - Glob
  - Grep
  - Bash
---

# Elasticsearch Version Migration

Migrate Elasticsearch between major versions (7 to 8, 8 to 9) following breaking changes.

## Trigger Phrases

"es upgrade", "elasticsearch migration version", "es 7 to 8", "es upgrade major", "es version upgrade", "elasticsearch breaking changes"

## Pre-Flight Checks

Before upgrading:
1. **Current version** — `GET /` to see version
2. **Breaking changes** — Read ES upgrade docs for your specific upgrade path
3. **Client compatibility** — Ensure client libraries support new version
4. **Snapshot backup** — Take snapshot before upgrade
5. **ES Docs** — https://www.elastic.co/guide/en/elasticsearch/reference/current/setup-upgrade.html

## Workflow

### 1. Understand Breaking Changes Per Version

**7 to 8 Breaking Changes:**
- Removed `_type` from APIs (indices now have single mapping type)
- Default security enabled (TLS certificates required)
- `敲` token transport removed (use Bearer tokens)
- `www-authenticate` header changes
- Java High Level REST Client deprecated (use new Java API Client)

**8 to 9 Breaking Changes:**
- Removed `geo_shape` deprecations
- Changes to `search_after` behavior
- API key format changes
- Potential field mapping changes

### 2. Upgrade Clients First

Before upgrading ES, upgrade client libraries:

```javascript
// Before ES 8.x
npm install @elastic/elasticsearch@7

// Upgrade to ES 8.x client
npm install @elastic/elasticsearch@8
```

### 3. Take Snapshot Backup

```json
PUT /_snapshot/my_backup
{
  "type": "fs",
  "settings": {
    "location": "/mnt/backup"
  }
}

POST /_snapshot/my_backup/snapshot_20240115
{
  "indices": "*",
  "include_global_state": true
}
```

### 4. Rolling Upgrade (Node by Node)

For clustered deployments:

```
1. Disable shard allocation
   PUT /_cluster/settings
   { "transient": { "cluster.routing.allocation.enable": "primaries" } }

2. Stop one node
   systemctl stop elasticsearch

3. Upgrade Elasticsearch on node

4. Start upgraded node

5. Wait for node to join cluster
   GET /_cat/health?v

6. Enable shard allocation
   PUT /_cluster/settings
   { "transient": { "cluster.routing.allocation.enable": "all" } }

7. Wait for yellow/green
   GET /_cluster/health?wait_for_status=green&timeout=30m

8. Repeat for remaining nodes
```

### 5. Re-enable Shard Allocation

```json
PUT /_cluster/settings
{
  "transient": {
    "cluster.routing.allocation.enable": "all"
  }
}
```

### 6. Run Upgrade Assistant

ES 7.10+ has built-in upgrade assistant:

```
GET /_upgrade
GET /_upgrade/check_preparation
```

### 7. Reindex Deprecated Indices

After upgrade, indices with old mappings may need reindex:

```json
GET /<index>/_reindex
```

### 8. API Changes for 7 to 8

**Remove `_type` from URLs:**

```javascript
// ES 7.x
client.search({ index: 'myindex', type: 'mydoc', body: {} })

// ES 8.x
client.search({ index: 'myindex', body: {} })  // No type
```

**Security Configuration:**

```javascript
// ES 8.x client with security
import { Client } from '@elastic/elasticsearch';

const client = new Client({
  node: 'https://localhost:9200',
  auth: {
    username: 'elastic',
    password: 'password'
  },
  tls: {
    caFingerprint: '...',
    rejectUnauthorized: false  // Only for dev
  }
});
```

**New Error Response Format:**

```javascript
// ES 8.x wraps errors differently
try {
  await client.search({ ... });
} catch (error) {
  if (error.meta?.statusCode === 404) {
    // Handle not found
  }
  console.error(error.meta?.body?.error);
}
```

## Good Example

```javascript
// ES 8.x compatible client setup
import { Client } from '@elastic/elasticsearch';

const esClient = new Client({
  node: process.env.ES_NODE || 'https://localhost:9200',
  auth: {
    apiKey: process.env.ES_API_KEY  // Preferred over username/password
  },
  tls: {
    caFingerprint: process.env.ES_CA_FINGERPRINT,
    rejectUnauthorized: process.env.NODE_ENV === 'production'
  }
});

// Check cluster health before upgrade
async function checkClusterHealth() {
  const health = await esClient.cluster.health();
  console.log(`Cluster: ${health.cluster_name}, Status: ${health.status}`);
  return health.status === 'green' || health.status === 'yellow';
}

// Version-aware query
async function searchWithCompatibility(index, query) {
  const response = await esClient.search({
    index,
    query,
    // ES 8.x ignores size when not needed, but required for pagination
    size: 20
  });
  
  return {
    hits: response.hits.hits,
    total: response.hits.total.value
  };
}
```

## Bad Example

```javascript
// NEVER: Use Basic Auth with ES 8.x (deprecated)
const client = new Client({
  node: 'https://localhost:9200',
  auth: { username: 'elastic', password: 'secret' }  // Deprecated warning
});

// NEVER: Skip snapshot before upgrade
await esClient.indices.delete({ index: 'old-index' });  // Lost forever!

// NEVER: Upgrade client before taking snapshot
await upgradeClient();  // Client talks to old ES, everything works
await upgradeES();      // ES upgraded
// Client no longer compatible, cannot roll back

// NEVER: Mixed versions in cluster
// Node1: ES 7.x
// Node2: ES 8.x  <- May cause compatibility issues
```

## Gotchas

1. **Removed Types in 8.x**: Indices can only have one type. `_type` removed from URLs. Multi-type indices must be reindexed.

2. **Security Enabled by Default**: ES 8.x has security (SSL, auth) enabled by default. Clients must configure credentials.

3. **Token Transport Removed**: `_auth` tokens not supported in 8.x. Use API keys or Bearer tokens.

4. **Index Compatibility**: Indices are forward-compatible only (n-1). ES 8 index cannot be opened by ES 7.

5. **Client Library Breaking**: Java High Level REST Client removed in 8.x. Use new Java API Client or HTTP client directly.

6. **API Key Recommended**: Basic Auth deprecated. Use API keys with `POST /_security/api_key`.

7. **Helmet of Breaking Changes**: Each minor version within a major can have breaking changes. Check changelog.

## When NOT to Use

- When you have insufficient disk space for snapshot + upgrade
- When indices are in an unsupported old format (pre-5.x indices must be reindexed through each version)
- When you need to downgrade after upgrade (not supported across major versions)
- When cluster is already red or unstable (fix before upgrading)
