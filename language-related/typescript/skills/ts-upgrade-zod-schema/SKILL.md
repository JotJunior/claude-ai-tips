---
name: ts-upgrade-zod-schema
description: Migra schemas Zod v3 para v4 em projetos TypeScript (Cloudflare Workers + Hono + Drizzle). Use quando mencionar "upgrade zod", "zod v4", "migrate zod", "zod 4 migration" ou "zod breaking changes". Realiza migration manual ou assistida de breaking changes.
allowed-tools:
  - Read
  - Glob
  - Grep
  - Bash
---

# TypeScript Upgrade Zod Schema (v3 para v4)

Realiza migracao de schemas Zod v3 para v4. Identifica breaking changes, aplica correcoes manuais ou assistidas, e valida que type inference e validacao continuam funcionando.

## Quando Usar

- Projeto precisa atualizar Zod de v3 para v4
- Encontrou erros de compilacao apos upgrade de dependencia
- Trigger phrases: "upgrade zod", "zod v4", "migrate zod", "zod 4 migration", "zod breaking changes"

## Pre-Flight

### Verificar Versao Atual

```bash
# Verificar versao atual do Zod
pnpm why zod

# Verificar no package.json
grep '"zod"' package.json
```

### Dependencias que Podem Ser Afetadas

```bash
# Verificar integracoes Zod
pnpm why @hono/zod-validator drizzle-zod zod-to-json-schema json-schema-to-zod
```

### Breaking Changes Zod v4 (Resumo)

| v3 | v4 | Notes |
|----|----|-------|
| `z.string().email()` | `z.email()` | Novo metodo |
| `z.coerce.number()` | `z.coerce.number()` | Comportamento mudou |
| `z.record(K, V)` | `z.record(K, V)` | Requer 2 args agora |
| `.strict()` | `.passthrough()` | Default mudou |
| `.refine()` async | `.refine()` async | Comportamento mudou |
| `.transform()` | `.transform()` | Type inference mudou |
| `z.input<T>` | `z.input<T>` | Pode mudar |
| `z.inferType()` | `z.infer<typeof schema>()` | Deprecated |

## Workflow

### Passo 1: Identificar Breaking Changes

```bash
# Buscar todos os arquivos com Zod
grep -rn "from 'zod'" src/
grep -rn "import { z }" src/
grep -rn "z\." src/**/*.ts | head -100
```

Criar inventario de patterns que precisam migracao:

```bash
# Schema methods que mudaram
grep -rn "\.email()" src/
grep -rn "\.url()" src/
grep -rn "\.uuid()" src/
grep -rn "\.cuid()" src/
grep -rn "\.strict()" src/
grep -rn "\.passthrough()" src/
grep -rn "\.refine()" src/
grep -rn "\.transform()" src/
grep -rn "\.partial()" src/
grep -rn "\.coerce\." src/
grep -rn "z\.record(" src/
grep -rn "z\.union(" src/
grep -rn "z\.intersect(" src/
```

### Passo 2: Ler CHANGELOG Zod v4

Consulte a documentacao oficial para detalhes completos:

