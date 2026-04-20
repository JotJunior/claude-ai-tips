---
name: cf-workers-add-route
description: |
  Use quando precisar adicionar uma route (rotas com wildcard path) ou custom
  domain ao Worker. Tambem quando mencionar "add cloudflare route", "novo custom
  domain", "configurar route worker", "wrangler route", "adicionar rota", "mapear
  dominio ao worker", "worker route pattern". Foco em configuracao wrangler.toml
  e DNS — NAO em codigo de aplicacao. Para operacoes de DNS records (criar A, CNAME,
  MX) veja cloudflare-dns. Para adicionar binding ao Worker veja cf-workers-add-binding.
allowed-tools:
  - Read
  - Bash
  - Glob
---

# Cloudflare Workers: Adicionar Route ou Custom Domain

Provisiona uma rota HTTPS para um Worker via `wrangler.toml`. Existem dois
mecanismos: **routes** (padrao com wildcards no path) e **custom domains**
(CNAME automatico com SSL gerenciado).

## Pre-Flight Reads

1. **`wrangler.toml`** existente — identificar secao `[routes]` ou `[[routes]]`
2. **`wrangler.toml`** — verificar se ha secao `[env.production]` com routes
3. **`wrangler.toml`** — localizar `zone_name` ou `zone_id` existente (se aplicavel)
4. DNS da zona — confirmar que a zona existe em Cloudflare e esta ativa
5. Se adding custom domain: verificar se o dominio ja esta em uso (Pages? outro Worker?)

## Workflow: Adicionar Route com Wildcard

### Passo 1 — Identificar a zona

Se a zona ainda nao esta no `wrangler.toml`, obtain o `zone_id` ou `zone_name`:

```bash
# Listar zonas disponiveis (requer CF API token com permissao Zonas)
wrangler whoami  # verificar account ativo

# OU via CF API (cf-api-call skill)
bash <path>/cf-api-call/scripts/call.sh GET /zones --account=<nick> --format=pretty
```

### Passo 2 — Editar wrangler.toml

Adicionar route na secao `[[routes]]` ou na raiz do arquivo:

```toml
name = "my-worker"
main = "src/index.ts"

# Route basica — todas as requests para api.example.com/*
[[routes]]
  pattern = "api.example.com/*"
  zone_name = "example.com"
  # OU: zone_id = "abc123def456"
```

**Sintaxes suportadas:**

```toml
# Opcao A: array de routes na raiz (todas vao para o mesmo worker)
routes = [
  { pattern = "api.example.com/*", zone_name = "example.com" },
  { pattern = "api2.example.com/*", zone_name = "example.com" },
]

# Opcao B: bloco [[routes]] (mais legivel, permite comentarios)
[[routes]]
  pattern = "api.example.com/*"
  zone_name = "example.com"

[[routes]]
  pattern = "staging.example.com/*"
  zone_name = "example.com"
  # Sem custom_domain = true → route normal, NAO cria CNAME automatico
```

### Passo 3 — Dry-run para validar

```bash
wrangler deploy --dry-run --message "add api route"
```

O output mostra:
- URL final que o Worker recebera
- Conflitos com routes existentes (Pages, outros Workers)
- Warnings de SSL pendente

### Passo 4 — Deploy

```bash
wrangler deploy --message "add api route"
```

O Wrangler cria automaticamente:
- Route no nivel do Worker
- SSL wildcard para `*.zone.com` (se a zona tiver SSL ativo)
- CNAME no Edge (NAO visivel no DNS dashboard como record manual)

### Passo 5 — Testar

```bash
curl -I https://api.example.com/
# Esperado: 200/404 ( Worker respondendo)
# Se SSL pendente: curl ate 60s apos deploy
```

## Workflow: Adicionar Custom Domain (CNAME Automatico)

Custom domain difere de route: cria entrada `[[routes]]` com
`custom_domain = true` e Cloudflare provisiona automaticamente:

1. Certificate DNS valido
2. Proxy (orange cloud) ativo
3. Sem necessidade de edit manual no DNS dashboard

```toml
[[routes]]
  pattern = "api.example.com"      # SEM /* — hostname exato
  zone_name = "example.com"
  custom_domain = true             # Cria CNAME automatico + SSL
```

