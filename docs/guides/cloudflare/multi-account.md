# Multi-Account

Gerenciar múltiplas contas Cloudflare, switching entre contas e namespacing de credenciais.

## Nicknames canônicos

Convenção sugerida:

| Contexto | Nickname |
|----------|----------|
| Conta principal pessoal/empresa | `pessoal`, `empresa`, `idcbr` |
| Conta por cliente | `cliente-<nome>` (kebab-case) |
| Ambientes (dev/staging/prod) | `dev`, `staging`, `prod` |
| Tokens com escopo restrito | `<conta>-<escopo>` (ex: `idcbr-dns`) |

## Troca por request

Cada invocação escolhe a conta explicitamente:

```bash
call.sh GET /zones --account=pessoal
call.sh GET /zones --account=cliente-acme
call.sh GET /zones --account=idcbr-dns
```

## Permissões granulares

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

---

[Voltar para índice](../guides/cloudflare/README.md)
