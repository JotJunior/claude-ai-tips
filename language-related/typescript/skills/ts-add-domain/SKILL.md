---
name: ts-add-domain
description: |
  Use quando o usuário disser "add domain", "novo domínio", "criar bounded context", "scaffold ddd", "novo módulo DDD", "criar domínio", "setup domain", "init domain"
  Também quando mencionar "nova feature", "novo módulo" no contexto de backend Cloudflare Workers com arquitetura DDD.
  NÃO use quando for apenas adicionar uma rota simples (use ts-add-route), ou quando for criar apenas um componente React (use ts-add-component).
allowed-tools: [Read, Write, Glob, Grep]
---

# Scaffold Bounded Context (DDD) para Cloudflare Workers + Hono

## Intro

Cria a estrutura completa de um bounded context no padrão DDD dentro de um projeto Cloudflare Workers (Hono + Drizzle ORM + Zod + Vitest). Gera todos os arquivos da camada de domínio (controller, service, repository, mapper, types, schema), integra no router principal e cria um teste vazio com Vitest.

## Trigger Phrases

- "add domain"
- "novo domínio"
- "criar bounded context"
- "scaffold ddd"
- "novo módulo DDD"
- "criar domínio"
- "setup domain"
- "init domain"

## Pre-flight Reads

1. **`/router.ts`** — Identificar padrão de export de rotas, como os controllers são registrados e o estilo de tipagem usado (HonoApp type).
2. **`/src/domains/`** — Listar domínios existentes para evitar colisão de nomes e observar convenções de nomenclatura.
3. **`/src/types/`** — Verificar se existe types shared que o novo domínio deve consumir ou estender.
4. **`/drizzle.config.ts`** — Confirmar path dos migrations e como schemas de domínio são referenciados.
5. **`/vitest.config.ts`** — Verificar setup de testes (setupFiles, environment).

## Workflow

1. **Parsear o nome do domínio** — Normalizar para PascalCase (ex: "user-profile" → "UserProfile"). Confirmar que não existe em `/src/domains/`.
2. **Criar diretório** — `src/domains/<PascalCaseName>/`.
3. **Gerar `types.ts`** — Interfaces do domínio (entidades de domínio, value objects, interfaces de repository). Usar `interface` para API pública do domínio (Liskov), `type` para unions/intersections internas.
4. **Gerar `schema.ts`** — Schema Drizzle com UUIDv7 como PK, `createdAt`/`updatedAt` como timestamp, `deletedAt` como nullable (soft delete). nome da tabela: `<snake_case>_table`.
5. **Gerar `repository.ts`** — Classe com métodos CRUD completos. Recebe `Database` (D1) no construtor (injeção de dependência). Métodos: `create`, `findById`, `findAll`, `update`, `delete` (soft delete).
6. **Gerar `mapper.ts`** — Funções bidirecionais `toDomain(row)` e `toPersistence(domain)` com type guards. UUID gerado com `crypto.randomUUID()`.
7. **Gerar `service.ts`** — Classe que orquestra repository + mapper. Métodos de domínio. Recebe repository via construtor (DI). Aplicar validação de invariantes do domínio.
8. **Gerar `controller.ts`** — thin Hono handler. Recebe service via DI (ex: `app.post('/domains', (c) => controller.create(c))`). Usa `zValidator` para parsear body/query/param. Delega para service e retorna `c.json` com status codes corretos (201 created, 404 not found, 400 bad request, 500 internal server error).
9. **Integrar no router** — Importar controller e registrar as rotas no `router.ts`. Usar `HonoApp` type para tipar o app.
10. **Gerar teste vazio** — `src/domains/<Name>/<Name>.test.ts` com describe block Vitest. Mock do repository com `vi.fn()`.

## Exemplos

### Bom — Estrutura gerada para "User"

```typescript
// src/domains/User/types.ts
export interface User {
  id: string;           // UUIDv7
  email: string;
  name: string;
  createdAt: Date;
  updatedAt: Date;
  deletedAt: Date | null;
}

export interface IUserRepository {
  create(user: Omit<User, 'id' | 'createdAt' | 'updatedAt'>): Promise<User>;
  findById(id: string): Promise<User | null>;
  findAll(): Promise<User[]>;
  update(id: string, data: Partial<User>): Promise<User>;
  delete(id: string): Promise<void>;
}
```

```typescript
// src/domains/User/schema.ts
import { sql } from 'drizzle-orm';
import { text, timestamp, sqliteTable } from 'drizzle-orm/sqlite-core';

export const userTable = sqliteTable('users', {
  id: text('id').primaryKey(),
  email: text('email').notNull().unique(),
  name: text('name').notNull(),
  createdAt: timestamp('created_at', { withTimezone: true })
    .notNull()
    .default(sql`(CURRENT_TIMESTAMP)`),
  updatedAt: timestamp('updated_at', { withTimezone: true })
    .notNull()
    .default(sql`(CURRENT_TIMESTAMP)`),
  deletedAt: timestamp('deleted_at', { withTimezone: true }),
});
```

