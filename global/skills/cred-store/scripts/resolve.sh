#!/bin/sh
# resolve.sh — resolve uma credencial registrada via cascata de fontes.
#
# Uso:
#   scripts/resolve.sh <key>                    # imprime segredo em stdout
#   scripts/resolve.sh <key> --format=env       # imprime KEY=value
#   scripts/resolve.sh <key> --format=json      # imprime JSON
#   scripts/resolve.sh <key> --with-metadata    # inclui metadados publicos
#
# Fontes suportadas (cascata por entry do registry):
#   env       variavel de ambiente
#   op        1Password CLI (requer `op` instalado e signed-in)
#   keychain  macOS Keychain (requer `security`)
#   file      arquivo em ~/.claude/credentials/files/<slug>.secret (chmod 600)
#
# Exit codes:
#   0  resolveu
#   1  key nao encontrada ou nenhuma fonte funcionou
#   2  permissao invalida em arquivo (>600 ou symlink)
#   3  1Password trancado/nao instalado e era a unica opcao
#   4  argumento invalido

set -eu

STORE_DIR="${CLAUDE_CREDS_DIR:-$HOME/.claude/credentials}"
REGISTRY="$STORE_DIR/registry.json"
AUDIT="$STORE_DIR/audit.log"

FORMAT="raw"
WITH_META=0
KEY=""

usage() {
  cat <<'USAGE'
resolve.sh — resolve uma credencial via cascata de fontes

Uso:
  resolve.sh <key> [--format=raw|env|json] [--with-metadata]

Opcoes:
  --format=FMT       formato de saida: raw|env|json (default: raw)
  --with-metadata    incluir metadados publicos (account_id, host, etc.)
  -h, --help         mostra esta ajuda

Variaveis de ambiente:
  CLAUDE_CREDS_DIR   diretorio do store (default: ~/.claude/credentials)
USAGE
}

for arg in "$@"; do
  case "$arg" in
    --format=*) FORMAT="${arg#--format=}" ;;
    --with-metadata) WITH_META=1 ;;
    -h|--help) usage; exit 0 ;;
    --*) printf 'argumento desconhecido: %s\n' "$arg" >&2; exit 4 ;;
    *)
      if [ -z "$KEY" ]; then
        KEY="$arg"
      else
        printf 'argumento inesperado: %s\n' "$arg" >&2
        exit 4
      fi
      ;;
  esac
done

if [ -z "$KEY" ]; then
  printf 'erro: <key> obrigatoria\n' >&2
  usage >&2
  exit 4
fi

case "$FORMAT" in
  raw|env|json) ;;
  *) printf 'erro: --format deve ser raw|env|json\n' >&2; exit 4 ;;
esac

if [ ! -f "$REGISTRY" ]; then
  printf 'erro: registry nao encontrado em %s\n' "$REGISTRY" >&2
  printf 'execute: bash scripts/init-store.sh\n' >&2
  exit 1
fi

# Extrai entry do registry (requer jq)
if ! command -v jq >/dev/null 2>&1; then
  printf 'erro: jq e obrigatorio. instale: brew install jq\n' >&2
  exit 4
fi

ENTRY=$(jq -c --arg k "$KEY" '.[$k] // empty' "$REGISTRY" 2>/dev/null || true)
if [ -z "$ENTRY" ]; then
  printf "erro: credencial '%s' nao registrada.\n" "$KEY" >&2
  printf 'execute: /cred-store-setup %s\n' "$KEY" >&2
  exit 1
fi

SOURCE=$(printf '%s' "$ENTRY" | jq -r '.source')
REF=$(printf '%s' "$ENTRY" | jq -r '.ref')

audit_log() {
  # audit_log <source> <exit_code>
  mkdir -p "$STORE_DIR"
  printf '%s resolve key=%s source=%s exit=%s\n' \
    "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$KEY" "$1" "$2" >> "$AUDIT" 2>/dev/null || true
}

resolve_env() {
  # $1 = nome da env var
  eval "printf '%s' \"\${$1:-}\""
}

resolve_op() {
  # $1 = op URI
  if ! command -v op >/dev/null 2>&1; then
    printf '1Password CLI (op) nao instalado\n' >&2
    return 3
  fi
  # 2>&1 captura erros de session expirada
  VAL=$(op read "$1" 2>&1) || {
    if printf '%s' "$VAL" | grep -q 'not signed in\|session expired\|locked'; then
      printf '1Password trancado — execute: op signin\n' >&2
      return 3
    fi
    printf 'op read falhou para %s\n' "$1" >&2
    return 1
  }
  printf '%s' "$VAL"
  return 0
}

