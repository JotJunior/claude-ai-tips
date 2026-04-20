---
name: ts-review-security
description: Audit de seguranca para stacks TypeScript (Cloudflare Workers + Hono + Drizzle + Zod). Use quando mencionar "security review", "audit security", "review security", "pentest review" ou "vuln scan". Abre verificacoes de SQL injection, XSS, CSRF, secrets em log, PII em log, JWT validation, rate limiting e CORS.
allowed-tools:
  - Read
  - Glob
  - Grep
  - Bash
---

# TypeScript Security Review

Realiza audit de seguranca em stacks TypeScript, focado em Cloudflare Workers + Hono + Drizzle + Zod. Identifica vulnerabilidades comuns (OWASP Top 10) e garante conformidade com LGPD/GDPR em logs.

## Quando Usar

- Code review com foco em seguranca
- Antes de deploy em producao
- Apos mudancas em autenticacao/autorizacao
- Trigger phrases: "security review", "audit security", "review security", "pentest review", "vuln scan"

## Pre-Flight

Mapear a estrutura do projeto e identificar pontos criticos de seguranca:

```
src/
├── routes/              # Endpoints expostos
├── handlers/            # Logica de handlers
├── middleware/          # Auth, CORS, rate limit
├── services/            # Logica de negocio
├── repository/          # Acesso ao banco (Drizzle)
├── schemas/             # Zod schemas de validacao
└── utils/               # Helpers (atencao: logs aqui)
```

Arquivos criticos a verificar primeiro:

1. `src/middleware/auth.ts` — validacao JWT, sessoes
2. `src/middleware/cors.ts` — configuracao CORS
3. `src/middleware/rate-limit.ts` — limitacao de requests
4. `src/handlers/**/*.ts` — todos os handlers
5. `src/repository/**/*.ts` — queries SQL
6. `src/utils/logger.ts` — formatacao de logs
7. `.env.example` ou `wrangler.toml` — configuracao de secrets

## Workflow

### Passo 1: SQL Injection (Drizzle)

Verificar se todas as queries usam prepared statements ou query builder do Drizzle:

```bash
# Buscar padroes perigosos
grep -rn "sql\`" src/repository/
grep -rn "db.execute" src/repository/
grep -rn "db.query" src/repository/
```

**Verificar**:
- [ ] Queries sao construidas com query builder (nao concatenacao de strings)
- [ ] Inputs de usuario passam por validacao Zod antes de chegar ao repository
- [ ] Nao ha `db.execute(sql\`...${userInput}...\``)` direto

**Padrao SEGURO (Drizzle)**:
```typescript
// CORRETO: Query builder com prepared statement
const result = await db
  .select()
  .from(users)
  .where(eq(users.email, input.email))
  .prepare('get-user-by-email');
```

**Padrao INSECURO**:
```typescript
// INCORRETO: Concatenacao direta - SQL Injection
const result = await db.execute(
  sql`SELECT * FROM users WHERE email = ${userInput}`
);
```

### Passo 2: XSS (React/Hono)

Verificar saidas HTML e innerHTML:

```bash
# Buscar padroes perigosos
grep -rn "dangerouslySetInnerHTML" src/
grep -rn "innerHTML" src/
grep -rn ".html(" src/
grep -rn "z.string().includes" src/schemas/
```

**Verificar**:
- [ ] Nao ha `dangerouslySetInnerHTML` sem sanitizacao
- [ ] Inputs sao validados com Zod antes de qualquer operacao
- [ ] Responses JSON nao contem HTML sem escape

**Padrao SEGURO**:
```typescript
// CORRETO: Resposta JSON com dados validados
return c.json({
  success: true,
  data: schema.parse(userInput)
});
```

### Passo 3: CSRF e SameSite Cookies

```bash
# Buscar configuracao de cookies
grep -rn "set-cookie" src/middleware/
grep -rn "cookie(" src/
```

**Verificar**:
- [ ] Cookies de sessao tem `SameSite=Strict` ou `SameSite=Lax`
- [ ] Cookies敏感性 tem `Secure` e `HttpOnly`
- [ ] Nao ha `SameSite=None` sem `Secure`

**Padrao SEGURO**:
```typescript
// CORRETO: Cookie com atributos de seguranca
c.header('Set-Cookie', 
  `session=${token}; HttpOnly; Secure; SameSite=Strict; Path=/`
);
```

### Passo 4: Secrets e PII em Logs (LGPD/GDPR)

**CRITICO**: Logs nunca devem conter dados pessoais ou segredos.

```bash
# Buscar logging de dados sensiveis
grep -rn "console.log" src/
grep -rn "logger\." src/
grep -rn "ctx.var" src/handlers/
```

**Verificar**:
- [ ] Logs NAO contem: CPF, email, telefone, senha, token, cartao de credito
- [ ] Dados pessoais sao truncados: `email: "jo***@domain.com"`
- [ ] Segredos sao mascarados: `token: "eyJ***"`
- [ ] UUIDs de sessoes sao usados (nao CPFs como session ID)

**Campo** | **Log acceptable** | **Log PROIBIDO**
----------|-------------------|-----------------
email | `jo***@domain.com` | `joao.silva@company.com`
CPF | `***.***.***-0001` | `123.456.789-00`
token | `eyJ***` | `eyJhbGciOiJIUzI1NiIs...`
senha | **nunca** | qualquer parte

**Padrao SEGURO**:
```typescript
// CORRETO: Logger com sanitizacao de PII
logger.info({
  event: 'user_login',
  userId: user.id,
  email: maskEmail(user.email),  // "jo***@domain.com"
  ip: maskIp(request.headers.get('CF-Connecting-IP')),
});

