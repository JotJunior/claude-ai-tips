---
name: cf-workers-create-r2-bucket
description: |
  Use quando precisar criar um novo bucket R2 para object storage (assets,
  uploads, backups, media). Tambem quando mencionar "create r2", "novo r2 bucket",
  "setup r2", "init r2", "criar bucket r2", "wrangler r2 bucket create",
  "r2 storage", "object storage cloudflare". Foco em provisionamento do bucket
  + binding + configuracao de CORS — NAO em upload/download de arquivos
  especificos ou patterns de migracao S3. Para adicionar binding ao Worker
  veja cf-workers-add-binding. Para consuming R2 in code veja data-related/r2.
allowed-tools:
  - Read
  - Bash
  - Glob
  - Grep
---

# Cloudflare Workers: Criar R2 Bucket

Cria um bucket R2 para object storage, configura o binding no `wrangler.toml`,
e define regras CORS para acesso via browser.

## Pre-Flight Reads

1. **`wrangler.toml`** atual — verificar secao `[[r2_buckets]]` existente
2. **`wrangler.toml`** — localizar `name` do Worker e `compatibility_date`
3. **`wrangler r2 bucket list`** — confirmar que bucket ainda nao existe
4. **`src/index.ts`** — verificar interface `Env` se ja tem R2 binding

## Workflow: Criar R2 Bucket

### Passo 1 — Criar o bucket

```bash
# Criar bucket
wrangler r2 bucket create assets-bucket

# Output esperado:
# Created bucket 'assets-bucket'
```

### Passo 2 — Adicionar binding ao wrangler.toml

```toml
name = "my-worker"
main = "src/index.ts"
compatibility_date = "2024-01-01"

[[r2_buckets]]
  binding = "ASSETS"
  bucket_name = "assets-bucket"
```

### Passo 3 — Gerar tipos TypeScript

```bash
wrangler types
```

```typescript
// worker-configuration.d.ts
interface Env {
  ASSETS: R2Bucket;
}
```

### Passo 4 — Configurar CORS (se acesso via browser)

```bash
# Criar arquivo de regras CORS
cat > cors.json <<'CORSEOF'
[
  {
    "AllowedOrigins": [
      "https://example.com",
      "https://*.example.com"
    ],
    "AllowedMethods": [
      "GET",
      "HEAD",
      "PUT",
      "POST"
    ],
    "AllowedHeaders": [
      "Content-Type",
      "Authorization",
      "X-Requested-With"
    ],
    "ExposeHeaders": [
      "ETag",
      "X-Request-Id"
    ],
    "MaxAgeSeconds": 86400
  }
]
CORSEOF

# Aplicar CORS ao bucket
wrangler r2 bucket cors put assets-bucket --rules cors.json
```

### Passo 5 — Testar operacoes basicas

```bash
# Upload via CLI (pequeno arquivo)
echo "test content" > test.txt
wrangler r2 object put assets-bucket/test.txt --file test.txt --binding=ASSETS

# Download
wrangler r2 object get assets-bucket/test.txt --binding=ASSETS

# List
wrangler r2 object list assets-bucket --binding=ASSETS
```

## Exemplo de Uso no Worker

```typescript
// src/index.ts
export interface Env {
  ASSETS: R2Bucket;
}

export default {
  async fetch(request: Request, env: Env): Promise<Response> {
    const url = new URL(request.url);

    if (request.method === "POST" && url.pathname === "/upload") {
      return handleUpload(request, env.ASSETS);
    }

    if (request.method === "GET" && url.pathname.startsWith("/assets/")) {
      return handleDownload(request, env.ASSETS);
    }

    return new Response("Not Found", { status: 404 });
  },
};

async function handleUpload(request: Request, bucket: R2Bucket): Promise<Response> {
  const formData = await request.formData();
  const file = formData.get("file") as File;

  if (!file) {
    return new Response("No file provided", { status: 400 });
  }

  const key = `uploads/${crypto.randomUUID()}-${file.name}`;
  await bucket.put(key, file.stream(), {
    httpMetadata: {
      contentType: file.type,
    },
    customMetadata: {
      uploadedBy: request.headers.get("X-User-Id") || "anonymous",
    },
  });

  return Response.json({ key, url: `/assets/${key}` });
}

async function handleDownload(request: Request, bucket: R2Bucket): Promise<Response> {
  const url = new URL(request.url);
  const key = url.pathname.replace("/assets/", "");

  const object = await bucket.get(key);

  if (!object) {
    return new Response("Not Found", { status: 404 });
  }

  return new Response(object.body, {
    headers: {
      "Content-Type": object.httpMetadata?.contentType || "application/octet-stream",
      "ETag": object.httpEtag,
    },
  });
}
```

