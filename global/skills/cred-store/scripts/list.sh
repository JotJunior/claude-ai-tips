#!/bin/sh
# list.sh — lista credenciais registradas no store (sem mostrar segredos).
#
# Uso:
#   scripts/list.sh                    # tabela legivel
#   scripts/list.sh --format=json      # JSON para consumo programatico
#   scripts/list.sh --provider=cloudflare   # filtra por provider

set -eu

STORE_DIR="${CLAUDE_CREDS_DIR:-$HOME/.claude/credentials}"
REGISTRY="$STORE_DIR/registry.json"

FORMAT="table"
PROVIDER_FILTER=""

for arg in "$@"; do
  case "$arg" in
    --format=*) FORMAT="${arg#--format=}" ;;
    --provider=*) PROVIDER_FILTER="${arg#--provider=}" ;;
    -h|--help)
      cat <<'USAGE'
list.sh — lista credenciais registradas

Uso:
  list.sh [--format=table|json] [--provider=<name>]

Nenhuma opcao mostra segredos — apenas metadata publica e fontes.
USAGE
      exit 0
      ;;
  esac
done

if [ ! -f "$REGISTRY" ]; then
  printf 'registry vazio (%s nao existe)\n' "$REGISTRY" >&2
  exit 0
fi

if ! command -v jq >/dev/null 2>&1; then
  printf 'erro: jq obrigatorio\n' >&2
  exit 4
fi

FILTER='.'
if [ -n "$PROVIDER_FILTER" ]; then
  FILTER="with_entries(select(.key | startswith(\"$PROVIDER_FILTER.\")))"
fi

case "$FORMAT" in
  json)
    jq "$FILTER | with_entries(.value |= del(.ref) | .value |= del(.fallback_sources))" "$REGISTRY"
    ;;
  table)
    printf '%-40s %-10s %-30s %s\n' KEY SOURCE CREATED METADATA
    printf '%-40s %-10s %-30s %s\n' \
      '----------------------------------------' \
      '----------' \
      '------------------------------' \
      '--------'
    jq -r "$FILTER | to_entries[] | [.key, .value.source, (.value.created_at // \"-\"), (.value.metadata // {} | tostring)] | @tsv" "$REGISTRY" \
      | awk -F'\t' '{ printf "%-40s %-10s %-30s %s\n", $1, $2, $3, $4 }'
    ;;
  *)
    printf 'erro: --format deve ser table|json\n' >&2
    exit 4
    ;;
esac
