# Credenciais Cloudflare no cred-store

Convencoes de armazenamento e consumo de credenciais CF pelo toolkit.
Complementa [`global/skills/cred-store/SKILL.md`](../../../global/skills/cred-store/SKILL.md).

## Key pattern

`cloudflare.<account-nickname>.api_token`

- `cloudflare` — provider literal
- `<account-nickname>` — identifica a conta ou contexto (kebab-case)
- `api_token` — tipo de credencial (CF moderno so usa API tokens scoped)

### Exemplos

| Key | Contexto |
|-----|----------|
| `cloudflare.idcbr.api_token` | Conta principal IDCBR |
| `cloudflare.pessoal.api_token` | Conta pessoal |
| `cloudflare.cliente-acme.api_token` | Conta de cliente |
| `cloudflare.idcbr-dns.api_token` | Token de mesma conta com escopo so DNS |
| `cloudflare.idcbr-workers.api_token` | Token de mesma conta com escopo so Workers |

Multiplos tokens por conta sao OK quando cada um tem escopo distinto
(principio de menor privilegio) — diferenciar pelo sufixo no nickname.

## Metadata fields tipicos

Campos guardados em `registry.json[<key>].metadata` (nao-sensiveis,
publicos):

| Campo | Tipo | Obrigatorio | Uso |
|-------|------|-------------|-----|
| `account_id` | string (32 hex) | sim | Substituicao `:account_id` em paths |
| `email` | string | nao | Auth legacy (quando aplicavel) |
| `zone_ids` | array[string] | nao | Zonas pre-cadastradas |
| `default_zone` | string (zone_id) | nao | Zona default para `cf-api-call` sem `--zone` |
| `token_permissions` | array[string] | nao | Escopos do token (para documentacao) |
| `token_expires_at` | ISO 8601 | nao | Expiracao para alertas |
| `dashboard_url` | string | nao | URL do dashboard (`https://dash.cloudflare.com/<account_id>/`) |

### Exemplo completo

```jsonc
{
  "cloudflare.idcbr.api_token": {
    "source": "op",
    "ref": "op://Personal/CF idcbr Token/credential",
    "metadata": {
      "account_id": "1783e2ca3a473ef8334a8b17df42878e",
      "email": "user@example.com",
      "zone_ids": [
        "ac2518a192ffd908938cffa4adac55bd",
        "9f8a7b6c5d4e3f2a1b0c9d8e7f6a5b4c"
      ],
      "default_zone": "ac2518a192ffd908938cffa4adac55bd",
      "token_permissions": [
        "Account:Workers Scripts:Edit",
        "Account:D1:Edit",
        "Zone:DNS:Edit",
        "Zone:Zone Settings:Read"
      ],
      "token_expires_at": "2026-10-15T00:00:00Z",
      "dashboard_url": "https://dash.cloudflare.com/1783e2ca3a473ef8334a8b17df42878e/"
    },
    "created_at": "2026-04-19T21:00:00Z",
    "last_validated_at": "2026-04-19T21:00:00Z",
    "fallback_sources": []
  }
}
```

## Fontes recomendadas por caso de uso

### 1Password (`source: op`) — **recomendado**

Para desenvolvedores individuais com 1Password instalado.

- **Prós**: criptografia, sync multi-device, biometria (Touch ID),
  sharing controlado em vaults compartilhados, audit do 1P
- **Contras**: requer `op` CLI + signin ativo; sessao expira

Convencao de URI:

```
op://<vault>/CF <nickname> Token/credential
```

Exemplos:
- `op://Personal/CF idcbr Token/credential`
- `op://Work/CF cliente-acme Token/credential`

Campo recomendado no item 1P:
- **Title**: `CF <nickname> Token`
- **Username**: email da conta
- **Password** (marcado como credential): o token
- **Category**: API Credential
- **Notes**: permissoes do token, data de criacao

### macOS Keychain (`source: keychain`) — alternativa sem 1Password

Para macOS sem 1Password.

- **Prós**: nativo, criptografia, sem dependencia externa
- **Contras**: macOS apenas; gerenciamento menos amigavel

Convencao de service name:

```
claude-cloudflare-<nickname>-api-token
```

Exemplos:
- `claude-cloudflare-idcbr-api-token`
- `claude-cloudflare-pessoal-api-token`

Comandos equivalentes:

```bash
# Adicionar
security add-generic-password \
  -s "claude-cloudflare-idcbr-api-token" \
  -a "user@example.com" \
  -w "$(read -rs; echo "$REPLY")"

# Ler
security find-generic-password -s "claude-cloudflare-idcbr-api-token" -w

# Remover
security delete-generic-password -s "claude-cloudflare-idcbr-api-token"
```

### Arquivo protegido (`source: file`) — ultimo recurso

Para ambientes sem 1P nem Keychain (Linux sem equivalente, containers).

- **Prós**: simples, funciona em qualquer sistema
- **Contras**: texto claro, requer disciplina de permissoes

Path: `~/.claude/credentials/files/cloudflare-<nickname>-api-token.secret`

Requer:
- `chmod 600`
- Sem symlinks
- Sem newline final
- Diretorio pai `~/.claude/credentials/files/` com `chmod 700`

### Variavel de ambiente (`source: env`) — CI e sessao temporaria

Para CI/CD, container runs ou troubleshooting.

