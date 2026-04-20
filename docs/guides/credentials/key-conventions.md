# Convenção de Keys e Metadata

## Convenção de keys

Formato canônico:

```
<provider>.<account>.<credtype>
```

| Parte | Regex | Exemplos |
|-------|-------|----------|
| provider | `[a-z0-9-]+` | `cloudflare`, `neon`, `elasticsearch`, `postgres`, `redis` |
| account | `[a-z0-9-]+` | `idcbr`, `pessoal`, `cliente-acme`, `production`, `smartgw` |
| credtype | `[a-z0-9_-]+` | `api_token`, `api_key`, `password`, `connection_string` |

Regex completo: `^[a-z0-9-]+\.[a-z0-9-]+\.[a-z0-9_-]+$`

### Exemplos por cenário

| Cenário | Key |
|---------|-----|
| Conta CF principal | `cloudflare.idcbr.api_token` |
| Conta CF de cliente | `cloudflare.cliente-acme.api_token` |
| Mesmo CF, token DNS-only | `cloudflare.idcbr-dns.api_token` |
| Neon produção | `neon.production.api_key` |
| Neon staging | `neon.staging.api_key` |
| ES cluster local | `elasticsearch.local.password` |
| ES cluster prod | `elasticsearch.production.password` |
| Postgres app direct | `postgres.myapp.connection_string` |

**Anti-pattern**: não usar underscores em provider/account (confunde com
credtype). Kebab-case em ambos.

---

## Metadata pública

Dados não-sensíveis armazenados em `registry.json` junto com cada entry.
Campos **padrão** por provider:

### Cloudflare

```json
{
  "account_id": "1783e2ca3a473ef8334a8b17df42878e",
  "email": "user@example.com",
  "zone_ids": ["abc...", "def..."],
  "default_zone": "abc...",
  "token_permissions": ["Account:Workers Scripts:Edit", "Zone:DNS:Edit"],
  "token_expires_at": "2026-10-15T00:00:00Z",
  "dashboard_url": "https://dash.cloudflare.com/1783.../"
}
```

### Neon

```json
{
  "project_id": "cold-sun-12345",
  "default_branch": "main",
  "connection_host": "ep-cold-sun-12345.us-east-2.aws.neon.tech"
}
```

### Elasticsearch

```json
{
  "host": "localhost",
  "port": 9200,
  "user": "elastic",
  "use_https": false,
  "cluster_version": "8.11.0"
}
```

### Postgres

```json
{
  "host": "db.example.com",
  "port": 5432,
  "database": "myapp",
  "user": "appuser",
  "ssl_mode": "require"
}
```

### Entry completa de exemplo

```json
{
  "cloudflare.idcbr.api_token": {
    "source": "op",
    "ref": "op://Personal/CF idcbr Token/credential",
    "metadata": {
      "account_id": "1783e2ca3a473ef8334a8b17df42878e",
      "email": "user@example.com",
      "zone_ids": ["abc...", "def..."],
      "default_zone": "abc...",
      "token_permissions": ["Account:Workers Scripts:Edit"],
      "token_expires_at": "2026-10-15T00:00:00Z"
    },
    "created_at": "2026-04-19T21:00:00Z",
    "updated_at": "2026-04-19T21:00:00Z",
    "last_validated_at": "2026-04-19T21:00:00Z",
    "fallback_sources": []
  }
}
```

---

Voltar para: [README.md](./README.md)
