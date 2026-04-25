#!/bin/sh
# test_common.sh — cobre cli/lib/common.sh
#
# Contrato:
#   log_info/warn/error imprimem "[level] msg" em stderr (nao stdout)
#   is_tty retorna 0/1 conforme stdout
#   color_enabled respeita NO_COLOR e TERM=dumb

TESTS_ROOT="${TESTS_ROOT:-$(cd "$(dirname "$0")/.." && pwd)}"
REPO_ROOT="${REPO_ROOT:-$(cd "$TESTS_ROOT/.." && pwd)}"

. "$TESTS_ROOT/lib/harness.sh"

CSTK_LIB="$REPO_ROOT/cli/lib"
export CSTK_LIB

# Helper para sourcing dentro de subshell isolado (evita poluicao).
_in_subshell() {
  sh -c "CSTK_LIB=$CSTK_LIB . $CSTK_LIB/common.sh; $*"
}

scenario_log_info_vai_para_stderr() {
  capture sh -c ". $CSTK_LIB/common.sh && log_info 'hello'"
  if [ "$_CAPTURED_EXIT" != "0" ]; then
    _fail "log_info exit $_CAPTURED_EXIT" "esperado 0"
    return 1
  fi
  assert_stderr_contains "[info] hello" || return 1
  if [ -n "$_CAPTURED_STDOUT" ]; then
    _fail "log_info stdout nao vazio" "stdout=$_CAPTURED_STDOUT"
    return 1
  fi
}

scenario_log_warn_formato() {
  capture sh -c ". $CSTK_LIB/common.sh && log_warn 'uh oh'"
  assert_stderr_contains "[warn] uh oh" || return 1
}

scenario_log_error_formato() {
  capture sh -c ". $CSTK_LIB/common.sh && log_error 'broke'"
  assert_stderr_contains "[error] broke" || return 1
}

scenario_is_tty_em_pipe_e_falso() {
  # quando stdout e capturado (pipe), is_tty retorna 1
  capture sh -c ". $CSTK_LIB/common.sh && is_tty"
  if [ "$_CAPTURED_EXIT" = "0" ]; then
    _fail "is_tty retornou 0 em pipe" "esperava 1"
    return 1
  fi
}

scenario_color_respeita_no_color() {
  capture sh -c "NO_COLOR=1 . $CSTK_LIB/common.sh && color_enabled"
  if [ "$_CAPTURED_EXIT" = "0" ]; then
    _fail "color_enabled honrou NO_COLOR?" "esperado !=0"
    return 1
  fi
}

scenario_color_dumb_term() {
  capture sh -c "TERM=dumb . $CSTK_LIB/common.sh && color_enabled"
  if [ "$_CAPTURED_EXIT" = "0" ]; then
    _fail "color_enabled honrou TERM=dumb?" "esperado !=0"
    return 1
  fi
}

scenario_idempotente_source() {
  # Sourcing duas vezes nao deve falhar nem redefinir.
  assert_exit 0 sh -c ". $CSTK_LIB/common.sh && . $CSTK_LIB/common.sh && log_info ok" \
    || return 1
}

run_all_scenarios