- **Prós**: nativo, funciona com tooling padrao (wrangler, gh)
- **Contras**: volatil (so na sessao), vaza em `ps -E`

Convencao:

```bash
export CLOUDFLARE_API_TOKEN="..."            # token principal
export CLOUDFLARE_ACCOUNT_ID="..."           # account id
export CLOUDFLARE_EMAIL="..."                # auth legacy (opcional)
export CLOUDFLARE_ZONE_ID_<NICKNAME>="..."   # zona especifica (opcional)
```

`cf-api-call` sem `--account=<nick>` cai em `CLOUDFLARE_API_TOKEN`/
`CLOUDFLARE_ACCOUNT_ID` automaticamente — util em CI.

## Multi-conta: onboarding de nova conta

Sequencia recomendada:

1. Criar API Token no dashboard da conta
   (`https://dash.cloudflare.com/profile/api-tokens`)
2. Anotar `account_id` da URL do dashboard
3. Decidir nickname canonico (`<cliente>` ou `<projeto>`)
4. Rodar `/cf-credentials-setup <nickname>`
5. Skill valida via `/user/tokens/verify` antes de gravar
6. Pronto — todas as skills CF agora aceitam `--account=<nickname>`

## Rotacao de token

CF tokens expirados retornam erro 10000. Processo de rotacao:

1. Criar token novo no dashboard (mesmo escopo do antigo)
2. Atualizar fonte:
   - **1P**: editar item existente, trocar valor
   - **Keychain**: `security delete-generic-password` + `security add-generic-password`
   - **File**: `echo -n "<novo>" > <path> && chmod 600 <path>`
3. Validar: `cf-api-call GET /user/tokens/verify --account=<nick>`
4. Atualizar `registry.json[<key>].last_validated_at` (manualmente ou via
   skill futura `cf-credentials-rotate`)
5. Revogar token antigo no dashboard

Nao deletar a entry do registry — so atualizar o segredo na fonte. Isso
preserva historico (`created_at`) e metadata.

## Permissoes granulares recomendadas

Principio de menor privilegio: criar tokens com escopo minimo necessario.

### Token para DNS (read + write)

```
Zone / DNS / Edit
```

Filtro: apenas as zonas gerenciadas.

### Token para Workers + D1 + KV + R2

```
Account / Workers Scripts / Edit
Account / D1 / Edit
Account / Workers KV Storage / Edit
Account / Workers R2 Storage / Edit
```

### Token para CI de deploy

```
Account / Workers Scripts / Edit
User / User Details / Read                (necessario para /user/tokens/verify)
```

### Token read-only para observability

```
Account / Account Analytics / Read
Zone / Zone Analytics / Read
Account / Logs / Read
```

### Token admin (dev local)

Usar com cautela. Nao commitar em CI.

```
All users / All accounts / Full Access  (NAO usar, prefira scoped)
```

## Auditoria

Cada operacao via `cf-api-call` registra em
`~/.claude/credentials/cloudflare/<nickname>/audit.log`:

```
2026-04-19T21:00:00Z GET /zones account=idcbr status=200 success=true
2026-04-19T21:01:15Z POST /zones/abc/dns_records account=idcbr status=200 success=true
2026-04-19T21:05:22Z DELETE /zones/abc/dns_records/xyz account=idcbr status=200 success=true
```

Revisao periodica recomendada:

```bash
tail -f ~/.claude/credentials/cloudflare/idcbr/audit.log
```

Para rotacao de audit.log (cresce indefinidamente):

```bash
cd ~/.claude/credentials/cloudflare/idcbr/
mv audit.log "audit-$(date +%Y%m).log"
touch audit.log
```

## Seguranca — checklist

- [ ] Token criado no dashboard com escopo minimo
- [ ] Token validado via `/user/tokens/verify`
- [ ] `account_id` correto nos metadata
- [ ] Fonte preferida: `op` > `keychain` > `file`
- [ ] `~/.claude/credentials/` em `chmod 700`
- [ ] `~/.claude/credentials/registry.json` em `chmod 600`
- [ ] `.gitignore` de `~/.claude/credentials/` ignora tudo
- [ ] Audit log monitorado
- [ ] Expiracao do token anotada em `token_expires_at`
- [ ] Rotacao planejada a cada 6-12 meses

## Erros comuns

### "credencial cloudflare.idcbr.api_token nao registrada"

Rodar `/cf-credentials-setup idcbr`.

### "path contem :account_id mas conta nao resolve account_id"

Metadata incompleto. Editar entry para incluir `account_id`:

```bash
# Via jq (cuidado — backup antes)
jq '.["cloudflare.idcbr.api_token"].metadata.account_id = "1783..."' \
   ~/.claude/credentials/registry.json > /tmp/r.json && \
   mv /tmp/r.json ~/.claude/credentials/registry.json
```

Ou re-rodar `cf-credentials-setup` (ele detecta entry existente e oferece
atualizar metadata).

### "op: not signed in"

```bash
op signin
# ou trocar para biometric unlock se configurado
```

### "Authentication error (code 10000)"

Token invalido, expirado ou revogado. Rotacionar conforme secao acima.

### "Account forbidden (code 10001)"

Token valido mas sem escopo na conta pretendida. Recriar com escopo
correto no dashboard da conta-alvo.
