---
name: cf-workers-create-kv-namespace
description: |
  Use quando precisar criar um novo KV namespace para caching ou storage
  key-value. Tambem quando mencionar "create kv", "novo kv namespace",
  "setup kv", "init kv", "criar kv", "kv namespace", "wrangler kv create".
  Foco em provisionamento do recurso + binding + uso basico — NAO em
  estrategias de cache ou invalidacao avancada. Para adicionar binding
  ao Worker veja cf-workers-add-binding. Para consumo (get/put/list patterns)
  veja data-related/kv.
allowed-tools:
  - Read
  - Bash
  - Glob
  - Grep
---

# Cloudflare Workers: Criar KV Namespace

Cria um namespace KV via `wrangler kv namespace create`, configura o binding
no `wrangler.toml`, e habilita uso local via preview namespace.

## Pre-Flight Reads

1. **`wrangler.toml`** atual — verificar secao `[[kv_namespaces]]` existente
2. **`wrangler.toml`** — localizar `name` do Worker e `compatibility_date`
3. **`wrangler kv namespace list`** — confirmar que namespace ainda nao existe
4. **`src/index.ts`** — verificar interface `Env` se ja tem KV binding

## Workflow: Criar KV Namespace

### Passo 1 — Criar namespace

```bash
# Criar namespace production
wrangler kv namespace create "CACHE"

# Output esperado:
# { id: "abc123def456", title: "CACHE" }
```

Copie o `id` outputado.

### Passo 2 — Criar preview namespace para dev local

```bash
# Namespace separado para wrangler dev (nao aponta pra prod)
wrangler kv namespace create "CACHE_PREVIEW" --env preview

# OU: wrangler dev usa o mesmo namespace com --local
# (dados persistem em .wrangler/state/v3/kv/)
```

### Passo 3 — Adicionar binding ao wrangler.toml

```toml
name = "my-worker"
main = "src/index.ts"
compatibility_date = "2024-01-01"

[[kv_namespaces]]
  binding = "CACHE"
  id = "abc123def456"           # production namespace id
  preview_id = "xyz789preview"  # preview namespace id (wrangler dev)
```

### Passo 4 — Gerar tipos e usar no codigo

```bash
wrangler types
```

```typescript
// worker-configuration.d.ts
interface Env {
  CACHE: KVNamespace;
}
```

```typescript
// src/index.ts
export interface Env {
  CACHE: KVNamespace;
}

export default {
  async fetch(request: Request, env: Env): Promise<Response> {
    const url = new URL(request.url);
    const cacheKey = `response:${url.pathname}`;

    // Tentar cache hit
    const cached = await env.CACHE.get(cacheKey);
    if (cached) {
      return new Response(cached, {
        headers: {
          "Content-Type": "application/json",
          "X-Cache": "HIT",
        },
      });
    }

    // Fetch original
    const response = await fetch(request);
    const body = await response.text();

    // Store in cache with TTL
    await env.CACHE.put(cacheKey, body, {
      expirationTtl: 3600,  // 1 hour
    });

    return new Response(body, {
      headers: {
        "Content-Type": response.headers.get("Content-Type") || "application/json",
        "X-Cache": "MISS",
      },
    });
  },
};
```

## Operacoes Basicas via CLI

```bash
# Put (gravar valor)
wrangler kv kv-key put "my-key" "my-value" --binding=CACHE

# Put com TTL (expiracao em segundos)
wrangler kv kv-key put "my-key" "my-value" --binding=CACHE --ttl=3600

# Get (ler valor)
wrangler kv kv-key get "my-key" --binding=CACHE

# Delete (remover)
wrangler kv kv-key delete "my-key" --binding=CACHE

# List (listar chaves com cursor)
wrangler kv kv-key list --binding=CACHE --prefix="response:"
```

## Exemplo BOM