```bash
wrangler deploy --dry-run
wrangler deploy
```

## Exemplo BOM

```toml
# wrangler.toml — worker com 2 routes em ambientes separados
name = "api-gateway"
main = "src/index.ts"
compatibility_date = "2024-01-01"

# Production: rotas publicas
[env.production]
routes = [
  { pattern = "api.example.com/*", zone_name = "example.com" },
  { pattern = "api.example.org/*", zone_name = "example.org" },
]

# Preview: route fixa para teste local
[env.preview]
routes = [
  { pattern = "preview-api.example.com/*", zone_name = "example.com" },
]
```

```typescript
// src/index.ts
export default {
  async fetch(request: Request, env: Env): Promise<Response> {
    const url = new URL(request.url);
    // Distingue por path
    if (url.pathname.startsWith("/api/v1/")) {
      return handleV1(request, env);
    }
    return new Response("Not Found", { status: 404 });
  },
};
```

## Exemplo RUIM

```toml
# WRONG: route com wildcard no host
[[routes]]
  pattern = "*.example.com/*"   # INVALIDO — wildcard no host nao suportado
  zone_name = "example.com"
```

```toml
# WRONG: mix de custom_domain em route com path
[[routes]]
  pattern = "api.example.com/*"
  custom_domain = true   # IGNORADO pelo wrangler — custom_domain so para hostname exato
```

```toml
# WRONG: zone_name e zone_id juntos (ambiguo)
[[routes]]
  pattern = "api.example.com/*"
  zone_name = "example.com"
  zone_id = "abc123"   # USAR SMENTE UM — zone_name preferivel
```

## Gotchas

### 1. Wildcard no host nao suportado

Routes Cloudflare **NAO aceitam** wildcards no hostname (somente no path).
`*.example.com/*` eh invalido. Para multi-subdomain, criar routes individuais
ou usar [Workers Routing via script](https://developers.cloudflare.com/workers/routing/route-matching/).

### 2. Zone_name vs zone_id — preferivel zone_name

`zone_name` faz lookup automatico e eh mais tolerante a migracoes entre
contas. `zone_id` eh mais rapido se voce tem muitas routes (evita lookup
por request), mas quebra se a zona for transferida.

### 3. Route com /* implica SSL automatico

Se a zona tem Universal SSL ativo, o certificado covera automaticamente
todas as subroutes. Se SSL esta desabilitado na zona, a route也不会 funcionar.

### 4. Conflito com Cloudflare Pages

Se houver um projeto Pages servindo a mesma zona, Pages tem precedencia
sobre Workers. O deploy da route pode aparentemente "funcionar" mas o Pages
intercepta. Verificar em Dash: Workers & Pages > [worker] > Triggers >
Custom Domains — se o dominio ja esta em Pages, primeiro desanexar.

### 5. HTTPS obrigatorio

Routes Workers **exigem HTTPS** — HTTP puro retorna 301 redirect. Nao ha
como desabilitar isso. Se precisar de HTTP puro para dev interno, use
`--local` com `wrangler dev`.

### 6. Order das routes (precendencia)

Se multiple routes correspondem ao mesmo pattern, a mais especifica (menos
wildcard) ganha. Se empatar, a route criada mais recentemente vence.
`custom_domain = true` (hostname exato) sempre tem precedencia sobre route
com `/*` no mesmo host.

### 7. Maturidade do SSL (propagacao)

Apos `wrangler deploy`, o certificado pode levar **ate 15 minutos** para
provisionar. requests retornam `526 Invalid SSL certificate` nesse periodo.
Wait fixo: 15min antes de alarmar.

## Quando NAO Usar

- **Operacoes de DNS records (A, CNAME, MX)** — use `cloudflare-dns` skill
- **Adicionar binding ao Worker (D1, KV, R2)** — use `cf-workers-add-binding`
- **Configurar Pages com custom domain** — Pages tem propria UI de dominios
- **Workers com mais de 1 rota fixa** em prod: considere se um Worker单一
  nao esta sobrecarregado — cada route dispara o mesmo script
- **Load Balancer**上前置 Worker: use [Cloudflare Load Balancer](https://developers.cloudflare.com/load-balancing/) em vez de rota simples
