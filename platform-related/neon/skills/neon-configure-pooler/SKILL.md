---
name: neon-configure-pooler
description: Configura connection pooler (pgbouncer em transaction mode) para serverless. Use quando mencionar "neon pooler", "configure pooler", "pgbouncer neon", "serverless pooler", "pooled connection", "transaction mode pooler". Tambem para "neon connection limit", "max connections", "pooler configuration". Nao use para setup inicial de credenciais (use neon-credentials-setup).
allowed-tools:
  - Read
  - Glob
  - Grep
  - Bash
---

# Neon Configure Pooler

Configura o connection pooler integrado do Neon (pgbouncer em transaction mode) para workloads serverless. Ensina quando usar pooled vs unpooled, como configurar no ORM, e armadilhas de transaction mode.

## Condicoes de Execucao

**Use quando**:
- Configurar aplicacao serverless (Workers, Lambda, Cloud Functions)
- Resolver erro "too many connections"
- Configurar Drizzle/Prisma/TypeORM para Neon
- Entender diferenca entre pooled e unpooled
- Migrar de database tradicional para Neon serverless

**Nao use quando**:
- Apenas setup inicial de credenciais (use `neon-credentials-setup`)
- Criar branches ou projects (use `neon-create-branch`, `neon-create-project`)
- Diagnosticar queries lentas (use `neon-list-connections`)
- Merge de branches (use `neon-merge-branch`)

## Conceitos Fundamentais

### Pooled vs Unpooled

| Aspecto | Pooled | Unpooled (Direct) |
|---------|--------|------------------|
| Host | `ep-xxx-pooler.region.neon.tech` | `ep-xxx.region.neon.tech` |
| Mode | Transaction (pgbouncer) | Session (Postgres nativo) |
| Max Connections | 10000 | 901 |
| Prepared Statements | Dinamicos apenas | Todos |
| LISTEN/NOTIFY | NAO suporta | Suporta |
| SET LOCAL | Nao persiste | Persiste |
| Advisory Locks | Limitados | Completos |

### Quando Usar Cada Um

**Pooled (transaction mode)**:
- Serverless functions (Workers, Lambda)
- Aplicacoes com muitas instancias paralelas
- Queries curtas e frequentes
- Maioria dos casos serverless

**Unpooled (session mode)**:
- Migrations (DDL precisa de session)
- Long transactions
- LISTEN/NOTIFY
- Prepared statements nomeados
- Advisory locks
- Importacao de dados em bulk

## Workflow

### Passo 1: Identificar Connection Strings

```bash
# Pooled (para aplicacao serverless)
neonctl connection-string $NEON_PROJECT_ID \
  --branch-name main \
  --pooler true
# Resultado: postgres://user:pass@ep-xxx-pooler.region.neon.tech/db?sslmode=require

# Unpooled (para migrations/manutencao)
neonctl connection-string $NEON_PROJECT_ID \
  --branch-name main \
  --pooler false
# Resultado: postgres://user:pass@ep-xxx.region.neon.tech/db?sslmode=require
```

### Passo 2: Configurar Variaveis de Ambiente

```bash
# .env

# Para serverless (Workers, Lambda) - pooled
DATABASE_URL=postgres://user:pass@ep-xxx-pooler.region.neon.tech/dbname?sslmode=require

# Para migrations e tools - unpooled
DIRECT_URL=postgres://user:pass@ep-xxx.region.neon.tech/dbname?sslmode=require
```

### Passo 3: Configurar Drizzle ORM

```typescript
// drizzle.config.ts
import { defineConfig } from 'drizzle-kit';

export default defineConfig({
  schema: './src/db/schema.ts',
  out: './drizzle',
  
  // Para migrations: usar DIRECT_URL
  // Para queries da aplicacao: DATABASE_URL
  dbCredentials: {
    url: process.env.DATABASE_URL!,
  },
});

// No codigo da aplicacao:
import { drizzle } from 'drizzle-orm/neon-http';

const db = drizzle({
  connection: process.env.DATABASE_URL!, // pooled
});

// Para migrations (script separado):
import { drizzle } from 'drizzle-orm/neon-http';
const dbMigration = drizzle({
  connection: process.env.DIRECT_URL!, // unpooled
});
```

### Passo 4: Configurar Prisma

```prisma
// schema.prisma

datasource db {
  provider  = "postgresql"
  url       = env("DATABASE_URL")      // pooled
  directUrl = env("DIRECT_URL")        // unpooled (para migrations)
}

generator client {
  provider        = "prisma-client-js"
  previewFeatures = ["driverAdapters"] // necessario para pooled
}
```

### Passo 5: Configurar Go (database/sql)

