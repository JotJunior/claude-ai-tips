---
name: d1-fts5-setup
description: |
  Configure Full-Text Search (FTS5) virtual tables in D1 for scalable search. Use when "d1 fts", "full text search d1", "fts5 cloudflare", "search d1", "fts5 virtual table".
  Use quando o usuário pedir: "fts5 d1", "full text search d1", "busca textual d1", "configurar fts5".
allowed-tools:
  - Read
  - Glob
  - Grep
  - Bash
---

# D1 FTS5 Setup

Configure Full-Text Search using FTS5 virtual tables in Cloudflare D1.

## Trigger Phrases

"d1 fts", "full text search d1", "fts5 cloudflare", "search d1", "fts5 virtual table", "fts5 trigger"

## Pre-Flight Checks

Before implementing FTS:
1. **FTS5 Support** — D1 supports FTS5 (not FTS3/4). Confirm via `wrangler d1 execute <db> --command "CREATE VIRTUAL TABLE fts USING fts5(content)"` test
2. **Search volume** — FTS5 indexes consume storage. Estimate at ~3x original data size
3. **D1 Docs** — https://developers.cloudflare.com/d1/build-databases/query-databases/#full-text-search

## Workflow

### 1. Create FTS5 Virtual Table

**Option A: Independent FTS table** (duplicates data)

```sql
CREATE VIRTUAL TABLE docs_fts USING fts5(title, body);
```

**Option B: External content table** (recommended, avoids duplication)

```sql
-- Main content table
CREATE TABLE IF NOT EXISTS docs (
    id INTEGER PRIMARY KEY,
    title TEXT NOT NULL,
    body TEXT NOT NULL,
    created_at INTEGER NOT NULL
) STRICT;

-- FTS virtual table referencing external content
CREATE VIRTUAL TABLE docs_fts USING fts5(
    title,
    body,
    content=docs,
    content_rowid=id
);
```

### 2. Create Sync Triggers

Keep FTS index synchronized with content table:

```sql
-- AFTER INSERT trigger
CREATE TRIGGER docs_ai AFTER INSERT ON docs BEGIN
    INSERT INTO docs_fts(rowid, title, body) VALUES (new.id, new.title, new.body);
END;

-- AFTER UPDATE trigger
CREATE TRIGGER docs_au AFTER UPDATE ON docs BEGIN
    INSERT INTO docs_fts(docs_fts, rowid, title, body) VALUES ('delete', old.id, old.title, old.body);
    INSERT INTO docs_fts(rowid, title, body) VALUES (new.id, new.title, new.body);
END;

-- AFTER DELETE trigger
CREATE TRIGGER docs_ad AFTER DELETE ON docs BEGIN
    INSERT INTO docs_fts(docs_fts, rowid, title, body) VALUES ('delete', old.id, old.title, old.body);
END;
```

### 3. Query FTS Index

Basic MATCH query:

```sql
SELECT * FROM docs_fts WHERE docs_fts MATCH 'palavra-chave';
```

Query with ranking (BM25):

```sql
SELECT d.*, bm25(docs_fts) as rank
FROM docs d
JOIN docs_fts ON d.id = docs_fts.rowid
WHERE docs_fts MATCH 'javascript tutorial'
ORDER BY rank;
```

Query with highlighting:

```sql
SELECT 
    d.id,
    highlight(docs_fts, 0, '<b>', '</b>') as highlighted_title,
    highlight(docs_fts, 1, '<b>', '</b>') as highlighted_body
FROM docs d
JOIN docs_fts ON d.id = docs_fts.rowid
WHERE docs_fts MATCH 'javascript'
LIMIT 20;
```

### 4. Advanced MATCH Syntax

```
-- Prefix search (words starting with)
'javasc*'

-- Multiple words (AND)
'javascript AND tutorial'

-- Multiple words (OR)
'javascript OR python'

-- Phrase search
'"full text search"'

-- NEAR (proximity)
'javascript NEAR/3 tutorial'

-- NOT exclusion
'javascript NOT java'

-- Column-specific
'title:javascript body:tutorial'
```

### 5. Use Snippet for Excerpts

```sql
SELECT 
    d.id,
    d.title,
    snippet(docs_fts, 1, '<b>', '</b>', '...', 20) as body_excerpt
FROM docs d
JOIN docs_fts ON d.id = docs_fts.rowid
WHERE docs_fts MATCH 'search term'
LIMIT 10;
```

## Good Example

```sql
-- Migration: 003_create_articles_fts
CREATE TABLE IF NOT EXISTS articles (
    id INTEGER PRIMARY KEY,
    title TEXT NOT NULL,
    content TEXT NOT NULL,
    author_id INTEGER REFERENCES users(id),
    published_at INTEGER,
    deleted_at INTEGER
) STRICT;

CREATE VIRTUAL TABLE articles_fts USING fts5(
    title,
    content,
    content=articles,
    content_rowid=id,
    tokenize='unicode61'
);

CREATE TRIGGER articles_ai AFTER INSERT ON articles BEGIN
    INSERT INTO articles_fts(rowid, title, content) VALUES (new.id, new.title, new.content);
END;

CREATE TRIGGER articles_ad AFTER DELETE ON articles BEGIN
    INSERT INTO articles_fts(articles_fts, rowid, title, content) VALUES ('delete', old.id, old.title, old.content);
END;

-- Query with ranking
SELECT a.*, bm25(articles_fts) as rank
FROM articles a
JOIN articles_fts ON a.id = articles_fts.rowid
WHERE articles_fts MATCH 'cloudflare workers' AND a.deleted_at IS NULL
ORDER BY rank
LIMIT 20;
```

## Bad Example

```sql
-- NEVER: FTS without sync triggers (index goes stale)
CREATE VIRTUAL TABLE articles_fts USING fts5(title, content, content=articles, content_rowid=id);
-- Missing triggers = FTS index never updated!

-- NEVER: Search without FTS table
SELECT * FROM articles WHERE title LIKE '%search%' OR content LIKE '%search%';  -- Slow, no index

-- NEVER: Use FTS MATCH on non-FTS column
SELECT * FROM articles WHERE id MATCH '123';  -- Error: id is not in FTS table
```

## Gotchas

1. **External Content Table**: Use `content=<table>` to avoid duplicating data in FTS virtual table. Data is queried via JOIN.

2. **Unicode Tokenizer**: Default `unicode61` tokenizer handles accents correctly. For Portuguese, this is sufficient.

3. **MATCH Syntax**: FTS5 MATCH syntax differs from LIKE. Prefix search uses `term*` (not `*term`). Boolean operators: AND, OR, NOT (uppercase).

4. **Contentless FTS5**: Can use `contentless` option for read-only FTS (no triggers needed), but then you cannot update/delete.

5. **Highlight/Snippet Overhead**: These functions process results at query time. For high-volume searches, precompute excerpts.

6. **FTS5 Column Constraints**: FTS5 virtual tables cannot have CHECK, DEFAULT, or UNIQUE constraints. Validation must be done on the content table.

7. **bm25 Ranking**: Lower BM25 score = better ranking. BM25 can be NULL for some matches.

## When NOT to Use

- For exact match queries (use standard SQL with indexes)
- For prefix-only search with very large vocabularies (consider trigram indexes)
- When you need faceted search with counts per category (use ES instead)
- When storage is severely constrained (FTS5 indexes can be 2-3x table size)
