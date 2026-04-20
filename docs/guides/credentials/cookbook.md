# Cookbook — Exemplos Práticos

## Consumindo credenciais

### Via `resolve.sh`

Sintaxe:

```bash
bash ~/Sistemas/claude-ai-tips/global/skills/cred-store/scripts/resolve.sh \
  <key> \
  [--format=raw|env|json] \
  [--with-metadata]
```

#### Formato `raw` (default)

Retorna apenas o segredo em stdout:

```bash
TOKEN=$(bash .../resolve.sh cloudflare.idcbr.api_token)
curl -H "Authorization: Bearer $TOKEN" https://api.cloudflare.com/client/v4/zones
```

#### Formato `env`

Retorna `KEY=value`, shell-eval friendly:

```bash
eval "$(bash .../resolve.sh cloudflare.idcbr.api_token --format=env)"
echo "$CLOUDFLARE_API_TOKEN"   # disponível
```

Nome da env derivado da key:

- `cloudflare.idcbr.api_token` → `CLOUDFLARE_API_TOKEN`
- `neon.production.api_key` → `NEON_API_KEY`
- `elasticsearch.local.password` → `ELASTICSEARCH_PASSWORD`

#### Formato `json`

Retorna objeto estruturado:

```bash
bash .../resolve.sh cloudflare.idcbr.api_token --format=json --with-metadata
```

```json
{
  "secret": "...",
  "metadata": {
    "account_id": "1783...",
    "email": "user@example.com"
  },
  "source": "op"
}
```

Útil para parse programático:

```bash
SECRET=$(bash .../resolve.sh <key> --format=json | jq -r .secret)
ACCOUNT=$(bash .../resolve.sh <key> --format=json --with-metadata | jq -r .metadata.account_id)
```

### Com `--with-metadata`

Injeta metadata pública como env vars adicionais:

```bash
eval "$(bash .../resolve.sh cloudflare.idcbr.api_token --format=env --with-metadata)"
# Disponível: CLOUDFLARE_API_TOKEN, CLOUDFLARE_ACCOUNT_ID, CLOUDFLARE_EMAIL,
#            CLOUDFLARE_ZONE_IDS, CLOUDFLARE_DEFAULT_ZONE, etc.
```

### Exit codes

| Code | Significado |
|------|-------------|
| `0` | Resolveu com sucesso |
| `1` | Key não encontrada OU nenhuma fonte funcionou |
| `2` | Permissões inválidas em arquivo (>600 ou symlink) |
| `3` | 1Password trancado/não instalado e era única opção |
| `4` | Argumento inválido |

### Pattern em skills que integram

```bash
#!/bin/sh
set -eu

KEY="${1:-cloudflare.idcbr.api_token}"

if ! TOKEN=$(bash /path/to/resolve.sh "$KEY" 2>/dev/null); then
  RC=$?
  case "$RC" in
    1) echo "credencial '$KEY' não registrada. Rode: /cf-credentials-setup $KEY" >&2 ;;
    3) echo "1Password trancado. Rode: op signin" >&2 ;;
    *) echo "erro resolver credencial (exit $RC)" >&2 ;;
  esac
  exit "$RC"
fi

# Usa $TOKEN em chamada HTTP
curl -H "Authorization: Bearer $TOKEN" "$API_URL"
unset TOKEN
```

---

## Cenários de uso

### Registrar Cloudflare via `cf-credentials-setup`

Skill específica de CF que pré-configura escopos recomendados:

```
/cf-credentials-setup pessoal
```

Fluxo: ver [cloudflare.md](../cloudflare/setup.md).

### Registrar provider genérico

```
/cred-store-setup neon.production.api_key
```

Prompts genéricos sem validação específica (a skill genérica não conhece
`/user/tokens/verify` da CF).

### Múltiplas contas do mesmo provider

Use nicknames distintos:

```
/cf-credentials-setup idcbr
/cf-credentials-setup pessoal
/cf-credentials-setup cliente-acme
```

Cada uma vira `cloudflare.<nick>.api_token` separada. Escolha por request:

```bash
bash .../call.sh GET /zones --account=cliente-acme
```

### Tokens com escopos distintos da mesma conta

Separar por sufixo no nickname:

```
/cf-credentials-setup idcbr-dns       # token com Zone:DNS:Edit apenas
/cf-credentials-setup idcbr-workers   # token com Account:Workers:Edit
/cf-credentials-setup idcbr-admin     # token full (uso raro)
```

Princípio de menor privilégio: cada skill usa o token mínimo necessário.

### Rotação de token

CF tokens podem expirar ou ser revogados. Rotação:

