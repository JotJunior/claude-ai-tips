#!/bin/sh
# secrets-filter.sh — filtro de secrets em report/suggestions/issue (FR-030).
#
# Ref: docs/specs/agente-00c/spec.md FR-030
#      docs/specs/agente-00c/threat-model.md T4
#      docs/specs/agente-00c/tasks.md FASE 6.6
#
# Le stdin, escreve stdout com substituicao de cada match por [REDACTED].
# Aplica em ordem (cada padrao independente, nao excludente):
#
#   1. Tokens com palavra-chave proxima:
#      `(token|key|secret|password|pwd|auth|api_key|access_key)\s*[:=]\s*"?[A-Za-z0-9_-]{20,}"?`
#      → reduz falsos positivos (hashes git, UUIDs sem contexto NAO sao filtrados)
#   2. AWS access keys: `AKIA[A-Z0-9]{16,}`
#   3. Bearer tokens: `Bearer\s+[A-Za-z0-9._-]+`
#   4. Basic auth em URLs: `https?://[^:]+:[^@]+@`
#   5. Valores de chaves do .env do projeto-alvo (carregado via --env-file).
#      Para cada `CHAVE=VALOR` em .env, substitui `VALOR` por [REDACTED].
#
# Subcomandos:
#   secrets-filter.sh scrub [--env-file FILE]
#       — Le stdin, aplica filtros, escreve stdout.
#       — `--env-file` opcional (se ausente, pula passo 5).
#
#   secrets-filter.sh check [--env-file FILE]
#       — Le stdin. Exit 0 se NAO contem secrets; exit 1 se contem (com
#         conteudo dos matches em stderr — nao em stdout para evitar leak
#         em pipelines).
#
# Exit codes:
#   0 sucesso (scrub) ou nenhum secret encontrado (check)
#   1 secret detectado em check
#   2 uso incorreto
#
# POSIX sh + sed/grep/awk.

set -eu

_SF_NAME="secrets-filter"

_sf_die_usage() { printf '%s: %s\n' "$_SF_NAME" "$1" >&2; exit 2; }

# Marcador unico usado durante substituicao multi-passo
_SF_MARK="[REDACTED]"

