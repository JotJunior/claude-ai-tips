---
name: ts-add-webhook
description: |
  Create webhook endpoint with HMAC signature validation and idempotency
  Use quando o usuário pedir: "criar webhook ts", "endpoint webhook typescript", "handler webhook", "webhook handler".
allowed-tools:
  - Read
  - Glob
  - Grep
  - Bash
---

# ts-add-webhook

Create a webhook endpoint for Cloudflare Workers with HMAC SHA256 signature validation, idempotency checks, and async processing queue.

## Trigger Phrases

"add webhook", "novo webhook", "criar webhook", "webhook handler", "stripe webhook", "github webhook"

## Arguments

$ARGUMENTS should specify:
- **Webhook provider** — Stripe, GitHub, custom, etc.
- **Route path** — URL path for the webhook (e.g., `/webhooks/stripe`)
- **Events to handle** — which events to support
- **Secret binding** — env variable name for webhook secret

## Pre-Flight Checks

Before writing webhook code, read:

1. **Existing routes** — `src/index.ts` or `src/routes.ts` to avoid conflicts
2. **Env types** — `src/env.ts` for webhook secret and queue bindings
3. **Schema** — `src/db/schema.ts` for idempotency table
4. **Provider docs** — the webhook signature algorithm (usually HMAC SHA256)
5. **wrangler.toml** — queue and D1 bindings

## Workflow

### Step 1: Create Webhook Route

```typescript
// src/routes/webhooks.ts
import { Hono } from 'hono';
import { env } from 'hono/adapter/cloudflare';
import type { Env } from '../env';

const webhook = new Hono();

// IMPORTANT: Raw body needed for signature validation — do NOT use c.json() here
webhook.post('/webhooks/:provider', async (c) => {
  const { provider } = c.req.param();
  
  // Step 1: Read RAW BODY before any parsing
  const rawBody = await c.req.text();
  
  // Step 2: Get signature from headers
  const signature = c.req.header(`x-${provider}-signature`) 
    || c.req.header('x-hub-signature-256')
    || c.req.header('stripe-signature');
  
  const envVars = env<Env>(c);
  
  // Step 3: Validate signature
  if (!signature) {
    return c.json({ error: 'Missing signature' }, 400);
  }
  
  const isValid = await validateSignature(
    rawBody,
    signature,
    envVars.WEBHOOK_SECRET
  );
  
  if (!isValid) {
    return c.json({ error: 'Invalid signature' }, 401);
  }
  
  // Step 4: Parse JSON AFTER validation
  let payload: Record<string, unknown>;
  try {
    payload = JSON.parse(rawBody);
  } catch {
    return c.json({ error: 'Invalid JSON' }, 400);
  }
  
  // Step 5: Idempotency check
  const eventId = extractEventId(provider, payload);
  if (eventId) {
    const alreadyProcessed = await checkIdempotency(envVars.DB, eventId);
    if (alreadyProcessed) {
      return c.json({ received: true, status: 'duplicate' }, 200);
    }
  }
  
  // Step 6: Queue for async processing
  await envVars.WEBHOOK_QUEUE.send({
    provider,
    eventId,
    payload,
    receivedAt: Date.now(),
  });
  
  // Step 7: Respond quickly (< 5s requirement)
  return c.json({ received: true }, 200);
});

export default webhook;
```

### Step 2: Implement Signature Validation

```typescript
// src/lib/webhook-validator.ts

/**
 * Validate HMAC SHA256 signature using timing-safe comparison
 * @param payload Raw request body (string)
 * @param signature Signature from header
 * @param secret WEBHOOK_SECRET env variable
 */
export async function validateSignature(
  payload: string,
  signature: string,
  secret: string
): Promise<boolean> {
  // Remove algorithm prefix if present (e.g., "sha256=")
  const sig = signature.replace(/^sha256=/, '');
  
  const encoder = new TextEncoder();
  const keyData = encoder.encode(secret);
  const messageData = encoder.encode(payload);
  
  const cryptoKey = await crypto.subtle.importKey(
    'raw',
    keyData,
    { name: 'HMAC', hash: 'SHA-256' },
    false,
    ['verify']
  );
  
  const signatureBuffer = Uint8Array.from(
    atob(sig),
    (c) => c.charCodeAt(0)
  );
  
  const messageBuffer = messageData.buffer.slice(
    messageData.byteOffset,
    messageData.byteOffset + messageData.byteLength
  );
  
  return crypto.subtle.verify(
    'HMAC',
    cryptoKey,
    signatureBuffer,
    messageBuffer
  );
}
```

### Step 3: Idempotency Check

```typescript
// src/lib/idempotency.ts

export async function checkIdempotency(
  db: D1Database,
  eventId: string,
  ttlSeconds = 86400 * 7
): Promise<boolean> {
  const result = await db
    .prepare('SELECT id FROM webhook_events WHERE id = ? AND created_at > ?')
    .bind(eventId, Date.now() - ttlSeconds * 1000)
    .first();
  
  return result !== null;
}

export async function markEventProcessed(
  db: D1Database,
  eventId: string,
  provider: string
): Promise<void> {
  await db
    .prepare(
      'INSERT INTO webhook_events (id, provider, created_at) VALUES (?, ?, ?)'
    )
    .bind(eventId, provider, Date.now())
    .run();
}
```

