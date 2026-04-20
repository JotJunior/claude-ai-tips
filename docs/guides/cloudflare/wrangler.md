# Wrangler CLI

Uso do wrangler CLI, comandos comuns, deploy, dev e secrets.

## Hook `check-wrangler-version`

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

## Update via `cf-wrangler-update`

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

## Comandos Wrangler comuns

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

---

[Voltar para índice](../guides/cloudflare/README.md)