- [Zod CHANGELOG](https://github.com/colinhacks/zod/blob/master/CHANGELOG.md)
- [Zod v4 Breaking Changes](https://zod.dev/doc/changelog)

### Passo 3: Aplicar Migration

#### 3.1: Validacao de Email

```typescript
// ANTES (v3)
const UserSchema = z.object({
  email: z.string().email('Email invalido'),
  website: z.string().url().optional(),
  id: z.string().uuid(),
});

// DEPOIS (v4)
const UserSchema = z.object({
  email: z.email('Email invalido'),           // z.email() em vez de z.string().email()
  website: z.url().optional(),                  // z.url() em vez de z.string().url()
  id: z.uuid(),                                  // z.uuid() em vez de z.string().uuid()
});
```

#### 3.2: Strict Mode (Mudanca de Default)

Em v3, `z.object()` permite chaves extras por default.
Em v4, `z.object()` rejeita chaves extras por default.

```typescript
// ANTES (v3)
const ConfigSchema = z.object({
  apiKey: z.string(),
});
// ConfigSchema.parse({ apiKey: 'x', extra: 1 }) // funciona em v3

// DEPOIS (v4)
const ConfigSchema = z.object({
  apiKey: z.string(),
  extra: z.string().optional(),  // adicionar campos se quiser permitir
});
// ou, se quiser permitir chaves extras:
const ConfigSchema = z.object({
  apiKey: z.string(),
}).passthrough();
```

**Se seu codigo depende de chaves extras**:
```typescript
// DEPOIS (v4) - Explicitamente permitir extras
const ConfigSchema = z.object({
  apiKey: z.string(),
}).passthrough();  // equivale ao antigo .strict(false)
```

#### 3.3: Coerce Mudou

```typescript
// ANTES (v3)
const AgeSchema = z.coerce.number();  // converte string para number

// DEPOIS (v4)
const AgeSchema = z.coerce.number();  // mesmo uso, mas comportamento interno mudou
// Agora lanca erro em valores invalidos ao inves de retornar NaN
```

#### 3.4: Record Requer 2 Args

```typescript
// ANTES (v3)
const StringRecordSchema = z.record(z.string());  // 1 arg funcionava

// DEPOIS (v4) - 2 args obrigatorios
const StringRecordSchema = z.record(z.string(), z.string());  // K, V
const NumberRecordSchema = z.record(z.string(), z.number());   // K, V
```

#### 3.5: Partial Behavior

```typescript
// ANTES (v3)
const PartialSchema = UserSchema.partial();

// DEPOIS (v4)
const PartialSchema = UserSchema.partial();
// Comportamento similar, mas type inference pode ser diferente
```

#### 3.6: Refine Async

```typescript
// ANTES (v3)
const RefinedSchema = z.string().refine(
  async (val) => { /* async check */ },
  { message: 'Invalid' }
);

// DEPOIS (v4) - similar, mas:
const RefinedSchema = z.string().refine(
  async (val) => { /* async check */ },
  { 
    message: 'Invalid',
    error: z.ZodErrorIssueCode.custom  // mais granular
  }
);
```

### Passo 4: Verificar Integracoes

#### @hono/zod-validator

```bash
# Verificar versao atual
pnpm why @hono/zod-validator

# Se incompativel, atualizar
pnpm up @hono/zod-validator
```

Verificar se a versao e compativel com Zod v4.

#### drizzle-zod

```bash
# Verificar versao
pnpm why drizzle-zod

# Gerar schemas novamente se necessario
pnpm drizzle-kit generate --output ./src/db/zod-schemas
```

### Passo 5: Validar Typecheck

```bash
# Limpar cache
rm -rf node_modules/.cache
pnpm tsc --noEmit
```

Corrigir erros de tipo relacionados a mudanca de `z.inferType<T>()` para `z.infer<typeof T>`.

```typescript
// ANTES (v3)
type User = z.inferType<typeof UserSchema>;

// DEPOIS (v4)
type User = z.infer<typeof UserSchema>;
```

### Passo 6: Rodar Tests

```bash
# Tests unitarios
pnpm test

# Tests de integracao se existir
pnpm test:integration
```

Verificar se validacoes ainda funcionam como esperado.

## Exemplo: Bom

### Schema Migrado v4 Idomatico

```typescript
// src/schemas/user.ts
import { z } from 'zod';

// Base user schema - v4 idiomático
export const UserSchema = z.object({
  id: z.uuid(),
  email: z.email(),
  name: z.string().min(1).max(255),
  age: z.number().int().positive().optional(),
  role: z.enum(['admin', 'user', 'guest']),
  createdAt: z.coerce.date(),
});

// Schema para criacao (subset de campos)
export const CreateUserSchema = UserSchema.pick({
  email: true,
  name: true,
  age: true,
  role: true,
}).extend({
  password: z.string().min(8).max(128),
});

// Schema para atualizacao (todos opcionais)
export const UpdateUserSchema = UserSchema.partial().pick({
  name: true,
  age: true,
  role: true,
});

// Schema de resposta (sem dados sensiveis)
export const UserResponseSchema = UserSchema.omit({
  // Nada sensivel para remover aqui, exemplo
}).extend({
  email: z.email(),  // email e aceitavel em resposta
});

// Type exports
export type User = z.infer<typeof UserSchema>;
export type CreateUser = z.infer<typeof CreateUserSchema>;
export type UpdateUser = z.infer<typeof UpdateUserSchema>;

// Validacao com error format personalizado
export function validateUser(data: unknown) {
  return UserSchema.safeParse(data);
}

// Validacao com erros formatados para API
export function validateUserForAPI(data: unknown) {
  const result = UserSchema.safeParse(data);
  if (!result.success) {
    return {
      valid: false as const,
      errors: result.error.issues.map(issue => ({
        path: issue.path.join('.'),
        message: issue.message,
      })),
    };
  }
  return { valid: true as const, data: result.data };
}
```

### Handler com Schema Migrado

```typescript
// src/handlers/user.ts
import type { Context } from 'hono';
import { CreateUserSchema, validateUserForAPI } from '../schemas/user';
import { db } from '../db';
import { users } from '../db/schema';
import { eq } from 'drizzle-orm';

export async function createUserHandler(c: Context) {
  const body = await c.req.json();
  
  // Validacao com Zod v4
  const validation = validateUserForAPI(body);
  
  if (!validation.valid) {
    return c.json({ 
      error: { 
        code: 'VALIDATION_ERROR', 
        message: 'Dados invalidos',
        details: validation.errors,
      } 
    }, 400);
  }
  
  const user = await db.insert(users).values(validation.data).returning();
  
  return c.json({ data: user }, 201);
}
```

## Exemplo: Ruim

### Schema Ainda em v3 (Com Warnings)

```typescript
// src/schemas/user.ts (ANTIPATTERN)
import { z } from 'zod';

// Uso de metodos antigos (deprecated em v4)
export const OldUserSchema = z.object({
  id: z.string().uuid(),  // WARNING: z.uuid() em vez de z.string().uuid()
  email: z.string().email(),  // WARNING: z.email() em vez de z.string().email()
  website: z.string().url().optional(),  // WARNING: z.url()
  metadata: z.record(z.string()),  // WARNING: z.record() precisa de 2 args
});

// Strict mode nao especificado (default mudou)
export const ConfigSchema = z.object({
  apiKey: z.string(),
});  // WARNING: Em v4, ja e strict por default

// InferType ainda usado
export type OldUser = z.inferType<typeof OldUserSchema>;  // WARNING: use z.infer<>

// Transform com type inference problematica
export const TransformedSchema = z.string()
  .transform(val => ({ value: val }))
  .transform(val => val.value.length);  // WARNING: Type inference pode falhar
```

### Handler Vulneravel a Injection

```typescript
// src/handlers/search.ts (ANTIPATTERN)
import { z } from 'zod';
import { db } from '../db';
import { sql } from 'drizzle-orm';

const SearchSchema = z.object({
  query: z.string(),
});

// Handler sem validacao de schema
export async function searchHandler(c: Context) {
  const { query } = c.req.query();
  
  // SQL Injection se query nao for sanitizada
  const results = await db.execute(
    sql`SELECT * FROM products WHERE name LIKE '%${query}%'`
  );
  
  return c.json(results);
}
```

## Gotchas

1. **@hono/zod-validator peer dependency**: Esta biblioteca tem peer dependency do Zod. Apos upgrade, verifique se a versao do @hono/zod-validator suporta Zod v4. Se nao, atualize ou faca fallback para validacao manual.

2. **drizzle-zod pode quebrar**: Se usar `drizzle-zod` para gerar schemas do banco, verifique se a versao e compativel com Zod v4. Algumas funcionalidades como `z.union` discriminated unions tem mudanca de comportamento.

3. **z.inferType deprecated**: `z.inferType<T>()` foi substituido por `z.infer<typeof schema>`. Faca grep global e substitua. Type inference pode mudar em alguns casos edge.

4. **Error format mudou**: `error.issues` substituiu `error.errors` em alguns contextos. Verifique como seu codigo trata erros de validacao Zod.

5. **.strict() vs .passthrough()**: Em v4, `z.object()` ja e strict por default. Se seu codigo depende de允许 chaves extras, adicione `.passthrough()` explicitamente.

6. **z.record() requer generics**: Em v4, `z.record(KeySchema, ValueSchema)` e obrigatorio com 2 argumentos. `z.record(z.string())` nao funciona mais.

7. **z.coerce.* mudou internamente**: O comportamento interno de `z.coerce` mudou para lanchar erros mais faceis de debug em valores invalidos (NaN -> ZodError).

## Quando NAO Usar

- **Projeto ja em Zod v4**: Nao ha migracao a fazer
- **Codigo novo**: Comece com Zod v4 desde o inicio
- **Bibliotecas que ainda nao suportam v4**: @hono/zod-validator, drizzle-zod, etc. Nestes casos, espere atualizacao ou faca fork
- **Testes E2E**: Validacao de output, nao de migracao

## Checklist de Validacao

- [ ] `pnpm why zod` mostra versao 4.x
- [ ] Todos `z.string().email()` migrados para `z.email()`
- [ ] Todos `z.string().url()` migrados para `z.url()`
- [ ] Todos `z.string().uuid()` migrados para `z.uuid()`
- [ ] `z.record()` com 2 generics
- [ ] `.passthrough()` adicionado onde necessario
- [ ] `z.inferType<T>()` substituido por `z.infer<typeof T>()`
- [ ] `@hono/zod-validator` compativel com Zod v4
- [ ] `drizzle-zod` compativel com Zod v4
- [ ] `pnpm tsc --noEmit` sem erros
- [ ] `pnpm test` passando
