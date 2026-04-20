---
name: ts-deploy-check
description: |
  Valida pré-deploy de Cloudflare Workers com checklist de bindings, secrets e configurações.
  Use quando o usuário disser "deploy check", "pre-deploy", "validar deploy", "wrangler deploy check",
  "antes de fazer deploy", "checar configuração de deploy".
  NÃO use para deploy automático via CI/CD (use hooks de CI específicos).
allowed-tools:
  - Bash
  - Read
  - Grep
  - Glob
---

# Deploy Check — Cloudflare Workers

Executa checklist de validação pré-deploy para projetos Cloudflare Workers + Hono + Drizzle ORM + TypeScript strict.

## Intro

Deploy sem validação é receita para incidentes em produção. Um deploy bem-sucedido
requer que bindings estejam configurados corretamente, secrets estejam definidos
no ambiente remoto (não no código), migrations D1 estejam aplicadas, e observabilidade
esteja ativa para monitorar a saúde do worker pós-deploy.

Este skill implementa um workflow estruturado que vai desde a leitura do
`wrangler.toml` até um dry-run do deploy, passando por todas as validações
necessárias para evitar surpresas em produção.

## Pre-flight Reads

- `wrangler.toml` — configuração do worker e bindings
- `.dev.vars` ou `.env` — variáveis locais (não commitar em produção)
- `drizzle.config.ts` — configuração do banco D1
- `wrangler.toml` de referência se existir em outro serviço similar

## Workflow

### 1. Ler wrangler.toml

```bash
cat wrangler.toml
```

Identificar:
- Nome do worker (`name`)
- Ambiente (`dev`, `staging`, `production`)
- Bindings: `vars`, `kv_namespaces`, `d1_databases`, `r2_buckets`, `queues`, `durable_objects`
- Routes configuradas (`routes`)
- Limites de CPU (`cpu_ms`) e duração (`max_duration`)

### 2. Listar secrets necessários

Para cada binding do tipo `vars` que contenha dados sensíveis:
```bash
# Listar vars definidos no wrangler.toml
grep -E "^\s*[a-z_]+\s*=" wrangler.toml | grep -v "#"

# vars sensíveis devem ser convertidos para secrets:
# 1. Identificar vars que contém credenciais ou keys
# 2. Documentar quais devem usar wrangler secret put
```

### 3. Validar code bindings

Buscar no código todas as referências a `c.env` ou `env.` para bindings:
```bash
grep -rn "process\.env\|c\.env\|\.env\." src/
```

Verificar:
- Todos os bindings usados no código estão declarados no wrangler.toml
- Não há referências a `process.env` diretas em Workers — usar sempre `c.env`
- Bindings de secrets estão acessando via `c.env.SECRET_NAME` (não `c.env.SECRET_NAME.value`)

### 4. Verificar migrations D1

Se o projeto usa D1:
```bash
# Listar migrations pendentes
ls -la drizzle/migrations/

# Verificar se migrations foram geradas
npx wrangler d1 migrations list <database_name> --local

# Aplicar migrations localmente para validar
npx wrangler d1 migrations apply <database_name> --local
```

### 5. Checkar bindings específicos

#### KV Namespace
```bash
# Verificar ID do KV no wrangler.toml
grep -A5 "kv_namespaces" wrangler.toml

# O ID deve estar presente no ambiente de produção (não apenas local)
```

#### R2 Bucket
```bash
# Verificar bucket name e configuração
grep -A5 "r2_buckets" wrangler.toml

# Confirmar que bucket existe na account Cloudflare
npx wrangler r2 bucket list
```

#### D1 Database
```bash
# Verificar database binding
grep -A5 "d1_databases" wrangler.toml

# Listar databases existentes
npx wrangler d1 list
```

#### Queue
```bash
# Verificar queue consumers
grep -A10 "\[queues\]" wrangler.toml

# Confirmar queue existe
npx wrangler queue list
```

### 6. Validar secrets no ambiente remoto

```bash
# Listar secrets existentes
npx wrangler secret list

# Para cada secret necessário, verificar se existe
# Se não existir, documentar que deve ser criado via:
npx wrangler secret put SECRET_NAME
# (entrar valor interativo)

# AVISO CRÍTICO: secrets NUNCA devem estar no wrangler.toml [vars]
# Apenas vars públicas (não sensíveis) podem estar em [vars]
```

### 7. Verificar routes e custom domains

