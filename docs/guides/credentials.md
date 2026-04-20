# Gestão de Credenciais

Guia prático do sistema `cred-store` + `cred-store-setup` — armazenamento e
consumo de credenciais externas (API tokens, passwords, connection strings)
de forma segura e agnóstica.

## Visão geral

O problema: skills do toolkit precisam autenticar contra APIs externas
(Cloudflare, Neon, Elasticsearch, etc.) sem:

- Vazar segredos em arquivos versionados
- Acoplar cada skill à sua própria lógica de secrets
- Forçar dependência de tooling específico (1Password, Keychain)
- Perder rastreabilidade de operações sensíveis

A solução: um **credential store agnóstico** com cascata de fontes, da mais
segura para a menos segura, onde cada credencial é identificada por uma
**key** estável e segredos **nunca** ficam em arquivo versionado.

Princípios:

1. **Segredos nunca em `registry.json`** — apenas referências
2. **Cascata de resolução** — env → 1Password → Keychain → arquivo
3. **Audit append-only** — rastreio de operações sem valores
4. **Permissões estritas** — diretórios `700`, arquivos `600`
5. **Agnóstico de provider** — mesma API para CF, Neon, ES, qualquer

## Arquitetura

### Cascata de fontes

```
                  resolve.sh <key>
                         │
                         ▼
        ┌─────────────────────────────────┐
        │  Lê entry em registry.json      │
        │  → source, ref, metadata         │
        └─────────────────────────────────┘
                         │
                         ▼
        ┌─────────────────────────────────┐
        │  Tenta fonte primária           │
        └─────────────────────────────────┘
                         │
    ┌────────────────────┼────────────────────┐
    ▼                    ▼                    ▼
┌────────┐          ┌────────┐          ┌────────┐
│  env   │          │   op   │          │keychain│
│        │          │ (1Pwd) │          │ (macOS)│
└────────┘          └────────┘          └────────┘
                         │
                         ▼
                    ┌────────┐
                    │  file  │
                    │ (600)  │
                    └────────┘
                         │
                  Primeiro sucesso vence
```

### Layout do store

```
~/.claude/credentials/                      (chmod 700)
├── .gitignore                              (ignora tudo por default)
├── README.md                               (doc do layout)
├── registry.json                           (chmod 600, índice key → source+ref+metadata)
├── audit.log                               (append-only, sem segredos)
├── files/                                  (chmod 700)
│   └── cloudflare-idcbr-api-token.secret   (chmod 600, quando source=file)
└── cloudflare/                             (por provider, opcional)
    └── idcbr/
        └── audit.log                       (audit específico CF+nick)
```

Permissões são validadas **em cada leitura**. Arquivo com `>600` é rejeitado.
Symlinks em `files/` são rejeitados (bypass de chmod).

## Primeiros passos

### Bootstrap do store

Rodar uma vez por máquina:

```bash
bash ~/Sistemas/claude-ai-tips/global/skills/cred-store/scripts/init-store.sh
```

Saída:

```
escrito: /Users/you/.claude/credentials/.gitignore
escrito: /Users/you/.claude/credentials/registry.json
escrito: /Users/you/.claude/credentials/README.md

credential store pronto em: /Users/you/.claude/credentials
proximo passo: /cred-store-setup <provider>.<account>.<type>
```

Flags disponíveis:

| Flag | Efeito |
|------|--------|
| `--force` | Sobrescreve `registry.json` (raro — só em bootstrap inicial) |
| `-h`, `--help` | Mostra ajuda |

Variável de ambiente:

```bash
export CLAUDE_CREDS_DIR=/path/alternativo    # override do default ~/.claude/credentials
```

### Registrar primeira credencial

No Claude Code, digite algo como:

```
configure credenciais Cloudflare para minha conta pessoal
```

A skill `cf-credentials-setup` vai guiar:

```
1. Nickname da conta? → pessoal
2. Escopo do token?    → Workers+D1+KV+R2 (ou customizar)
3. Fonte?              → op / keychain / file / env
4. (se op) URI 1P?     → op://Personal/CF pessoal Token/credential
5. Account ID?         → 1783e2ca3a473ef8334a8b17df42878e
6. Email (opcional)    → user@example.com
7. (valida via /user/tokens/verify)
8. Gravado em registry.json ✓
```