```typescript
// src/domains/User/repository.ts
import type { Database } from 'drizzle-orm';
import type { userTable } from './schema.js';
import type { User, IUserRepository } from './types.js';

export class UserRepository implements IUserRepository {
  constructor(private db: Database) {}

  async create(data: Omit<User, 'id' | 'createdAt' | 'updatedAt'>): Promise<User> {
    const id = crypto.randomUUID();
    const now = new Date();
    await this.db.insert(userTable).values({ id, ...data, createdAt: now, updatedAt: now });
    return this.findById(id) as Promise<User>;
  }

  async findById(id: string): Promise<User | null> {
    const row = await this.db.select().from(userTable).where(eq(userTable.id, id)).get();
    return row ?? null;
  }

  async findAll(): Promise<User[]> {
    return this.db.select().from(userTable).where(isNull(userTable.deletedAt)).all();
  }

  async update(id: string, data: Partial<User>): Promise<User> {
    await this.db.update(userTable).set({ ...data, updatedAt: new Date() }).where(eq(userTable.id, id));
    return this.findById(id) as Promise<User>;
  }

  async delete(id: string): Promise<void> {
    await this.db.update(userTable).set({ deletedAt: new Date() }).where(eq(userTable.id, id));
  }
}
```

```typescript
// src/domains/User/mapper.ts
import type { User } from './types.js';
import type { userTable } from './schema.js';

export function toDomain(row: typeof userTable.$inferSelect): User {
  return {
    id: row.id,
    email: row.email,
    name: row.name,
    createdAt: new Date(row.createdAt),
    updatedAt: new Date(row.updatedAt),
    deletedAt: row.deletedAt ? new Date(row.deletedAt) : null,
  };
}

export function toPersistence(user: Omit<User, 'id' | 'createdAt' | 'updatedAt'>): typeof userTable.$inferInsert {
  return {
    id: crypto.randomUUID(),
    email: user.email,
    name: user.name,
  };
}
```

```typescript
// src/domains/User/service.ts
import type { User } from './types.js';
import type { IUserRepository } from './types.js';
import { toDomain } from './mapper.js';

export class UserService {
  constructor(private repository: IUserRepository) {}

  async createUser(data: { email: string; name: string }): Promise<User> {
    if (!data.email.includes('@')) {
      throw new Error('INVALID_EMAIL');
    }
    const existing = await this.repository.findAll();
    if (existing.some((u) => u.email === data.email)) {
      throw new Error('EMAIL_ALREADY_EXISTS');
    }
    return this.repository.create(data);
  }

  async getUser(id: string): Promise<User | null> {
    return this.repository.findById(id);
  }
}
```

```typescript
// src/domains/User/controller.ts
import { Hono } from 'hono';
import { zValidator } from '@hono/zod-validator';
import { z } from 'zod';
import type { UserService } from './service.js';

const createUserSchema = z.object({
  email: z.string().email(),
  name: z.string().min(1),
});

export class UserController {
  constructor(private service: UserService) {}

  create = this.hono.post('/', zValidator('json', createUserSchema), async (c) => {
    const body = c.req.valid('json');
    try {
      const user = await this.service.createUser(body);
      return c.json(user, 201);
    } catch (err) {
      if (err instanceof Error) {
        if (err.message === 'EMAIL_ALREADY_EXISTS') return c.json({ error: 'Email already exists' }, 409);
        if (err.message === 'INVALID_EMAIL') return c.json({ error: 'Invalid email' }, 400);
      }
      return c.json({ error: 'Internal server error' }, 500);
    }
  });

  private hono = new Hono();
}
```

```typescript
// src/domains/User/User.test.ts
import { describe, it, expect, vi } from 'vitest';
import { UserService } from './service.js';

describe('UserService', () => {
  it('should be defined', () => {
    const mockRepo = { create: vi.fn(), findById: vi.fn(), findAll: vi.fn(), update: vi.fn(), delete: vi.fn() };
    const service = new UserService(mockRepo);
    expect(service).toBeDefined();
  });
});
```

### Ruim — Misturando concerns e usando `type` para interfaces de domínio

```typescript
// RUIM: type para interface pública de domínio (não permite implements)
type UserRepository = {
  create(user: any): Promise<User>;
};

// RUIM: repository fazendo validação de domínio (violação de SRP)
async create(data: any) {
  if (!data.email.includes('@')) throw new Error('Invalid email'); // isso é responsabilidade do SERVICE
  // ... implementação
}

// RUIM: sem soft delete
async delete(id: string) {
  await this.db.delete(userTable).where(eq(userTable.id, id)); // DELETE físico!
}
```

## Gotchas

1. **Interface vs Type** — Use `interface` para contratos públicos do domínio (ex: `IUserRepository`) pois permite `implements`. Use `type` para unions, intersections e tipos utilitários internos.

2. **Repository injetado por DI** — Nunca instancie o repository diretamente no controller. Passe-o via construtor (ou use um DI container simples). Isso permite mockar em testes e respeita o princípio da inversão de dependência.

3. **Mapper bidirecional** — Sempre implemente `toDomain(row)` e `toPersistence(domain)`. O `toDomain` é crítico para garantir que datas do SQLite (string) sejam convertidas para `Date` do JS. Sem isso, bugs sutis aparecem em comparações de tempo.

4. **UUIDv7 no D1** — Drizzle com SQLite no D1 não tem coluna GENERATED AS. Gere UUIDs no código com `crypto.randomUUID()` antes de inserir. Crie uma helper `generateId()` em `src/utils/id.ts`.

5. **Soft delete obrigatório** — Nunca use DELETE físico em dados de negócio. Sempre marque `deletedAt`. Queries devem filtrar `WHERE deleted_at IS NULL` por padrão.

6. **Zod schema junto ao controller** — Schemas Zod de validação de request ficam no `controller.ts` (ou em `schemas/` separado), não no `service.ts`. O service é agnóstico de transporte HTTP.
