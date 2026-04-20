---
name: ts-add-route
description: |
  Use quando o usuário disser "add route", "nova rota", "criar endpoint", "add hono route", "novo endpoint", "adicionar rota", "POST endpoint", "GET endpoint", "PUT endpoint", "DELETE endpoint"
  Também quando mencionar "criar handler", "novo handler", "webhook", "API endpoint", "rest api"
  NAO use quando for criar um domínio completo (use ts-add-domain), ou quando for criar componente React (use ts-add-component).
allowed-tools: [Read, Write, Glob, Grep]
---

# Adicionar Rota Hono com Zod Validator

## Intro

Adiciona uma nova rota a um Cloudflare Worker usando Hono como router. A rota recebe um schema Zod para validação automática de request (via `zValidator` do `@hono/zod-validator`), delega para a service layer e retorna resposta tipada. O schema Zod inferido permite acesso type-safe ao body/query/param validado via `c.req.valid()`.

## Trigger Phrases

- "add route"
- "nova rota"
- "criar endpoint"
- "add hono route"
- "novo endpoint"
- "adicionar rota"
- "POST endpoint"
- "GET endpoint"
- "PUT endpoint"
- "DELETE endpoint"
- "criar handler"
- "novo handler"
- "webhook"
- "API endpoint"
- "rest api"

## Pre-flight Reads

1. **`/src/router.ts`** — Identificar padrão de registro de rotas (como controllers são importados e anexados), verificar se existe `.route('/basepath', controller.hono)` e o tipo `HonoApp`.
2. **`/src/services/<Entity>Service.ts`** — Confirmar que o service que a rota vai chamar já existe e verificar a assinatura dos métodos disponíveis.
3. **`/src/domains/<Entity>/schemas/`** — Verificar se já existe schema Zod reutilizável para a entidade em questão.
4. **`/src/types/http.ts`** — Verificar convenções de tipos de resposta (padronização de `{ data, error }` response envelope).
5. **`/vite.config.ts`** ou **`/wrangler.toml`** — Confirmar entry point e path de build.

## Workflow

1. **Identificar método HTTP e path** — POST/GET/PUT/DELETE + path (ex: `POST /users`, `GET /users/:id`). Normalizar para convenção Hono (ex: `/users/:id`).
2. **Escolher controller existente ou criar novo** — Se a rota pertence a um domínio existente, usar o controller existente. Se novo domínio, usar `ts-add-domain`.
3. **Definir schema Zod** — Criar schema de validação para body/query/params. Nomes de campos em `camelCase`. Usar `z.string()`, `z.number()`, `z.boolean()`, `z.enum()` conforme tipo real. Campos opcionais usar `.optional()`.
4. **Registrar rota no controller** — Adicionar método no controller usando `(this.hono.post|get|put|delete)('/path', zValidator('json'|'query'|'param', schema), handler)`.
5. **Tipar retorno de `c.req.valid()`** — O retorno de `c.req.valid('json')` é automaticamente inferido do schema Zod passado. Declarar variável para usar inference correta.
6. **Implementar handler** — Chamar service method, mapear resposta para formato padronizado, usar `c.json(data, status)`.
7. **Tratar erros com c.json** — Error handling em todas as branches: 400 (bad request/invalid input), 404 (not found), 409 (conflict), 500 (internal server error). Nunca expor stack trace.
8. **Integrar no router.ts** — Importar controller (se novo), anexar via `.route('/prefix', controller.hono)`. Atualizar tipo `HonoApp` se necessário.
9. **Testar** — Criar teste em `*.test.ts` com `fetch()` Hono para validar rota.

## Exemplos

### Bom — POST /users com Zod validation completa

