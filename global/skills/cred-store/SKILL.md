---
name: cred-store
description: |
  Use quando uma skill precisa LER uma credencial (API token, password,
  connection string) de forma segura — Cloudflare API token, Neon API key,
  Elasticsearch password, Redis URL, etc. Tambem quando o usuario pedir para
  "resolver credencial", "ler token", "carregar secret", "buscar credencial",
  "get credential". Cascata: env var -> 1Password CLI -> macOS Keychain ->
  arquivo protegido em ~/.claude/credentials/. NAO use para ARMAZENAR
  credenciais novas (use cred-store-setup). NAO use para credenciais
  especificas de um projeto (Wrangler .dev.vars, .env).
argument-hint: "<credential-key> [--account=<nick>] [--format=raw|env|json]"
allowed-tools:
  - Bash
  - Read
---

# Skill: Credential Store (consulta)

Skill agnostica para resolver credenciais de serviços externos via cascata de
fontes, da mais segura para a menos segura. **Somente leitura** — para
registrar credenciais novas, usar `cred-store-setup`.

## Quando e invocada

Outras skills do toolkit consomem esta quando precisam autenticar contra
servicos externos:

- `platform-related/cloudflare-*` — API token da Cloudflare
- `platform-related/neon/` — API key do Neon
- `data-related/elasticsearch/` — usuario/senha ou API key do cluster
- `data-related/postgres/` — connection string
- Qualquer skill de integracao com provedor externo

## Arquitetura

```
~/.claude/credentials/
├── .gitignore              # ignora tudo sensivel
├── registry.json           # indice {key -> source, ref, metadata}
├── audit.log               # log append-only de resolve/register
└── files/                  # APENAS quando source=file (chmod 600)
    └── <slug>.secret
```

**Segredo em si NUNCA fica em registry.json** — o JSON apenas aponta para
onde buscar. O segredo vive em:
- `env` — variavel de ambiente (volatil)
- `op` — 1Password CLI (criptografado, persistente)
- `keychain` — macOS Keychain (criptografado, persistente)
- `file` — `files/<slug>.secret` (texto claro, chmod 600, ultimo recurso)

## Argumentos

`$ARGUMENTS` deve conter a chave da credencial:

| Formato da chave | Exemplo |
|---|---|
| `<provider>.<account>.<credtype>` | `cloudflare.idcbr.api_token` |
| `<provider>.<env>.<credtype>` | `neon.production.api_key` |
| `<provider>.<cluster>.<credtype>` | `elasticsearch.smartgw.password` |

Opcoes:

- `--account=<nick>` — especifica a conta (quando a key e ambigua)
- `--format=raw|env|json` — formato de saida (default: `raw`)
  - `raw`: stdout contem apenas o segredo
  - `env`: stdout contem `KEY=value` (shell-eval friendly)
  - `json`: stdout contem `{"secret": "...", "metadata": {...}}`
- `--with-metadata` — inclui metadados nao-sensiveis (account_id, zone_id,
  endpoint, etc.) alem do segredo

## Fluxo de resolucao

```
1. Parsea <key>
2. Le registry.json -> localiza entry da key
3. Tenta fontes NA ORDEM da entry (source primario + fallbacks):
   a. env  -> ${REF}
   b. op   -> op read "op://..."        (requer `op` instalado)
   c. keychain -> security find-generic-password -s <ref> -w  (macOS only)
   d. file -> cat files/<slug>.secret   (chmod 600 validado)
4. Registra resolve em audit.log (key + source usado + timestamp)
5. Imprime na saida no formato solicitado
6. Se nada funcionar -> exit 1 com mensagem clara
```

## Uso pelas outras skills

### Padrao recomendado (bash)

```bash
SECRET=$(bash "$CLAUDE_PROJECT_DIR"/.claude/skills/cred-store/scripts/resolve.sh \
  cloudflare.idcbr.api_token)

curl -H "Authorization: Bearer $SECRET" \
  https://api.cloudflare.com/client/v4/zones
```

### Com metadados

```bash
eval "$(bash scripts/resolve.sh cloudflare.idcbr.api_token --format=env --with-metadata)"
# Agora disponivel: CLOUDFLARE_API_TOKEN, CLOUDFLARE_ACCOUNT_ID, CLOUDFLARE_EMAIL
```

### JSON para consumo programatico

```bash
bash scripts/resolve.sh elasticsearch.smartgw.password --format=json
# {"secret": "...", "metadata": {"host": "localhost", "port": 9200, "user": "elastic"}}
```