function maskEmail(email: string): string {
  const [local, domain] = email.split('@');
  return `${local.slice(0, 2)}***@${domain}`;
}
```

**Padrao INSECURO**:
```typescript
// INCORRETO: Log com dados pessoais expostos
logger.info({
  event: 'user_login',
  user: {
    id: user.id,
    email: user.email,        // "joao.silva@company.com" - VIOLA LGPD
    cpf: user.cpf,            // "123.456.789-00" - VIOLA LGPD
  }
});
```

### Passo 5: JWT Validation

```bash
# Buscar validacao JWT
grep -rn "jwt" src/middleware/
grep -rn "verify" src/middleware/auth.ts
```

**Verificar**:
- [ ] JWT e verificado com secret/public key
- [ ] Expiracao (`exp`) e verificada
- [ ] Emissor (`iss`) e verificado se aplicavel
- [ ] Audiencia (`aud`) e verificada se aplicavel
- [ ] Algoritmo e restrito (nao `none`)

**Padrao SEGURO**:
```typescript
// CORRETO: Verificacao completa de JWT
import { jwtVerify } from 'hono/jwt';

const payload = await jwtVerify(token, c.env.JWT_SECRET, {
  issuer: 'api.acme.com',
  audience: 'acme-app',
});

if (payload.payload.exp < Math.floor(Date.now() / 1000)) {
  return c.json({ error: { code: 'TOKEN_EXPIRED', message: 'Token expirado' } }, 401);
}
```

**Padrao INSECURO**:
```typescript
// INCORRETO: JWT sem verificacao de expiracao
const payload = jwt.decode(token);
if (payload) {
  // Nao verifica exp, iss, aud - vulneravel
}
```

### Passo 6: Rate Limiting

```bash
# Buscar implementacao de rate limit
grep -rn "rate" src/middleware/
grep -rn "limit" src/middleware/
```

**Verificar**:
- [ ] Rate limiting existe em endpoints publicos
- [ ] Rate limiting usa identifiers confiaveis (IP + header X-Forwarded-For)
- [ ] Respeita headers `Retry-After` e `X-RateLimit-*`
- [ ] Limites diferentes para autenticados vs anonimos

**Padrao SEGURO**:
```typescript
// CORRETO: Rate limiting por IP com duracao
import { Ratelimit } from '@upstash/ratelimit';
import { Redis } from '@upstash/redis/cloudflare';

const ratelimit = new Ratelimit({
  redis: Redis.fromEnv(),
  limiter: 'sliding_window',
  analytics: true,
  prefix: 'rl:api',
  max: 100,
  duration: '60s',
});

export async function rateLimitMiddleware(c: Context) {
  const ip = c.req.header('CF-Connecting-IP') ?? 'unknown';
  const { success, remaining, reset } = await ratelimit.limit(ip);
  
  if (!success) {
    return c.json({
      error: { code: 'RATE_LIMITED', message: 'Muitas requisicoes' }
    }, 429, {
      'Retry-After': reset.toString(),
      'X-RateLimit-Remaining': remaining.toString(),
    });
  }
}
```

### Passo 7: CORS Configuration

```bash
# Buscar configuracao CORS
grep -rn "cors" src/middleware/
grep -rn "Access-Control" src/
```

**Verificar**:
- [ ] CORS nao usa `*` em producao (ApenasDEV)
- [ ] Origins permitidos vem de env var (nao hardcoded)
- [ ] Metodos permitidos sao restritos ao minimo necessario
- [ ] Headers permitidos sao restritos

**Padrao SEGURO**:
```typescript
// CORRETO: CORS restritivo com env
const corsOrigins = c.env.ALLOWED_ORIGINS?.split(',') ?? [];
const requestOrigin = c.req.header('Origin');

if (corsOrigins.includes(requestOrigin)) {
  c.header('Access-Control-Allow-Origin', requestOrigin);
}
c.header('Access-Control-Allow-Methods', 'GET, POST, OPTIONS');
c.header('Access-Control-Allow-Headers', 'Content-Type, Authorization');
c.header('Access-Control-Allow-Credentials', 'true');
```

**Padrao INSECURO**:
```typescript
// INCORRETO: CORS permitir tudo - APENAS DEV
app.use('*', cors({
  origin: '*',  // PROIBIDO em producao
}));
```

## Exemplo: Bom

### Handler Seguro

```typescript
// src/handlers/user.ts
import { z } from 'zod';
import type { Context } from 'hono';
import { db } from '../db';
import { users } from '../db/schema';
import { eq } from 'drizzle-orm';
import { logger } from '../utils/logger';

