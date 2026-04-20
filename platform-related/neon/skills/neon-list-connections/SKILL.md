---
name: neon-list-connections
description: Lista conexoes ativas e queries em execucao no Neon. Use quando mencionar "list neon connections", "active connections", "neon pg_stat_activity", "show queries", "neon connections", "listar queries", "monitorar conexoes". Tambem para "long running queries", "slow queries", "connection pool leak". Nao use para configuracao de pooler (use neon-configure-pooler).
allowed-tools:
  - Read
  - Glob
  - Grep
  - Bash
---

# Neon List Connections

Lista conexoes ativas e queries em execucao no Neon usando `pg_stat_activity`. Identifica queries lentas, conexoes idle in transaction (pool leaks), e permite cancelamento/terminacao.

## Condicoes de Execucao

**Use quando**:
- Diagnosticar lentidao em aplicacao
- Identificar conexoes suspensas/hung
- Monitorar uso do connection pooler
- Investigar queries em deadlock
- Fazer troubleshooting de timeout
- Antes de operacoes de migracao (verificar conexoes ativas)

**Nao use quando**:
- Configurar connection pooler (use `neon-configure-pooler`)
- Criar/modificar resources (use `neon-create-branch`, etc.)
- Setup de credenciais (use `neon-credentials-setup`)
- Apenas monitorar metrics (use Neon dashboard ou Prometheus exporter)

## Pre-Flight Checks

1. Verificar connection string esta configurada:
```bash
echo $DATABASE_URL | grep -q "neon.tech" && echo "DATABASE_URL OK" || echo "DATABASE_URL nao configurada"
```

2. Verificar que psql esta disponivel:
```bash
psql --version
```

3. Confirmar project/branch:
```bash
neonctl branches list --project-id $NEON_PROJECT_ID
```

## Workflow

### Passo 1: Conectar e Listar Queries Ativas

```sql
-- Query principal: todas conexoes nao-idle
SELECT 
  pid,
  usename,
  application_name,
  client_addr,
  state,
  wait_event,
  query_start,
  NOW() - query_start AS duration,
  left(query, 200) AS query_preview
FROM pg_stat_activity 
WHERE state != 'idle' 
ORDER BY duration DESC;
```

### Passo 2: Query Completa com Detalhes

```sql
-- Versao detalhada: conexoes ativas ordenadas por duracao
SELECT 
  pid,
  usename,
  application_name,
  datname,
  state,
  wait_event_type,
  wait_event,
  query_start,
  NOW() - query_start AS duration,
  left(query, 500) AS full_query,
  leader_pid,
  backend_type
FROM pg_stat_activity 
WHERE state IS NOT NULL 
ORDER BY 
  CASE WHEN state = 'active' THEN 0 ELSE 1 END,
  duration DESC;
```

### Passo 3: Filtrar por Estado

```sql
-- Somente queries ativas (executando)
SELECT pid, usename, query, query_start, NOW() - query_start AS duration
FROM pg_stat_activity 
WHERE state = 'active' 
ORDER BY duration DESC;

-- Somente conexoes idle
SELECT pid, usename, query_start, state
FROM pg_stat_activity 
WHERE state = 'idle' 
ORDER BY query_start;

-- Somente "idle in transaction" (PROBLEMATICO - leak de conexao)
SELECT pid, usename, query_start, NOW() - query_start AS idle_duration, left(query, 100) AS query
FROM pg_stat_activity 
WHERE state = 'idle in transaction' 
ORDER BY idle_duration DESC;
```

### Passo 4: Identificar Queries Lentas

```sql
-- Queries rodando ha mais de 30 segundos
SELECT 
  pid,
  usename,
  NOW() - query_start AS running_time,
  state,
  left(query, 300) AS query
FROM pg_stat_activity 
WHERE state = 'active' 
  AND query_start < NOW() - INTERVAL '30 seconds'
ORDER BY running_time DESC;

-- Queries esperando lock ha muito tempo
SELECT 
  pid,
  usename,
  NOW() - query_start AS waiting_time,
  wait_event,
  left(query, 200) AS query
FROM pg_stat_activity 
WHERE wait_event IS NOT NULL 
  AND wait_event != 'Activity'
ORDER BY waiting_time DESC;
```

### Passo 5: Cancelar ou Terminar Query

```sql
-- Cancelamento gentil (equivale a Ctrl+C)
-- A query pode continuar por alguns segundos antes de parar
SELECT pg_cancel_backend(pid);

-- Terminacao forcada (mata imediatamente)
-- Use quando pg_cancel nao funcionar
SELECT pg_terminate_backend(pid);
```

### Passo 6: Verificar Limites de Conexao

```sql
-- Configuracao atual
SHOW max_connections;

-- Uso atual
SELECT 
  COUNT(*) AS current_connections,
  (SELECT setting FROM pg_settings WHERE name = 'max_connections') AS max_connections
FROM pg_stat_activity;
```

## Exemplo Completo (Bash Script)

