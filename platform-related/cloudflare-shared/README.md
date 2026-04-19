# cloudflare-shared/

Fundacao para todas as skills que interagem com Cloudflare. **Nao eh invocavel
diretamente** — provê componentes (hooks, wrappers, skills de setup) que outros
namespaces CF consomem.

## Conteudo

| Recurso | Tipo | Descricao |
|---------|------|-----------|
| [`hooks/check-wrangler-version.sh`](./hooks/check-wrangler-version.sh) | hook | `PreToolCall` Bash — avisa se `wrangler` esta desatualizado |
| [`skills/cf-api-call/`](./skills/cf-api-call/) | skill | Wrapper REST generico (auth, retry, rate-limit, audit) |
| [`skills/cf-credentials-setup/`](./skills/cf-credentials-setup/) | skill | Wrapper pre-configurado sobre `cred-store-setup` para CF |
| [`skills/cf-wrangler-update/`](./skills/cf-wrangler-update/) | skill | Atualiza Wrangler no package manager correto |
| [`references/api-vs-wrangler.md`](./references/api-vs-wrangler.md) | ref | Catalogo: o que so eh possivel via API REST |
| [`references/api-endpoint-catalog.md`](./references/api-endpoint-catalog.md) | ref | Endpoints CF API usados pelas skills |
| [`references/credential-storage.md`](./references/credential-storage.md) | ref | Como CF credenciais sao armazenadas via `cred-store` |

## Principio

Cloudflare expoe dois planos:

1. **CLI (`wrangler`, `cloudflared`)** — cobre subset focado em Workers + deploy
2. **REST API (`api.cloudflare.com/client/v4`)** — cobre TUDO, incluindo recursos
   que o CLI nao toca (DNS, Access, WAF, Pages advanced, Analytics, Images,
   Stream, Load Balancers, Turnstile, Workers Builds triggers, ...)

Skills de `platform-related/cloudflare-*` combinam os dois. `cloudflare-shared/`
provê a base comum para evitar duplicacao:

```
platform-related/
├── cloudflare-shared/      (esta pasta — fundacao)
├── cloudflare-workers/     (consome cf-api-call, cf-credentials-setup)
├── cloudflare-dns/         (consome cf-api-call, cf-credentials-setup)
└── ... (access/, r2/, pages/, etc. — futuros)
```

## Dependencias

- [`global/skills/cred-store/`](../../global/skills/cred-store/) — leitura de credenciais
- [`global/skills/cred-store-setup/`](../../global/skills/cred-store-setup/) — registro de credenciais
- `jq` — parsing JSON (nos scripts)
- `curl` — cliente HTTP (nos scripts)

## Como consumir (de outras skills CF)

```bash
# Resolver credencial (via cred-store)
TOKEN=$(bash .../global/skills/cred-store/scripts/resolve.sh \
  cloudflare.idcbr.api_token)

# Chamar API via wrapper
bash .../platform-related/cloudflare-shared/skills/cf-api-call/scripts/call.sh \
  GET /zones --account=idcbr
```

## Hooks registrados (settings.json)

Este namespace registra `PreToolCall` hooks em [`settings.json`](./settings.json)
para interceptar comandos `wrangler` e alertar sobre versao desatualizada.

Para ativar em um projeto consumidor:

```bash
cp platform-related/cloudflare-shared/settings.json <projeto>/.claude/settings.json
cp -r platform-related/cloudflare-shared/hooks/ <projeto>/.claude/hooks/
```

## Ver tambem

- [platform-related/README.md](../README.md) — visao geral da categoria
- [global/skills/cred-store/SKILL.md](../../global/skills/cred-store/SKILL.md) — gestao de credenciais
