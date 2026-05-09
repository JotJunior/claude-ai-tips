#!/bin/sh
# test_budget.sh — cobre global/skills/agente-00c-runtime/scripts/budget.sh.

TESTS_ROOT="${TESTS_ROOT:-$(cd "$(dirname "$0")" && pwd)}"
REPO_ROOT="${REPO_ROOT:-$(cd "$TESTS_ROOT/.." && pwd)}"
. "$TESTS_ROOT/lib/harness.sh"

SCRIPT="$REPO_ROOT/global/skills/agente-00c-runtime/scripts/budget.sh"
RW="$REPO_ROOT/global/skills/agente-00c-runtime/scripts/state-rw.sh"
ON="$REPO_ROOT/global/skills/agente-00c-runtime/scripts/state-ondas.sh"

if ! command -v jq >/dev/null 2>&1; then
  printf '# test_budget.sh: jq ausente — pulando\n'
  exit 0
fi

_init_with_onda() {
  capture "$RW" init --state-dir "$1" --execucao-id "x" \
    --projeto-alvo-path "/tmp/p" --descricao "POC budget tests"
  capture "$ON" start --state-dir "$1"
}

scenario_status_imprime_3_linhas_tsv() {
  _sd="$TMPDIR_TEST/state"
  _init_with_onda "$_sd"
  capture "$SCRIPT" status --state-dir "$_sd"
  [ "$_CAPTURED_EXIT" = 0 ] || { _fail "status" "$_CAPTURED_STDERR"; return 1; }
  assert_stdout_contains "tool_calls	0	80" || return 1
  assert_stdout_contains "wallclock	" || return 1
  assert_stdout_contains "state_size	" || return 1
}

scenario_check_inicial_passa() {
  _sd="$TMPDIR_TEST/state"
  _init_with_onda "$_sd"
  capture "$SCRIPT" check --state-dir "$_sd"
  [ "$_CAPTURED_EXIT" = 0 ] || { _fail "check inicial" "$_CAPTURED_STDERR"; return 1; }
}

scenario_tool_calls_threshold_dispara_exit_1() {
  _sd="$TMPDIR_TEST/state"
  _init_with_onda "$_sd"
  capture "$RW" set --state-dir "$_sd" \
    --field '.orcamentos.tool_calls_onda_corrente' --value '85'
  capture "$SCRIPT" check --state-dir "$_sd"
  if [ "$_CAPTURED_EXIT" != 1 ]; then
    _fail "tool_calls trigger" "esperado 1, obtido $_CAPTURED_EXIT"
    return 1
  fi
  assert_stdout_contains "tool_calls	85	80" || return 1
}

scenario_state_size_threshold_dispara_exit_1() {
  _sd="$TMPDIR_TEST/state"
  _init_with_onda "$_sd"
  # Reduz threshold p/ valor menor que estado atual
  capture "$RW" set --state-dir "$_sd" \
    --field '.orcamentos.estado_size_threshold_bytes' --value '100'
  capture "$SCRIPT" check --state-dir "$_sd"
  if [ "$_CAPTURED_EXIT" != 1 ]; then
    _fail "state_size trigger" "esperado 1, obtido $_CAPTURED_EXIT"
    return 1
  fi
  assert_stdout_contains "state_size	" || return 1
}

scenario_wallclock_threshold_dispara_exit_1() {
  _sd="$TMPDIR_TEST/state"
  _init_with_onda "$_sd"
  # Reduz threshold p/ 0 -> qualquer wallclock dispara
  capture "$RW" set --state-dir "$_sd" \
    --field '.orcamentos.wallclock_threshold_segundos' --value '0'
  capture "$SCRIPT" check --state-dir "$_sd"
  if [ "$_CAPTURED_EXIT" != 1 ]; then
    _fail "wallclock trigger" "esperado 1, obtido $_CAPTURED_EXIT"
    return 1
  fi
  assert_stdout_contains "wallclock	" || return 1
}

scenario_check_state_ausente_falha() {
  _sd="$TMPDIR_TEST/empty"
  mkdir -p "$_sd"
  capture "$SCRIPT" check --state-dir "$_sd"
  if [ "$_CAPTURED_EXIT" != 1 ]; then
    _fail "state ausente" "esperado 1"
    return 1
  fi
}

run_all_scenarios
