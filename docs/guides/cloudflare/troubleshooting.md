# Troubleshooting

Erros comuns, diagnósticos e soluções.

## Tabela de erros

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

## Debugar retry

Aumentar verbosity no stderr:

```bash
call.sh GET /zones --account=idcbr --retry=5 2>&1 | tee /tmp/debug.log
grep -E '\[try|rate limited|erro' /tmp/debug.log
```

## Verificar token manualmente

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

## Dry-run antes de bulk delete

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

---

[Voltar para índice](../guides/cloudflare/README.md)
