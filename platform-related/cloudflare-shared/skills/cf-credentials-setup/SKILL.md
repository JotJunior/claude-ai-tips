---
name: cf-credentials-setup
description: |
  Use quando o usuario precisa registrar uma nova credencial da Cloudflare
  (API token scoped) no cred-store para consumo por skills de
  platform-related/cloudflare-*. Tambem quando mencionar "cadastrar token
  cloudflare", "configurar cf account", "setup cloudflare", "adicionar
  conta cloudflare", "cf credentials", "onboard cloudflare". Wrapper
  pre-configurado sobre cred-store-setup com validacao via GET
  /user/tokens/verify, metadata fields tipicos (account_id, email,
  zone_ids), e recomendacao de escopo de token. NAO use para ler
  credencial ja registrada (use cf-api-call ou cred-store).
argument-hint: "[<account-nickname>] [--source=op|keychain|file]"
allowed-tools:
  - Bash
  - Read
  - Write
  - Edit
  - AskUserQuestion
---

# Skill: Cloudflare Credentials Setup

Wrapper pre-configurado sobre `cred-store-setup` para registro de API
tokens da Cloudflare. Cobre o fluxo tipico end-to-end: criacao do token
no dashboard, escolha de fonte de armazenamento, coleta de metadados
(account_id, email), validacao contra `/user/tokens/verify`, gravacao
no registry.

## Pre-requisitos

- `cred-store` inicializado (`global/skills/cred-store/scripts/init-store.sh`)
- Acesso ao dashboard Cloudflare para criar/obter API token
- Uma das fontes de armazenamento disponivel:
  - `op` (1Password CLI) — recomendado
  - `keychain` (macOS Keychain)
  - `file` (arquivo `chmod 600`)

## Fluxo interativo

### Etapa 1: identificar a conta

Perguntar nickname da conta (ex: `idcbr`, `pessoal`, `cliente-xyz`). Se
passado como argumento, pular.

Validar:
- Regex `^[a-z0-9-]+$`
- Nao colidir com key ja registrada (checar `registry.json`)

Key final sera: `cloudflare.<nickname>.api_token`

### Etapa 2: recomendar escopo de token

**Nunca** usar "Global API Key" da Cloudflare — deprecada para uso programatico.
Sempre API Token scoped.

Orientar o usuario a criar token em:

```
https://dash.cloudflare.com/profile/api-tokens
```

Escopos recomendados por caso de uso:

| Caso | Permissoes |
|------|------------|
| Workers + D1 + KV + R2 | `Account:Workers Scripts:Edit`, `Account:Workers KV:Edit`, `Account:D1:Edit`, `Account:R2:Edit` |
| DNS management | `Zone:DNS:Edit` em zonas especificas (ou All Zones) |
| Access management | `Account:Access: Apps and Policies:Edit` |
| WAF / Security | `Zone:Firewall Services:Edit` |
| Analytics (read-only) | `Account:Analytics:Read`, `Zone:Analytics:Read` |
| Workers Builds triggers | `Account:Workers Scripts:Edit` + `User:Memberships:Read` |
| Tudo (dev, alto risco) | `Account:*:Edit` + `Zone:*:Edit` |

Imprimir a recomendacao correspondente ao uso pretendido (perguntar via
`AskUserQuestion`).

### Etapa 3: detectar fontes disponiveis

Mesmo que `cred-store-setup`:

```bash
HAS_OP=$(command -v op >/dev/null && echo 1 || echo 0)
HAS_KC=$([ "$(uname)" = "Darwin" ] && command -v security >/dev/null && echo 1 || echo 0)
```

### Etapa 4: escolher fonte

`AskUserQuestion` com opcoes dinamicas. Preferencia recomendada:

1. `op` (se disponivel) — `op://Personal/CF <nickname> Token/credential` ou convencao do vault
2. `keychain` — service `claude-cloudflare-<nickname>-api-token`
3. `file` — `~/.claude/credentials/files/cloudflare-<nickname>-api-token.secret`

### Etapa 5: coletar o segredo

**Nunca aceitar via argumento.** Prompt com `read -rs`.

Para `op`: perguntar URI; testar `op read "$URI"` para confirmar existencia
sem imprimir.

Para `keychain`: `read -rs` + `security add-generic-password -s claude-cloudflare-<nick>-api-token -a <user> -w "$SECRET"`.

Para `file`: `read -rs` + `echo -n "$SECRET" > "$FILE" && chmod 600 "$FILE"`.

### Etapa 6: coletar metadata

Perguntar via `AskUserQuestion`:

- **account_id** (obrigatorio) — 32 hex chars. Exibido no dashboard em
  qualquer tela de Account. Se o usuario nao souber, orientar a visitar
  `https://dash.cloudflare.com/` e pegar da URL.
- **email** (opcional) — email da conta, util para auth legacy
- **zone_ids** (opcional, lista) — zonas pre-cadastradas para uso em
  `--zone=<nick>`. Pode ser preenchido depois.
