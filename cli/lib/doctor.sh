# doctor.sh — comando `cstk doctor`.
#
# Ref: docs/specs/cstk-cli/contracts/cli-commands.md §doctor
#      docs/specs/cstk-cli/spec.md §SC-007
#      docs/specs/cstk-cli/quickstart.md Scenario 10
#
# Funcao exportada:
#   doctor_main "$@"
#
# Sintaxe:
#   cstk doctor [--scope global|project] [--fix]
#
# Comportamento:
#   1. Le manifest do scope; le diretorios em scope_dir/
#   2. Classifica cada skill em uma destas categorias:
#        OK      — entry no manifest + dir em disco + hash match
#        EDITED  — entry no manifest + dir em disco + hash mismatch
#        MISSING — entry no manifest, mas dir ausente em disco
#        ORPHAN  — dir em disco, mas sem entry no manifest (third-party)
#   3. Reporta achados em stderr; resumo final
#   4. --fix: remove entries MISSING; recalcula source_sha256 de skills OK
#      (refresh, ainda que normalmente nao haja diff). NUNCA modifica
#      conteudo de skills (FR-007: third-party preservado; EDITED fica
#      inalterado para preservar trabalho do usuario).
#
# Exit codes:
#   0 sem drift OU --fix executado (best-effort reconciliation)
#   1 drift detectado sem --fix
#   2 uso incorreto

if [ -n "${_CSTK_DOCTOR_LOADED:-}" ]; then
  return 0 2>/dev/null
fi
_CSTK_DOCTOR_LOADED=1

# shellcheck source=/dev/null
. "${CSTK_LIB:?CSTK_LIB must be set}/common.sh"
# shellcheck source=/dev/null
. "${CSTK_LIB}/compat.sh"
# shellcheck source=/dev/null
. "${CSTK_LIB}/hash.sh"
# shellcheck source=/dev/null
. "${CSTK_LIB}/manifest.sh"

_doctor_print_help() {
  cat >&2 <<'HELP'
cstk doctor — verifica integridade da instalacao (manifest vs disco).

USO:
  cstk doctor [--scope global|project] [--fix]

OPCOES:
  --scope S   global (default) ou project
  --fix       Reconcilia: remove entries MISSING; recalcula hash de OK.
              NUNCA modifica conteudo de skills.

CLASSIFICACAO:
  OK       entry + dir + hash batem
  EDITED   entry + dir, mas hash diverge (edit local — use cstk update --force)
  MISSING  entry sem dir (use --fix para limpar manifest)
  ORPHAN   dir sem entry (skill third-party — preservada)

EXIT:
  0  sem drift, ou --fix executado
  1  drift detectado sem --fix
HELP
}

