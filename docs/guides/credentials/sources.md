# Fontes de Armazenamento

Este documento descreve as quatro fontes suportadas pelo `cred-store`, em ordem
de prioridade (cascata).

## 1Password CLI (recomendado)

**Vantagens**: criptografia, sync multi-device, biometria (Touch ID),
sharing via vaults compartilhados, audit no 1P.

**Desvantagens**: requer `op` CLI + signin ativo.

### Instalação

```bash
brew install 1password-cli         # macOS
# Linux: https://developer.1password.com/docs/cli/get-started/
```

### Signin

```bash
op signin
```

Se tem biometria configurada, desbloqueia via app 1Password. Senão, pede
Secret Key + master password na primeira vez.

### Criar item (via CLI)

```bash
op item create \
  --category="API Credential" \
  --title="CF pessoal Token" \
  --vault=Personal \
  credential="cf-api-token-aqui"
```

Ou via GUI: `Cmd+N` → tipo "API Credential" → preencher.

### URI format

```
op://<vault>/<item>/<field>
```

Exemplos:

- `op://Personal/CF idcbr Token/credential`
- `op://Work/Neon production/api_key`
- `op://Shared/ES smartgw/password`

Field canônico para tokens: `credential` (tipo API Credential) ou `password`
(tipo Password). Customizado: qualquer nome que criou.

### Teste manual

```bash
op read "op://Personal/CF idcbr Token/credential"
```

Retorna valor diretamente, sem prompt (se sessão ativa).

### Sessão expirada

```
[ERROR] You are not currently signed in.
```

Renovar:

```bash
op signin
```

Sessões expiram após período de inatividade (default ~30min, configurável).

---

## macOS Keychain

**Vantagens**: nativo, criptografia, sem dependência externa.

**Desvantagens**: macOS apenas, gerenciamento menos amigável.

### Convenção de service name

```
claude-<key-slugified>
```

Onde key `cloudflare.idcbr.api_token` vira `claude-cloudflare-idcbr-api-token`.

### Adicionar credencial

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

### Ler credencial

```bash
security find-generic-password -s "claude-cloudflare-idcbr-api-token" -w
```

Flag `-w` retorna só o valor (sem metadata). Sem `-w`, mostra estrutura completa.

### Remover credencial

```bash
security delete-generic-password -s "claude-cloudflare-idcbr-api-token"
```

---

## Arquivo protegido

**Vantagens**: funciona em qualquer sistema, simples.

**Desvantagens**: texto claro, requer disciplina de permissões.

### Path canônico

```
~/.claude/credentials/files/<key-slugified>.secret
```

### Criar manualmente (alternativa ao `cred-store-setup`)

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

### Requisitos validados em cada leitura

- `chmod 600` ou `400` (leitura apenas pelo owner)
- Não pode ser symlink
- Arquivo legível
- Sem newline final (convenção — leitura com `cat` preserva)

Violações fazem `resolve.sh` abortar com exit 2.

---

## Variável de ambiente

**Vantagens**: nativo, funciona com tooling existente (wrangler, gh, etc.),
ideal para CI.

**Desvantagens**: volátil (sessão apenas), vaza em `ps -eww -E`.

### Convenção

```bash
export CLOUDFLARE_API_TOKEN="..."            # token principal
export CLOUDFLARE_ACCOUNT_ID="..."           # account id
export CLOUDFLARE_EMAIL="..."                # auth legacy (opcional)
```

### Quando usar

- **CI/CD**: secret do GitHub Actions injetado como env var
- **Container**: variável do compose, K8s secret
- **Troubleshooting**: sessão temporária de shell

### Quando NÃO usar

- Sessão interativa de longa duração (use op/keychain)
- Compartilhada com processos filhos (vaza via `ps -E`)
- Arquivo versionado (`.env` sem `.gitignore`)

---

Voltar para: [README.md](./README.md)