# _sf_apply_filters STDIN-via-pipe ENV_FILE
# Imprime stdin filtrado em stdout. Aplicacao em sequencia via tempfiles
# (mais simples e portavel que multiplas substituicoes em sed -e).
_sf_apply_filters() {
  _env=$1
  _t1=$(mktemp); _t2=$(mktemp)
  cat > "$_t1"

  # Ordem: especificos primeiro (rules com formato unico), generico ultimo.
  # Caso contrario, o regex generico de token mascararia AKIA/Bearer com
  # [REDACTED] genenrico e perderia o tipo do secret.

  # 1. AWS access keys (formato unico)
  sed -E 's/AKIA[A-Z0-9]{16,}/[REDACTED-AWS-KEY]/g' "$_t1" > "$_t2"
  mv "$_t2" "$_t1"; _t2=$(mktemp)

  # 2. Bearer tokens (formato unico)
  sed -E 's/Bearer[[:space:]]+[A-Za-z0-9._=+\/-]+/Bearer [REDACTED]/g' "$_t1" > "$_t2"
  mv "$_t2" "$_t1"; _t2=$(mktemp)

  # 3. Basic auth em URLs (https://user:pass@host -> https://[REDACTED]@host)
  sed -E 's,(https?://)[^:[:space:]]+:[^@[:space:]]+@,\1[REDACTED]@,g' "$_t1" > "$_t2"
  mv "$_t2" "$_t1"; _t2=$(mktemp)

  # 4. Tokens genericos com palavra-chave proxima (proximidade reduz falsos
  #    positivos). Regex: (KEY) WS* [:=] WS* "?" [A-Za-z0-9...]{20,} "?".
  if sed -E -e 's/((token|key|secret|password|pwd|auth|api_?key|access_?key)[[:space:]]*[:=][[:space:]]*"?)[A-Za-z0-9_=+\/-]{20,}("?)/\1[REDACTED]\3/Ig' \
    "$_t1" > "$_t2" 2>/dev/null; then
    mv "$_t2" "$_t1"
    _t2=$(mktemp)
  fi

  # 5. Valores de .env (se passado)
  if [ -n "$_env" ] && [ -f "$_env" ]; then
    while IFS= read -r _line || [ -n "$_line" ]; do
      case "$_line" in
        ''|\#*|export\ *=\ *|*=\ *) ;;
      esac
      # Pula vazias/comentarios
      case "$_line" in
        ''|\#*) continue ;;
      esac
      # Captura VALOR de KEY=VALUE (remove `export ` opcional, aspas)
      _l=$(printf '%s' "$_line" | sed -E 's/^export[[:space:]]+//')
      _val=$(printf '%s' "$_l" | sed -nE 's/^[A-Za-z_][A-Za-z0-9_]*=//p')
      [ -z "$_val" ] && continue
      # Remove aspas externas
      _val=$(printf '%s' "$_val" | sed -E 's/^"(.*)"$/\1/; s/^'"'"'(.*)'"'"'$/\1/')
      # Comprimentos curtos sao ignorados (high false-positive rate)
      _len=$(printf '%s' "$_val" | wc -c | tr -d ' ')
      [ "$_len" -lt 8 ] && continue
      # Escape de caracteres especiais para sed (path delimiter usado: ESC do RS)
      _esc=$(printf '%s' "$_val" | sed 's/[]\/$*.^[]/\\&/g')
      sed -E "s/${_esc}/[REDACTED-ENV]/g" "$_t1" > "$_t2"
      mv "$_t2" "$_t1"; _t2=$(mktemp)
    done < "$_env"
  fi

  cat "$_t1"
  rm -f -- "$_t1" "$_t2" 2>/dev/null || :
}

_sf_cmd_scrub() {
  _env=""
  while [ "$#" -gt 0 ]; do
    case "$1" in
      --env-file) _env=$2; shift 2 ;;
      *) _sf_die_usage "scrub: flag desconhecida: $1" ;;
    esac
  done
  _sf_apply_filters "$_env"
}

_sf_cmd_check() {
  _env=""
  while [ "$#" -gt 0 ]; do
    case "$1" in
      --env-file) _env=$2; shift 2 ;;
      *) _sf_die_usage "check: flag desconhecida: $1" ;;
    esac
  done
  # Aplica filtros e compara com original
  _orig=$(mktemp); _filt=$(mktemp)
  cat > "$_orig"
  # Re-injetar via pipe
  _sf_apply_filters "$_env" < "$_orig" > "$_filt"
  if cmp -s "$_orig" "$_filt"; then
    rm -f -- "$_orig" "$_filt"
    exit 0
  fi
  printf '%s: SECRETS DETECTADOS no input\n' "$_SF_NAME" >&2
  rm -f -- "$_orig" "$_filt"
  exit 1
}

# ---------- Dispatch ----------

if [ "$#" -lt 1 ]; then
  cat >&2 <<'HELP'
secrets-filter.sh — filtro de secrets em report/suggestions/issue (FR-030).

USO:
  secrets-filter.sh scrub [--env-file FILE]   < input > output
  secrets-filter.sh check [--env-file FILE]   < input

Aplica em sequencia: tokens com palavra-chave proxima, AWS keys, Bearer
tokens, basic auth em URLs, valores de .env (se --env-file).

EXIT (check):
  0 nenhum secret detectado
  1 secret detectado
HELP
  exit 2
fi

_SF_SUBCMD=$1
shift

case "$_SF_SUBCMD" in
  scrub)           _sf_cmd_scrub "$@" ;;
  check)           _sf_cmd_check "$@" ;;
  -h|--help|help)  exit 0 ;;
  *) _sf_die_usage "subcomando desconhecido: $_SF_SUBCMD" ;;
esac
