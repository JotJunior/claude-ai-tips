# platform-related/neon/

Skills para gestao de Neon Postgres serverless: projects, branches, endpoints,
pooler config e anonymization. Branching Git-like com scale-to-zero.

## Conteudo

| Recurso | Tipo | Descricao |
|---------|------|-----------|
| [`skills/neon-credentials-setup/`](./skills/neon-credentials-setup/) | skill | Configura NEON_API_KEY + connection strings (pooled/unpooled) |
| [`skills/neon-create-project/`](./skills/neon-create-project/) | skill |Bootstrap project (region, pg_version, tier) via API/CLI |
| [`skills/neon-create-branch/`](./skills/neon-create-branch/) | skill | Branch Copy-on-Write para dev/test (snapshot timestamp) |
| [`skills/neon-merge-branch/`](./skills/neon-merge-branch/) | skill | Schema diff + apply migrations do branch para main |
| [`skills/neon-list-connections/`](./skills/neon-list-connections/) | skill | Lista pg_stat_activity + cancel/terminate queries |
| [`skills/neon-configure-pooler/`](./skills/neon-configure-pooler/) | skill | Pooler transaction mode (pgbouncer-compatible) |
| [`skills/neon-anonymize-branch/`](./skills/neon-anonymize-branch/) | skill | PII redaction em staging (email, cpf, phone —  via pg_anonymize) |

## Conceitos-chave

- **Project:** agrupamento logico (equivalente a "organizacao" ou "conta")
- **Branch:** copia isolada do banco (CoW) — usa para dev/test
- **Endpoint:** conexao ao banco (compute) — pode ser suspended (scale-to-zero)
- **Pooler:** Connection pooler (transaction mode) — pooled vs unpooled URL
- **Role:** papel Postgres (herda de project-level)
- **Database:** database dentro do project
- **CLI:** `neonctl` para operacoes em linha de comando
- **API:** `console.neon.tech/api/v2` (v2 endpoint)

## Stack

- **Postgres:** 15+ (versao definida por project)
- **Connection pooler:** pgBouncer em transaction mode
- **API:** REST v2 com API key authentication
- **CLI:** neonctl (cross-platform)

## Dependencias

- `neonctl` CLI instalado
- `psql` para execucao de queries (opcional)
- API key configurada via `cred-store`

## Como invocar

```
"crie um novo project para o cliente X na regiao sa-east-1"
"crie um branch de dev a partir do main para testar migrations"
"liste conexoes ativas e cancele queries stuck >30s"
"configure o pooler transaction mode para o endpoint production"
"anonymize branch staging: aplique redaction em email e cpf"
"merge branch feature-xyz: gere diff e aplique no main"
```

## Padroes-chave

- **Branching workflow:** branch para cada feature, merge via diff
- **Scale-to-zero:** suspend compute quando nao em uso (cold start ~500ms)
- **Pooler:** usar pooled URL em aplicacao (transaction mode)
- **Anonymization:** usar pg_anonymize ou similar para staging seguro
- **Connection strings:** distinguir pooled (transiente) vs unpooled (admin)
- **Credentials:** nunca hardcoded — usar cred-store

## Ver tambem

- [`../../language-related/python/`](../../language-related/python/) — codigo FastAPI/Pydantic
- [`../../data-related/postgres/`](../../data-related/postgres/) — queries e otimizacao
- [`../../global/skills/cred-store/`](../../global/skills/cred-store/) — gestao de credenciais
