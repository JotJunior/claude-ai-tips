---
name: cred-store-setup
description: |
  Use quando o usuario precisa REGISTRAR uma nova credencial (API token,
  password, key) no credential store local para ser consumida por outras
  skills. Tambem quando mencionar "setup credencial", "registrar token",
  "adicionar api key", "configurar credenciais", "salvar secret",
  "onboard credential". Oferece cascata de opcoes de armazenamento
  (1Password > Keychain > arquivo protegido) com prompts interativos e
  valida o segredo antes de gravar quando possivel. NAO use para APENAS
  LER credencial ja registrada (use cred-store).
argument-hint: "[<credential-key>] [--source=op|keychain|file] [--validate-cmd=<cmd>]"
allowed-tools:
  - Bash
  - Read
  - Write
  - Edit
  - AskUserQuestion
---

# Skill: Credential Store Setup (interativo)

Registra uma nova credencial no credential store local. Interativa por
padrao — guia o usuario por escolha de fonte, coleta do segredo e teste
de validacao.

## Fluxo interativo

### Etapa 1: identificar a credencial

Se `<credential-key>` nao foi passada como argumento, perguntar:

> Qual credencial voce quer registrar? (formato: `<provider>.<account>.<tipo>`)
>
> Exemplos:
> - `cloudflare.idcbr.api_token`
> - `neon.production.api_key`
> - `elasticsearch.smartgw.password`

Validar formato (regex: `^[a-z0-9-]+\.[a-z0-9-]+\.[a-z0-9_-]+$`).

### Etapa 2: detectar fontes disponiveis

Rodar no startup:

```bash
# 1Password CLI instalado?
command -v op >/dev/null && HAS_OP=1 || HAS_OP=0

# Keychain disponivel (macOS only)?
[ "$(uname)" = "Darwin" ] && command -v security >/dev/null && HAS_KC=1 || HAS_KC=0
```

### Etapa 3: escolher fonte

Usar `AskUserQuestion` com opcoes dinamicas baseadas no que esta disponivel:

**Sempre oferecer:**
- `file` — arquivo protegido (chmod 600) em `~/.claude/credentials/files/`

**Se `HAS_OP=1`:**
- `op` — 1Password CLI (recomendado: criptografado, persistente, biometria)

**Se `HAS_KC=1`:**
- `keychain` — macOS Keychain (criptografado, persistente)

**Sempre oferecer:**
- `env` — variavel de ambiente (volatil; registra apenas o NOME da env var,
  nao o valor)

Ordem de recomendacao exibida ao usuario:
`op > keychain > file > env`

### Etapa 4: coletar metadados

Perguntar metadados publicos (nao-sensiveis) associados a credencial:

- **Cloudflare**: `account_id`, `email` (se global key), `zone_ids` (opcional)
- **Neon**: `project_id`, `connection_string_host` (sem password)
- **Elasticsearch**: `host`, `port`, `user`, `use_https`
- **Postgres**: `host`, `port`, `database`, `user` (sem password)

Esses metadados vao para `registry.json` junto com a entry da key e ficam
disponiveis para consumidores que passarem `--with-metadata` no `resolve.sh`.

### Etapa 5: coletar o segredo

**Nunca aceitar segredo via argumento de linha de comando** (vaza em
shell history e `ps`). Sempre via prompt com `read -rs` (sem echo) ou
interface equivalente.

Para `op`: perguntar o URI (`op://<vault>/<item>/<field>`) e testar com
`op read "$URI"` para verificar que o valor existe (sem imprimir).

Para `keychain`: ler segredo via prompt, gravar com
`security add-generic-password -s claude-<slug> -a <user> -w <value>`.

Para `file`: ler segredo via prompt, gravar em
`~/.claude/credentials/files/<slug>.secret` com `chmod 600`.

Para `env`: perguntar apenas o NOME da variavel (nao o valor) e registrar
a referencia no registry.

### Etapa 6: validar (opcional, recomendado)

Se `--validate-cmd=<cmd>` foi passado ou se a skill conhece comando de
validacao para o provedor, testar o segredo recem-registrado:

| Provider | Comando de validacao |
|---|---|
| Cloudflare | `curl -s -H "Authorization: Bearer $SECRET" https://api.cloudflare.com/client/v4/user/tokens/verify` |
| Neon | `curl -s -H "Authorization: Bearer $SECRET" https://console.neon.tech/api/v2/users/me` |
| Elasticsearch | `curl -s -u elastic:$SECRET "$HOST:$PORT/_cluster/health"` |
| Postgres | `psql "$CONN_STR" -c 'SELECT 1'` |

