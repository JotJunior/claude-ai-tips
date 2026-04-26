# ui.sh — modo interativo: seletor numerado em TTY (FASE 8.1).
#
# Ref: docs/specs/cstk-cli/spec.md FR-009 (modo interativo)
#      docs/specs/cstk-cli/research.md Decision 8 (sem fzf/dialog)
#      docs/specs/cstk-cli/quickstart.md Scenarios 11, 12
#
# Funcoes exportadas:
#   require_tty                          — 0 OK; 1 nao-TTY (caller mapeia exit 2)
#   ui_select_interactive PROFILES_PATH SKILLS_LIST [MODE]
#                                        — orchestrator. PROFILES_PATH pode ser
#                                          vazio (modo update). SKILLS_LIST e
#                                          string newline-separated.
#                                          MODE = "install" | "update" (so usado
#                                          em mensagens). Default "install".
#                                          Stdout: skills selecionadas, uma por
#                                          linha. Exit 0 OK, 1 abort/erro.
#   _ui_apply_toggle CURRENT INPUT       — pure helper; aplica toggle (XOR de
#                                          numeros). Stdout: novo set ordenado.
#                                          Retorno: 0 OK, 1 input invalido.
#   _ui_resolve_skills SELECTION INDEX_TSV PROFILES_PATH
#                                        — pure helper; expande profiles +
#                                          adiciona skills explicitas. Stdout:
#                                          skills resolvidas (sort -u).
#
# Bypass de TTY check (apenas testes):
#   CSTK_FORCE_INTERACTIVE=1 — pula require_tty e le stdin normalmente
#
# POSIX sh + awk. Deps: read, awk, sort, printf, sed, wc.

if [ -n "${_CSTK_UI_LOADED:-}" ]; then
  return 0 2>/dev/null
fi
_CSTK_UI_LOADED=1

# shellcheck source=/dev/null
. "${CSTK_LIB:?CSTK_LIB must be set}/common.sh"
# shellcheck source=/dev/null
. "${CSTK_LIB}/profiles.sh"

# require_tty: verifica que stdin e TTY (necessario para `read` interativo).
# Retorno: 0 OK; 1 nao-TTY (caller deve abortar com exit 2).
require_tty() {
  if [ "${CSTK_FORCE_INTERACTIVE:-0}" = 1 ]; then
    return 0
  fi
  if [ -t 0 ]; then
    return 0
  fi
  log_error "ui: --interactive requires a TTY. Use --profile or explicit skill names instead."
  return 1
}

# _ui_apply_toggle CURRENT INPUT
# Pure: aplica XOR set entre CURRENT (sorted-unique numbers) e INPUT (raw user
# input — espacos/tabs como separador, dedup interno do INPUT primeiro).
# Stdout: novo set, espaco-separado, ordenado numericamente, sem duplicatas.
# Retorno: 0 OK, 1 INPUT contem caractere invalido (so digitos/whitespace OK).
_ui_apply_toggle() {
  _upt_current=$1
  _upt_input=$2
  case "$_upt_input" in
    *[!0-9\ \	]*)
      return 1
      ;;
  esac
  printf '%s\n%s\n' "$_upt_current" "$_upt_input" | awk '
    NR == 1 {
      n = split($0, a, /[ \t]+/)
      for (i = 1; i <= n; i++) if (a[i] != "") set[a[i] + 0] = 1
      next
    }
    NR == 2 {
      # Dedup do INPUT antes de aplicar toggle (re-digitar mesmo numero
      # numa unica linha = no-op em vez de toggle duplo).
      n = split($0, a, /[ \t]+/)
      for (i = 1; i <= n; i++) {
        if (a[i] == "") continue
        seen[a[i] + 0] = 1
      }
      for (k in seen) {
        if (k in set) delete set[k]
        else set[k] = 1
      }
    }
    END {
      m = 0
      for (k in set) {
        m++
        sorted[m] = k + 0
      }
      for (i = 2; i <= m; i++) {
        key = sorted[i]; j = i - 1
        while (j >= 1 && sorted[j] > key) { sorted[j+1] = sorted[j]; j-- }
        sorted[j+1] = key
      }
      out = ""
      for (i = 1; i <= m; i++) out = (i == 1 ? sorted[i] "" : out " " sorted[i])
      print out
    }
  '
}

