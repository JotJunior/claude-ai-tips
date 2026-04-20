# Guia: Cloudflare

Guia prático do namespace `platform-related/cloudflare-shared/` — uso de
Wrangler CLI + Cloudflare REST API via skills do toolkit.

## Visão geral

A Cloudflare expõe dois planos de integração programática:

| Plano | Cobre | Limitações |
|-------|-------|------------|
| **Wrangler CLI** | Workers deploy/dev/tail, secret management, D1 migrations, bindings (D1/KV/R2/Queue) | Não cobre DNS, Access, WAF, Workers Builds triggers, Page Rules, Rate Limiting, etc. |
| **REST API** (`api.cloudflare.com/client/v4`) | **Tudo** — superconjunto do Wrangler | Mais verboso; requer auth explícito; rate limit 1200 req/5min |

O toolkit oferece:

- **Hook** `check-wrangler-version` — avisa quando Wrangler local está desatualizado
- **Skill** `cf-wrangler-update` — atualiza no PM detectado (bun/pnpm/yarn/npm)
- **Skill** `cf-credentials-setup` — onboarding interativo de API token
- **Skill** `cf-api-call` — wrapper para REST API com retry, audit, rate-limit

## Setup inicial

### Pré-requisitos

```bash
node --version          # ≥18 (ideal 20+)
jq --version            # qualquer
curl --version          # qualquer
op --version            # opcional (1Password CLI, recomendado)
```

Wrangler (preferir devDep local):

```bash
cd /caminho/projeto
bun add -d wrangler@latest           # ou npm install -D / pnpm add -D
```

Verifique:

```bash
npx wrangler --version
```

### Criar API Token no dashboard

