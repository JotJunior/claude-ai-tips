---
name: cf-workers-add-webhook
description: Create secure webhook endpoint with signature validation and idempotency. Use quando: "add cf webhook", "webhook cloudflare", "secure webhook", "stripe webhook worker", "webhook signature validation", "hmac verification". Tambem quando: receber webhooks dePayment providers (Stripe, Pagar.me), notificacoes de APIs externas, eventos de webhooks. NAO use quando: endpoint interno sem validacao (use generic route), webhook GraphQL, webhook sem idempotencia.
allowed-tools:
  - Read
  - Bash
  - Glob
  - Grep
---

# Cloudflare Workers — Add Webhook

Cria endpoint webhook seguro com validacao de assinatura HMAC-SHA256,
idempotencia via KV/D1, e processing async via Queue. Seguireste workflow
para evitar vulnerabilidades comuns (replay attacks, signature bypass,
double-processing).

## Trigger Phrases

- "add cf webhook"
- "webhook cloudflare"
- "secure webhook"
- "stripe webhook worker"
- "webhook signature validation"
- "hmac verification"
- "webhook idempotency"

## Pre-Flight Checks

Antes de iniciar, leia:

1. **wrangler.toml** — identificar KV binding e Queue producer
   ```bash
   grep -E "kv_|queues" wrangler.toml | head -20
   ```
2. **Secrets ja configurados** — verificar se secret do webhook existe
   ```bash
   wrangler secret list 2>/dev/null | grep -E "WEBHOOK|SECRET|STRIPE" || echo "Nenhum secret encontrado"
   ```
3. **Routes no wrangler.toml** — identificar domínio configurado
   ```bash
   grep -E "routes|custom_domain|route" wrangler.toml | head -10
   ```

## Workflow

### Passo 1 — Criar route POST no worker

No arquivo principal (ex: `src/index.ts` ou `src/webhook.ts`):

```typescript
import Hono from 'hono';
import { crypto } from 'cloudflare:sockets';

const app = new Hono();

// Middleware: raw body para signature validation
app.post('/webhook', async (c) => {
    // 1. Ler raw body ANTES de qualquer parsing
    const rawBody = await c.req.text();
    const signature = c.req.header('stripe-signature') || c.req.header('x-hub-signature-256');
    
    // 2. Validar assinatura HMAC
    const secret = c.env.WEBHOOK_SECRET;
    const isValid = await verifySignature(rawBody, signature, secret);
    
    if (!isValid) {
        return c.text('Unauthorized', 401);
    }
    
    // 3. Parsear evento
    const event = JSON.parse(rawBody);
    
    // 4. Idempotency check via event ID
    const idempotencyKey = `webhook:${event.id}`;
    const alreadyProcessed = await c.env.WEBHOOK_KV.get(idempotencyKey);
    
    if (alreadyProcessed) {
        return c.text('OK', 200); // ja processado, retornar 200 rapido
    }
    
    // 5. Enfileirar para processing async
    await c.env.WEBHOOK_QUEUE.send(JSON.stringify({
        eventId: event.id,
        eventType: event.type,
        payload: event.data.object,
        receivedAt: Date.now()
    }));
    
    // 6. Marcar como processando (TTL para evitar duplicacao em caso de retry)
    await c.env.WEBHOOK_KV.put(idempotencyKey, "processing", { expirationTtl: 300 });
    
    // 7. Retornar 200 rapido (< 5s)
    return c.text('OK', 200);
});
```

### Passo 2 — Função de validacao HMAC (timing-safe)

```typescript
async function verifySignature(
    payload: string,
    signature: string,
    secret: string
): Promise<boolean> {
    const encoder = new TextEncoder();
    const keyData = encoder.encode(secret);
    const payloadData = encoder.encode(payload);
    
    // Importar chave HMAC
    const cryptoKey = await crypto.subtle.importKey(
        'raw',
        keyData,
        { name: 'HMAC', hash: 'SHA-256' },
        false,
        ['verify']
    );
    
    // Decodificar assinatura hex
    const signatureBytes = hexToBytes(signature.replace('sha256=', ''));
    
    // Verificacao timing-safe
    const result = await crypto.subtle.verify(
        'HMAC',
        cryptoKey,
        signatureBytes,
        payloadData
    );
    
    return result;
}

function hexToBytes(hex: string): Uint8Array {
    const bytes = new Uint8Array(hex.length / 2);
    for (let i = 0; i < hex.length; i += 2) {
        bytes[i / 2] = parseInt(hex.substr(i, 2), 16);
    }
    return bytes;
}
```

### Passo 3 — Configurar secrets

```bash
# Criar secret via wrangler
wrangler secret put WEBHOOK_SECRET
# Digitar o secret (nao echo via pipe — evita ficar em history)

# Para Stripe:
wrangler secret put STRIPE_WEBHOOK_SECRET
```

### Passo 4 — Configurar wrangler.toml

```toml
name = "webhook-receiver"
main = "src/index.ts"
compatibility_date = "2024-03-01"

[observability]
enabled = true

# KV namespace para idempotency
[[kv_namespaces]]
binding = "WEBHOOK_KV"
id = "abc123..."

# Queue producer para processing async
[[queues.producers]]
queue = "webhook-events"
binding = "WEBHOOK_QUEUE"

# Variavel publica (nao secreta)
[vars]
ENVIRONMENT = "production"
```

### Passo 5 — Consumer (processar eventos enfileirados)

