---
name: ts-add-test
description: |
  Create Vitest unit/integration tests for Cloudflare Workers with Hono
  Use quando o usuário pedir: "criar teste ts", "vitest test", "novo teste typescript", "adicionar teste".
allowed-tools:
  - Read
  - Glob
  - Grep
  - Bash
---

# ts-add-test

Create Vitest unit/integration tests for Cloudflare Workers projects following AAA pattern and proper mocking.

## Trigger Phrases

"add test", "novo teste", "criar teste", "vitest test", "test coverage"

## Arguments

$ARGUMENTS should specify:
- **Target** — which file/module to test (e.g., `src/handlers/users.ts`, `src/services/auth.ts`)
- **Layer** — handler, service, utils, middleware
- **Scope** — specific function or entire module

## Pre-Flight Checks

Before writing any test code, read:

1. **Target source file** — the file being tested
2. **Schema file** — `src/db/schema.ts` for Drizzle ORM entities
3. **Env types** — `src/index.ts` or `src/env.ts` for environment bindings
4. **Existing tests** — any `*.test.ts` in the same directory for patterns
5. **vitest.config.ts** — verify test environment and globals setup

## Workflow

### Step 1: Identify Target

Parse the user request to determine:
- **File to test** — source file path
- **Function/method** — specific exported function
- **Dependencies** — D1, KV, env bindings, external APIs

### Step 2: Create Test File

Create `*.test.ts` in the same directory as the source file:

```bash
# Se testando src/handlers/users.ts
# criar src/handlers/users.test.ts
```

### Step 3: Set Up Imports and Mocks

```typescript
import { describe, it, expect, vi, beforeEach, afterEach } from 'vitest';
import { Hono } from 'hono';

// Mock Cloudflare bindings antes de importar módulos
vi.mock('cloudflare:workers', () => ({
  env: {
    DB: { prepare: vi.fn(), exec: vi.fn(), batch: vi.fn() },
    KV: { get: vi.fn(), put: vi.fn(), delete: vi.fn() },
  },
}));

// Mock do módulo que contém o código
vi.mock('../../db', () => ({
  drizzle: vi.fn(),
  schema: {},
}));
```

### Step 4: Write AAA Pattern Tests

#### Arrange — Set up mocks and inputs

```typescript
describe('UserHandler', () => {
  let app: Hono;
  
  beforeEach(() => {
    app = new Hono();
    // Reset all mocks
    vi.clearAllMocks();
  });
  
  afterEach(() => {
    vi.useRealTimers(); // Limpar timer mocks
  });
```

#### Act — Call the function being tested

```typescript
  it('should create user successfully', async () => {
    // Arrange
    const mockEnv = {
      DB: {
        prepare: vi.fn().mockReturnValue({
          bind: vi.fn().mockReturnValue({
            first: vi.fn().mockResolvedValue(null),
          }),
        }),
      },
    };
    
    // Act
    const result = await createUser(mockEnv as any, { email: 'test@example.com', name: 'Test' });
    
    // Assert
    expect(result).toBeDefined();
    expect(result.email).toBe('test@example.com');
  });
```

#### Assert — Verify outcomes

```typescript
  it('should reject invalid email', async () => {
    // Arrange
    const invalidEmail = 'not-an-email';
    
    // Act
    const result = await createUser(mockEnv as any, { email: invalidEmail });
    
    // Assert
    expect(result).toBeNull();
  });
```

## Mock Patterns

### D1 Mock

```typescript
vi.mock('cloudflare:workers', () => ({
  env: {
    DB: {
      prepare: vi.fn().mockReturnValue({
        bind: vi.fn().mockReturnValue({
          first: vi.fn().mockResolvedValue(null),
          all: vi.fn().mockResolvedValue([]),
          run: vi.fn().mockResolvedValue({ success: true }),
        }),
      }),
      exec: vi.fn().mockResolvedValue({ success: true }),
      batch: vi.fn().mockResolvedValue([]),
    },
  },
}));
```

