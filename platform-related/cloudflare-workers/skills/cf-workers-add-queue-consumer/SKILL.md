---
name: cf-workers-add-queue-consumer
description: |
  Configure Cloudflare Queue consumer with retry and DLQ. Use quando: "add queue consumer", "wrangler queue", "cloudflare queue setup", "novo consumer", "configurar queue worker". Tambem quando: criar producer para enfileirar, configurar retry policy, DLQ. NAO use quando: filas SQS (use data-related/aws/), processamento em batch fora do Workers.
allowed-tools:
  - Read
  - Bash
  - Glob
  - Grep
---

# Cloudflare Workers — Add Queue Consumer

Configura consumer de Cloudflare Queues com politica de retry, DLQ
(dead-letter queue) e acknowledgement explicito. Integra binding no
wrangler.toml e implementa handler TypeScript com semantics correta.

## Trigger Phrases

- "add queue consumer"
- "wrangler queue"
- "cloudflare queue setup"
- "novo consumer"
- "configurar queue worker"
- "dead letter queue"
- "dlq cloudflare"

## Pre-Flight Checks

Antes de iniciar, leia:

1. **wrangler.toml** — identificar queues existentes e bindings atuais
   ```bash
   grep -E "queues|consumer|producer" wrangler.toml | head -20
   ```
2. **Queues existentes** — listar queues no account
   ```bash
   wrangler queues list
   ```
3. **Bindings no codigo** — ver como env.QUEUE esta sendo usado
   ```bash
   grep -rn "queue" --include="*.ts" src/ | head -10
   ```

## Workflow

### Passo 1 — Criar queue principal

```bash
wrangler queues create <queue-name>
```

Exemplo:
```bash
wrangler queues create my-worker-queue
```

### Passo 2 — Criar DLQ (Dead Letter Queue)

```bash
wrangler queues create <queue-name>-dlq
```

DLQ recebe mensagens que falharam apos todas as tentativas de retry.

### Passo 3 — Configurar wrangler.toml

```toml
name = "my-worker"
main = "src/index.ts"

[observability]
enabled = true

# Producer — worker enfileira mensagens
[[queues.producers]]
queue = "my-worker-queue"
binding = "PROD_QUEUE"

# Consumer — este worker processa mensagens
[[queues.consumers]]
queue = "my-worker-queue"
max_batch_size = 10           # default 10, max 100
max_batch_timeout = 30        # segundos, default 30
max_retries = 3               # default 3, max 10
dead_letter_queue = "my-worker-queue-dlq"
```

### Passo 4 — Implementar handler

```typescript
export default {
    async queue(
        batch: MessageBatch,
        env: Env,
        ctx: ExecutionContext
    ): Promise<void> {
        // Processar cada mensagem
        for (const message of batch.messages) {
            try {
                const payload = JSON.parse(message.body);
                
                // Lógica de negócio
                await processPayment(payload);
                
                // Acknowledge explícito — mensagem processada com sucesso
                message.ack();
            } catch (error) {
                // Retry: jogar excecao faz o Workers re-enfileirar
                // ate max_retries configurado no wrangler.toml
                throw error;
                // OU: retry manual
                // await message.retry();
            }
        }
    }
}
```

### Passo 5 — Producer (enfileirar)

```typescript
// Em outro worker ou endpoint
async function enqueueTask(payload: object): Promise<void> {
    await env.PROD_QUEUE.send(JSON.stringify(payload));
}
```

## Exemplo Completo: wrangler.toml

```toml
name = "payment-processor"
main = "src/index.ts"
compatibility_date = "2024-03-01"

[observability]
enabled = true
tail_consumers = [{ formula = "statusCode >= 500" }]

# Producer binding — para workers que enviam mensagens
[[queues.producers]]
queue = "payment-tasks"
binding = "PAYMENT_QUEUE"

# Consumer — este worker processa payments
[[queues.consumers]]
queue = "payment-tasks"
max_batch_size = 5
max_batch_timeout = 60
max_retries = 5
dead_letter_queue = "payment-tasks-dlq"

# Voce tambem pode ter mais de um consumer (outro worker)
[[queues.consumers]]
queue = "payment-tasks"
queue = "notification-queue"
```