```typescript
// Em outro worker ou consumer separado
export default {
    async queue(batch, env, ctx) {
        for (const message of batch.messages) {
            const event = JSON.parse(message.body);
            
            try {
                switch (event.eventType) {
                    case 'payment.succeeded':
                        await handlePaymentSucceeded(event.payload);
                        break;
                    case 'payment.failed':
                        await handlePaymentFailed(event.payload);
                        break;
                    default:
                        console.log(`Unknown event type: ${event.eventType}`);
                }
                
                // Atualizar status no KV
                await env.WEBHOOK_KV.put(`webhook:${event.eventId}`, "processed");
                message.ack();
            } catch (error) {
                console.error(`Failed to process event ${event.eventId}:`, error);
                // Retry via exception ou message.retry()
                throw error;
            }
        }
    }
}
```

## Exemplo: Webhook Stripe completo

```typescript
import { Hono } from 'hono';
import { crypto } from 'cloudflare:sockets';

const app = new Hono();

app.post('/webhook/stripe', async (c) => {
    const rawBody = await c.req.text();
    const signature = c.req.header('stripe-signature');
    
    // Validar assinatura Stripe
    if (!await verifyStripeSignature(rawBody, signature, c.env.STRIPE_WEBHOOK_SECRET)) {
        return c.text('Invalid signature', 401);
    }
    
    const event = JSON.parse(rawBody);
    
    // Idempotency via event ID
    const key = `stripe:${event.id}`;
    if (await c.env.KV.get(key)) {
        return c.text('Already processed', 200);
    }
    
    // Processamento sincrono ou via queue
    await c.env.EVENT_QUEUE.send(JSON.stringify(event));
    await c.env.KV.put(key, "queued", { expirationTtl: 86400 });
    
    return c.text('OK', 200);
});

async function verifyStripeSignature(
    payload: string,
    signature: string,
    secret: string
): Promise<boolean> {
    const elements = signature.split(',');
    const timestampElement = elements.find(e => e.startsWith('t='));
    const signatureElement = elements.find(e => e.startsWith('v1='));
    
    if (!timestampElement || !signatureElement) return false;
    
    const timestamp = timestampElement.substring(2);
    const expectedSignature = signatureElement.substring(3);
    
    // Stripe usa: timestamp.payload com secret
    const signedPayload = `${timestamp}.${payload}`;
    
    const encoder = new TextEncoder();
    const key = await crypto.subtle.importKey(
        'raw',
        encoder.encode(secret),
        { name: 'HMAC', hash: 'SHA-256' },
        false,
        ['verify']
    );
    
    const signatureBytes = hexToBytes(expectedSignature);
    const payloadBytes = encoder.encode(signedPayload);
    
    return await crypto.subtle.verify('HMAC', key, signatureBytes, payloadBytes);
}
```

## Exemplo Ruim (EVITAR)

```typescript
// EVITAR: parse JSON antes de validar assinatura
app.post('/webhook', async (c) => {
    const body = await c.req.json();  // JA parseou — raw body perdido
    // Nao da mais para verificar assinatura!
    const sig = c.req.header('x-signature');
    verifySignature(JSON.stringify(body), sig, secret); // Assinatura nao vai bater
});

// EVITAR: comparacao timing-unsafe
if (signature === expectedSignature) {  // vulneravel a timing attacks
    return c.text('OK', 200);
}

// EVITAR: sem idempotency — mesmo evento processado multiplas vezes
app.post('/webhook', async (c) => {
    const event = await c.req.json();
    await processPayment(event.data);  // double-processing se webhook re-enviado
    return c.text('OK', 200);
});

// EVITAR: processamento pesado no handler (timeout > 5s)
app.post('/webhook', async (c) => {
    const event = await c.req.json();
    await heavyProcessing(event);  // Workers vai timeout
    return c.text('OK', 200);
});
```

## Gotchas

1. **Timing-safe compare**: Use SEMPRE `crypto.subtle.verify()` para
   comparacao de HMAC. Comparacao com `===` eh vulneravel a timing attacks.

2. **Webhook 200 rapido**: Workers devem responder em < 5s. Processamento
   pesado deve ser enfileirado via Queue para processamento assincrono.

3. **Idempotency via event_id key**: Sempre verificar se evento ja foi
   processado antes de prosseguir. Usar KV com TTL para evitar duplicacao.

4. **Raw body antes parse**: Obter body como text ANTES de parse.
   Apos `req.json()`, raw body nao esta mais disponivel.

5. **Replay protection com timestamp**: Validar que timestamp do evento
   nao eh muito antigo (ex: > 5 min) para evitar replay de eventos antigos.

6. **Secret via wrangler secret put**: NUNCA colocar secrets no [vars]
   do wrangler.toml. Secrets DEVEM ser configurados via `wrangler secret put`.

7. **Headers corretos para cada provider**:
   - Stripe: `stripe-signature` (contem timestamp e v1)
   - GitHub: `x-hub-signature-256` (contem sha256=...)
   - Pagar.me: `x-pagarme-signature` (HMAC-SHA256)

## Quando NAO usar

- **Endpoint interno sem validacao** → usar route generica sem webhook pattern
- **GraphQL subscriptions** → usar pattern especifico para GraphQL
- **Webhook sem idempotencia** → garantir que provider rejeita retries (raro)
- **Consumer de webhook ja recebido via Queue** → ja esta pronto em consumer

## Ver tambem

- [`platform-related/cloudflare-workers/skills/cf-workers-add-queue-consumer/`](./cf-workers-add-queue-consumer/) — setup de Queue
- [`platform-related/cloudflare-shared/skills/cf-api-call/`](../../../cloudflare-shared/skills/cf-api-call/) — API REST para gerenciamento
- [`global/skills/owasp-security/`](../../../global/skills/owasp-security/) — revisao de seguranca OWASP
