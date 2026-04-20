---
name: cf-workers-deploy-check
description: |
  Pre-deploy validation: bindings, secrets, migrations, observability, rollback plan. Use quando: "cf deploy check", "wrangler deploy validation", "pre-deploy worker", "validar deploy cloudflare", "deploy worker production", "revisar antes de fazer deploy". Tambem quando: validar ambiente antes de migration, verificar secrets faltando, garantir observability configurado. NAO use quando: rollback de emergencia (use plano de rollback jah definido), deploy de infraestrutura (use cf-api-call).
allowed-tools:
  - Read
  - Bash
  - Glob
  - Grep
---

# Cloudflare Workers — Deploy Check

Executa validacao completa antes de deploy em producao. Verifica bindings,
secrets, migrations aplicadas, observability configurado, e review do
rollback plan. Evitar surpresas em production.

## Trigger Phrases

- "cf deploy check"
- "wrangler deploy validation"
- "pre-deploy worker"
- "validar deploy cloudflare"
- "deploy worker production"
- "revisar antes de fazer deploy"
- "verificar antes de deploy"

## Pre-Flight Checks

Antes de iniciar, leia:

1. **wrangler.toml completo** — entender estrutura e ambientes
   ```bash
   cat wrangler.toml
   ```
2. **Logs recentes** — verificar se deploy anterior teve problemas
   ```bash
   wrangler tail --recent-logs 2>/dev/null | head -30 || echo "Nenhum log recente"
   ```

## Workflow

### Passo 1 — Listar bindings necessarios

```bash
# Extrair todos os bindings do wrangler.toml
grep -E "binding|kv_namespaces|d1_databases|r2_buckets|queues|ai" wrangler.toml
```

Bindings esperados:
- `kv_namespaces` — KV para cache/idempotency
- `d1_databases` — D1 para persistencia
- `r2_buckets` — R2 para arquivos
- `queues` — Queue producers/consumers
- `ai` — Workers AI

### Passo 2 — Verificar secrets configurados

```bash
# Listar todos os secrets ja configurados
wrangler secret list

# Para cada binding que exige secret (não mostrado no list),
# verificar se foi configurado
wrangler secret list 2>/dev/null | grep -E "STRIPE|OPENAI|SECRET|TOKEN|KEY"
```

**REGRA CRITICA**: Secrets nunca devem estar em `[vars]`. Verificar:
```bash
# Procurar secrets hardcoded no wrangler.toml (EVITAR)
grep -E "secret.*=.*['\"]" wrangler.toml || echo "OK: sem secrets hardcoded"
```

### Passo 3 — Verificar codigo por env vars faltantes

```bash
# Procurar process.env usage (Node.js pattern — verificar se nao eh usado)
grep -rn "process\.env" --include="*.ts" src/ || echo "OK: sem process.env"

# Verificar se todas as env vars usadas tem binding no wrangler.toml
grep -rn "env\." --include="*.ts" src/ | grep -v "env.DB\|env.KV\|env.QUEUE\|env.R2\|env.AI" | head -20
```

### Passo 4 — Verificar D1 migrations aplicadas

```bash
# Listar migrations pendentes
wrangler d1 migrations list <database-name> --remote 2>/dev/null || echo "Nenhuma migration pendente"

# Verificar se migrations aplicadas correspondem ao codigo
# (migrations que faltam vao causar erros em producao)
```

### Passo 5 — Verificar observability configurado

```bash
# Check observability section
grep -A5 "\[observability\]" wrangler.toml

# Verificar tail_consumers configurados (para logs)
grep -A3 "tail_consumers" wrangler.toml || echo "AVISO: tail_consumers nao configurado"
```

Configuracao correta:
```toml
[observability]
enabled = true
```

Opcional — custom tail consumer para alertas:
```toml
tail_consumers = [{ formula = "statusCode >= 500" }]
```

### Passo 6 — Dry-run do deploy

```bash
# Simular deploy sem realmente fazer
wrangler deploy --dry-run --message "Validation run"
```

Isso detecta:
- Erros de sintaxe no wrangler.toml
- bindings faltando
- Problemas de permissions

### Passo 7 — Review wrangler.toml [env.production]

Verificar overrides de ambiente de producao:

```toml
[env.production]
name = "my-worker-prod"
routes = [
    { pattern = "api.example.com", zone_id = "abc123" }
]
```

Verificar:
- `zone_id` obrigatorio quando usando custom domain
- `routes` vs `custom_domain` — so um ou outro, nao ambos
- Workers pagos tem limites de CPU diferentes

## Checklist de Validacao