1. Acesse [`https://dash.cloudflare.com/profile/api-tokens`](https://dash.cloudflare.com/profile/api-tokens)
2. Clique em **Create Token**
3. Use um template ou **Create Custom Token**
4. Aplique **escopo mínimo** necessário

#### Escopos recomendados por caso de uso

| Caso | Permissões |
|------|------------|
| Workers + D1 + KV + R2 | `Account:Workers Scripts:Edit`, `Account:Workers KV:Edit`, `Account:D1:Edit`, `Account:R2:Edit` |
| DNS management | `Zone:DNS:Edit` (em zonas específicas ou All Zones) |
| Access (Zero Trust) | `Account:Access: Apps and Policies:Edit` |
| WAF / Security | `Zone:Firewall Services:Edit` |
| Analytics (read-only) | `Account:Analytics:Read`, `Zone:Analytics:Read` |
| Workers Builds triggers | `Account:Workers Scripts:Edit` + `User:Memberships:Read` |
| Admin completo (apenas dev) | `Account:*:Edit` + `Zone:*:Edit` |

**Nunca** use **Global API Key** — deprecada para uso programático. Sempre
API Token scoped.

5. Guarde o token (mostrado uma única vez)

### Registrar via `cf-credentials-setup`

No Claude Code:

```
configure credenciais Cloudflare para conta idcbr
```

A skill guia:

```
1. Nickname? → idcbr
2. Escopo do token? (selecione caso de uso)
3. Fonte?    → op (recomendado) | keychain | file
4. URI / service / path da fonte
5. Account ID (32 hex)? → 1783e2ca3a473ef8334a8b17df42878e
6. Email (opcional, para auth legacy)?
7. Zone IDs (opcional, pode adicionar depois)?
8. (Valida via GET /user/tokens/verify)
9. Gravado em registry.json ✓
```

Modo não-interativo (automação):

```bash
cf-credentials-setup \
  --account=idcbr \
  --source=op \
  --ref="op://Personal/CF idcbr Token/credential" \
  --account-id="1783e2ca3a473ef8334a8b17df42878e" \
  --email="user@example.com"
```

### Validar

Listar zonas da conta:

```bash
bash ~/Sistemas/claude-ai-tips/platform-related/cloudflare-shared/skills/cf-api-call/scripts/call.sh \
  GET /zones --account=idcbr --format=pretty
```

Saída esperada:

```json
{
  "success": true,
  "result": [
    {"id": "ac25...", "name": "unity.00k.io", "status": "active", ...},
    {"id": "9f8a...", "name": "inde-intel.tkto.app", "status": "active", ...}
  ],
  "result_info": {"total_count": 2, "page": 1, "per_page": 20}
}
```

## Wrangler CLI

### Hook `check-wrangler-version`

Ativado via `.claude/settings.json`:

```bash
cp ~/Sistemas/claude-ai-tips/platform-related/cloudflare-shared/settings.json .claude/settings.json
cp ~/Sistemas/claude-ai-tips/platform-related/cloudflare-shared/hooks/check-wrangler-version.sh .claude/hooks/
chmod +x .claude/hooks/check-wrangler-version.sh
```

Comportamento:

- Roda antes de qualquer comando `Bash` contendo `wrangler`
- Cache 24h em `/tmp/.claude-wrangler-version-check`
- Compara versão local (devDep ou global) com latest no npm
- **Não bloqueia** — apenas emite aviso no stderr:

```
[wrangler-version] wrangler desatualizado: local=3.87.0 latest=4.81.1 — para atualizar: bun add -d wrangler@latest
```

Detecta package manager pelo lockfile:

| Lockfile presente | PM sugerido | Comando |
|-------------------|-------------|---------|
| `bun.lock` | bun | `bun add -d wrangler@latest` |
| `pnpm-lock.yaml` | pnpm | `pnpm add -D wrangler@latest` |
| `yarn.lock` | yarn | `yarn add -D wrangler@latest` |
| `package-lock.json` | npm | `npm install -D wrangler@latest` |

### Update via `cf-wrangler-update`

Skill explícita (complementa o hook passivo):

```
atualize wrangler no projeto
```

Executa:

1. Detecta PM + escopo (devDep vs global)
2. Busca latest no npm
3. Compara e decide (ok / minor bump / major bump)
4. Major bump: pede confirmação com link do changelog
5. Executa update no PM correto
6. Valida `wrangler --version` pós-update
7. Limpa cache do hook

Flags úteis:

```bash
# Verificar sem atualizar (dry-run)
cf-wrangler-update --check-only

# Forçar versão específica
cf-wrangler-update --target-version=4.80.0

# Pular confirmação em major bump (automação)
cf-wrangler-update --no-confirm

# Update global (raro)
cf-wrangler-update --global
```

### Comandos Wrangler comuns

| Comando | Uso |
|---------|-----|
| `wrangler dev` | Dev server local com bindings |
| `wrangler deploy` | Deploy do Worker |
| `wrangler tail <name>` | Logs em tempo real |
| `wrangler secret put <NAME>` | Adiciona secret encrypted |
| `wrangler secret list` | Lista secrets (nomes apenas) |
| `wrangler secret delete <NAME>` | Remove secret |
| `wrangler d1 create <name>` | Cria database D1 |
| `wrangler d1 migrations apply <name> --remote` | Aplica migrations em prod |
| `wrangler d1 execute <name> --remote --command="SELECT 1"` | SQL ad-hoc |
| `wrangler kv:namespace create <name>` | Cria namespace KV |
| `wrangler kv:key put --namespace-id=<id> <key> <value>` | Put key |
| `wrangler r2 bucket create <name>` | Cria bucket R2 |
| `wrangler queues create <name>` | Cria queue |
| `wrangler versions upload` | Upload sem deploy (para gradual rollout) |

**Importante**: muitos projetos de referência (split-ai, unity-dash,
inde-intelligence) proíbem `wrangler deploy` manual em código —
deploy é feito **exclusivamente via Git Integration** (Cloudflare Workers
Builds). Ver [policy do split-ai](../../platform-related/cloudflare-shared/references/api-vs-wrangler.md#deploy-policy-do-split-ai).

## API REST via `cf-api-call`

### Estrutura básica

```bash
bash .../cf-api-call/scripts/call.sh <METHOD> <PATH> [opções]
```

Exemplos simples:

```bash
# GET sem auth explícito (resolve via --account)
call.sh GET /zones --account=idcbr

# POST com body inline
call.sh POST /zones/:zone_id/dns_records \
  --zone=abc123 \
  --account=idcbr \
  --data='{"type":"A","name":"api","content":"1.2.3.4","proxied":true,"ttl":1}'

# PATCH com body de arquivo
call.sh PATCH /zones/:zone_id/dns_records/xyz \
  --zone=abc123 --account=idcbr \
  --data-file=./dns-update.json
```

### Flags disponíveis

| Flag | Descrição |
|------|-----------|
| `--account=<nick>` | Conta registrada via `cf-credentials-setup` |
| `--zone=<id>` | Zone ID; substitui `:zone_id` no path |
| `--data='<json>'` | Body JSON inline |
| `--data-file=<path>` | Body JSON lido de arquivo |
| `--query='<qs>'` | Query string (ex: `per_page=50&page=1`) |
| `--format=json\|raw\|pretty` | Formato de saída (default: `json`) |
| `--retry=<n>` | Max retries (default: `3`) |
| `--timeout=<s>` | Timeout por request (default: `30`) |
| `--base=<url>` | Base URL alternativo |
| `--audit` / `--no-audit` | Força/desativa audit log |
| `--dry-run` | Imprime request sem executar |

### Resolução automática de placeholders

O wrapper substitui `:account_id` e `:zone_id` no path:

```bash
call.sh GET /accounts/:account_id/workers/scripts --account=idcbr
# expande para:
# GET /accounts/1783e2ca3a473ef8334a8b17df42878e/workers/scripts
```

`:account_id` vem do `metadata.account_id` registrado para `--account=idcbr`.
`:zone_id` vem de `--zone=<valor>` (literal ou resolvido via registry futuramente).

### Formatos de saída

#### `json` (default)

Body completo, sem processamento:

```bash
call.sh GET /zones --account=idcbr | jq '.result[].name'
```

#### `raw`

Body puro, sem parse:

```bash
call.sh GET /zones --account=idcbr --format=raw > raw-response.json
```

Útil para endpoints que retornam non-JSON (raro em CF).

#### `pretty`

JSON pretty-printed via `jq .`:

```bash
call.sh GET /zones --account=idcbr --format=pretty
```

Ideal para leitura humana.

### Retry e rate limit

Comportamento automático:

- **Retry default**: 3 tentativas com backoff exponencial (1s, 2s, 4s + jitter)
- **429 Too Many Requests**: respeita header `Retry-After` se presente
- **5xx**: retry com backoff
- **4xx (exceto 429)**: **NÃO retry** — erro do cliente, falha imediata
- **Network errors** (DNS, timeout): retry com backoff

Rate limit da CF API: ~1200 req/5min **por usuário (token)**. Múltiplas skills
consumindo o mesmo token somam no mesmo bucket. Para bulk ops, throttlear
manualmente (ex: sleep 60s a cada 200 requests).

### Error parsing

CF retorna erros no formato:

```json
{
  "success": false,
  "errors": [{"code": 10000, "message": "Authentication error"}],
  "messages": [],
  "result": null
}
```

O wrapper:

- Parseia `.success` e emite exit ≠0 quando `false`
- stderr contém `[errors]` estruturado
- stdout mantém body completo para parse do caller

#### Exit codes

| Code | Significado |
|------|-------------|
| `0` | Sucesso (`.success == true`) |
| `1` | Erro de aplicação (auth, permission, validation — não-retriável) |
| `2` | Erro de rede/timeout após retries |
| `3` | Credencial não encontrada (via cred-store) |
| `4` | Argumento inválido |

### Dry-run

```bash
call.sh DELETE /zones/:zone_id/dns_records/abc \
  --zone=xyz123 --account=idcbr --dry-run
```

Saída:

```
DRY-RUN
DELETE https://api.cloudflare.com/client/v4/zones/xyz123/dns_records/abc
Authorization: Bearer [REDACTED]
Content-Type: application/json
```

Útil para:

- Validar path antes de op destrutiva
- Gerar `curl` equivalente para documentação
- Testar em ambiente review sem token válido

## Cookbook de operações

### Listar zonas da conta

```bash
call.sh GET /zones --account=idcbr --format=pretty
```

Com filtros:

```bash
call.sh GET /zones --account=idcbr \
  --query="status=active&per_page=50" --format=pretty
```

### Listar DNS records de uma zona

```bash
call.sh GET /zones/:zone_id/dns_records \
  --zone=ac2518a192ffd908938cffa4adac55bd \
  --account=idcbr \
  --query="per_page=100" \
  --format=pretty
```

Filtrar por tipo:

```bash
call.sh GET /zones/:zone_id/dns_records \
  --zone=<id> --account=idcbr \
  --query="type=A"
```

Filtrar por nome exato:

```bash
call.sh GET /zones/:zone_id/dns_records \
  --zone=<id> --account=idcbr \
  --query="name=api.example.com"
```

### Criar A record

```bash
call.sh POST /zones/:zone_id/dns_records \
  --zone=ac2518a192ffd908938cffa4adac55bd \
  --account=idcbr \
  --data='{
    "type": "A",
    "name": "api",
    "content": "1.2.3.4",
    "proxied": true,
    "ttl": 1,
    "comment": "API endpoint"
  }'
```

`ttl: 1` = Auto quando `proxied: true`. Para não-proxied, use TTL em segundos
(60, 300, 3600, etc.).

### Criar CNAME proxied

```bash
call.sh POST /zones/:zone_id/dns_records \
  --zone=<id> --account=idcbr \
  --data='{
    "type": "CNAME",
    "name": "blog",
    "content": "myblog.platform.com",
    "proxied": true,
    "ttl": 1
  }'
```

### Criar TXT (SPF/DKIM/DMARC)

SPF:

```bash
call.sh POST /zones/:zone_id/dns_records \
  --zone=<id> --account=idcbr \
  --data='{
    "type": "TXT",
    "name": "@",
    "content": "v=spf1 include:_spf.google.com include:amazonses.com ~all",
    "ttl": 3600
  }'
```

DKIM:

```bash
call.sh POST /zones/:zone_id/dns_records \
  --zone=<id> --account=idcbr \
  --data='{
    "type": "TXT",
    "name": "selector1._domainkey",
    "content": "v=DKIM1; k=rsa; p=MIGfMA0...",
    "ttl": 3600
  }'
```

DMARC:

```bash
call.sh POST /zones/:zone_id/dns_records \
  --zone=<id> --account=idcbr \
  --data='{
    "type": "TXT",
    "name": "_dmarc",
    "content": "v=DMARC1; p=reject; rua=mailto:dmarc@example.com; pct=100",
    "ttl": 3600
  }'
```

### Atualizar record (PATCH)

Parcial (só campos alterados):

```bash
call.sh PATCH /zones/:zone_id/dns_records/abc123 \
  --zone=<id> --account=idcbr \
  --data='{"content":"5.6.7.8","comment":"updated 2026-04-19"}'
```

Total (PUT substitui tudo):

```bash
call.sh PUT /zones/:zone_id/dns_records/abc123 \
  --zone=<id> --account=idcbr \
  --data='{
    "type": "A",
    "name": "api",
    "content": "5.6.7.8",
    "proxied": true,
    "ttl": 1
  }'
```

### Deletar record (com confirmação)

Sempre com dry-run primeiro:

```bash
# 1. Ver o que seria feito
call.sh DELETE /zones/:zone_id/dns_records/abc123 \
  --zone=<id> --account=idcbr --dry-run

# 2. Executar (irreversível)
call.sh DELETE /zones/:zone_id/dns_records/abc123 \
  --zone=<id> --account=idcbr
```

Resposta:

```json
{"result": {"id": "abc123"}, "success": true}
```

### Trigger Workers Build manual

Requer conhecer `trigger_uuid` (ver dashboard ou `/builds/workers/:tag/triggers`):

```bash
call.sh POST /accounts/:account_id/builds/triggers/ed429790-6a5c-4412-bb78-3093c82619b2/builds \
  --account=idcbr \
  --data='{}'
```

### Purge cache por URLs

```bash
call.sh POST /zones/:zone_id/purge_cache \
  --zone=<id> --account=idcbr \
  --data='{
    "files": [
      "https://example.com/style.css",
      "https://example.com/app.js"
    ]
  }'
```

### Purge cache por tags

Requer Cache Tags configuradas via Workers ou Page Rules:

```bash
call.sh POST /zones/:zone_id/purge_cache \
  --zone=<id> --account=idcbr \
  --data='{"tags": ["homepage", "blog-post-42"]}'
```

### Purge cache total (último recurso)

```bash
call.sh POST /zones/:zone_id/purge_cache \
  --zone=<id> --account=idcbr \
  --data='{"purge_everything": true}'
```

Cuidado: invalida tudo, origem vai receber carga pesada.

### GraphQL Analytics

Top 10 hostnames por tráfego nas últimas 24h:

```bash
cat > /tmp/top-hosts.json <<'EOF'
{
  "query": "query TopHosts($accountTag: string!, $since: Time!, $until: Time!) { viewer { accounts(filter: {accountTag: $accountTag}) { httpRequestsAdaptiveGroups(filter: {datetime_geq: $since, datetime_lt: $until}, limit: 10, orderBy: [count_DESC]) { count dimensions { clientRequestHTTPHost } } } } }",
  "variables": {
    "accountTag": "1783e2ca3a473ef8334a8b17df42878e",
    "since": "2026-04-18T00:00:00Z",
    "until": "2026-04-19T00:00:00Z"
  }
}
EOF

call.sh POST /graphql \
  --base=https://api.cloudflare.com/client/v4/graphql \
  --account=idcbr \
  --data-file=/tmp/top-hosts.json \
  --format=pretty
```

### Listar Access apps

```bash
call.sh GET /accounts/:account_id/access/apps \
  --account=idcbr --format=pretty
```

### Configurar setting de zona (SSL)

```bash
call.sh PATCH /zones/:zone_id/settings/ssl \
  --zone=<id> --account=idcbr \
  --data='{"value": "full_strict"}'
```

Settings comuns:

| Setting | Valores típicos |
|---------|------------------|
| `ssl` | `off`, `flexible`, `full`, `full_strict` |
| `min_tls_version` | `1.0`, `1.1`, `1.2`, `1.3` |
| `always_use_https` | `on`, `off` |
| `automatic_https_rewrites` | `on`, `off` |
| `brotli` | `on`, `off` |
| `http3` | `on`, `off` |
| `0rtt` | `on`, `off` |
| `security_level` | `off`, `essentially_off`, `low`, `medium`, `high`, `under_attack` |

## Multi-account

### Nicknames canônicos

Convenção sugerida:

| Contexto | Nickname |
|----------|----------|
| Conta principal pessoal/empresa | `pessoal`, `empresa`, `idcbr` |
| Conta por cliente | `cliente-<nome>` (kebab-case) |
| Ambientes (dev/staging/prod) | `dev`, `staging`, `prod` |
| Tokens com escopo restrito | `<conta>-<escopo>` (ex: `idcbr-dns`) |

### Troca por request

Cada invocação escolhe a conta explicitamente:

```bash
call.sh GET /zones --account=pessoal
call.sh GET /zones --account=cliente-acme
call.sh GET /zones --account=idcbr-dns
```

### Permissões granulares

Princípio de menor privilégio — um token por escopo:

| Nickname | Escopo do token |
|----------|-----------------|
| `idcbr-dns` | `Zone:DNS:Edit` apenas |
| `idcbr-workers` | `Account:Workers*:Edit` |
| `idcbr-analytics` | `Account/Zone Analytics:Read` |
| `idcbr-admin` | Full (uso raro, dev only) |

Skills escolhem o token mínimo via flag:

```bash
# Skill de DNS usa token específico
call.sh POST /zones/:zone_id/dns_records --account=idcbr-dns ...

# Skill de deploy usa token Workers
call.sh POST /accounts/:account_id/workers/scripts/... --account=idcbr-workers ...
```

## Audit trail

### Localização

Global:

```
~/.claude/credentials/audit.log
```

Por conta CF:

```
~/.claude/credentials/cloudflare/<nickname>/audit.log
```

### Formato

```
<timestamp> <method> <path> account=<nick> status=<http> success=<true|false>
```

Exemplo:

```
2026-04-19T21:00:00Z GET /zones account=idcbr status=200 success=true
2026-04-19T21:01:15Z POST /zones/abc/dns_records account=idcbr status=200 success=true
2026-04-19T21:05:22Z DELETE /zones/abc/dns_records/xyz account=idcbr status=200 success=true
2026-04-19T21:10:00Z POST /zones/abc/purge_cache account=idcbr status=429 success=false
```

**Nunca contém**: request body, response body, headers, token.

### Quando é ativado

Por default:

- Métodos de escrita (`POST`, `PATCH`, `PUT`, `DELETE`) → audit **ON**
- Métodos de leitura (`GET`, `HEAD`) → audit **OFF**

Override via flag:

```bash
# Forçar audit de GET
call.sh GET /zones --account=idcbr --audit

# Desativar audit de POST (validações, verify)
call.sh POST /user/tokens/verify --account=idcbr --no-audit
```

### Rotação

Não-automática. Manualmente:

```bash
cd ~/.claude/credentials/cloudflare/idcbr/
mv audit.log "audit-$(date +%Y%m).log"
touch audit.log
chmod 600 audit.log
```

Ou rolling window:

```bash
tail -n 10000 audit.log > /tmp/audit.log && mv /tmp/audit.log audit.log
```

## Integração com `wrangler.toml`

### O que o toolkit NÃO toca

`cf-api-call` é **read-only** quanto ao `wrangler.toml` do projeto. Não
modifica bindings, compat_date, vars, rotas.

### O que você edita manualmente

```toml
name = "meu-worker"
main = "src/index.ts"
compatibility_date = "2026-04-19"       # manter atualizado
compatibility_flags = ["nodejs_compat"]

[[d1_databases]]
binding = "DB"
database_name = "meu-db"
database_id = "abc123..."
migrations_dir = "migrations"

[[kv_namespaces]]
binding = "CACHE"
id = "def456..."

[[r2_buckets]]
binding = "ASSETS"
bucket_name = "meu-bucket"

[[queues.producers]]
binding = "JOBS"
queue = "jobs-queue"

[[queues.consumers]]
queue = "jobs-queue"
max_batch_size = 10
dead_letter_queue = "jobs-dlq"
```

### Política de deploy

Projetos de referência (split-ai, unity-dash, inde-intelligence) seguem:

> **Deploy de código exclusivamente via Git Integration.**
> `wrangler deploy` manual **proibido** para código.
>
> Fluxo:
> 1. Push para `main`
> 2. Cloudflare Workers Builds detecta push
> 3. Executa build (npm install + npx wrangler deploy)
> 4. Deploy automático

Razões:

- Reproducibilidade (sempre a partir do commit)
- Auditoria (build logs acessíveis via API `/builds/`)
- Consistência de runtime (mesmo ambiente sempre)
- Impede deploy acidental de WIP

### Compat date discipline

`compatibility_date` em `wrangler.toml` deve ser atualizada periodicamente
(a cada trimestre). Skills futuras (planejadas) podem validar que está
dentro de ~6 meses.

## Troubleshooting

| Código / Sintoma | Causa | Solução |
|------------------|-------|---------|
| `10000 Authentication error` | Token inválido/expirado/revogado | Criar novo no dashboard, rotacionar |
| `10001 Account forbidden` | Token sem escopo na conta alvo | Recriar com escopo correto |
| `429 Too many requests` | Rate limit (1200/5min/user) | Aguardar `Retry-After`; throttlear manualmente em bulk |
| `7003 Invalid zone identifier` | Zone ID errado | Listar zonas com `GET /zones` |
| `81057 DNS record already exists` | Duplicata | Usar PATCH em record existente, ou ver primeiro |
| `81058 DNS content invalid` | Formato de `content` errado | Ex: A precisa IPv4, CNAME precisa hostname |
| `403 Forbidden` em endpoint que deveria funcionar | Token expirou sem aviso | `/user/tokens/verify` para confirmar |
| `op: not signed in` | Sessão 1P expirou | `op signin` |
| `wrangler: command not found` | Não instalado | `bun add -d wrangler@latest` |
| `check-wrangler-version` fica avisando | Lockfile não detectado | Verifique se `bun.lock`/`pnpm-lock.yaml` está no projeto |
| Deploy falha com "source: wrangler" no log | Legacy endpoint usado | Usar `/builds/` namespace (ver `api-vs-wrangler.md`) |
| `cf-api-call` dá timeout | Endpoint lento ou network | `--timeout=60` ou verificar rede |
| `jq: command not found` | jq ausente | `brew install jq` / `apt-get install jq` |

### Debugar retry

Aumentar verbosity no stderr:

```bash
call.sh GET /zones --account=idcbr --retry=5 2>&1 | tee /tmp/debug.log
grep -E '\[try|rate limited|erro' /tmp/debug.log
```

### Verificar token manualmente

Bypass o wrapper para debugar auth:

```bash
TOKEN=$(bash .../resolve.sh cloudflare.idcbr.api_token)
curl -s -H "Authorization: Bearer $TOKEN" \
  https://api.cloudflare.com/client/v4/user/tokens/verify | jq
```

Resposta esperada:

```json
{
  "result": {"id": "...", "status": "active"},
  "success": true,
  "errors": [],
  "messages": [{"code": 10000, "message": "This API Token is valid and active"}]
}
```

### Dry-run antes de bulk delete

Sempre antes de deletar em massa:

```bash
# 1. Listar candidatos
call.sh GET /zones/:zone_id/dns_records \
  --zone=<id> --account=idcbr \
  --query="type=A" | jq '.result[] | select(.name | contains("-old"))'

# 2. Dry-run em cada
for ID in $(...); do
  call.sh DELETE /zones/:zone_id/dns_records/$ID \
    --zone=<zone> --account=idcbr --dry-run
done

# 3. Confirmar manual e executar
```

## Ver também

- [`cf-api-call/SKILL.md`](../../platform-related/cloudflare-shared/skills/cf-api-call/SKILL.md)
- [`cf-credentials-setup/SKILL.md`](../../platform-related/cloudflare-shared/skills/cf-credentials-setup/SKILL.md)
- [`cf-wrangler-update/SKILL.md`](../../platform-related/cloudflare-shared/skills/cf-wrangler-update/SKILL.md)
- [`api-vs-wrangler.md`](../../platform-related/cloudflare-shared/references/api-vs-wrangler.md) — tabela de cobertura
- [`api-endpoint-catalog.md`](../../platform-related/cloudflare-shared/references/api-endpoint-catalog.md) — endpoints curados
- [`credential-storage.md`](../../platform-related/cloudflare-shared/references/credential-storage.md) — convenções CF
- [`credentials.md`](./credentials.md) — gestão de credenciais em geral
- [Cloudflare API docs](https://developers.cloudflare.com/api/)
- [Wrangler CLI docs](https://developers.cloudflare.com/workers/wrangler/)
- [Workers Builds](https://developers.cloudflare.com/workers/ci-cd/builds/)