## Exemplo: Handler com idempotencia

```typescript
export default {
    async queue(
        batch: MessageBatch<PaymentTask>,
        env: Env,
        ctx: ExecutionContext
    ): Promise<void> {
        for (const message of batch.messages) {
            const task = message.body;
            
            // Idempotency check via message.id
            const processedKey = `processed:${task.orderId}`;
            const alreadyProcessed = await env.KV.get(processedKey);
            
            if (alreadyProcessed) {
                message.ack(); // ja processado, confirmar e continuar
                continue;
            }
            
            try {
                await processPayment(task);
                
                // Marcar como processado (TTL de 7 dias)
                await env.KV.put(processedKey, "1", { expirationTtl: 604800 });
                
                message.ack();
            } catch (error) {
                // message.attempts: número de tentativas já realizadas (1-based)
                const retryCount = message.attempts;

                if (retryCount >= 3) {
                    // Vai para DLQ apos max_retries
                    throw error;
                }

                // Manual retry
                message.retry();
            }
        }
    }
}
```

## Exemplo Ruim (EVITAR)

```typescript
// EVITAR: consumer sem ack
export default {
    async queue(batch, env, ctx) {
        for (const message of batch.messages) {
            await processSomething(message.body);
            // FALHA: mensagem nao recebe ack, Workers re-delivera infinitamente
        }
    }
}

// EVITAR: nao configurar DLQ em producao
[[queues.consumers]]
queue = "my-queue"
max_retries = 3
// FALTA: dead_letter_queue = "my-queue-dlq"
// Em producao, mensagens com falha definitiva serao PERDIDAS

// EVITAR: batch muito grande
max_batch_size = 100  // pode estourar CPU se processamento for pesado
```

## Gotchas

1. **max_batch_size default 10**: Controle o tamanho do lote conforme
   complexidade do processamento. Lotes grandes reduzem overhead mas
   podem estourar CPU (limite 50ms no plano gratuito, 5min no paid).

2. **max_retries default 3**: Apos esgotar retries, mensagem vai para DLQ.
   Sem DLQ configurado, mensagens sao perdidas em producao.

3. **DLQ obrigatorio em prod**: Sempre configure `dead_letter_queue` em
   ambiente de producao para evitar perda de mensagens criticas.

4. **ack/retry explicito**: Voce DEVE chamar `message.ack()` ou
   `message.retry()`. Se o handler terminar sem nenhuma acao, a mensagem
   permanece em estado pendente e sera re-deliverada.

5. **Idempotency via message.id**: Cada mensagem tem ID unico. Use KV ou
   D1 para marcar processamento e evitar duplicatas.

6. **Exactly-once NAO garantido**: Cloudflare Queues oferece at-least-once.
   Seu codigo deve ser idempotente. Mensagens podem ser deliveradas
   mais de uma vez em casos de falha.

7. **max_batch_timeout em segundos**: Tempo maximo para receber batch
   cheio ou estourar timeout. Default 30s. Ajuste conforme latencia
   expected do processamento.

## Quando NAO usar

- **SQS/SQS FIFO** → use `data-related/aws/skills/sqs-consumer-pattern`
- **RabbitMQ** → use `language-related/go/skills/go-add-consumer`
- **Batch processing fora do Workers** → considere Workers Tartaro ou Durable
- **Stream processing** → use Cloudflare Streams ou third-party

## Ver tambem

- [`platform-related/cloudflare-shared/skills/cf-api-call/`](../../../cloudflare-shared/skills/cf-api-call/) — API REST para gerenciar queues
- [`global/skills/cred-store/`](../../../global/skills/cred-store/) — gerenciamento de credenciais