### Step 4: Register Route

```typescript
// src/index.ts
import { Hono } from 'hono';
import webhookRoutes from './routes/webhooks';

const app = new Hono();

app.route('/', webhookRoutes);

export default {
  async fetch(request: Request, env: Env, ctx: ExecutionContext) {
    return app.fetch(request, env, ctx);
  },
};
```

## Schema for Idempotency Table

```sql
-- Migration: Create webhook_events table for idempotency
CREATE TABLE IF NOT EXISTS webhook_events (
  id TEXT PRIMARY KEY,
  provider TEXT NOT NULL,
  payload TEXT,
  created_at INTEGER NOT NULL,
  processed_at INTEGER
);

CREATE INDEX IF NOT EXISTS idx_webhook_events_created_at 
  ON webhook_events(created_at);
```

## Example: Good Webhook (Signature + Idempotency)

```typescript
// BOM: Webhook com signature validation e idempotency
webhook.post('/webhooks/stripe', async (c) => {
  const rawBody = await c.req.text();
  const signature = c.req.header('stripe-signature');
  const envVars = env<Env>(c);
  
  // Timing-safe validation
  if (!await validateSignature(rawBody, signature, envVars.WEBHOOK_SECRET)) {
    return c.json({ error: 'Invalid signature' }, 401);
  }
  
  const payload = JSON.parse(rawBody);
  const eventId = payload.id; // Stripe event ID
  
  // Idempotency check
  const exists = await checkIdempotency(envVars.DB, eventId);
  if (exists) {
    return c.json({ status: 'already_processed' }, 200);
  }
  
  // Queue async processing
  await envVars.WEBHOOK_QUEUE.send({
    type: payload.type,
    eventId,
    data: payload.data,
  });
  
  await markEventProcessed(envVars.DB, eventId, 'stripe');
  
  return c.json({ received: true }, 200);
  // RESPONDIDO EM < 5s — processing happens async
});
```

## Example: Bad Webhook (Trusting Payload)

```typescript
// RUIM: Webhook sem signature validation — confia no payload
webhook.post('/webhooks/stripe', async (c) => {
  // ERRO: Sem validação de signature, qualquer um pode enviar payloads falsos
  const payload = await c.req.json();
  
  // ERRO: Sem idempotency, o mesmo evento processado 2x se retry acontecer
  if (payload.type === 'payment.succeeded') {
    await fulfillOrder(payload.data);
    // PROBLEMAS:
    // 1. Qualquer um pode forjar payloads
    // 2. Duplicate orders se webhook reenviar
    // 3. Sem async queue, timeout se processing for lento
    // 4. Sem raw body, signature validation é impossível
  }
  
  return c.json({ ok: true }, 200);
});
```

## Gotchas

1. **Timing-safe comparison**: NEVER use `===` to compare signatures. Use `crypto.subtle.verify()` which is timing-safe. String comparison is vulnerable to timing attacks.

2. **Webhook must respond < 5s**: Queue heavy processing. Respond 200 immediately after validation and queueing. Stripe/GitHub will retry if no response.

3. **Idempotency via event_id**: Use provider's event ID as idempotency key. Store in D1 with TTL to prevent infinite storage growth.

4. **Raw body before parse**: Read `c.req.text()` BEFORE `c.req.json()`. Once JSON is parsed, raw bytes are consumed and signature validation fails.

5. **Replay protection**: Validate timestamp if provider includes `timestamp` in signature. Reject events older than 5 minutes to prevent replay attacks.

6. **Provider-specific quirks**: 
   - Stripe: `stripe-signature` header, `t=` timestamp prefix
   - GitHub: `x-hub-signature-256` header, `sha256=` prefix
   - Slack: `X-Slack-Signature`, timing window check

7. **Error handling**: Return 200 for processed duplicates, 400 for malformed, 401 for invalid signature. NEVER return 500 to webhook providers (they will retry indefinitely).

## Verification

Test webhook locally:

```bash
# Gerar signature de teste
BODY='{"test":"event"}'
SECRET='whsec_test'
SIGNATURE=$(echo -n "$BODY" | openssl dgst -sha256 -hmac "$SECRET" | cut -d' ' -f2)

curl -X POST http://localhost:8787/webhooks/test \
  -H "Content-Type: application/json" \
  -H "x-webhook-signature: sha256=$SIGNATURE" \
  -d "$BODY"
```

Verify:
- Invalid signature returns 401
- Duplicate event returns 200 with `status: duplicate`
- Valid new event returns 200 immediately

## When NOT to Use

- **Real-time user response needed**: Webhooks are async. If user must see result immediately, use direct API call instead.
- **High-frequency events**: Webhooks are designed for sparse events. For high-frequency data, use bulk APIs or streaming.
- **Complex multi-step transactions**: Break into smaller webhooks or use async queue pattern with status polling.