```go
// db.go
package db

import (
    "database/sql"
    _ "github.com/lib/pq"
)

var (
    // Pooled - para aplicacao
    DB *sql.DB
    
    // Unpooled - para migrations
    DirectDB *sql.DB
)

func InitPooled(dsn string) error {
    DB = sql.Open("postgres", dsn)
    DB.SetMaxOpenConns(10)  // serverless = poucas conexoes
    DB.SetMaxIdleConns(5)
    DB.SetConnMaxLifetime(5 * time.Minute)
    return nil
}

func InitDirect(dsn string) error {
    DirectDB = sql.Open("postgres", dsn)
    DirectDB.SetMaxOpenConns(1)  // migrations = 1 conexao
    DirectDB.SetConnMaxLifetime(1 * time.Hour)
    return nil
}
```

## Exemplo Completo (.env)

```bash
# ===========================================
# Neon Configuration - Exemplo Completo
# ===========================================

# Projeto
NEON_PROJECT_ID=soft-hour-12345678

# API Key (NUNCA commitar)
NEON_API_KEY=ntoy_xxxxxxxxxxxxxxxxxxxxx

# Connection Strings
# Pooled: para serverless functions, Workers, Lambda
DATABASE_URL=postgres://alex:password@ep-xxx-pooler.aws-neon.tech/main?sslmode=require

# Unpooled: para migrations, backups, long transactions
DIRECT_URL=postgres://alex:password@ep-xxx.aws-neon.tech/main?sslmode=require

# Branch especifica (para dev/staging)
DEV_DATABASE_URL=postgres://alex:password@ep-xxx-pooler.aws-neon.tech/dev?sslmode=require
STAGING_DATABASE_URL=postgres://alex:password@ep-xxx-pooler.aws-neon.tech/staging?sslmode=require
```

## Exemplo Ruim

```typescript
// RUIM: Usar pooled para migrations
const migration = drizzle({
  connection: process.env.DATABASE_URL, // pooled = pgbouncer transaction mode
});
// ERROR: cannot run migration in transaction mode
// DDL requires session mode

// RUIM: Usar pooled para LISTEN/NOTIFY
const subscription = await db.subscribe('notifications');
// pooler does NOT support LISTEN/NOTIFY

// RUIM: Max connections muito alto
db.connect({ maxConnections: 1000 }); // too many!
pgnode has limit of 10000 pooled / 901 unpooled

// RUIM: SET LOCAL em pooled connection
await db.execute(sql`SET LOCAL work_mem = '256MB'`);
// SET LOCAL persists only for the transaction
// BUT: pooler may route to different backend

// RUIM: Prepared statements nomeados em pooled
const stmt = await db.prepare('SELECT * FROM users WHERE id = $1');
// Named prepared statements not supported in transaction mode

// RUIM: Ignorar que pooler e transaction mode
// Every query is a separate transaction (autocommit off)
// BEGIN...COMMIT wrapping must be explicit if needed
```

## Gotchas (5-7 itens)

1. **Pooler NAO suporta LISTEN/NOTIFY**: Se aplicacao usa pub/sub, usar unpooled ou alternative (ex: webhook ao invés de notify).

2. **Advisory locks tem comportamento diferente**: Transaction mode pooler pode nao manter advisory locks corretamente. Testar ou usar unpooled.

3. **SET LOCAL nao persiste corretamente**: Variaveis SET em uma transacao podem nao ser vistas por outra transacao no mesmo pool. Prefira SET sem LOCAL.

4. **Prepared statements: dinamicos vs nomeados**: pooler suporta apenas `PREPARE` sem nome e `EXECUTE`. Named prepared statements (`PREPARE foo AS SELECT...`) podem falhar.

5. **Max connections: 10000 pooled / 901 unpooled**: Nao tenta ultrapassar. Se aplicar muitos workers, pooling externo (PgBouncerstandalone) pode ser necessario.

6. **Connection string muda com pooler**: Host muda de `ep-xxx.region.neon.tech` para `ep-xxx-pooler.region.neon.tech`. NUNCA hardcode, sempre use `neonctl connection-string`.

7. **statement_timeout pode nao funcionar**: Rate limit do pooler pode conflitar. Teste antes de usar em production.

## Configuracao por Tecnologia

### Node.js (node-postgres)

```javascript
// pooled
const pool = new Pool({
  connectionString: process.env.DATABASE_URL,
  max: 10,  // serverless = poucas conexoes
});

// unpooled (migrations)
import { Client } from 'pg';
const client = new Client({ connectionString: process.env.DIRECT_URL });
await client.connect();
```

### Python (asyncpg)

```python
# pooled
import asyncpg
pool = await asyncpg.create_pool(
    process.env.DATABASE_URL,
    min_size=2,
    max_size=10
)

# unpooled
import asyncpg
conn = await asyncpg.connect(process.env.DIRECT_URL)
```

### Bun

```typescript
// pooled
const db = Bun.sql`postgres:${process.env.DATABASE_URL}`;

// unpooled
// Bun nao suporta unpooled direto
// Use node-postgres para migrations
```

## Quando Nao Usar

- **Setup de credenciais**: Apos configurar pooler, use `neon-credentials-setup` para documentar .env
- **Criar project/branch**: Pooler e configurado automaticamente no project
- **Debug de conexao**: Use `neon-list-connections` para ver conexoes ativas
- **Migrations**: Ja coberto por DIRECT_URL (unpooled)