doctor_main() {
  _doctor_reset_state

  if ! _doctor_parse_args "$@"; then
    return 2
  fi

  if [ "$_doctor_help" = 1 ]; then
    _doctor_print_help
    return 0
  fi

  if ! _doctor_resolve_scope_dir; then
    return 1
  fi

  # Walk manifest entries primeiro
  if [ -f "$_doctor_manifest_path" ]; then
    _doctor_old_ifs=$IFS
    IFS='
'
    for _line in $(read_manifest "$_doctor_manifest_path"); do
      IFS=$_doctor_old_ifs
      _skill=$(printf '%s' "$_line" | awk -F'\t' '{print $1}')
      _stored_sha=$(printf '%s' "$_line" | awk -F'\t' '{print $3}')
      _doctor_classify_entry "$_skill" "$_stored_sha"
      IFS='
'
    done
    IFS=$_doctor_old_ifs
  fi

  # Walk disk dirs em scope_dir/ — quem nao tem entry vira ORPHAN
  if [ -d "$_doctor_scope_dir" ]; then
    for _d in "$_doctor_scope_dir"/*; do
      [ -d "$_d" ] || continue
      _name=$(basename -- "$_d")
      # Skipa lock dirs e arquivos de manifest.
      case "$_name" in
        .cstk.lock|.cstk-manifest|.*) continue ;;
      esac
      # Se nao listado no manifest -> ORPHAN
      if ! _doctor_in_seen "$_name"; then
        _doctor_record "$_name" ORPHAN ""
      fi
    done
  fi

  # Aplica --fix se solicitado, antes do report final.
  if [ "$_doctor_fix" = 1 ]; then
    _doctor_apply_fix
  fi

  _doctor_emit_report

  if [ "$_doctor_fix" = 1 ]; then
    return 0
  fi
  if [ "$_doctor_count_drift" -gt 0 ]; then
    return 1
  fi
  return 0
}

_doctor_reset_state() {
  _doctor_help=0
  _doctor_fix=0
  _doctor_scope=global
  _doctor_scope_dir=""
  _doctor_manifest_path=""
  _doctor_seen=""
  _doctor_findings=""
  _doctor_count_ok=0
  _doctor_count_edited=0
  _doctor_count_missing=0
  _doctor_count_orphan=0
  _doctor_count_drift=0
}

_doctor_parse_args() {
  while [ "$#" -gt 0 ]; do
    case "$1" in
      --help|-h) _doctor_help=1; shift ;;
      --fix) _doctor_fix=1; shift ;;
      --scope)
        if [ "$#" -lt 2 ]; then log_error "doctor: --scope exige valor"; return 1; fi
        case "$2" in
          global|project) _doctor_scope=$2 ;;
          *) log_error "doctor: --scope invalido: $2"; return 1 ;;
        esac
        shift 2
        ;;
      --scope=*)
        _doctor_scope=${1#--scope=}
        case "$_doctor_scope" in
          global|project) ;;
          *) log_error "doctor: --scope invalido"; return 1 ;;
        esac
        shift
        ;;
      --) shift; break ;;
      -*) log_error "doctor: flag desconhecida: $1"; return 1 ;;
      *) log_error "doctor: argumento posicional inesperado: $1"; return 1 ;;
    esac
  done
  return 0
}

_doctor_resolve_scope_dir() {
  case "$_doctor_scope" in
    global) _doctor_scope_dir="${HOME:?HOME nao setado}/.claude/skills" ;;
    project) _doctor_scope_dir="./.claude/skills" ;;
    *) log_error "doctor: scope invalido"; return 1 ;;
  esac
  _doctor_manifest_path=$(manifest_default_path "$_doctor_scope") || return 1
  return 0
}

# _doctor_classify_entry: classifica uma entry do manifest (skill, stored_sha).
_doctor_classify_entry() {
  _ce_skill=$1
  _ce_stored=$2
  _doctor_seen="$_doctor_seen
$_ce_skill"

  _ce_dir="$_doctor_scope_dir/$_ce_skill"
  if [ ! -d "$_ce_dir" ]; then
    _doctor_record "$_ce_skill" MISSING ""
    return 0
  fi
  _ce_hash=$(hash_dir "$_ce_dir" 2>/dev/null) || _ce_hash=""
  if [ "$_ce_hash" = "$_ce_stored" ]; then
    _doctor_record "$_ce_skill" OK "$_ce_hash"
  else
    _doctor_record "$_ce_skill" EDITED "$_ce_hash"
  fi
}

_doctor_in_seen() {
  case "$_doctor_seen" in
    *"
$1"*) return 0 ;;
  esac
  return 1
}

# _doctor_record: anota status; mantem em $_doctor_findings (status\tskill\tdetail).
_doctor_record() {
  _r_skill=$1
  _r_status=$2
  _r_detail=$3
  _doctor_findings="$_doctor_findings
$_r_status	$_r_skill	$_r_detail"
  case "$_r_status" in
    OK) _doctor_count_ok=$((_doctor_count_ok + 1)) ;;
    EDITED)
      _doctor_count_edited=$((_doctor_count_edited + 1))
      _doctor_count_drift=$((_doctor_count_drift + 1))
      ;;
    MISSING)
      _doctor_count_missing=$((_doctor_count_missing + 1))
      _doctor_count_drift=$((_doctor_count_drift + 1))
      ;;
    ORPHAN)
      _doctor_count_orphan=$((_doctor_count_orphan + 1))
      _doctor_count_drift=$((_doctor_count_drift + 1))
      ;;
  esac
}

# _doctor_apply_fix: implementa --fix. Reparos seguros apenas:
#   - MISSING: remove entry do manifest
#   - OK: recalcula hash e re-upserta (refresh; idempotente)
# NAO toca: EDITED (preserva edits do usuario), ORPHAN (preserva third-party).
_doctor_apply_fix() {
  _df_old_ifs=$IFS
  IFS='
'
  for _f in $_doctor_findings; do
    IFS=$_df_old_ifs
    _status=$(printf '%s' "$_f" | awk -F'\t' '{print $1}')
    _skill=$(printf '%s' "$_f" | awk -F'\t' '{print $2}')
    _detail=$(printf '%s' "$_f" | awk -F'\t' '{print $3}')
    case "$_status" in
      MISSING)
        if ! remove_entry "$_doctor_manifest_path" "$_skill"; then
          log_error "doctor --fix: remove_entry falhou para $_skill"
        else
          log_info "doctor --fix: removida entry MISSING $_skill"
        fi
        ;;
      OK)
        # Refresh: reusa entry atual mas com hash recalculado (no-op se nao mudou)
        _entry=$(lookup_entry "$_doctor_manifest_path" "$_skill") || continue
        _ver=$(printf '%s' "$_entry" | awk -F'\t' '{print $2}')
        _ts=$(printf '%s' "$_entry" | awk -F'\t' '{print $4}')
        upsert_entry "$_doctor_manifest_path" "$_skill" "$_ver" "$_detail" "$_ts" 2>/dev/null || :
        ;;
    esac
    IFS='
'
  done
  IFS=$_df_old_ifs
}

_doctor_emit_report() {
  {
    printf '==> cstk doctor (scope: %s)\n' "$_doctor_scope"
    if [ -n "$_doctor_findings" ]; then
      _emit_old_ifs=$IFS
      IFS='
'
      for _f in $_doctor_findings; do
        IFS=$_emit_old_ifs
        _status=$(printf '%s' "$_f" | awk -F'\t' '{print $1}')
        _skill=$(printf '%s' "$_f" | awk -F'\t' '{print $2}')
        case "$_status" in
          OK)      printf '  [OK]       %s\n' "$_skill" ;;
          EDITED)  printf '  [EDITED]   %s    local edits detected\n' "$_skill" ;;
          MISSING) printf '  [MISSING]  %s    in manifest, not on disk\n' "$_skill" ;;
          ORPHAN)  printf '  [ORPHAN]   %s    on disk, not in manifest (third-party)\n' "$_skill" ;;
        esac
        IFS='
'
      done
      IFS=$_emit_old_ifs
    fi
    printf '  ---\n'
    printf '  ok:      %d\n' "$_doctor_count_ok"
    printf '  edited:  %d\n' "$_doctor_count_edited"
    printf '  missing: %d\n' "$_doctor_count_missing"
    printf '  orphan:  %d\n' "$_doctor_count_orphan"
    if [ "$_doctor_count_drift" -gt 0 ]; then
      if [ "$_doctor_fix" = 1 ]; then
        printf '  --fix executado: entries MISSING removidas; EDITED/ORPHAN preservados.\n'
      else
        printf '  [DRIFT] %d issue(s). Run with --fix to reconcile manifest.\n' "$_doctor_count_drift"
      fi
    fi
  } >&2
}