Validacoes que passam -> gravar no registry.
Validacoes que falham -> NAO gravar; reportar erro ao usuario e oferecer retry.

### Etapa 7: registrar em `registry.json`

Estrutura da entry:

```jsonc
{
  "cloudflare.idcbr.api_token": {
    "source": "op",
    "ref": "op://Personal/CF IDCBR Token/credential",
    "metadata": {
      "account_id": "1783e2ca3a473ef8334a8b17df42878e",
      "email": "user@example.com"
    },
    "created_at": "2026-04-19T18:32:11Z",
    "updated_at": "2026-04-19T18:32:11Z",
    "last_validated_at": "2026-04-19T18:32:11Z",
    "fallback_sources": []
  }
}
```

### Etapa 8: audit log

Registrar em `~/.claude/credentials/audit.log`:

```
2026-04-19T18:32:11Z register key=cloudflare.idcbr.api_token source=op validated=true
```

### Etapa 9: confirmar ao usuario

Exibir:

```
credencial registrada: cloudflare.idcbr.api_token
fonte: 1Password (op://Personal/CF IDCBR Token/credential)
validacao: ok
uso:
  bash <repo>/global/skills/cred-store/scripts/resolve.sh cloudflare.idcbr.api_token
```

## Argumentos nao-interativos (para automacao)

Quando todos os parametros sao passados, a skill pula os prompts:

```bash
cred-store-setup \
  --key=cloudflare.idcbr.api_token \
  --source=op \
  --ref="op://Personal/CF IDCBR Token/credential" \
  --metadata='{"account_id":"1783..."}' \
  --validate-cmd="curl -s -H 'Authorization: Bearer $SECRET' https://api.cloudflare.com/client/v4/user/tokens/verify | jq -e '.success'"
```

Nao interativo NAO pede segredo — assume que a `ref` aponta para o
valor (1Password URI, keychain service name, ou env var name). Para `file`,
a skill LE do stdin se `--source=file` for usado sem prompt.

## Gotchas

### Segredo em argumento de linha vaza em shell history e `ps`

Mesmo em modo nao-interativo, a skill NUNCA aceita o valor literal em
`--secret=...`. Para `file`, le via stdin. Para outras fontes, espera que
o segredo ja esteja armazenado na fonte (op/keychain/env) e so registra a
referencia.

### Validar antes de gravar — nao ao contrario

Se voce gravar a entry e DEPOIS validar, um erro de digitacao em op URI
deixa lixo no registry. Sempre validar primeiro (quando possivel) e so
gravar em caso de sucesso.

### Keychain service name tem limite de caracteres

`security add-generic-password` aceita service names de ate 255 caracteres,
mas ferramentas GUI truncam em ~63. Manter slugs curtos (max 50 chars).

### op vault name com espacos quebra URI

`op://My Vault/Item/field` nao funciona; usar `op://MyVault/Item/field` ou
escape `%20`. Ao pedir o URI ao usuario, mostrar exemplo com vault
canonico (sem espacos).

### Nao auto-criar registry.json se ele NAO existe

Se `~/.claude/credentials/registry.json` nao existe, chamar
`scripts/init-store.sh` (que cria o diretorio com `.gitignore` correto)
antes de gravar. Nao assumir que o diretorio esta pronto.

### .gitignore em ~/.claude/credentials/ — essencial

`init-store.sh` cria um `.gitignore` com:

```
# Nunca versionar conteudo deste diretorio
*
!.gitignore
!README.md
```

Ou seja, tudo e ignorado por default. Isso protege contra o usuario ter
`~/.claude/` versionado por acidente (ocorre quando o usuario
git-versiona `~/` inteiro).

### Atualizar credencial existente = UPDATE, nao INSERT

Se a key ja existe em `registry.json`, perguntar antes de sobrescrever.
Se sobrescrever, atualizar `updated_at` e manter `created_at` original.
NAO duplicar entries.

### Remover credencial NAO e responsabilidade desta skill

Para deletar, usar `cred-store-remove` (skill separada, futura). Esta
skill e append/update only.

## Ver tambem

- `cred-store` — skill de LEITURA de credenciais registradas
- `global/skills/cred-store/scripts/init-store.sh` — inicializa o diretorio