Para registro genérico (não-CF):

```
registre credencial para neon com account nickname production
```

Aciona `cred-store-setup` com prompts equivalentes.

### Verificar registro

```bash
bash ~/Sistemas/claude-ai-tips/global/skills/cred-store/scripts/list.sh
```

Saída tabela:

```
KEY                                      SOURCE     CREATED                        METADATA
---------------------------------------- ---------- ------------------------------ --------
cloudflare.pessoal.api_token             op         2026-04-19T21:00:00Z           {"account_id":"1783...","email":"user@example.com"}
neon.production.api_key                  keychain   2026-04-19T22:15:00Z           {"project_id":"cold-sun-123"}
```

Filtrar por provider:

```bash
bash .../list.sh --provider=cloudflare
```

Formato JSON para consumo programático:

```bash
bash .../list.sh --format=json | jq '."cloudflare.pessoal.api_token".metadata'
```

## Fontes de armazenamento

### 1Password CLI (recomendado)

**Vantagens**: criptografia, sync multi-device, biometria (Touch ID),
sharing via vaults compartilhados, audit no 1P.

**Desvantagens**: requer `op` CLI + signin ativo.

#### Instalação

```bash
brew install 1password-cli         # macOS
# Linux: https://developer.1password.com/docs/cli/get-started/
```

#### Signin

```bash
op signin
```

Se tem biometria configurada, desbloqueia via app 1Password. Senão, pede
Secret Key + master password na primeira vez.

#### Criar item (via CLI)

```bash
op item create \
  --category="API Credential" \
  --title="CF pessoal Token" \
  --vault=Personal \
  credential="cf-api-token-aqui"
```

Ou via GUI: `Cmd+N` → tipo "API Credential" → preencher.

#### URI format

```
op://<vault>/<item>/<field>
```

Exemplos:

- `op://Personal/CF idcbr Token/credential`
- `op://Work/Neon production/api_key`
- `op://Shared/ES smartgw/password`

Field canônico para tokens: `credential` (tipo API Credential) ou `password`
(tipo Password). Customizado: qualquer nome que criou.

#### Teste manual

```bash
op read "op://Personal/CF idcbr Token/credential"
```

Retorna valor diretamente, sem prompt (se sessão ativa).

#### Sessão expirada

```
[ERROR] You are not currently signed in.
```

Renovar:

```bash
op signin
```

Sessões expiram após período de inatividade (default ~30min, configurável).

### macOS Keychain

**Vantagens**: nativo, criptografia, sem dependência externa.

**Desvantagens**: macOS apenas, gerenciamento menos amigável.

#### Convenção de service name

```
claude-<key-slugified>
```

Onde key `cloudflare.idcbr.api_token` vira `claude-cloudflare-idcbr-api-token`.

#### Adicionar credencial

```bash
security add-generic-password \
  -s "claude-cloudflare-idcbr-api-token" \
  -a "user@example.com" \
  -w "valor-do-token-aqui"
```

Flags:

- `-s <service>`: service name (a chave no Keychain)
- `-a <account>`: account (tipicamente email)
- `-w <value>`: password value (omitir para prompt seguro)

Forma interativa (sem valor no histórico):

```bash
security add-generic-password \
  -s "claude-cloudflare-idcbr-api-token" \
  -a "user@example.com" \
  -w
# prompt aparece, digita o valor, Enter
```

#### Ler credencial

```bash
security find-generic-password -s "claude-cloudflare-idcbr-api-token" -w
```

Flag `-w` retorna só o valor (sem metadata). Sem `-w`, mostra estrutura completa.

#### Remover credencial

```bash
security delete-generic-password -s "claude-cloudflare-idcbr-api-token"
```

### Arquivo protegido

**Vantagens**: funciona em qualquer sistema, simples.

**Desvantagens**: texto claro, requer disciplina de permissões.

#### Path canônico

```
~/.claude/credentials/files/<key-slugified>.secret
```