# _ui_build_index PROFILES_PATH SKILLS_LIST
# Pure: emite TSV "kind<TAB>number<TAB>name" enumerando profiles entao skills.
# PROFILES_PATH vazio = pula bloco de profiles (modo update).
# SKILLS_LIST e string com uma skill por linha.
_ui_build_index() {
  _ubi_profiles_path=$1
  _ubi_skills_list=$2
  _ubi_idx=0
  if [ -n "$_ubi_profiles_path" ] && [ -f "$_ubi_profiles_path" ]; then
    _ubi_profiles=$(list_profiles "$_ubi_profiles_path") || _ubi_profiles=""
    _ubi_old_ifs=$IFS
    IFS='
'
    for _ubi_p in $_ubi_profiles; do
      IFS=$_ubi_old_ifs
      [ -n "$_ubi_p" ] || continue
      _ubi_idx=$((_ubi_idx + 1))
      printf 'profile\t%d\t%s\n' "$_ubi_idx" "$_ubi_p"
      IFS='
'
    done
    IFS=$_ubi_old_ifs
  fi
  if [ -n "$_ubi_skills_list" ]; then
    _ubi_old_ifs=$IFS
    IFS='
'
    for _ubi_s in $_ubi_skills_list; do
      IFS=$_ubi_old_ifs
      [ -n "$_ubi_s" ] || continue
      _ubi_idx=$((_ubi_idx + 1))
      printf 'skill\t%d\t%s\n' "$_ubi_idx" "$_ubi_s"
      IFS='
'
    done
    IFS=$_ubi_old_ifs
  fi
}

# _ui_render_menu INDEX_TSV
# Imprime menu numerado em stderr a partir do INDEX_TSV.
_ui_render_menu() {
  _urm_index=$1
  _urm_seen_profile=0
  _urm_seen_skill=0
  printf '\n' >&2
  printf '%s\n' "$_urm_index" | while IFS='	' read -r _urm_kind _urm_num _urm_name; do
    [ -n "$_urm_kind" ] || continue
    case "$_urm_kind" in
      profile)
        if [ "$_urm_seen_profile" = 0 ]; then
          printf 'Profiles:\n' >&2
          _urm_seen_profile=1
        fi
        printf '  %3d) %s\n' "$_urm_num" "$_urm_name" >&2
        ;;
      skill)
        if [ "$_urm_seen_skill" = 0 ]; then
          printf 'Skills:\n' >&2
          _urm_seen_skill=1
        fi
        printf '  %3d) %s\n' "$_urm_num" "$_urm_name" >&2
        ;;
    esac
  done
}

# _ui_resolve_skills SELECTION INDEX_TSV PROFILES_PATH
# Pure: para cada numero em SELECTION, mapeia via INDEX_TSV. Profiles sao
# expandidos via resolve_profile (skills); skills passam direto.
# Stdout: skills resolvidas, uma por linha, sort -u.
# Numeros invalidos (fora do INDEX) sao reportados em stderr e ignorados.
_ui_resolve_skills() {
  _urs_selection=$1
  _urs_index=$2
  _urs_profiles_path=$3
  _urs_tmp_index=$(mktemp 2>/dev/null) || return 1
  printf '%s\n' "$_urs_index" > "$_urs_tmp_index"

  _urs_out=""
  _urs_old_ifs=$IFS
  IFS=' 	'
  set -- $_urs_selection
  IFS=$_urs_old_ifs

  for _urs_n in "$@"; do
    [ -n "$_urs_n" ] || continue
    _urs_match=$(awk -F'\t' -v n="$_urs_n" '$2 == n { print $1 "\t" $3; exit }' "$_urs_tmp_index")
    if [ -z "$_urs_match" ]; then
      log_warn "ui: numero invalido (ignorado): $_urs_n"
      continue
    fi
    _urs_kind=${_urs_match%%	*}
    _urs_name=${_urs_match#*	}
    case "$_urs_kind" in
      profile)
        if [ -n "$_urs_profiles_path" ]; then
          _urs_expand=$(resolve_profile "$_urs_profiles_path" "$_urs_name") || {
            log_warn "ui: falha ao expandir profile $_urs_name"
            continue
          }
          _urs_out="$_urs_out
$_urs_expand"
        else
          log_warn "ui: profile sem profiles_path (bug interno): $_urs_name"
        fi
        ;;
      skill)
        _urs_out="$_urs_out
