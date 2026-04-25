# list.sh — comando `cstk list`.
#
# Ref: docs/specs/cstk-cli/contracts/cli-commands.md §list
#      docs/specs/cstk-cli/spec.md FR-013 (observabilidade)
#
# Funcao exportada:
#   list_main "$@"
#
# Sintaxe:
#   cstk list [--scope global|project] [--format tsv|pretty] [--available]
#             [--from URL]
#
# Modos:
#   default       — le manifest do scope; status clean/edited/missing por skill
#   --available   — baixa catalog da release alvo (sem lock, sem escrita) e
#                   lista skills disponiveis no catalog
#
# Format default: pretty em TTY, tsv em pipe (FR observabilidade).
#
# Exit codes:
#   0 sucesso
#   1 erro (manifest corrompido / download falhou em --available)
#   2 uso incorreto

if [ -n "${_CSTK_LIST_LOADED:-}" ]; then
  return 0 2>/dev/null
fi
_CSTK_LIST_LOADED=1

# shellcheck source=/dev/null
. "${CSTK_LIB:?CSTK_LIB must be set}/common.sh"
# shellcheck source=/dev/null
. "${CSTK_LIB}/compat.sh"
# shellcheck source=/dev/null
. "${CSTK_LIB}/http.sh"
# shellcheck source=/dev/null
. "${CSTK_LIB}/tarball.sh"
# shellcheck source=/dev/null
. "${CSTK_LIB}/hash.sh"
# shellcheck source=/dev/null
. "${CSTK_LIB}/manifest.sh"

_list_print_help() {
  cat >&2 <<'HELP'
cstk list — lista skills instaladas (manifest) ou disponiveis (--available).

USO:
  cstk list [--scope global|project] [--format tsv|pretty] [--available]
            [--from URL]

OPCOES:
  --scope S      global (default) ou project
  --format F     tsv ou pretty. Default: pretty em TTY, tsv em pipe.
  --available    Lista catalog da release alvo (precisa de --from ou
                 $CSTK_RELEASE_URL); nao adquire lock nem escreve.
  --from URL     URL do tarball para --available.

EXEMPLOS:
  cstk list                       # skills instaladas em global
  cstk list --scope project       # skills do projeto atual
  cstk list --available --from URL    # skills disponiveis no catalog
HELP
}

list_main() {
  _list_reset_state

  if ! _list_parse_args "$@"; then
    return 2
  fi

  if [ "$_list_help" = 1 ]; then
    _list_print_help
    return 0
  fi

  if ! _list_resolve_scope_dir; then
    return 1
  fi

  # Format default depende de TTY
  if [ -z "$_list_format" ]; then
    if is_tty; then
      _list_format=pretty
    else
      _list_format=tsv
    fi
  fi

  if [ "$_list_available" = 1 ]; then
    _list_do_available
    return $?
  fi

  _list_do_local
  return $?
}

_list_reset_state() {
  _list_help=0
  _list_available=0
  _list_scope=global
  _list_format=""
  _list_from=""
  _list_scope_dir=""
  _list_manifest_path=""
  _list_staged=""
  _list_catalog_dir=""
  _list_release_version=""
}

_list_parse_args() {
  while [ "$#" -gt 0 ]; do
    case "$1" in
      --help|-h) _list_help=1; shift ;;
      --available) _list_available=1; shift ;;
      --scope)
        if [ "$#" -lt 2 ]; then
          log_error "list: --scope exige valor"
          return 1
        fi
        case "$2" in
          global|project) _list_scope=$2 ;;
          *) log_error "list: --scope invalido: $2"; return 1 ;;
        esac
        shift 2
        ;;
      --scope=*)
        _list_scope=${1#--scope=}
        case "$_list_scope" in
          global|project) ;;
          *) log_error "list: --scope invalido: $_list_scope"; return 1 ;;
        esac
        shift
        ;;
      --format)
        if [ "$#" -lt 2 ]; then
          log_error "list: --format exige valor (tsv|pretty)"
          return 1
        fi
        case "$2" in
          tsv|pretty) _list_format=$2 ;;
          *) log_error "list: --format invalido: $2 (use tsv|pretty)"; return 1 ;;
        esac
        shift 2
        ;;
      --format=*)
        _list_format=${1#--format=}
        case "$_list_format" in
          tsv|pretty) ;;
          *) log_error "list: --format invalido: $_list_format"; return 1 ;;
        esac
        shift
        ;;
      --from)
        if [ "$#" -lt 2 ] || [ -z "$2" ]; then
          log_error "list: --from exige valor (URL)"
          return 1
        fi
        _list_from=$2
        shift 2
        ;;
      --from=*)
        _list_from=${1#--from=}
        shift
        ;;
      --) shift; break ;;
      -*)
        log_error "list: flag desconhecida: $1"
        return 1
        ;;
      *)
        log_error "list: argumento posicional inesperado: $1"
        return 1
        ;;
    esac
  done
  return 0
}