const UserQuerySchema = z.object({
  email: z.string().email().optional(),
});

export async function getUserHandler(c: Context) {
  // 1. Validar input
  const query = UserQuerySchema.parse(c.req.query());
  
  // 2. Rate limit (preparado pelo middleware, aqui apenas verificamos)
  const rateLimitData = c.get('rateLimit');
  if (!rateLimitData?.success) {
    return c.json({ 
      error: { code: 'RATE_LIMITED', message: 'Muitas requisicoes' } 
    }, 429);
  }
  
  // 3. Query com prepared statement
  const result = await db
    .select()
    .from(users)
    .where(query.email ? eq(users.email, query.email) : undefined)
    .prepare('get-users');
  
  // 4. Log seguro (sem PII)
  logger.info({
    event: 'user_query',
    filter: query.email ? 'by_email' : 'all',
    resultCount: result.length,
  });
  
  return c.json({ data: result });
}
```

### Middleware Auth Seguro

```typescript
// src/middleware/auth.ts
import { jwtVerify } from 'hono/jwt';
import type { Context } from 'hono';

export async function authMiddleware(c: Context, next: Next) {
  const token = c.req.header('Authorization')?.replace('Bearer ', '');
  
  if (!token) {
    return c.json({ 
      error: { code: 'UNAUTHORIZED', message: 'Token requerido' } 
    }, 401);
  }
  
  try {
    const payload = await jwtVerify(token, c.env.JWT_SECRET, {
      issuer: 'api.acme.com',
      audience: 'acme-app',
    });
    
    // Verificar expiracao manualmente (por seguranca extra)
    const now = Math.floor(Date.now() / 1000);
    if (payload.payload.exp && payload.payload.exp < now) {
      throw new Error('Token expirado');
    }
    
    c.set('user', payload.payload);
    await next();
  } catch (err) {
    logger.warn({ event: 'auth_failed', reason: 'invalid_token' });
    return c.json({ 
      error: { code: 'UNAUTHORIZED', message: 'Token invalido' } 
    }, 401);
  }
}
```

## Exemplo: Ruim

### Handler Vulneravel

```typescript
// src/handlers/user.ts (ANTIPATTERN - NAO FAZER)
import { db } from '../db';
import { sql } from 'drizzle-orm';

export async function getUserHandler(c: Context) {
  const email = c.req.query('email');
  
  // SQL Injection vulneravel
  const result = await db.execute(
    sql`SELECT * FROM users WHERE email = ${email}`
  );
  
  // Log com PII - VIOLA LGPD
  logger.info({
    event: 'user_query',
    email: email,  // "joao.silva@company.com"
  });
  
  // Nao valida input
  // Nao tem rate limit
  // Nao verifica autenticacao
  
  return c.json(result);
}
```

### Middleware Auth Vulneravel

```typescript
// src/middleware/auth.ts (ANTIPATTERN - NAO FAZER)
import { jwt } from '@hono/jwt';

export async function authMiddleware(c: Context, next: Next) {
  const token = c.req.header('Authorization')?.replace('Bearer ', '');
  
  // Nao verifica expiracao
  // Nao verifica issuer/audience
  // Usa secret sem validacao de algoritmo
  const payload = jwt.decode(token);
  
  if (payload) {
    c.set('user', payload);
    await next();
  }
}
```

## Gotchas

1. **PII em logs estruturados**: Nao importa se o log esta em JSON ou texto. CPF, email, telefone, senha, tokens e cartoes de credito NAO podem aparecer de forma legivel em nenhum log. Use hash ou truncate.

2. **JWT `exp` verification**: Bibliotecas como `jose` ou `hono/jwt` NAO verificam `exp` automaticamente em todos os casos. Verifique a documentacao e faca verificacao manual se necessario.

3. **CORS `*` em producao**: wildcard CORS e aceitavel apenas em DEV. Producao DEVE ter origins explicitos de env vars.

4. **CSP Header**: Para aplicacoes que renderizam HTML, considere adicionar Content-Security-Policy header para mitigar XSS.

5. **Subresource Integrity**: Se usar scripts de CDN, adicione `integrity` attribute com hash SHA. CDN pode ser comprometido.

6. **Secrets via env, nao variaveis**: Credenciais DEVEM vir de `c.env` (Cloudflare Workers) ou `process.env` com validacao Zod. Nunca hardcode ou commit secrets.

7. **Rate limit em todas as rotas**: Ataques de forca bruta e DDoS funcionam em qualquer endpoint. Rate limit deve cobrir toda a API, nao apenas autenticacao.

## Quando NAO Usar

- **Codigo gerado** (scaffold, migrations) — sao transientes
- **Testes de unidade** — validacao de output, nao seguranca
- **Docs/Markdown** — coverage diferente
- **Quick hotfix de producao** — documentar vulnerabilidades e corrigir depois