$_urs_name"
        ;;
    esac
  done

  rm -f "$_urs_tmp_index" 2>/dev/null || :
  printf '%s\n' "$_urs_out" | awk 'NF>0' | sort -u
}

# ui_select_interactive PROFILES_PATH SKILLS_LIST [MODE]
# Orchestrator: render -> loop de toggle -> confirm -> resolve.
# Stdout: skills resolvidas (uma por linha) em sucesso.
# Retorno: 0 OK, 1 abort/erro/no-tty.
ui_select_interactive() {
  _usi_profiles_path=$1
  _usi_skills_list=$2
  _usi_mode=${3:-install}

  if ! require_tty; then
    return 1
  fi

  _usi_index=$(_ui_build_index "$_usi_profiles_path" "$_usi_skills_list")
  if [ -z "$_usi_index" ]; then
    log_error "ui: nada para selecionar (catalog/manifest vazio)"
    return 1
  fi

  printf '==> cstk %s — modo interativo\n' "$_usi_mode" >&2
  _ui_render_menu "$_usi_index"

  _usi_selection=""
  while :; do
    printf '\nNumeros para toggle (espaco-separados; ENTER para concluir, q para abortar): ' >&2
    if ! IFS= read -r _usi_line; then
      log_error "ui: stdin fechou inesperadamente"
      return 1
    fi
    case "$_usi_line" in
      q|Q|quit|QUIT)
        log_warn "ui: cancelado pelo usuario"
        return 1
        ;;
      "")
        break
        ;;
    esac
    _usi_new=$(_ui_apply_toggle "$_usi_selection" "$_usi_line") || {
      log_warn "ui: input invalido (use apenas digitos e espacos): $_usi_line"
      continue
    }
    _usi_selection=$_usi_new
    printf 'Selecao atual: %s\n' "${_usi_selection:-<vazio>}" >&2
  done

  if [ -z "$_usi_selection" ]; then
    log_error "ui: nenhuma selecao feita — abortado"
    return 1
  fi

  _usi_resolved=$(_ui_resolve_skills "$_usi_selection" "$_usi_index" "$_usi_profiles_path")
  if [ -z "$_usi_resolved" ]; then
    log_error "ui: selecao resolveu set vazio (numeros invalidos?) — abortado"
    return 1
  fi

  _usi_count=$(printf '%s\n' "$_usi_resolved" | awk 'NF>0' | wc -l | awk '{print $1}')
  printf '\nSelecao final (%d skill(s)):\n' "$_usi_count" >&2
  printf '%s\n' "$_usi_resolved" | sed 's/^/  - /' >&2
  printf 'Confirmar? [y/N] ' >&2
  if ! IFS= read -r _usi_confirm; then
    log_error "ui: stdin fechou inesperadamente"
    return 1
  fi
  case "$_usi_confirm" in
    y|Y|yes|YES|s|S|sim|SIM) ;;
    *)
      log_warn "ui: cancelado pelo usuario"
      return 1
      ;;
  esac

  printf '%s\n' "$_usi_resolved"
  return 0
}
