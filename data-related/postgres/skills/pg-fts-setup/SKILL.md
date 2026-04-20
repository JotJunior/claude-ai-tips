---
name: pg-fts-setup
description: Implement PostgreSQL full-text search using tsvector, tsquery, dictionaries, and GIN indexes. Use when asked to fts postgres, full text search postgres, tsvector setup, search postgres, text search, search functionality.
allowed-tools:
  - Read
  - Glob
  - Grep
  - Bash
---

# PostgreSQL Full-Text Search Setup

Implement PostgreSQL full-text search with tsvector, tsquery, dictionaries, and GIN indexes for efficient text search.

## Trigger Phrases

"fts postgres", "full text search postgres", "tsvector setup", "search postgres", "text search", "search functionality", "tsquery", "tsrank"

## Pre-Flight Checks

1. Confirm search volume and performance requirements
2. Check PostgreSQL version: Full-text search features vary by version
3. Identify language for text processing (Portuguese, English, etc.)
4. Check existing table structure and content volume

## Workflow

### Step 1: Choose Language and Dictionary

```sql
-- Available dictionaries
-- 'simple': No stop words, no stemming (good for codes, identifiers)
-- 'english': English stemming and stop words
-- 'portuguese': Portuguese stemming and stop words (install via contrib)
-- 'spanish', 'french', 'german', etc.

-- Install hunspell dictionaries for Portuguese (if not available)
-- Ubuntu/Debian: apt-get install hunspell-pt-pt
-- Or use unaccent extension for accent removal

-- Check available dictionaries
SELECT * FROM pg_ts_dict WHERE dictname LIKE '%portuguese%';
SELECT * FROM pg_ts_config;
```

### Step 2: Install Required Extensions

```sql
-- Unaccent for removing accents (important for Portuguese)
CREATE EXTENSION IF NOT EXISTS unaccent;

-- Enable the unaccent dictionary as a text search template
CREATE TEXT SEARCH CONFIGURATION IF NOT EXISTS portuguese (COPY = portuguese);
ALTER TEXT SEARCH CONFIGURATION portuguese MAPPING FOR hword_asciipart WITH unaccent, simple;
ALTER TEXT SEARCH CONFIGURATION portuguese MAPPING FOR word WITH unaccent, portuguese_stem;
```

### Step 3: Create tsvector Column

```sql
-- Option 1: Generated column (stored, computed on insert/update)
CREATE TABLE articles (
    id SERIAL PRIMARY KEY,
    title VARCHAR(255) NOT NULL,
    body TEXT,
    search_vector tsvector GENERATED ALWAYS AS (
        setweight(to_tsvector('portuguese', coalesce(title, '')), 'A') ||
        setweight(to_tsvector('portuguese', coalesce(body, '')), 'B')
    ) STORED,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Option 2: Manual tsvector with trigger (for more control)
CREATE TABLE articles_manual (
    id SERIAL PRIMARY KEY,
    title VARCHAR(255) NOT NULL,
    body TEXT,
    search_vector tsvector,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Trigger to update search_vector
CREATE OR REPLACE FUNCTION articles_search_trigger() RETURNS TRIGGER AS $$
BEGIN
    NEW.search_vector := 
        setweight(to_tsvector('portuguese', coalesce(NEW.title, '')), 'A') ||
        setweight(to_tsvector('portuguese', coalesce(NEW.body, '')), 'B');
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER articles_search_update
    BEFORE INSERT OR UPDATE ON articles_manual
    FOR EACH ROW
    EXECUTE FUNCTION articles_search_trigger();
```

### Step 4: Create GIN Index

```sql
-- GIN index for fast search
CREATE INDEX idx_articles_search ON articles USING GIN(search_vector);

-- For Portuguese with unaccent
CREATE INDEX idx_articles_search_pt ON articles USING GIN(search_vector);
ALTER INDEX idx_articles_search OWNER TO app_user;
```

### Step 5: Query with tsquery

```sql
-- Basic search with to_tsquery (strict)
SELECT id, title, ts_rank(search_vector, to_tsquery('portuguese', 'postgres')) AS rank
FROM articles
WHERE search_vector @@ to_tsquery('portuguese', 'postgres')
ORDER BY rank DESC;

-- websearch_to_tsquery (more forgiving, user-friendly)
SELECT id, title
FROM articles
WHERE search_vector @@ websearch_to_tsquery('portuguese', 'postgres full text search')
ORDER BY ts_rank_cd(search_vector, websearch_to_tsquery('portuguese', 'postgres full text search')) DESC;

-- Phrase search with quotes
SELECT id, title
FROM articles
WHERE search_vector @@ websearch_to_tsquery('portuguese', '"full text" postgres')
ORDER BY ts_rank_cd(search_vector, websearch_to_tsquery('portuguese', '"full text" postgres')) DESC;

-- Prefix matching (partial words)
SELECT id, title
FROM articles
WHERE search_vector @@ to_tsquery('portuguese', 'postgres:*')
ORDER BY ts_rank(search_vector, to_tsquery('portuguese', 'postgres:*')) DESC;
```

### Step 6: Add Ranking and Highlighting