## Exemplo BOM

```toml
# wrangler.toml
[[r2_buckets]]
  binding = "ASSETS"
  bucket_name = "assets-bucket"
```

```json
// cors.json — permitir GET/HEAD de qualquer origem (assets publicos)
[
  {
    "AllowedOrigins": ["*"],
    "AllowedMethods": ["GET", "HEAD"],
    "AllowedHeaders": ["Content-Type"],
    "MaxAgeSeconds": 3600
  }
]
```

```json
// cors.json — upload com auth (origens especificas)
[
  {
    "AllowedOrigins": ["https://app.example.com"],
    "AllowedMethods": ["GET", "HEAD", "PUT", "POST", "DELETE"],
    "AllowedHeaders": ["Content-Type", "Authorization", "X-Upload-Token"],
    "ExposeHeaders": ["ETag"],
    "MaxAgeSeconds": 86400
  }
]
```

## Exemplo RUIM

```toml
# WRONG: bucket_name errado (nao existe)
[[r2_buckets]]
  binding = "ASSETS"
  bucket_name = "wrong-name"   # Bucket nao existe!
```

```json
// WRONG: CORS permitindo todas as origens em PUT/POST (security risk)
[
  {
    "AllowedOrigins": ["*"],
    "AllowedMethods": ["PUT", "POST"],  // NEVER allow * with write methods
    "AllowedHeaders": ["*"]
  }
]
```

```typescript
// WRONG: fazer download sem verificar se objeto existe
const object = await env.ASSETS.get(key);
return new Response(object.body);  // throws if object is null
```

## Gotchas

### 1. R2 nao tem egress fee (diferenca de S3)

R2 cobra apenas pelo storage e operacoes (GET/PUT/DELETE). **Nao cobra egress**
para downloads. Isso muda o modelo de custo comparado a S3 — para aplicacoes
com muito download, R2 eh muito mais barato.

### 2. Public bucket via r2.dev ou custom domain

R2 buckets nao sao publicos por default. Para expor via URL:

```bash
# Via r2.dev subdomain (automatico)
# BUCKET/assets-bucket.r2.dev/key

# Via custom domain (Workers没啥额外费用)
# config via dashboard: R2 > Bucket > Settings > Custom Domain
```

### 3. Multipart upload para arquivos > 5MB

```typescript
// Upload de arquivo grande (> 5MB) via multipart
const multipart = await bucket.createMultipartUpload(key);

try {
  const part1 = await fetch(part1Url);
  const { partNumber } = await multipart.uploadPart(1, part1.body);

  await multipart.complete({
    parts: [{ partNumber, etag: "etag-from-upload" }],
  });
} catch {
  await multipart.abort();
}
```

### 4. Lifecycle rules via dashboard

Wrangler NAO suporta lifecycle rules (auto-expiracao de objetos).
Configurar via Dashboard: R2 > Bucket > Settings > Lifecycle Rules.

### 5. Schema do cors.json

| Campo | Tipo | Descricao |
|-------|------|-----------|
| `AllowedOrigins` | string[] | Origens permitidas; `*` para qualquer (GET/HEAD only) |
| `AllowedMethods` | string[] | GET, HEAD, PUT, POST, DELETE |
| `AllowedHeaders` | string[] | Headers aceitos; `*` para qualquer |
| `ExposeHeaders` | string[] | Headers expostos ao cliente |
| `MaxAgeSeconds` | number | Cache de preflight em segundos |

### 6. R2 nao suporta Range requests natively

Se precisar de resumable downloads ou streaming de video, implementar via
Worker com Range header handling sobre `object.body` (limitado).

### 7. Max object size: 5TB

Objetos individuais podem ter até 5TB. Para arquivos maiores,
usar multipart upload.

## Quando NAO Usar

- **Database-like queries** — R2 é object storage, nao queryable. Usar D1 ou Postgres
- **Dados que precisam de indexacao** — R2 nao tem built-in search. Para
  busca de objetos, implementar Worker-side ou usar Vectorize
- **Website hosting estatico** — usar Cloudflare Pages (tem CDN built-in e
  redirect rules). R2 + Worker requiere mais configuracao manual
- **High-frequency small writes** — cada PUT conta como operacao; otimizar
  batching para workloads intenso
- **Adicionar binding sem criar bucket** — use `cf-workers-add-binding`
