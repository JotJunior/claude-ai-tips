#!/bin/sh
# init-store.sh — bootstrap do credential store em ~/.claude/credentials/.
#
# Cria:
#   ~/.claude/credentials/.gitignore    (ignora tudo por default)
#   ~/.claude/credentials/registry.json (JSON vazio)
#   ~/.claude/credentials/files/        (diretorio para source=file)
#   ~/.claude/credentials/README.md     (explica o layout)
#
# Idempotente: nao sobrescreve arquivos existentes (exceto com --force).

set -eu

STORE_DIR="${CLAUDE_CREDS_DIR:-$HOME/.claude/credentials}"
FORCE=0

for arg in "$@"; do
  case "$arg" in
    --force) FORCE=1 ;;
    -h|--help)
      cat <<'USAGE'
init-store.sh — inicializa o credential store

Uso:
  init-store.sh [--force]

Cria ~/.claude/credentials/ com estrutura protegida.
Idempotente: arquivos existentes sao preservados (exceto com --force).
USAGE
      exit 0
      ;;
  esac
done

write_or_keep() {
  # write_or_keep <file> <content>
  FILE="$1"
  CONTENT="$2"
  if [ -f "$FILE" ] && [ "$FORCE" = "0" ]; then
    printf 'mantido: %s\n' "$FILE" >&2
    return 0
  fi
  printf '%s' "$CONTENT" > "$FILE"
  printf 'escrito: %s\n' "$FILE" >&2
}

mkdir -p "$STORE_DIR/files"
chmod 700 "$STORE_DIR"
chmod 700 "$STORE_DIR/files"

# .gitignore — tudo ignorado por default (paranoia)
write_or_keep "$STORE_DIR/.gitignore" '# Credential store — nao versionar conteudo.
*
!.gitignore
!README.md
'

# registry.json — objeto vazio
if [ ! -f "$STORE_DIR/registry.json" ] || [ "$FORCE" = "1" ]; then
  printf '{}\n' > "$STORE_DIR/registry.json"
  chmod 600 "$STORE_DIR/registry.json"
  printf 'escrito: %s/registry.json\n' "$STORE_DIR" >&2
else
  printf 'mantido: %s/registry.json\n' "$STORE_DIR" >&2
fi

# README explicativo
write_or_keep "$STORE_DIR/README.md" '# Claude Credential Store

Diretorio gerenciado pelas skills `cred-store` e `cred-store-setup` do toolkit
`claude-ai-tips`.

## Layout

```
~/.claude/credentials/
├── .gitignore           # ignora tudo (paranoia)
├── registry.json        # indice key -> {source, ref, metadata}
├── audit.log            # log append-only de resolve/register
├── files/               # segredos tipo source=file (chmod 600)
└── README.md            # este arquivo
```

## Seguranca

- Diretorio `700` (so owner)
- `registry.json` `600` (so owner)
- `files/*.secret` `600` e sem symlinks permitidos
- Segredos NUNCA em `registry.json` — apenas referencias

## Uso

Via skills:

```bash
# Registrar nova credencial (interativo)
/cred-store-setup cloudflare.idcbr.api_token

# Resolver credencial (consumido por outras skills)
bash <repo>/global/skills/cred-store/scripts/resolve.sh cloudflare.idcbr.api_token

# Listar (sem mostrar segredos)
bash <repo>/global/skills/cred-store/scripts/list.sh
```

## Fontes suportadas

| Fonte | Persistente | Criptografada | Plataforma |
|---|---|---|---|
| `op` (1Password CLI) | sim | sim | qualquer |
| `keychain` (macOS) | sim | sim | macOS |
| `file` | sim | NAO (chmod 600) | qualquer |
| `env` (var de ambiente) | sessao apenas | no trafego | qualquer |

Ordem de preferencia: `op > keychain > file > env`.
'

printf '\n' >&2
printf 'credential store pronto em: %s\n' "$STORE_DIR" >&2
printf 'proximo passo: /cred-store-setup <provider>.<account>.<type>\n' >&2
