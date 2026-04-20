# Setup

Credenciais, contas, primeiros passos e autenticação via wrangler.

## Pré-requisitos

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

## Criar API Token no dashboard

1. Acesse [`https://dash.cloudflare.com/profile/api-tokens`](https://dash.cloudflare.com/profile/api-tokens)
2. Clique em **Create Token**
3. Use um template ou **Create Custom Token**
4. Aplique **escopo mínimo** necessário

### Escopos recomendados por caso de uso

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

## Registrar via `cf-credentials-setup`

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

## Validar

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

---

[Voltar para índice](../guides/cloudflare/README.md)