_list_resolve_scope_dir() {
  case "$_list_scope" in
    global) _list_scope_dir="${HOME:?HOME nao setado}/.claude/skills" ;;
    project) _list_scope_dir="./.claude/skills" ;;
    *) log_error "list: scope invalido"; return 1 ;;
  esac
  _list_manifest_path=$(manifest_default_path "$_list_scope") || return 1
  return 0
}

# _list_do_local: itera manifest, classifica cada entry, emite no formato.
_list_do_local() {
  if [ ! -f "$_list_manifest_path" ]; then
    log_warn "list: manifest ausente em $_list_manifest_path (nada instalado)"
    return 0
  fi

  # Header em pretty
  if [ "$_list_format" = pretty ]; then
    printf '%-25s %-10s %-10s %s\n' "SKILL" "VERSION" "STATUS" "INSTALLED"
  fi

  _list_count=0
  _list_old_ifs=$IFS
  IFS='
'
  for _line in $(read_manifest "$_list_manifest_path"); do
    IFS=$_list_old_ifs
    _list_count=$((_list_count + 1))
    _skill=$(printf '%s' "$_line" | awk -F'\t' '{print $1}')
    _version=$(printf '%s' "$_line" | awk -F'\t' '{print $2}')
    _stored_sha=$(printf '%s' "$_line" | awk -F'\t' '{print $3}')
    _ts=$(printf '%s' "$_line" | awk -F'\t' '{print $4}')

    _dst="$_list_scope_dir/$_skill"
    if [ ! -d "$_dst" ]; then
      _status=missing
    else
      _hash=$(hash_dir "$_dst" 2>/dev/null) || _hash=""
      if [ "$_hash" = "$_stored_sha" ]; then
        _status=clean
      else
        _status=edited
      fi
    fi

    case "$_list_format" in
      tsv)
        printf '%s\t%s\t%s\t%s\n' "$_skill" "$_version" "$_status" "$_ts"
        ;;
      pretty)
        # Trunca/pad data para "YYYY-MM-DD"
        _date=$(printf '%s' "$_ts" | cut -c1-10)
        printf '%-25s %-10s %-10s %s\n' "$_skill" "$_version" "$_status" "$_date"
        ;;
    esac
    IFS='
'
  done
  IFS=$_list_old_ifs
  return 0
}

# _list_do_available: baixa catalog e lista skills disponiveis (sem lock).
_list_do_available() {
  if [ -z "$_list_from" ]; then
    _list_from=${CSTK_RELEASE_URL:-}
  fi
  if [ -z "$_list_from" ]; then
    log_error "list --available: --from URL ausente e \$CSTK_RELEASE_URL nao setado"
    return 1
  fi
  case "$_list_from" in
    http://*|https://*|file://*) ;;
    *) log_error "list --available: --from precisa ser URL"; return 1 ;;
  esac

  _list_staged=$(mktemp -d 2>/dev/null) || {
    log_error "list: mktemp falhou"
    return 1
  }
  trap 'rm -rf -- "$_list_staged" 2>/dev/null || :' EXIT INT TERM

  if ! download_and_verify "$_list_from" "${_list_from}.sha256" "$_list_staged"; then
    return 1
  fi

  _list_catalog_dir=$(find "$_list_staged" -maxdepth 3 -type d -name catalog 2>/dev/null | head -1)
  if [ -z "$_list_catalog_dir" ] || [ ! -d "$_list_catalog_dir" ]; then
    log_error "list: catalog/ nao encontrado no tarball"
    return 1
  fi
  if [ -f "$_list_catalog_dir/VERSION" ]; then
    _list_release_version=$(head -n 1 -- "$_list_catalog_dir/VERSION" | tr -d '[:space:]')
  fi

  if [ "$_list_format" = pretty ]; then
    printf '%-25s %s\n' "SKILL" "ORIGIN"
  fi

  # Lista skills do catalog (skills/ + language/*/skills/)
  if [ -d "$_list_catalog_dir/skills" ]; then
    for _d in "$_list_catalog_dir/skills"/*; do
      [ -d "$_d" ] || continue
      _name=$(basename -- "$_d")
      _list_emit_available "$_name" "global"
    done
  fi
  if [ -d "$_list_catalog_dir/language" ]; then
    for _lang in "$_list_catalog_dir/language"/*; do
      [ -d "$_lang/skills" ] || continue
      _lang_name=$(basename -- "$_lang")
      for _d in "$_lang/skills"/*; do
        [ -d "$_d" ] || continue
        _name=$(basename -- "$_d")
        _list_emit_available "$_name" "language-$_lang_name"
      done
    done
  fi
  return 0
}

_list_emit_available() {
  _ea_name=$1
  _ea_origin=$2
  case "$_list_format" in
    tsv) printf '%s\t%s\n' "$_ea_name" "$_ea_origin" ;;
    pretty) printf '%-25s %s\n' "$_ea_name" "$_ea_origin" ;;
  esac
}