#### Criar manualmente (alternativa ao `cred-store-setup`)

```bash
STORE=~/.claude/credentials/files
KEY_SLUG=cloudflare-idcbr-api-token

# Entrada interativa sem histórico
read -rs -p "Token: " TOKEN; echo
printf '%s' "$TOKEN" > "$STORE/$KEY_SLUG.secret"
chmod 600 "$STORE/$KEY_SLUG.secret"
unset TOKEN
```

Atenção: **sem newline final** (`printf %s`, não `echo`). Newline vira parte
da variável quando lida.

#### Requisitos validados em cada leitura

- `chmod 600` ou `400` (leitura apenas pelo owner)
- Não pode ser symlink
- Arquivo legível
- Sem newline final (convenção — leitura com `cat` preserva)

Violações fazem `resolve.sh` abortar com exit 2.

### Variável de ambiente

**Vantagens**: nativo, funciona com tooling existente (wrangler, gh, etc.),
ideal para CI.

**Desvantagens**: volátil (sessão apenas), vaza em `ps -eww -E`.

#### Convenção

```bash
export CLOUDFLARE_API_TOKEN="..."            # token principal
export CLOUDFLARE_ACCOUNT_ID="..."           # account id
export CLOUDFLARE_EMAIL="..."                # auth legacy (opcional)
```

#### Quando usar

- **CI/CD**: secret do GitHub Actions injetado como env var
- **Container**: variável do compose, K8s secret
- **Troubleshooting**: sessão temporária de shell

#### Quando NÃO usar

- Sessão interativa de longa duração (use op/keychain)
- Compartilhada com processos filhos (vaza via `ps -E`)
- Arquivo versionado (`.env` sem `.gitignore`)

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

## Cookbook

### Registrar Cloudflare via `cf-credentials-setup`

Skill específica de CF que pré-configura escopos recomendados:

```
/cf-credentials-setup pessoal
```

Fluxo: ver [cloudflare.md](./cloudflare.md#setup-inicial).

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

## Troubleshooting

| Sintoma | Causa provável | Solução |
|---------|----------------|---------|
| `erro: credencial 'X' nao registrada` | Key não existe em `registry.json` | `bash .../list.sh` para ver registradas; `/cred-store-setup <key>` para registrar |
| `1Password trancado — execute: op signin` | Sessão do op expirou | `op signin` (ou desbloqueia app com biometria) |
| `entry nao encontrada no keychain: X` | Service name errado ou credencial apagada | `security find-generic-password -s <service>` para debugar |
| `erro: <path> tem permissoes 644` | `chmod` do arquivo não é `600` | `chmod 600 <path>` |
| `erro: <path> eh um symlink` | Symlink em `files/` (rejeitado) | Copiar arquivo real (não symlink) ou usar source=op/keychain |
| `erro: jq e obrigatorio` | `jq` não instalado | `brew install jq` ou `apt-get install jq` |
| `registry.json` corrompido (JSON inválido) | Edição manual errada | Restaurar backup ou rodar `init-store.sh --force` e re-registrar |
| `audit.log` crescendo indefinidamente | Sem rotação automática | Rotacionar manualmente (ver cookbook) |
| `op: session expired, please sign in again` | Sessão longa expirou mid-operação | `op signin` e retry |
| Erro CF 10000 após resolve ok | Token inválido ou revogado | Criar novo no dashboard, rotacionar (ver cookbook) |
| Erro CF 10001 após resolve ok | Token sem escopo na conta alvo | Recriar token com escopo correto |

## Ver também

- [`cred-store/SKILL.md`](../../global/skills/cred-store/SKILL.md) —
  contrato da skill
- [`cred-store-setup/SKILL.md`](../../global/skills/cred-store-setup/SKILL.md) —
  fluxo de registro
- [`credential-storage.md`](../../platform-related/cloudflare-shared/references/credential-storage.md) —
  convenções específicas para CF
- [`cloudflare.md`](./cloudflare.md) — uso de credenciais CF em prática
- [1Password CLI docs](https://developer.1password.com/docs/cli/)
- [macOS security man page](https://ss64.com/mac/security.html)