```bash
# Listar routes configuradas
grep -A10 "\[routes\]" wrangler.toml

# Verificar se há custom domain configurado
grep -i "zone_id\|custom_domain" wrangler.toml

# Se custom domain: zone_id é obrigatório
# pattern: zone_id = "xxxxx"
```

### 8. Ativar tail logs para debug

```bash
# Ativar tailing para capturar logs pós-deploy
npx wrangler deploy --dry-run --outdir ./dist 2>&1 | head -50

# Em produção, verificar se analytics engine está configurado
grep -i "analytics_engine" wrangler.toml
```

### 9. Rollback plan

Antes do deploy, documentar rollback:
```bash
# Se deploy falhar, reverter para versão anterior
npx wrangler deploy --env production --message "rollback v1.2.3"

# Listar versões disponíveis
npx wrangler versions list

# Rollback específico
npx wrangler versions revert <version_id> --env production
```

### 10. Dry-run

```bash
# Executar deploy em dry-run mode para validar tudo
npx wrangler deploy --dry-run --outdir ./dist

# Se dry-run passar, fazer deploy real
npx wrangler deploy
```

## Checklist Final

```
 Pré-deploy checklist:
 [ ] wrangler.toml lido e bindings verificados
 [ ] Secrets criados via wrangler secret put (não em vars)
 [ ] Bindings KV/R2/D1/Queue verificados
 [ ] Migrations D1 aplicadas localmente
 [ ] Routes configuradas (zone_id presente para custom domains)
 [ ] Limites de CPU/Duration dentro do budget (50ms CPU)
 [ ] Tail logs ativo para debug pós-deploy
 [ ] Rollback plan documentado
 [ ] Analytics engine configurado
 [ ] Dry-run executado com sucesso
 [ ] Package.json version updated (se aplicável)
```

## Exemplo Bom

Deploy seguro com rollback plan documentado:

```bash
# 1. Validação de secrets
$ npx wrangler secret list
# SECRET_NAME      - exists

# 2. Migrations D1
$ npx wrangler d1 migrations apply production-db --local
# Migration applied successfully

# 3. Dry-run
$ npx wrangler deploy --dry-run
# ...
# Upload worker v1.2.3 to Cloudflare... success

# 4. Deploy com mensagem
$ npx wrangler deploy --message "feat: adicionar novo endpoint de users"

# 5. Rollback documentado
# Em caso de problema:
# $ npx wrangler versions revert <version_id>
```

**Por que é bom**: Dry-run antes, secrets verificados, rollback plan documentado.

## Exemplo Ruim

Deploy direto em produção sem validação:

```bash
npx wrangler deploy
```

**Por que é ruim**: Sem dry-run, sem verificar secrets, sem rollback plan. Se algo falhar, não há como reverter facilmente.

```toml
# wrangler.toml com secrets em vars (ERRADO!)
[vars]
DATABASE_URL = "postgres://user:pass@host/db"  # RUIM: senha exposta
API_KEY = "sk-live-xxxxx"  # RUIM: key exposta
```

**Por que é ruim**: Secrets em vars são visíveis no dashboard da Cloudflare e no código fonte. Qualquer pessoa com acesso ao repositório pode ver as credenciais.

## Gotchas

- **Gotcha 1**: Secrets NUNCA em `wrangler.toml [vars]` — usar sempre `wrangler secret put`. Vars são públicas e visíveis no dashboard.
- **Gotcha 2**: Para custom domains, `zone_id` é obrigatório. Sem ele, o deploy pode não aplicar as routes corretamente.
- **Gotcha 3**: Limite de CPU Workers é 50ms no plano free, 30s no plano paid. Monitorar no dashboard para evitar throttling.
- **Gotcha 4**: Logs de `console.log` aparecem no `wrangler tail` mas não no dashboard. Para observabilidade real, configurar Analytics Engine.
- **Gotcha 5**: D1 migrations devem ser aplicadas ANTES do deploy em produção. Em dev local, usar `--local` flag.
- **Gotcha 6**: Se o worker acessa recursos externos (APIs, webhooks), garantir que não há hardcoded URLs — usar variáveis de ambiente.
- **Gotcha 7**: Deploy em produção sem dry-run é operação de alto risco. Sempre fazer dry-run primeiro, especialmente após mudanças de bindings.

## Quando NÃO usar

- **Deploy via CI/CD** — hooks de CI já devem implementar este checklist
- **Deploy de infraestrutura** — usar skills de Cloudflare (platform-related)
- **Testes de carga** — ferramenta especializada necessária
- **Rollback de emergência** — gh pr merge/revert ou wrangler diretamente
