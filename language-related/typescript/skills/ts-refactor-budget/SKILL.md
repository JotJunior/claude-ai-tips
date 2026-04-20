---
name: ts-refactor-budget
description: Refatora arquivos e funcoes que excedem budgets de tamanho (250 linhas/arquivo, 50 linhas/funcao). Use quando mencionar "refactor budget", "file too big", "function too long", "split file", "refactor file" ou "code smell size". Tambem para divulsao de arquivos monoliticos e extracao de modulos por responsabilidade.
allowed-tools:
  - Read
  - Glob
  - Grep
  - Bash
---

# TypeScript Refactor Budget

Aplica budgets de tamanho em arquivos TypeScript e refatora em modulos menores quando excedidos. Mantem a responsabilidade unica e facilita manutencao, testes e code review.

## Quando Usar

- Arquivo individual excede 250 linhas
- Funcao individual excede 50 linhas
- Arquivo contem multiplas responsabilidades misturadas
- Code review identifica "arquivo grande demais"
- Trigger phrases: "refactor budget", "file too big", "function too long", "split file", "refactor file", "code smell size"

## Pre-Flight

Identificar o arquivo-alvo e analisar seu conteudo:

1. **Localizar o arquivo**: Use glob ou grep para encontrar o arquivo mencionado
2. **Contar linhas**: `wc -l arquivo.ts` para verificar se excede 250 linhas
3. **Mapear responsabilidades**: Ler o arquivo e identificar grupos logicos de codigo
4. **Identificar consumers**: Quem importa/exporta este arquivo

Arquivos de referencia a verificar:
- `**/handlers/**/*.ts` — handlers de API
- `**/services/**/*.ts` — logica de negocio
- `**/routes/**/*.ts` — definicoes de rotas
- `**/schemas/**/*.ts` — Zod schemas
- `**/utils/**/*.ts` — funcoes auxiliares

## Workflow

### Passo 1: Analisar Tamanho Atual

```bash
# Contar linhas do arquivo
wc -l src/handlers/user.ts

# Contar linhas por funcao
wc -l src/handlers/user.ts && grep -n "function\|const.*=" src/handlers/user.ts | head -20
```

### Passo 2: Identificar Responsabilidades

A leitura do arquivo deve revelar agrupamentos naturais:

| Responsabilidade | Indicadores |
|------------------|-------------|
| **Types/Interfaces** | `interface X`, `type X =`, `enum X` |
| **Zod Schemas** | `z.object`, `z.array`, `.extend()` |
| **Helpers/Utils** | Funcoes pure functions sem estado |
| **Constants** | `const X =`, valores fixos |
| **Business Logic** | Regras de dominio, validacoes especificas |
| **API Handlers** | `handler`, `route`, `endpoint` |

### Passo 3: Criar Estrutura de Modulos

Para um arquivo `user.ts` de 500+ linhas, a estrutura ideal:

```
user/
├── index.ts           # Barrel file com re-exports
├── types.ts           # Interfaces e tipos compartilhados
├── schemas.ts         # Zod schemas (se aplicavel)
├── constants.ts       # Constantes do dominio
├── helpers.ts         # Funcoes auxiliares pure
├── repository.ts      # Acesso a dados (se aplicavel)
├── service.ts         # Logica de negocio (se aplicavel)
└── handlers.ts        # Handlers de API (se aplicavel)
```

**Regra**: 1 arquivo = 1 responsabilidade unica.

### Passo 4: Extrair Modulos

Ordem de extracao recomendada (dependencias primeiro):

1. **types.ts** — interfaces e tipos
2. **constants.ts** — valores constantes
3. **schemas.ts** — Zod schemas (depende de types)
4. **helpers.ts** — funcoes utilitarias (depende de types, constants)
5. **repository.ts** — acesso a dados (depende de types, schemas)
6. **service.ts** — logica de negocio (depende de todos acima)
7. **handlers.ts** — handlers de API (depende de todos acima)

### Passo 5: Criar Barrel File (index.ts)

```typescript
// user/index.ts
export * from './types.ts';
export * from './constants.ts';
export * from './schemas.ts';
export * from './helpers.ts';
export * from './service.ts';
export * from './handlers.ts';
```

**Importante**: Barrel files podem quebrar tree-shaking em bundles. Quando possivel, use imports diretos nos consumers.

### Passo 6: Atualizar Imports nos Consumers

```typescript
// ANTES (import do arquivo monolítico)
import { UserService, UserType, USER_ROLES } from '../user.ts';

// DEPOIS (imports diretos por responsabilidade)
import type { UserType } from '../user/types.ts';
import { USER_ROLES } from '../user/constants.ts';
import { UserService } from '../user/service.ts';
```

### Passo 7: Validar

```bash
# TypeScript compila
pnpm typecheck

# Tests ainda passam
pnpm test

# Lint sem erros
pnpm lint
```

## Exemplo: Bom

### Antes (Arquivo Monolitico - 480 linhas)