```bash
#!/bin/bash
# neon-connections-monitor.sh

DATABASE_URL="${DATABASE_URL:-$DIRECT_URL}"

echo "=== Neon Connections Monitor ==="
echo "Branch: $(echo $DATABASE_URL | grep -oP 'ep-[^/]+')"
echo "Timestamp: $(date)"
echo ""

echo "=== Conexoes Ativas (non-idle) ==="
psql "$DATABASE_URL" -t -c "
SELECT 
  pid,
  usename,
  state,
  EXTRACT(EPOCH FROM (NOW() - query_start))::int AS seconds,
  left(query, 100) AS query
FROM pg_stat_activity 
WHERE state != 'idle' 
ORDER BY EXTRACT(EPOCH FROM (NOW() - query_start)) DESC
LIMIT 20;
"

echo ""
echo "=== Idle In Transaction (PROBLEMA) ==="
psql "$DATABASE_URL" -t -c "
SELECT 
  pid,
  usename,
  EXTRACT(EPOCH FROM (NOW() - query_start))::int AS idle_seconds,
  left(query, 100) AS query
FROM pg_stat_activity 
WHERE state = 'idle in transaction'
ORDER BY EXTRACT(EPOCH FROM (NOW() - query_start)) DESC;
"

echo ""
echo "=== Queries Lentas (>60s) ==="
psql "$DATABASE_URL" -t -c "
SELECT 
  pid,
  state,
  EXTRACT(EPOCH FROM (NOW() - query_start))::int AS running_seconds,
  left(query, 150) AS query
FROM pg_stat_activity 
WHERE state = 'active' 
  AND query_start < NOW() - INTERVAL '60 seconds'
ORDER BY EXTRACT(EPOCH FROM (NOW() - query_start)) DESC;
"

echo ""
echo "=== Uso de Conexoes ==="
psql "$DATABASE_URL" -t -c "
SELECT 
  COUNT(*) AS used,
  (SELECT setting FROM pg_settings WHERE name = 'max_connections')::int AS max,
  COUNT(*)::float / (SELECT setting FROM pg_settings WHERE name = 'max_connections')::int * 100 AS pct
FROM pg_stat_activity;
"
```

## Exemplo Ruim

```sql
-- RUIM: Kill sem identificar problema
SELECT pg_terminate_backend(1234);
-- Sem saber o que query fazia, pode causar inconsistencia

-- RUIM: Nao filtrar por database
SELECT * FROM pg_stat_activity;
-- Mostra conexoes de TODAS databases, confuso

-- RUIM: Ignorar idle in transaction
-- idle in transaction = conexao retida sem trabalho
-- Se muitos, connection pool vai encher

-- RUIM: Nao monitorar antes de migracao
-- Migrations falham se conexoes ativas existirem
-- Sempre fazer: listar -> kill problematicas -> migrar

-- RUIM: Queries muito longas no output
-- query text pode ter megabytes
-- Use LEFT(query, N) para truncagem
```

## Gotchas (5-7 itens)

1. **pg_stat_activity requer role com permissao**: Usuarios normais veem apenas suas propias conexoes. Ver com `SELECT has_table_privilege('pg_stat_activity', 'SELECT');`.

2. **pg_cancel e gentil, pg_terminate e forcado**: pg_cancel envia SIGINT (等同 Ctrl+C), query pode continuar. pg_terminate envia SIGTERM, mata imediatamente. Use pg_cancel primeiro.

3. **Idle in transaction = leak de conexao**: Conexao retida sem fazer nada. Causa esgotamento do connection pooler. Achar e matar imediatamente.

4. **max_connections no Neon e 901 (unpooled) ou 10000 (pooled)**: Valor depende se usa pooler ou nao. Nao tentar aumentar.

5. **wait_event mostra em que a query espera**: `Lock` = esperando lock, `IO` = esperando I/O, `BufferPin` = esperando buffer. Útil para diagnostico.

6. **Query Start e resettado**: Para queries em transaction, query_start mostra quando transaction começou, nao query atual.

7. **Connection strings diferentes mostram conexoes diferentes**: Branch diferente = conexoes diferentes. Monitore a branch correta.

## Queries de Troubleshooting

```sql
-- Verificar locks (deadlock detection)
SELECT 
  l.locktype,
  l.relation::regclass,
  l.mode,
  l.pid,
  l.granted,
  a.query
FROM pg_locks l
JOIN pg_stat_activity a ON l.pid = a.pid
WHERE NOT l.granted;

-- Verificar queries por application_name
SELECT application_name, COUNT(*) 
FROM pg_stat_activity 
GROUP BY application_name;

-- Verificar queries por usuario
SELECT usename, COUNT(*) 
FROM pg_stat_activity 
WHERE state != 'idle'
GROUP BY usename;

-- Verificar uso de memoria por query (approximado)
SELECT 
  pid,
  query,
  (total_exec_time / 1000)::int AS total_ms,
  calls,
  mean_exec_time::int AS mean_ms
FROM pg_stat_statements
ORDER BY total_exec_time DESC
LIMIT 10;
```

## Quando Nao Usar

- **Configurar pooler**: Use `neon-configure-pooler` para entender pooled vs unpooled
- **Criar/modificar resources**: Use skills de create/branch/delete
- **Setup inicial**: Use `neon-credentials-setup` para configurar .env
- **Monitoramento continuo**: Use Neon dashboard ou configure Prometheus exporter
