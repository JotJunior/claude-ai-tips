#!/bin/sh
# call.sh — wrapper para Cloudflare REST API com auth, retry, audit.
#
# Uso:
#   call.sh <METHOD> <PATH> [opcoes]
#
# Opcoes:
#   --account=<nick>         conta registrada via cred-store-setup
#   --zone=<id|nick>         zone id (substitui :zone_id no path)
#   --data='<json>'          body JSON inline
#   --data-file=<path>       body JSON de arquivo
#   --query='<qs>'           query string
#   --format=json|raw|pretty saida (default: json)
#   --retry=<n>              max retries (default: 3)
#   --timeout=<s>            timeout por request (default: 30)
#   --base=<url>             base URL (default: api.cloudflare.com/client/v4)
#   --audit                  forca audit log (default: on para PATCH/POST/PUT/DELETE)
#   --no-audit               desativa audit
#   --dry-run                imprime request sem executar
#
# Exit codes:
#   0  sucesso (.success == true, 2xx)
#   1  erro de aplicacao (auth/permission/validation — 4xx exceto 429)
#   2  erro de rede/timeout apos retries
#   3  credencial nao encontrada
#   4  argumento invalido

set -eu

CRED_STORE_RESOLVE="${CRED_STORE_RESOLVE:-}"
if [ -z "$CRED_STORE_RESOLVE" ]; then
  SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
  CRED_STORE_RESOLVE="$SCRIPT_DIR/../../../../../global/skills/cred-store/scripts/resolve.sh"
fi

METHOD=""
REQ_PATH=""
ACCOUNT=""
ZONE=""
DATA=""
DATA_FILE=""
QUERY=""
FORMAT="json"
RETRY=3
TIMEOUT=30
BASE="https://api.cloudflare.com/client/v4"
AUDIT="auto"
DRY_RUN=0

usage() {
  sed -n '2,24p' "$0" | sed 's/^# \?//'
}

for arg in "$@"; do
  case "$arg" in
    --account=*)   ACCOUNT="${arg#--account=}" ;;
    --zone=*)      ZONE="${arg#--zone=}" ;;
    --data=*)      DATA="${arg#--data=}" ;;
    --data-file=*) DATA_FILE="${arg#--data-file=}" ;;
    --query=*)     QUERY="${arg#--query=}" ;;
    --format=*)    FORMAT="${arg#--format=}" ;;
    --retry=*)     RETRY="${arg#--retry=}" ;;
    --timeout=*)   TIMEOUT="${arg#--timeout=}" ;;
    --base=*)      BASE="${arg#--base=}" ;;
    --audit)       AUDIT="on" ;;
    --no-audit)    AUDIT="off" ;;
    --dry-run)     DRY_RUN=1 ;;
    -h|--help)     usage; exit 0 ;;
    --*)           printf 'argumento invalido: %s\n' "$arg" >&2; exit 4 ;;
    *)
      if [ -z "$METHOD" ]; then METHOD="$arg"
      elif [ -z "$REQ_PATH" ]; then REQ_PATH="$arg"
      else printf 'argumento inesperado: %s\n' "$arg" >&2; exit 4
      fi
      ;;
  esac
done

[ -z "$METHOD" ] && { usage >&2; exit 4; }
[ -z "$REQ_PATH" ] && { printf '<PATH> obrigatorio\n' >&2; exit 4; }

case "$METHOD" in
  GET|POST|PUT|PATCH|DELETE|HEAD|OPTIONS) ;;
  *) printf 'metodo invalido: %s\n' "$METHOD" >&2; exit 4 ;;
esac

case "$FORMAT" in
  json|raw|pretty) ;;
  *) printf '--format deve ser json|raw|pretty\n' >&2; exit 4 ;;
esac

if ! command -v jq >/dev/null 2>&1 || ! command -v curl >/dev/null 2>&1; then
  printf 'dependencias ausentes: jq, curl\n' >&2
  exit 4
fi

# audit auto = on para metodos de escrita
if [ "$AUDIT" = "auto" ]; then
  case "$METHOD" in
    POST|PUT|PATCH|DELETE) AUDIT="on" ;;
    *) AUDIT="off" ;;
  esac
fi

TOKEN=""
ACCOUNT_ID=""