```typescript
// src/handlers/order.ts (480 linhas)
import { z } from 'zod';
import type { Context } from 'hono';

const OrderStatus = {
  PENDING: 'pending',
  PROCESSING: 'processing',
  SHIPPED: 'shipped',
  DELIVERED: 'delivered',
} as const;

const AddressSchema = z.object({
  street: z.string(),
  city: z.string(),
  state: z.string(),
  zip: z.string(),
});

const OrderItemSchema = z.object({
  productId: z.string(),
  quantity: z.number().positive(),
  price: z.number().positive(),
});

const CreateOrderSchema = z.object({
  customerId: z.string().uuid(),
  items: z.array(OrderItemSchema).min(1),
  shippingAddress: AddressSchema,
  billingAddress: AddressSchema,
});

interface OrderItem {
  productId: string;
  quantity: number;
  price: number;
}

interface Address {
  street: string;
  city: string;
  state: string;
  zip: string;
}

interface Order {
  id: string;
  customerId: string;
  items: OrderItem[];
  status: keyof typeof OrderStatus;
  shippingAddress: Address;
  billingAddress: Address;
  total: number;
  createdAt: Date;
}

function calculateTotal(items: OrderItem[]): number {
  return items.reduce((sum, item) => sum + item.price * item.quantity, 0);
}

function validateOrder(order: unknown): Order {
  return CreateOrderSchema.parse(order);
}

// ... 400+ linhas de handlers, repository, business logic
```

### Depois (Estrutura Modular - 4 arquivos focados)

```
src/handlers/order/
├── index.ts          # 15 linhas - barrel
├── types.ts          # 45 linhas - interfaces
├── schemas.ts        # 50 linhas - Zod schemas
├── constants.ts      # 20 linhas - constantes
├── helpers.ts        # 35 linhas - funcoes utilitarias
├── service.ts        # 80 linhas - logica de negocio
└── handlers.ts       # 60 linhas - handlers HTTP
```

```typescript
// src/handlers/order/types.ts (45 linhas)
import type { OrderStatus } from './constants.ts';

export interface Address {
  street: string;
  city: string;
  state: string;
  zip: string;
}

export interface OrderItem {
  productId: string;
  quantity: number;
  price: number;
}

export interface Order {
  id: string;
  customerId: string;
  items: OrderItem[];
  status: OrderStatus;
  shippingAddress: Address;
  billingAddress: Address;
  total: number;
  createdAt: Date;
}
```

```typescript
// src/handlers/order/helpers.ts (35 linhas)
import type { OrderItem } from './types.ts';

export function calculateTotal(items: OrderItem[]): number {
  return items.reduce((sum, item) => sum + item.price * item.quantity, 0);
}

export function formatOrderId(id: string): string {
  return `ORD-${id.slice(0, 8).toUpperCase()}`;
}

export function isShippable(status: OrderStatus): boolean {
  return status === 'processing';
}
```

## Exemplo: Ruim

**Violacoes comuns que esta skill detecta e corrige:**

1. **Arquivo com 600 linhas sem divisoes**
   ```typescript
   // NAO FAZER: Tudo em um arquivo
   // user-service.ts (600 linhas)
   // Contem: types, schemas, constants, helpers, repository, service, handlers
   ```

2. **Funcao com 120 linhas**
   ```typescript
   // NAO FAZER: Funcao gigante que faz muitas coisas
   const processOrder = (order: Order) => {
     // 120 linhas de logica misturada
   };
   ```

3. **Barrel file que re-exporta tudo indiscriminadamente**
   ```typescript
   // NAO FAZER: Re-exportar tudo sem organizacao
   export * from './types.ts';
   export * from './schemas.ts';
   export * from './constants.ts';
   export * from './helpers.ts';
   export * from './service.ts';
   export * from './handlers.ts';
   // Consumer importa coisas que nao precisa
   ```

4. **Imports circulares por má organizacao**
   ```typescript
   // NAO FAZER: Dependencies cruzadas
   // a.ts -> b.ts -> c.ts -> a.ts
   ```

## Gotchas

1. **Barrel files e Tree-shaking**: Re-exports em `index.ts` podem impedir tree-shaking em bundlers. Prefira imports diretos nos consumers quando o bundle size for critico (Cloudflare Workers tem limite de 1MB).

2. **Circular dependencies**: Ao extrair modulos, verifique imports. Se A importa B e B importa A, ha dependencia circular. Solucao: mover interfaces/tipos para arquivo separado que ambos importam.

3. **API publica**: Mantenha a superficie de exports minima. Consumers nao precisam de todos os helpers internos; exponha apenas o que e necessario.

4. **Testes entre cada extracao**: Apos extrair cada modulo, rode testes para garantir que nada quebrou. Refatoracoes atomicas sao mais faceis de debugar.

5. **Mover arquivos vs copiar**: Ao refatorar, mova o codigo (nao copie) para evitar duplicacao. Atualize imports em todos os consumers.

6. **Zod schemas com dependencies**: Se schemas dependem de types, extraia types primeiro. Ordem incorreta causa erros de compilacao em cascata.

7. **Constants em arquivos separados**: Constantes que eram definidas proximo ao uso podem precisar ir para `constants.ts`. Isso pode revelar codigo que referencia constantes de outro modulo.

## Quando NAO Usar

- **Arquivos gerados automaticamente** (node_modules, dist, scaffold) — refatorar esses e perder o gerador
- **Tests que duplicam estrutura** — absorver a duplicacao e foco em refatorar codigo de producao
- **Migrations SQL** — cada migration e independente por design
- **Arquivos com menos de 150 linhas** — overhead de modularizacao nao justifica
- **急切 entregas de hotfix** — documentar a divida tecnica e agendar refatoracao

## Checklist de Validacao

- [ ] `wc -l` do arquivo original < 250 linhas
- [ ] Maior funcao < 50 linhas
- [ ] Cada arquivo tem responsabilidade unica
- [ ] Imports atualizados em todos os consumers
- [ ] TypeScript compila sem erros
- [ ] Tests passam
- [ ] Lint passa