```sql
-- Ranking with ts_rank_cd (cumulative density ranking, better for multi-word)
SELECT 
    id, 
    title,
    ts_rank_cd(search_vector, websearch_to_tsquery('portuguese', $1)) AS rank
FROM articles
WHERE search_vector @@ websearch_to_tsquery('portuguese', $1)
ORDER BY rank DESC;

-- Highlighting results (shows matching terms)
SELECT 
    id,
    title,
    ts_headline('portuguese', body, websearch_to_tsquery('portuguese', $1), 
        'StartSel=<mark>, StopSel=</mark>, MaxWords=50, MinWords=20') AS snippet
FROM articles
WHERE search_vector @@ websearch_to_tsquery('portuguese', $1);

-- Combined: rank + highlight
SELECT 
    id,
    title,
    ts_rank_cd(search_vector, q) AS rank,
    ts_headline('portuguese', body, q, 'StartSel=<mark>, StopSel=</mark>') AS snippet
FROM articles,
     websearch_to_tsquery('portuguese', $1) AS q
WHERE search_vector @@ q
ORDER BY rank DESC;
```

### Step 7: Optimize for Large Datasets

```sql
-- Partial index for recent articles only
CREATE INDEX idx_articles_recent_search ON articles(created_at DESC) 
    WHERE created_at > '2024-01-01';

-- Combined index for time-filtered search
CREATE INDEX idx_articles_search_created ON articles USING GIN(search_vector) 
    WHERE created_at > '2024-01-01';

-- Rank with early filtering
SELECT id, title, ts_rank_cd(search_vector, q) AS rank
FROM articles,
     websearch_to_tsquery('portuguese', $1) AS q
WHERE search_vector @@ q
  AND created_at > '2024-01-01'  -- early filter using index
ORDER BY rank DESC
LIMIT 20;
```

## Complete Example: Article Search Table

```sql
CREATE TABLE articles (
    id SERIAL PRIMARY KEY,
    title VARCHAR(500) NOT NULL,
    summary TEXT,
    body TEXT NOT NULL,
    author VARCHAR(100),
    tags TEXT[],  -- array for exact tag matching
    search_vector tsvector GENERATED ALWAYS AS (
        setweight(to_tsvector('portuguese', coalesce(title, '')), 'A') ||
        setweight(to_tsvector('portuguese', coalesce(summary, '')), 'B') ||
        setweight(to_tsvector('portuguese', coalesce(body, '')), 'C') ||
        setweight(to_tsvector('simple', coalesce(array_to_string(tags, ' '), '')), 'D')
    ) STORED,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    is_published BOOLEAN DEFAULT false
);

-- Indexes
CREATE INDEX idx_articles_search ON articles USING GIN(search_vector);
CREATE INDEX idx_articles_published ON articles(created_at DESC) WHERE is_published = true;
CREATE INDEX idx_articles_tags ON articles USING GIN(tags);

-- Reindex after bulk insert
REINDEX INDEX idx_articles_search;
```

## Search Query Functions

| Function | Description | Example |
|----------|-------------|---------|
| `to_tsvector('dict', text)` | Convert text to tsvector | `to_tsvector('portuguese', 'Full text search')` |
| `to_tsquery('dict', text)` | Convert text to tsquery (strict) | `to_tsquery('portuguese', 'postgres & search')` |
| `websearch_to_tsquery('dict', text)` | User-friendly query parsing | `websearch_to_tsquery('portuguese', 'postgres search')` |
| `ts_rank(vec, query)` | Ranking function | `ts_rank(search_vector, q)` |
| `ts_rank_cd(vec, query)` | Cumulative density rank | `ts_rank_cd(search_vector, q)` |
| `ts_headline('dict', text, query)` | Highlight matches | `ts_headline('portuguese', body, q)` |

## Gotchas

1. **Dictionary for Portuguese**: Use 'portuguese' dictionary, not 'simple'. If the Portuguese dictionary is not installed, install contrib packages: `postgresql-contrib` package.

2. **Unaccent extension for accents**: In Portuguese, users search for "pizza" and expect results with "pizza", "piça", etc. Use unaccent extension and create custom text search configuration.

3. **websearch_to_tsquery vs to_tsquery**: `websearch_to_tsquery` is more forgiving for user input. It handles spaces as AND, supports quotes for phrases, and handles colons for prefixes. Prefer it for user-facing search.

4. **STORED vs computed on query**: Generated columns with STORED are computed on INSERT/UPDATE and stored on disk. Non-stored (VIRTUAL) would compute on every read. STORED is correct for frequently searched columns.

5. **Weight categories (A,B,C,D)**: Assign weights to give more importance to title (A) vs body (C). `ts_rank_cd` uses weights in ranking calculation.

6. **Prefix matching with `:*`**: To match "postgres" in "postgresql", use `to_tsquery('portuguese', 'postgres:*')`.

7. **tsvector size**: Large documents create large tsvector values. Consider `summary` field for search instead of full `body` when body is very large.

8. **Index maintenance**: GIN indexes are large and slow to build. For very large tables, consider building incrementally or using `CONCURRENTLY`.

9. **Phrase search requires quotes**: `"full text"` in websearch_to_tsquery searches for the exact phrase, not individual words.

10. **Array columns for exact matching**: If you need exact tag/category matching alongside FTS, use separate TEXT[] column with GIN index, not FTS.

## When NOT to Use This Skill

- When you need simple exact-match searches (use regular indexes)
- When you need to design JSONB storage (use `pg-jsonb-patterns`)
- When you need to create migrations (use `pg-add-migration`)
- When you need to review schema (use `pg-review-schema`)