if [ -n "$ACCOUNT" ]; then
  KEY="cloudflare.$ACCOUNT.api_token"
  META_JSON=$(bash "$CRED_STORE_RESOLVE" "$KEY" --format=json --with-metadata 2>&1) || {
    RC=$?
    printf 'erro ao resolver credencial %s (exit %s)\n' "$KEY" "$RC" >&2
    printf '%s\n' "$META_JSON" >&2
    exit 3
  }
  TOKEN=$(printf '%s' "$META_JSON" | jq -r '.secret')
  ACCOUNT_ID=$(printf '%s' "$META_JSON" | jq -r '.metadata.account_id // empty')
else
  TOKEN="${CLOUDFLARE_API_TOKEN:-}"
  ACCOUNT_ID="${CLOUDFLARE_ACCOUNT_ID:-}"
  if [ -z "$TOKEN" ]; then
    printf 'erro: --account=<nick> ou CLOUDFLARE_API_TOKEN obrigatorio\n' >&2
    exit 3
  fi
fi

# Injetar :account_id e :zone_id no path quando presentes
EXPANDED_PATH="$REQ_PATH"
case "$EXPANDED_PATH" in
  *:account_id*)
    [ -z "$ACCOUNT_ID" ] && { printf 'path contem :account_id mas conta nao resolve account_id\n' >&2; exit 4; }
    EXPANDED_PATH=$(printf '%s' "$EXPANDED_PATH" | sed "s/:account_id/$ACCOUNT_ID/g")
    ;;
esac

if [ -n "$ZONE" ]; then
  # --zone aceita id literal ou nickname (futuro: resolver nick via registry)
  ZONE_ID="$ZONE"
  case "$EXPANDED_PATH" in
    *:zone_id*) EXPANDED_PATH=$(printf '%s' "$EXPANDED_PATH" | sed "s/:zone_id/$ZONE_ID/g") ;;
  esac
fi