resolve_keychain() {
  # $1 = service name
  if [ "$(uname)" != "Darwin" ]; then
    printf 'keychain disponivel apenas em macOS\n' >&2
    return 1
  fi
  if ! command -v security >/dev/null 2>&1; then
    printf 'security CLI nao encontrado\n' >&2
    return 1
  fi
  security find-generic-password -s "$1" -w 2>/dev/null || {
    printf 'entry nao encontrada no keychain: %s\n' "$1" >&2
    return 1
  }
}

resolve_file() {
  # $1 = slug
  FILE="$STORE_DIR/files/$1.secret"
  if [ -L "$FILE" ]; then
    printf 'erro: %s e um symlink (rejeitado)\n' "$FILE" >&2
    return 2
  fi
  if [ ! -f "$FILE" ]; then
    printf 'arquivo nao encontrado: %s\n' "$FILE" >&2
    return 1
  fi
  # Validar chmod <= 600
  PERMS=$(stat -f '%A' "$FILE" 2>/dev/null || stat -c '%a' "$FILE" 2>/dev/null || echo "")
  case "$PERMS" in
    600|400) ;;
    *)
      printf 'erro: %s tem permissoes %s (esperado 600 ou 400)\n' "$FILE" "$PERMS" >&2
      return 2
      ;;
  esac
  # Sem newline final
  cat "$FILE"
}

# Roda a fonte primaria; se falhar e houver fallbacks, tenta cada uma
SECRET=""
RESOLVED_SOURCE=""
TRY_LIST="$SOURCE"
FALLBACKS=$(printf '%s' "$ENTRY" | jq -r '.fallback_sources[]? // empty' 2>/dev/null || true)
[ -n "$FALLBACKS" ] && TRY_LIST="$TRY_LIST $FALLBACKS"

for S in $TRY_LIST; do
  S_REF="$REF"
  # fallback sources podem ter refs distintas (nao implementado nesta versao)
  case "$S" in
    env)      SECRET=$(resolve_env "$S_REF" 2>&1) && RESOLVED_SOURCE="env" && break || SECRET="" ;;
    op)      SECRET=$(resolve_op "$S_REF") && RESOLVED_SOURCE="op" && break || { RC=$?; [ "$RC" = "3" ] && { audit_log "op" 3; exit 3; }; SECRET=""; } ;;
    keychain) SECRET=$(resolve_keychain "$S_REF") && RESOLVED_SOURCE="keychain" && break || SECRET="" ;;
    file)    SECRET=$(resolve_file "$S_REF") && RESOLVED_SOURCE="file" && break || { RC=$?; [ "$RC" = "2" ] && { audit_log "file" 2; exit 2; }; SECRET=""; } ;;
    *)       printf 'source desconhecida: %s\n' "$S" >&2 ;;
  esac
done

if [ -z "$RESOLVED_SOURCE" ]; then
  audit_log "none" 1
  printf 'erro: nenhuma fonte resolveu %s\n' "$KEY" >&2
  exit 1
fi

audit_log "$RESOLVED_SOURCE" 0

# Saida
case "$FORMAT" in
  raw)
    printf '%s' "$SECRET"
    if [ "$WITH_META" = "1" ]; then
      printf '\n' >&2
      printf '%s' "$ENTRY" | jq -r '.metadata // {} | to_entries | .[] | "\(.key)=\(.value)"' >&2
    fi
    ;;
  env)
    # Nome da env derivado da key: cloudflare.idcbr.api_token -> CLOUDFLARE_API_TOKEN
    PROVIDER=$(printf '%s' "$KEY" | awk -F. '{print toupper($1)}')
    CREDTYPE=$(printf '%s' "$KEY" | awk -F. '{print toupper($3)}' | tr - _)
    printf '%s_%s=%s\n' "$PROVIDER" "$CREDTYPE" "$SECRET"
    if [ "$WITH_META" = "1" ]; then
      printf '%s' "$ENTRY" | jq -r --arg p "$PROVIDER" '.metadata // {} | to_entries | .[] | "\($p)_\(.key | ascii_upcase)=\(.value)"'
    fi
    ;;
  json)
    if [ "$WITH_META" = "1" ]; then
      printf '%s' "$ENTRY" | jq --arg s "$SECRET" '{secret: $s, metadata: (.metadata // {}), source: .source}'
    else
      jq -n --arg s "$SECRET" '{secret: $s}'
    fi
    ;;
esac
