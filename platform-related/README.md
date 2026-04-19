# platform-related/

Skills, hooks e convenções **específicas de plataformas/runtimes onde o código é executado**.

## Propósito

Agrupa o conhecimento que muda quando você troca a plataforma de execução —
bindings, comandos CLI proprietários (wrangler, fly, vercel), APIs de
provisionamento, ciclo de vida de recursos (criar/listar/atualizar/remover
databases, filas, buckets, DNS records, etc.).

## Critério de inclusão

Uma skill entra aqui quando responde à pergunta:

> **"Como o recurso é provisionado, configurado ou operado?"**

Exemplos: criar D1 via wrangler, configurar binding, aplicar migration,
deploy via Git Integration, criar zona DNS, criar branch Neon, setar secret.

## Quando NÃO entra aqui (vai para outra categoria)

| Se a skill é sobre... | Categoria correta |
|---|---|
| como **escrever** o código | `language-related/` |
| como **consumir** dados (queries, DSL, mapping) | `data-related/` |

## Dicotomia "ops vs consumo" — exemplo concreto

Para o mesmo serviço (D1, Postgres, Elasticsearch) há duas facetas separadas
em categorias diferentes:

| Serviço | Faceta ops (aqui) | Faceta consumo (`data-related/`) |
|---|---|---|
| D1 | `wrangler d1 create`, bindings no `wrangler.toml`, `migrations apply` | query patterns SQLite, batch vs serial, FTS5 setup |
| Postgres (Neon) | API Neon: criar project/branch/compute, pooler config | queries SQL, indexing, JSONB, EXPLAIN ANALYZE |
| Elasticsearch | ILM, snapshots, shard allocation, API keys | DSL queries, mapping design, aggregations |

## Subpastas planejadas

| Subpasta | Plataforma | Status | Cobertura |
|---|---|---|---|
| [`cloudflare-shared/`](./cloudflare-shared/) | Fundação Cloudflare | planejada | wrapper API REST, check de versão Wrangler |
| [`cloudflare-workers/`](./cloudflare-workers/) | Cloudflare Workers + Hono | planejada | deploy via Git Integration, bindings, ops D1/KV/R2/Queue |
| [`cloudflare-dns/`](./cloudflare-dns/) | Cloudflare DNS API | planejada | CRUD records, zone migrate, DNSSEC, audit SPF/DKIM/DMARC |
| [`neon/`](./neon/) | Neon (Postgres serverless) | planejada | API: projects, branches, compute, pooler, anonymize |

## Anatomia de uma subpasta

```
<plataforma>/
├── README.md
├── settings.json
├── hooks/
├── skills/
├── references/         # catálogos de endpoints API, breaking changes
└── examples/
```

## Regras gerais para skills de plataforma

1. **Credenciais via `global/skills/cred-store/`** — nunca implementar gestão
   de secrets própria; reusar a skill agnóstica
2. **Nunca comitar segredos** em `config.json` ou exemplos; só account IDs,
   zone IDs, project IDs, etc. (metadados públicos)
3. **Idempotência** em operações de provisionamento (detectar se recurso já
   existe antes de criar)
4. **Dry-run como default** em operações destrutivas (delete, rename,
   migrate); exigir `--apply` explícito
5. **Audit log** de operações via API em `~/.claude/credentials/<provider>/audit.log`
6. **Version awareness** — validar versão de CLI/SDK antes de operar
   (Wrangler, cloudflared, flyctl, etc.)
7. **Multi-account como cidadão de primeira** — sempre aceitar
   `--account=<nickname>` ou equivalente; nunca assumir conta default silenciosa

## Como adicionar uma nova plataforma

1. Criar pasta `<plataforma>/` com o shape acima
2. Escrever `README.md` listando operações cobertas e dependências
   (ex: requer `cred-store`, requer CLI instalado)
3. Criar `settings.json` se houver hooks de gate (ex: `check-<cli>-version`)
4. Criar primeira skill de setup (credenciais + teste de conectividade)
5. Documentar aqui no README de categoria

## Ver também

- [`language-related/`](../language-related/) — skills por linguagem
- [`data-related/`](../data-related/) — skills de consumo de serviços
- [`global/skills/cred-store/`](../global/skills/cred-store/) — gestão agnóstica de credenciais