```toml
# wrangler.toml — KV binding com preview separado
[[kv_namespaces]]
  binding = "CACHE"
  id = "abc123def456"
  preview_id = "xyz789preview"   # namespace de preview, isolado de prod
```

```typescript
// src/lib/cache.ts — helper tipado
export async function getCache<T>(
  kv: KVNamespace,
  key: string,
): Promise<T | null> {
  const value = await kv.get(key);
  if (!value) return null;
  try {
    return JSON.parse(value) as T;
  } catch {
    return null;
  }
}

export async function setCache(
  kv: KVNamespace,
  key: string,
  value: unknown,
  ttlSeconds: number,
): Promise<void> {
  const serialized = JSON.stringify(value);
  await kv.put(key, serialized, { expirationTtl: ttlSeconds });
}
```

## Exemplo RUIM

```toml
# WRONG: esquecendo preview_id (wrangler dev aponta pra prod)
[[kv_namespaces]]
  binding = "CACHE"
  id = "prod-uuid"   # MISSING preview_id — wrangler dev usa este id!
```

```typescript
// WRONG: sem tratamento de expiracao (valor cresce indefinidamente)
await env.CACHE.put("session:" + token, userData);
// BETER: always use expirationTtl or expiration

// WRONG: storing large objects (>25MB limit)
await env.CACHE.put("huge-data", hugeObject); // Exceeds 25MB limit
```

## Gotchas

### 1. eventual consistency — propagacao ate 60s

KV eh eventual consistent: writes podem levar **ate 60 segundos** para
propagar para todas as edge locations. Reads imediatamente apos writes
podem retornar valor antigo ou `null`. Para cache de leitura pesada
(funciona bem) mas NAO para dados que precisam de strong consistency.

### 2. Max value size: 25MB

Valores maiores que 25MB retornam erro `KV_VALUE_TOO_LARGE`. Para objetos
maiores, usar R2 (ate 5TB).

### 3. Max key size: 512 bytes

Keys muito longas (ex: hash de paths extensos) podem ultrapassar 512B.
Truncar keys ou usar hash SHA-256 se necessario.

### 4. list() com pagination

```typescript
// list() retorna ate 1000 keys por vez; usar cursor para paginar
async function listAllKeys(kv: KVNamespace, prefix: string): Promise<string[]> {
  const keys: string[] = [];
  let cursor: string | undefined;

  do {
    const list = await kv.list({ prefix, limit: 1000, cursor });
    keys.push(...list.keys.map((k) => k.name));
    cursor = list.list_complete ? undefined : list.cursor;
  } while (cursor);

  return keys;
}
```

### 5. TTL vs expirationTtl

```typescript
// expirationTtl: segundos ate expirar (relativo ao momento atual)
kv.put("key", "value", { expirationTtl: 3600 });

// expiration: timestamp Unix absoluto (para data fija)
kv.put("key", "value", { expiration: Math.floor(Date.now() / 1000) + 86400 });
```

### 6. Cache ideal para leitura pesada

KV brilha em workloads read-heavy (90%+ reads, writes不是很频繁). Para
write-heavy ou dados que mudam muito, considere D1 ou just-in-time recomputation.

### 7. Wrangler dev usa namespace local automatico

Se voce rodar `wrangler dev --binding=CACHE`, wrangler automaticamente
cria um namespace temporario local (persisted em `.wrangler/state/v3/kv/`).
Nao precisa de `preview_id` explicito se usar `--local` flag.

## Quando NAO Usar

- **Dados que requerem strong consistency** — KV eventual consistency pode
  retornar dados antigos ate 60s apos write
- **Valores maiores que 25MB** — usar R2
- **Dados relacionais ou queries complexas** — usar D1
- **Session storage com dados criticos** — KV pode perder dados em evictions;
  para sessions criticos, usar Durable Objects ou D1
- **Write-heavy workloads** — KV nao eh otimizado para muitas escritas
- **Adicionar binding sem criar namespace** — use `cf-workers-add-binding`