```
1. Criar novo token no dashboard CF (mesmo escopo)
2. Atualizar fonte:
   - op: editar item existente, trocar campo 'credential'
   - keychain: security delete... + security add-generic-password...
   - file: echo -n "<novo>" > .../files/<slug>.secret
3. Validar:
   bash .../call.sh GET /user/tokens/verify --account=<nick>
4. Revogar token antigo no dashboard CF
5. Atualizar registry.json (opcional — updated_at automático no setup)
```

Skill futura `cred-store-rotate` (planejada) vai automatizar esse fluxo.

### Migrar de `file` para `op`

```bash
# 1. Ler valor atual
OLD_SECRET=$(cat ~/.claude/credentials/files/cloudflare-idcbr-api-token.secret)

# 2. Criar item no 1Password
op item create \
  --category="API Credential" \
  --title="CF idcbr Token" \
  --vault=Personal \
  credential="$OLD_SECRET"

# 3. Atualizar registry.json (editar manualmente ou rodar setup de novo)
#    Trocar:
#      "source": "file" → "source": "op"
#      "ref": "cloudflare-idcbr-api-token" → "ref": "op://Personal/CF idcbr Token/credential"

# 4. Testar
bash .../resolve.sh cloudflare.idcbr.api_token

# 5. Remover arquivo
rm ~/.claude/credentials/files/cloudflare-idcbr-api-token.secret
unset OLD_SECRET
```

### Audit trail

Arquivo global em `~/.claude/credentials/audit.log`:

```
2026-04-19T21:00:00Z resolve key=cloudflare.idcbr.api_token source=op exit=0
2026-04-19T21:01:15Z resolve key=cloudflare.idcbr.api_token source=op exit=0
2026-04-19T22:30:00Z resolve key=neon.production.api_key source=keychain exit=0
```

Rotação manual (audit.log não rotaciona automaticamente):

```bash
cd ~/.claude/credentials/
mv audit.log "audit-$(date +%Y%m).log"
touch audit.log && chmod 600 audit.log
```

Audit por provider (quando `cf-api-call` loga):

```
~/.claude/credentials/cloudflare/idcbr/audit.log
```

Formato:

```
2026-04-19T21:00:00Z GET /zones account=idcbr status=200 success=true
2026-04-19T21:01:15Z POST /zones/abc/dns_records account=idcbr status=200 success=true
2026-04-19T21:05:22Z DELETE /zones/abc/dns_records/xyz account=idcbr status=200 success=true
```

---

## Segurança

### Checklist obrigatório

Antes de usar em projeto real:

- [ ] Bootstrap rodado (`init-store.sh`)
- [ ] `~/.claude/credentials/` em `chmod 700`
- [ ] `registry.json` em `chmod 600`
- [ ] `files/*.secret` em `chmod 600`
- [ ] `.gitignore` do store ignora tudo
- [ ] Nenhum segredo em `registry.json` (verificar manualmente:
      `cat registry.json | grep -iE '(sk-|token|password|secret)'`)
- [ ] Audit log monitorado (rotação periódica)
- [ ] Tokens com escopos mínimos (princípio de menor privilégio)
- [ ] Expiração registrada em `token_expires_at` (alertas futuros)
- [ ] Plano de rotação (6-12 meses)

### Anti-patterns

```bash
# ❌ NÃO: segredo em argumento de CLI (vaza em ps + histórico)
cred-store-setup --secret="sk-xxx..."

# ❌ NÃO: commit de .claude/credentials/
git add ~/.claude/credentials/    # .gitignore deve prevenir

# ❌ NÃO: chmod 644 em arquivo secret
chmod 644 ~/.claude/credentials/files/*.secret

# ❌ NÃO: echo com newline
echo "$TOKEN" > secret            # adiciona \n

# ❌ NÃO: log que imprime $TOKEN
echo "[DEBUG] token=$TOKEN"        # vai pra stdout/stderr/log

# ❌ NÃO: env var persistente em ~/.bashrc, ~/.zshrc
export CLOUDFLARE_API_TOKEN="..."  # vaza em subshell, ps, core dumps
```

### Por que `registry.json` nunca contém segredo

Múltiplas camadas de risco:

1. **Backup automático** (Time Machine, Dropbox, iCloud) pode copiar sem
   criptografia
2. **Leak acidental** (upload de arquivo, screenshot, compartilhamento)
3. **Chmod escalonado** (umask do usuário pode mudar permissões em cópia)
4. **Histórico git acidental** (se `~/` é git-versionado por engano)
5. **Dumps de memória** (swap pode ter conteúdo do arquivo)

Por isso: segredo vive em **keystore criptografado** (op/keychain) ou
**arquivo dedicado chmod 600 fora do versionamento**. Registry só sabe
**onde buscar**, não o que é.

---

Voltar para: [README.md](./README.md)