```typescript
// src/domains/User/controller.ts
import { Hono } from 'hono';
import { zValidator } from '@hono/zod-validator';
import { z } from 'zod';
import type { UserService } from './service.js';

const createUserSchema = z.object({
  email: z.string().email('Email inválido'),
  name: z.string().min(1, 'Nome é obrigatório').max(255),
  role: z.enum(['admin', 'user']).default('user'),
});

export class UserController {
  private hono = new Hono();

  constructor(private service: UserService) {
    this.hono.post('/', zValidator('json', createUserSchema), async (c) => {
      const body = c.req.valid('json');
      // body é tipo inferido: { email: string; name: string; role?: 'admin' | 'user' }

      try {
        const user = await this.service.createUser(body);
        return c.json({ data: user }, 201);
      } catch (err) {
        if (err instanceof Error) {
          if (err.message === 'EMAIL_ALREADY_EXISTS') {
            return c.json({ error: { code: 'EMAIL_CONFLICT', message: 'Email já está em uso' } }, 409);
          }
        }
        return c.json({ error: { code: 'INTERNAL_ERROR', message: 'Erro interno' } }, 500);
      }
    });

    this.hono.get('/:id', async (c) => {
      const id = c.req.param('id');
      const user = await this.service.getUser(id);

      if (!user) {
        return c.json({ error: { code: 'NOT_FOUND', message: 'Usuário não encontrado' } }, 404);
      }

      return c.json({ data: user }, 200);
    });
  }
}
```

```typescript
// src/router.ts
import { Hono } from 'hono';
import { UserController } from './domains/User/controller.js';
import { UserService } from './domains/User/service.js';
import { UserRepository } from './domains/User/repository.js';

type Env = {Bindings: { DB: D1Database }};

const app = new Hono<{ Bindings: Env }>();

const db = app.getDB('DB');

const userRepository = new UserRepository(db);
const userService = new UserService(userRepository);
const userController = new UserController(userService);

app.route('/users', userController.hono);

export type HonoApp = typeof app;
```

### Ruim — Sem zValidator, handler gordo, error vazando stack

```typescript
// RUIM: Sem validação Zod, body any
this.hono.post('/', async (c) => {
  const body = await c.req.json(); // any! sem tipagem
  const user = await this.service.createUser(body as any); // gambiarra
  return c.json(user);
});

// RUIM: Handler fazendo lógica de negócio (violação de SRP)
this.hono.post('/', async (c) => {
  const body = await c.req.json();
  // Lógica de validação, persistência, tudo aqui! Controller deveria ser thin.
  const id = crypto.randomUUID();
  // ...
});

// RUIM: Error handling expondo stack trace
} catch (err) {
  return c.json({ error: (err as Error).stack }, 500); // EXPÕE STACK TRACE!
}

// RUIM: Status code genérico
return c.json(user); // Falta status code! Default 200, mas deveria ser 201.
```

## Gotchas

1. **`zValidator('json'|'query'|'param', schema)`** — A ordem dos imports importa. Asegure-se de importar `z` de `zod` e `zValidator` de `@hono/zod-validator`. O primeiro argumento ('json'|'query'|'param') indica de onde o validator lê os dados.

2. **`c.req.valid('json')` tipo inferido** — O retorno é automaticamente tipado com base no schema Zod fornecido. Você não precisa fazer cast manual. Ex: `const body = c.req.valid('json')` → body é `{ email: string; name: string }`.

3. **Error handling com `c.json`** — Sempre retorne `{ error: { code: string, message: string } }`. Nunca use `throw` em handlers Hono (exceto em middleware de erro). Status codes: 201 (created), 200 (ok), 400 (bad request), 404 (not found), 409 (conflict), 500 (server error).

4. **Soft delete no GET** — Queries de list/get devem filtrar `deleted_at IS NULL`. Sempre. Mesmo em rotas simples.

5. **UUID como param** — Params de rota (ex: `:id`) são sempre `string`. Validar formato UUID com Zod (`.uuid()`) antes de passar para o service. Isso evita queries desnecessárias no banco.

6. **Middleware de autenticação** — Se a rota requer auth, usar `app.use('/protected/*', authMiddleware)` no router principal, não dentro do handler. Handler não deve chamar middleware manualmente.