```markdown
## Pre-Deploy Checklist

### Bindings
- [ ] Todos os bindings declarados no wrangler.toml
- [ ] Todos os bindings referenciados no codigo existem em wrangler.toml
- [ ] KV namespaces com IDs corretos
- [ ] D1 databases com database_ids corretos

### Secrets
- [ ] Todos os secrets via `wrangler secret put`
- [ ] Nenhum secret em [vars]
- [ ] Secrets listados correspondem aos bindings

### Migrations
- [ ] D1 migrations aplicadas localmente testadas
- [ ] D1 migrations aplicadas em remote (producao)
- [ ] Nenhuma migration pendente

### Observability
- [ ] [observability] enabled = true
- [ ] tail_consumers configurados (se necessario)
- [ ] wrangler tail consegue acessar logs

### Rotas
- [ ] zone_id presente para custom domains
- [ ] rota correta (routes vs custom_domain)
- [ ] CNAME DNS apontando para workers

### Limites
- [ ] CPU limit: 50ms (plano gratuito) ou 5min (plano paid)
- [ ] Memoria: 128MB (free) ou 512MB-1.5GB (paid)
- [ ] Duration: 30s (free) ou unlimited (paid)
```

## Exemplo: Wrangler.toml Validado

```toml
name = "production-worker"
main = "src/index.ts"
compatibility_date = "2024-03-01"

# Observability — OBRIGATORIO
[observability]
enabled = true
tail_consumers = [{ formula = "statusCode >= 500" }]

# Override producao
[env.production]
name = "production-worker"
routes = [
    { pattern = "api.example.com", zone_id = "abc123def456" }
]

# Bindings
[[kv_namespaces]]
binding = "CACHE_KV"
id = "abc123..."

[[kv_namespaces]]
binding = "WEBHOOK_KV"
id = "def456..."

[[d1_databases]]
binding = "DB"
database_name = "minha-db"
database_id = "ghi789..."

[[queues.producers]]
queue = "events"
binding = "EVENT_QUEUE"

# Variaveis publicas (NAO SECRETAS)
[vars]
ENVIRONMENT = "production"
API_VERSION = "2024-01"
```

## Exemplo Ruim (EVITAR)

```toml
# EVITAR: secret em [vars]
[vars]
STRIPE_SECRET = "sk_live_xxxx"  # ERRADO — exposto no codigo

# EVITAR: binding sem ID
[[kv_namespaces]]
binding = "CACHE_KV"
# FALTA: id = "..."

# EVITAR: observability desativado em prod
[observability]
enabled = false  # SEM LOGS

# EVITAR: routes sem zone_id
routes = [
    { pattern = "api.example.com" }
    # FALTA: zone_id = "..."
]
```

## Gotchas

1. **Secrets nunca em [vars]**: Sempre usar `wrangler secret put` para
   configurar secrets. Variaveis em [vars] sao publicas e visiveis no
   dashboard da Cloudflare.

2. **Routes vs custom_domain**: Sao mutualmente exclusivos. Routes
   requerem `zone_id` (existe para domaines ja configurados no CF).
   Custom domains sao automativos (requer DNS delegacao).

3. **zone_id obrigatorio**: Para routes com padrao de dominio customizado,
   o `zone_id` deve estar presente. Encontrar via:
   ```bash
   wrangler zones list | grep example.com
   ```

4. **Observability tail logs ativos**: Sem `[observability] enabled = true`,
   voce nao tem acesso aos logs do Workers. Sem `tail_consumers`, alertas
   em caso de erros 5xx nao funcionam.

5. **tail_consumers configurados**: Permite derivar metricas, alertas e
   logs customizados. Configurar formula para filtrar erros (5xx).

6. **CPU limit 50ms gratis, 5min paid**: Plano gratuito limita CPU em
   50ms por request. Deploys de producao devem usar plano Workers Paid
   para evitar timeouts em operacoes pesadas.

7. **Rollback plan**: Sempre ter plano documentado antes de deploy:
   - Tag git para rollback: `git tag v1.2.3-deploy`
   - Comando rollback: `wrangler deploy --env production --old-deploy-id <id>`
   - Migration rollback (se aplicavel): `wrangler d1 migrations apply <db> --remote`

## Quando NAO usar

- **Rollback de emergencia** → ter rollback plan ja documentado e testado
- **Deploy de infraestrutura via API** → usar `cf-api-call` diretamente
- **Migration apenas** → usar `cf-workers-add-migration`
- **Deploy via Git Integration** → a Cloudflare ja faz validacoes automaticas

## Ver tambem

- [`platform-related/cloudflare-workers/skills/cf-workers-add-migration/`](./cf-workers-add-migration/) — aplicar migrations
- [`platform-related/cloudflare-workers/skills/cf-workers-add-binding/`](./cf-workers-add-binding/) — adicionar bindings
- [`platform-related/cloudflare-shared/skills/cf-api-call/`](../../../cloudflare-shared/skills/cf-api-call/) — operacoes via API
- [`global/skills/cred-store/`](../../../global/skills/cred-store/) — gerenciamento de credenciais