## Comportamento com credencial ausente

Se a key nao existe no registry, NAO tentar fontes default ou adivinhar.
Emitir mensagem estruturada:

```
credential 'cloudflare.idcbr.api_token' nao registrada.
execute: /cred-store-setup cloudflare.idcbr.api_token
ou defina CLOUDFLARE_API_TOKEN no ambiente atual.
```

Exit code 1. Quem chama decide como lidar (pedir ao usuario, fallback, etc.).

## Comportamento com 1Password

1Password CLI (`op`) e a fonte **preferida** quando disponivel — credenciais
ficam criptografadas em vault persistente, desbloqueadas via biometria
(Touch ID) ou chave mestra.

- Se `op` nao esta instalado: skill registra no audit.log e segue para
  keychain/file
- Se `op` esta instalado mas trancado: retornar erro pedindo unlock
  (`op signin` ou biometria)
- URI 1Password segue formato `op://<vault>/<item>/<field>`

## Comportamento com Keychain (macOS)

Fallback quando `op` nao esta disponivel. Usa `security` CLI nativo:

```bash
security find-generic-password -s "claude-<slug>" -w
```

O `service name` e derivado da key: `cloudflare.idcbr.api_token` ->
`claude-cloudflare-idcbr-api-token`.

## Comportamento com arquivo

Ultimo recurso. Armazenado em `~/.claude/credentials/files/<slug>.secret`
com:

- `chmod 600` (so o owner le/escreve)
- validacao de permissoes na leitura (se `>600`, aborta com aviso de seguranca)
- sem newline final (para evitar contaminacao de variavel)

## Saida padrao vs erro

- **stdout**: apenas o segredo resolvido (ou `KEY=value` / JSON conforme
  `--format`)
- **stderr**: mensagens de fallback, avisos, audit-trail
- **exit 0**: resolveu com sucesso
- **exit 1**: key nao encontrada ou nenhuma fonte disponivel
- **exit 2**: permissao invalida em arquivo (`>600`)
- **exit 3**: 1Password trancado ou nao instalado quando era a unica opcao

## Gotchas

### Nao imprimir segredo em log nem em mensagem de erro

Mensagens de erro devem citar apenas a `key`, nunca o valor. Isso eh
enforced pelo script `resolve.sh` — quem chama a skill deve tomar mesmo
cuidado.

### Segredo em variavel de ambiente vaza em `ps -E`

Se o consumidor exporta a credencial num processo filho, usuarios com
acesso ao host veem em `ps -eww -E`. Preferir passar via stdin ou
header HTTP, nao via env quando possivel.

### 1Password CLI tem cache de sessao curto

Sessoes `op signin` expiram. Se a skill roda em batch longo, precisa
renovar. O script `resolve.sh` detecta `op: (ERROR) ... not signed in` e
retorna exit 3 para o consumidor saber que precisa pedir unlock.

### audit.log nunca contem segredo

Registra apenas: timestamp, key, source-used, exit-code. Sem o valor.
Se alguem precisar auditar acesso, o log e suficiente; o valor nunca
e rastreavel via audit.

### Nao e substituto para secrets de projeto

Secrets especificos de um projeto (ex: `.dev.vars` do Wrangler,
`.env.local` do Next, `DATABASE_URL` em CI) nao vao aqui. Esta skill e
para credenciais globais reusadas entre projetos (API tokens de provedor,
keys de serviço pessoais).

### Key ambigua sem `--account`

`cloudflare.api_token` (sem `<account>`) retorna erro pedindo especificacao
quando ha mais de uma conta registrada. Nunca chutar — erro explicito.

### Symlink em `files/`

Scripts rejeitam symlinks para evitar bypass de chmod (ex: symlink
aponta para arquivo com 644). Cheque `[ -L ]` antes de ler.

---

## Scripts disponiveis

| Script | Uso | Descricao |
|---|---|---|
| `scripts/resolve.sh <key>` | leitura | Resolve credencial via cascata |
| `scripts/list.sh` | listagem | Lista keys registradas (sem segredos) |
| `scripts/init-store.sh` | bootstrap | Cria `~/.claude/credentials/` com `.gitignore` |

## Ver tambem

- `cred-store-setup` — skill interativa para REGISTRAR novas credenciais
- [`platform-related/README.md`](../../../platform-related/README.md) — consumidores primarios
- [`data-related/README.md`](../../../data-related/README.md) — consumidores primarios
