---
name: ts-add-queue-consumer
description: Add Cloudflare Queue consumer with retry, DLQ, and batch processing
allowed-tools:
  - Read
  - Glob
  - Grep
  - Bash
---

# ts-add-queue-consumer

Add a Cloudflare Queue consumer to a Workers project with retry policy, dead letter queue, and batch processing support.

## Trigger Phrases

"add queue", "queue consumer", "novo consumer", "cloudflare queue", "background job"

## Arguments

$ARGUMENTS should specify:
- **Queue name** — which queue to consume (e.g., `notifications-queue`)
- **Consumer handler** — function name for processing messages
- **Retry policy** — max retries, backoff, dead letter queue name
- **Batch settings** — max_batch_size, max_batch_timeout

## Pre-Flight Checks

Before writing consumer code, read:

1. **wrangler.toml** — existing queue bindings and consumer configurations
2. **Producer code** — `src/queue.ts` or wherever messages are enqueued
3. **Schema** — `src/db/schema.ts` for any entities referenced
4. **Env types** — `src/index.ts` for environment binding types
5. **Existing consumers** — any `src/queue/**/*.ts` for patterns

## Workflow

### Step 1: Configure wrangler.toml

Add the consumer binding if not already present:

```toml
# wrangler.toml
[[queues.consumers]]
queue = "notifications-queue"
max_batch_size = 10
max_batch_timeout = 30
max_retries = 3
dead_letter_queue = "notifications-dlq"
```

### Step 2: Define Queue Binding Type

```typescript
// src/env.ts
export interface Env {
  NOTIFICATIONS_QUEUE: Queue.Queue;
  NOTIFICATIONS_DLQ: Queue.Queue;
  DB: D1Database;
}
```

### Step 3: Create Consumer Handler

```typescript
// src/queue/notifications.ts
import type { Queue, Message } from '@cloudflare/workers-types';

interface NotificationMessage {
  id: string;
  userId: string;
  type: 'email' | 'sms';
  payload: Record<string, unknown>;
  timestamp: number;
}

export async function processNotifications(
  batch: Message<NotificationMessage>[],
  env: Env,
  ctx: ExecutionContext
): Promise<void> {
  const results = await Promise.allSettled(
    batch.map(async (message) => {
      try {
        await processNotification(message.body, env);
        await message.ack();
      } catch (error) {
        // Retry policy: requeue with exponential backoff
        if (message.attempts < (env.NOTIFICATIONS_QUEUE.maxRetries ?? 3)) {
          await message.retry();
        } else {
          // Send to DLQ after max retries
          await message.ack();
          await env.NOTIFICATIONS_DLQ.send(message.body);
        }
      }
    })
  );
  
  // Log failures for monitoring
  const failures = results.filter(r => r.status === 'rejected');
  if (failures.length > 0) {
    console.error(`Failed to process ${failures.length}/${batch.length} messages`);
  }
}

async function processNotification(
  msg: NotificationMessage,
  env: Env
): Promise<void> {
  // Business logic here
  // Must be idempotent!
  const existing = await env.DB
    .prepare('SELECT id FROM processed_notifications WHERE id = ?')
    .bind(msg.id)
    .first();
  
  if (existing) {
    // Already processed — skip (idempotency)
    return;
  }
  
  // Process notification...
  await env.DB
    .prepare('INSERT INTO processed_notifications (id, user_id, type, created_at) VALUES (?, ?, ?, ?)')
    .bind(msg.id, msg.userId, msg.type, Date.now())
    .run();
}
```

### Step 4: Register Consumer in Worker

```typescript
// src/index.ts
import { Hono } from 'hono';
import { processNotifications } from './queue/notifications';

const app = new Hono();

app.onError((err, c) => {
  console.error('Worker error:', err);
  return c.json({ error: 'Internal server error' }, 500);
});

export default {
  async fetch(request: Request, env: Env, ctx: ExecutionContext) {
    return app.fetch(request, env, ctx);
  },
  // Queue consumer — nome deve corresponder ao binding em wrangler.toml
  async queue(batch: Message[], env: Env, ctx: ExecutionContext) {
    await processNotifications(batch, env, ctx);
  },
};
```

## Idempotency Pattern

Always make consumer idempotent to handle duplicates:

```typescript
async function processNotification(
  msg: NotificationMessage,
  env: Env
): Promise<void> {
  // Check if already processed using message.id as idempotency key
  const key = `processed:${msg.id}`;
  
  const alreadyProcessed = await env.KV.get(key);
  if (alreadyProcessed === 'true') {
    return; // Skip duplicate
  }
  
  // Do the work...
  
  // Mark as processed with TTL (e.g., 7 days)
  await env.KV.put(key, 'true', { expirationTtl: 604800 });
}
```

## Batch Processing Pattern

```typescript
export async function processNotifications(
  batch: Message<NotificationMessage>[],
  env: Env,
  ctx: ExecutionContext
): Promise<void> {
  // Batch insert for efficiency
  const statements = batch.map(msg => ({
    sql: 'INSERT INTO notifications (id, user_id, type, payload) VALUES (?, ?, ?, ?)',
    args: [msg.body.id, msg.body.userId, msg.body.type, JSON.stringify(msg.body.payload)],
  }));
  
  try {
    await env.DB.batch(statements.map(s => 
      env.DB.prepare(s.sql).bind(...s.args)
    ));
    
    // Ack all messages on success
    batch.forEach(msg => msg.ack());
  } catch (error) {
    // Retry all on batch failure
    batch.forEach(msg => msg.retry());
  }
}
```

## Example: Good Consumer (Idempotent with DLQ)

```typescript
// BOM: Consumer idempotente com DLQ e dedup
export async function processNotifications(
  batch: Message<NotificationMessage>[],
  env: Env,
  ctx: ExecutionContext
): Promise<void> {
  for (const message of batch) {
    try {
      // Idempotency check via KV
      const dedupKey = `notif:${message.body.id}`;
      const exists = await env.KV.get(dedupKey);
      if (exists) {
        message.ack(); // Skip already processed
        continue;
      }
      
      await processNotification(message.body, env);
      await env.KV.put(dedupKey, '1', { expirationTtl: 86400 * 7 });
      message.ack();
    } catch (error) {
      if (message.attempts < 3) {
        message.retry({ delaySeconds: Math.pow(2, message.attempts) });
      } else {
        message.ack();
        await env.NOTIFICATIONS_DLQ.send(message.body);
      }
    }
  }
}
```

## Example: Bad Consumer (No Idempotency)

```typescript
// RUIM: Consumer sem idempotência — duplica processamento
export async function processNotifications(
  batch: Message<NotificationMessage>[],
  env: Env,
  ctx: ExecutionContext
): Promise<void> {
  for (const message of batch) {
    // ERRO: Sem check de dedup, toda mensagem é processada novamente
    await sendEmail(message.body);
    message.ack();
    // PROBLEMAS:
    // 1. Se msg.ack() falhar após envio, mensagem será reenviada
    // 2. Duplicate emails/sms para o usuário
    // 3. Retry vai duplicar notificações
    // 4. Sem DLQ, mensagens com erro permanente são perdidas
  }
}
```

## Gotchas

1. **max_batch_size default**: Default is 10 messages. Increase for throughput-critical consumers, decrease for slow operations.

2. **max_retries default**: Default is 3 retries. Set `dead_letter_queue` for messages that exceed retries.

3. **Dead letter queue is mandatory in production**: Without DLQ, messages that fail all retries are lost forever. Always configure.

4. **Explicit ack/retry**: Messages are NOT automatically acknowledged. You MUST call `message.ack()` or `message.retry()`.

5. **Exactly-once not guaranteed**: Cloudflare Queues provides at-least-once delivery. Use idempotency keys (message.id + stored check) to deduplicate.

6. **Batch vs serial**: For I/O-bound work, process in parallel with `Promise.allSettled`. For CPU-bound, process serially.

7. **Context.waitUntil**: If doing async work after queue handler returns, use `ctx.waitUntil(promise)` to prevent premature termination.

## Verification

Test locally with Miniflare:

```bash
npx wrangler dev --local
# Em outro terminal, enviar mensagens de teste:
npx wrangler queue send <queue-name> '{"id":"test-1","userId":"u1","type":"email"}'
```

Verify in dashboard:
- Messages in flight
- DLQ depth
- Retry counts
- Processing time per message

## When NOT to Use

- **Synchronous response required**: Queues are async. If user needs immediate response, process inline and return.
- **Sub-second latency**: Queues have inherent latency (seconds). Use direct invocation for real-time needs.
- **More than 100 messages/second**: Consider higher-tier Cloudflare plan or sharding across multiple queues.