### KV Mock

```typescript
vi.mock('cloudflare:workers', () => ({
  env: {
    KV: {
      get: vi.fn().mockResolvedValue(null),
      put: vi.fn().mockResolvedValue(undefined),
      delete: vi.fn().mockResolvedValue(undefined),
      list: vi.fn().mockResolvedValue({ keys: [], list_complete: true }),
    },
  },
}));
```

### Env Bindings Mock

```typescript
const mockEnv = {
  WEBHOOK_SECRET: 'test-secret',
  QUEUE_NAME: 'test-queue',
  DB: { /* D1 mock */ },
  KV: { /* KV mock */ },
};
```

### Timer Mock

```typescript
beforeEach(() => {
  vi.useFakeTimers();
});

afterEach(() => {
  vi.useRealTimers();
});
```

## Example: Good Test (Isolated with D1 Mock)

```typescript
// src/services/users.test.ts
import { describe, it, expect, vi, beforeEach } from 'vitest';
import { createUser, getUserById } from './users';

vi.mock('cloudflare:workers', () => ({
  env: {
    DB: { /* mock D1 */ },
  },
}));

describe('UserService', () => {
  describe('createUser', () => {
    it('should create user with valid data', async () => {
      // Arrange
      const mockDb = createMockD1();
      const input = { email: 'test@example.com', name: 'Test User' };
      
      // Act
      const result = await createUser({ DB: mockDb } as any, input);
      
      // Assert
      expect(result).toMatchObject({
        email: 'test@example.com',
        name: 'Test User',
      });
      expect(mockDb.prepare).toHaveBeenCalled();
    });
    
    it('should reject duplicate email', async () => {
      // Arrange
      const mockDb = createMockD1({ emailExists: true });
      const input = { email: 'existing@example.com', name: 'Test' };
      
      // Act
      const result = await createUser({ DB: mockDb } as any, input);
      
      // Assert
      expect(result).toBeNull();
    });
  });
});
```

## Example: Bad Test (Leaking to Production)

```typescript
// RUIM: Este teste vaza para produção real
import { it, expect } from 'vitest';

it('should create user', async () => {
  // ERRO: Acessando DB real sem mock
  const result = await fetch('https://api.production.com/users', {
    method: 'POST',
    body: JSON.stringify({ email: 'test@example.com' }),
  });
  
  expect(result.status).toBe(201);
  // PROBLEMAS:
  // 1. Requer credenciais reais
  // 2. Afeta dados de produção
  // 3. Teste lento e flaky
  // 4. Não pode rodar em CI sem secrets
});
```

## Gotchas

1. **Never import real env**: Always mock `cloudflare:workers` or `hono` bindings. Real env vars are only available at runtime.

2. **Async/await**: Every async operation must be awaited. Missing await is the #1 cause of flaky tests.

3. **Cleanup in afterEach**: Always call `vi.clearAllMocks()` and `vi.useRealTimers()` to prevent test pollution.

4. **Timer mocks**: If testing code with `setTimeout` or `Date`, use `vi.useFakeTimers()` and reset in `afterEach`.

5. **Happy-dom setup**: For Hono/React handlers, configure `testEnvironment: 'happy-dom'` in vitest.config.ts.

6. **Coverage check**: Run `npx vitest run --coverage` to verify coverage. Minimum: 80% for critical paths.

7. **D1 binding mock**: D1 `prepare().bind().first()` chain must be mocked at each step. Cannot mock just `prepare()`.

## Verification

After generating tests, run:

```bash
npx vitest run src/**/*.test.ts
```

If tests fail:
- Check mock chain (prepare → bind → first/all/run)
- Verify env bindings are properly typed
- Ensure all async calls are awaited
- Reset timers if using fake timers

## When NOT to Use

- **Integration tests with real D1**: Use separate `*.integration.test.ts` with Wrangler test mode
- **E2E tests**: Use Playwright or Puppeteer instead
- **Testing private functions**: Test through public API only