# Garante leading slash
case "$EXPANDED_PATH" in
  /*) ;;
  *) EXPANDED_PATH="/$EXPANDED_PATH" ;;
esac

URL="$BASE$EXPANDED_PATH"
[ -n "$QUERY" ] && URL="$URL?$QUERY"

# Body: --data-file tem precedencia sobre --data
BODY=""
if [ -n "$DATA_FILE" ]; then
  [ ! -f "$DATA_FILE" ] && { printf 'arquivo nao encontrado: %s\n' "$DATA_FILE" >&2; exit 4; }
  BODY=$(cat "$DATA_FILE")
elif [ -n "$DATA" ]; then
  BODY="$DATA"
fi

audit_log() {
  # audit_log <status> <success>
  [ "$AUDIT" != "on" ] && return 0
  AUDIT_DIR="${CLAUDE_CREDS_DIR:-$HOME/.claude/credentials}/cloudflare/${ACCOUNT:-default}"
  mkdir -p "$AUDIT_DIR" 2>/dev/null || return 0
  printf '%s %s %s account=%s status=%s success=%s\n' \
    "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$METHOD" "$EXPANDED_PATH" \
    "${ACCOUNT:-default}" "$1" "$2" >> "$AUDIT_DIR/audit.log" 2>/dev/null || true
}

if [ "$DRY_RUN" = "1" ]; then
  printf 'DRY-RUN\n' >&2
  printf '%s %s\n' "$METHOD" "$URL"
  printf 'Authorization: Bearer [REDACTED]\n'
  printf 'Content-Type: application/json\n'
  [ -n "$BODY" ] && printf '\n%s\n' "$BODY"
  exit 0
fi

# Backoff exponencial: 1s, 2s, 4s, ... + jitter
sleep_backoff() {
  ATTEMPT="$1"
  SLEEP=$(awk "BEGIN { print 2^($ATTEMPT - 1) }")
  JITTER=$(awk 'BEGIN { srand(); print rand() }')
  awk "BEGIN { print $SLEEP + $JITTER }"
}

# Parse Retry-After (segundos ou HTTP date)
parse_retry_after() {
  HEADER_VAL="$1"
  case "$HEADER_VAL" in
    ''|*[!0-9]*) echo "" ;;
    *) echo "$HEADER_VAL" ;;
  esac
}

ATTEMPT=1
while [ "$ATTEMPT" -le "$(( RETRY + 1 ))" ]; do
  HEADERS_FILE=$(mktemp)
  BODY_FILE=$(mktemp)

  set +e
  if [ -n "$BODY" ]; then
    HTTP_CODE=$(curl -s -w '%{http_code}' -o "$BODY_FILE" -D "$HEADERS_FILE" \
      --max-time "$TIMEOUT" \
      -X "$METHOD" \
      -H "Authorization: Bearer $TOKEN" \
      -H "Content-Type: application/json" \
      -d "$BODY" \
      "$URL")
    CURL_RC=$?
  else
    HTTP_CODE=$(curl -s -w '%{http_code}' -o "$BODY_FILE" -D "$HEADERS_FILE" \
      --max-time "$TIMEOUT" \
      -X "$METHOD" \
      -H "Authorization: Bearer $TOKEN" \
      -H "Accept: application/json" \
      "$URL")
    CURL_RC=$?
  fi
  set -e

  if [ "$CURL_RC" != "0" ]; then
    printf '[try %s/%s] erro de rede (curl=%s)\n' "$ATTEMPT" "$(( RETRY + 1 ))" "$CURL_RC" >&2
    rm -f "$HEADERS_FILE" "$BODY_FILE"
    if [ "$ATTEMPT" -le "$RETRY" ]; then
      DELAY=$(sleep_backoff "$ATTEMPT")
      sleep "$DELAY" 2>/dev/null || true
      ATTEMPT=$(( ATTEMPT + 1 ))
      continue
    fi
    audit_log "network-error" "false"
    exit 2
  fi

  case "$HTTP_CODE" in
    2*)
      BODY_CONTENT=$(cat "$BODY_FILE")
      rm -f "$HEADERS_FILE" "$BODY_FILE"
      SUCCESS=$(printf '%s' "$BODY_CONTENT" | jq -r '.success // true' 2>/dev/null || echo "true")
      if [ "$SUCCESS" = "false" ]; then
        printf '%s' "$BODY_CONTENT" | jq -c '.errors // []' >&2
        audit_log "$HTTP_CODE" "false"
        case "$FORMAT" in
          pretty) printf '%s' "$BODY_CONTENT" | jq . ;;
          raw)    printf '%s' "$BODY_CONTENT" ;;
          *)      printf '%s' "$BODY_CONTENT" ;;
        esac
        exit 1
      fi
      audit_log "$HTTP_CODE" "true"
      case "$FORMAT" in
        pretty) printf '%s' "$BODY_CONTENT" | jq . ;;
        raw)    printf '%s' "$BODY_CONTENT" ;;
        *)      printf '%s' "$BODY_CONTENT" ;;
      esac
      exit 0
      ;;
    429)
      RETRY_AFTER=$(grep -i '^retry-after:' "$HEADERS_FILE" 2>/dev/null | awk -F': ' '{print $2}' | tr -d '\r\n ')
      RETRY_AFTER=$(parse_retry_after "$RETRY_AFTER")
      DELAY=${RETRY_AFTER:-$(sleep_backoff "$ATTEMPT")}
      printf '[try %s/%s] rate limited 429 — aguardando %ss\n' "$ATTEMPT" "$(( RETRY + 1 ))" "$DELAY" >&2
      rm -f "$HEADERS_FILE" "$BODY_FILE"
      if [ "$ATTEMPT" -le "$RETRY" ]; then
        sleep "$DELAY" 2>/dev/null || true
        ATTEMPT=$(( ATTEMPT + 1 ))
        continue
      fi
      audit_log "429" "false"
      exit 2
      ;;
    5*)
      printf '[try %s/%s] erro servidor %s\n' "$ATTEMPT" "$(( RETRY + 1 ))" "$HTTP_CODE" >&2
      BODY_PREVIEW=$(head -c 500 "$BODY_FILE" 2>/dev/null || echo "")
      rm -f "$HEADERS_FILE" "$BODY_FILE"
      if [ "$ATTEMPT" -le "$RETRY" ]; then
        DELAY=$(sleep_backoff "$ATTEMPT")
        sleep "$DELAY" 2>/dev/null || true
        ATTEMPT=$(( ATTEMPT + 1 ))
        continue
      fi
      audit_log "$HTTP_CODE" "false"
      printf '%s\n' "$BODY_PREVIEW" >&2
      exit 2
      ;;
    *)
      BODY_CONTENT=$(cat "$BODY_FILE")
      rm -f "$HEADERS_FILE" "$BODY_FILE"
      printf '[erro] http=%s\n' "$HTTP_CODE" >&2
      printf '%s' "$BODY_CONTENT" | jq -c '.errors // []' >&2 2>/dev/null || printf '%s\n' "$BODY_CONTENT" >&2
      audit_log "$HTTP_CODE" "false"
      case "$FORMAT" in
        pretty) printf '%s' "$BODY_CONTENT" | jq . 2>/dev/null || printf '%s' "$BODY_CONTENT" ;;
        *) printf '%s' "$BODY_CONTENT" ;;
      esac
      exit 1
      ;;
  esac
done