- **default_zone** (opcional) — zona default quando `--zone` nao passado

### Etapa 7: validar o token

Chamada a `GET /user/tokens/verify` via `cf-api-call` em modo sem audit
(validacao nao e operacao de negocio):

```bash
bash ../cf-api-call/scripts/call.sh GET /user/tokens/verify \
  --account=<nickname> --no-audit 2>&1 | jq -e '.success == true'
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

Se `.success == false` ou `.result.status != "active"`:
- **NAO gravar** a credencial
- Reportar erro ao usuario com o message.code (ex: 10000)
- Oferecer retry com outro token

### Etapa 8: registrar

Invocar `cred-store-setup` em modo nao-interativo com os parametros
coletados. Entry final em `registry.json`:

```jsonc
{
  "cloudflare.idcbr.api_token": {
    "source": "op",
    "ref": "op://Personal/CF idcbr Token/credential",
    "metadata": {
      "account_id": "1783e2ca3a473ef8334a8b17df42878e",
      "email": "user@example.com",
      "zone_ids": ["abc...", "def..."],
      "default_zone": "abc...",
      "token_permissions": ["Account:Workers:Edit", "Zone:DNS:Edit"]
    },
    "created_at": "2026-04-19T21:00:00Z",
    "last_validated_at": "2026-04-19T21:00:00Z",
    "fallback_sources": []
  }
}
```

### Etapa 9: confirmar + proximos passos

```
credencial registrada: cloudflare.idcbr.api_token
fonte: 1Password
validacao: ok (token ativo, status=active)

uso via cf-api-call:
  bash cf-api-call/scripts/call.sh GET /zones --account=idcbr --format=pretty

listar todas as contas CF registradas:
  bash cred-store/scripts/list.sh --provider=cloudflare
```

## Argumentos nao-interativos (automacao)

Aceita parametros pre-definidos para automacao:

```bash
cf-credentials-setup \
  --account=idcbr \
  --source=op \
  --ref="op://Personal/CF idcbr Token/credential" \
  --account-id="1783e2ca3a473ef8334a8b17df42878e" \
  --email="user@example.com" \
  --default-zone="abc123"
```

Metadados podem ser passados via `--account-id`, `--email`, `--zone-ids` (vírgulas),
`--default-zone`. O fluxo pula as perguntas correspondentes.

## Gotchas

### Token Global API Key vs Scoped Token

CF tem dois formatos de credencial:

| Formato | Como usar | Recomendacao |
|---------|-----------|-------------|
| **Global API Key** | headers `X-Auth-Key` + `X-Auth-Email` | **NAO usar** — maximo risco, nao-scoped |
| **API Token** | header `Authorization: Bearer <token>` | **usar sempre** — scoped, rotacionavel |

Esta skill so aceita API Tokens. Se o usuario tentar registrar Global Key,
avisar e recusar.

### Validacao nao garante escopo correto

`/user/tokens/verify` confirma que o token eh **valido**, nao que tem
os escopos necessarios para as operacoes futuras. Se skills subsequentes
falharem com 403, investigar escopo no dashboard.

### account_id nao eh opcional para a maioria dos endpoints

Muitos endpoints CF usam `/accounts/:account_id/...`. Nao ter account_id
no metadata impede uso de `--account=<nick>` com path injection. Se o
usuario nao sabe o account_id, orientar:

```
https://dash.cloudflare.com/  -->  URL contem /dash.cloudflare.com/<account_id>/
```

### Token de mesma conta mas scopes diferentes

Um mesmo `<account_id>` pode ter multiplos tokens com escopos distintos
(ex: `idcbr-dns-only` para DNS, `idcbr-workers-full` para Workers). A
chave `cloudflare.<nick>.api_token` distingue por nickname — usar nicks
descritivos quando tiver multiplos tokens da mesma conta.

### Cross-account operations

Se o usuario opera multiplas contas frequentemente, padronizar nicks
para facilitar troca (`cliente-acme`, `cliente-bcd`, `pessoal`,
`empresa`). O `cf-api-call --account=<nick>` troca a conta por request.

### Rotation e expiration

CF tokens podem ter expiration. A skill nao monitora — mas ao chamar
`/user/tokens/verify`, o `result.expires_on` aparece se definido. Pode
ser gravado em metadata como `token_expires_at` para alertas futuros
(fora do escopo desta skill).

### Validacao com `--no-audit`

A chamada `GET /user/tokens/verify` durante validacao NAO deve entrar
no audit log de operacoes de negocio. Usar `--no-audit` no cf-api-call.

## Scripts

Esta skill e primariamente declarativa (orquestra `cred-store-setup`
internamente). Nao tem scripts proprios alem do fluxo documentado.

## Ver tambem

- [`cred-store-setup`](../../../../global/skills/cred-store-setup/) — base generica
- [`cf-api-call`](../cf-api-call/) — consumidor primario das credenciais
- [`references/credential-storage.md`](../../references/credential-storage.md) — padroes de convencao
