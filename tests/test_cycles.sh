#!/bin/sh
# test_cycles.sh — cobre global/skills/agente-00c-runtime/scripts/cycles.sh.

TESTS_ROOT="${TESTS_ROOT:-$(cd "$(dirname "$0")" && pwd)}"
REPO_ROOT="${REPO_ROOT:-$(cd "$TESTS_ROOT/.." && pwd)}"
. "$TESTS_ROOT/lib/harness.sh"

SCRIPT="$REPO_ROOT/global/skills/agente-00c-runtime/scripts/cycles.sh"
RW="$REPO_ROOT/global/skills/agente-00c-runtime/scripts/state-rw.sh"

if ! command -v jq >/dev/null 2>&1; then
  printf '# test_cycles.sh: jq ausente — pulando\n'
  exit 0
fi

_init() {
  capture "$RW" init --state-dir "$1" --execucao-id "x" \
    --projeto-alvo-path "/tmp/p" --descricao "POC cycles tests"
}

scenario_count_inicial_zero() {
  _sd="$TMPDIR_TEST/state"
  _init "$_sd"
  capture "$SCRIPT" count --state-dir "$_sd"
  assert_stdout_contains "0" || return 1
}

scenario_tick_incrementa_sequencial() {
  _sd="$TMPDIR_TEST/state"
  _init "$_sd"
  for n in 1 2 3; do
    capture "$SCRIPT" tick --state-dir "$_sd"
    assert_stdout_contains "$n" || return 1
  done
  capture "$SCRIPT" count --state-dir "$_sd"
  assert_stdout_contains "3" || return 1
}

scenario_tick_progress_made_zera() {
  _sd="$TMPDIR_TEST/state"
  _init "$_sd"
  capture "$SCRIPT" tick --state-dir "$_sd"
  capture "$SCRIPT" tick --state-dir "$_sd"
  capture "$SCRIPT" tick --state-dir "$_sd" --progress-made
  assert_stdout_contains "0" || return 1
}

scenario_tick_acima_de_max_exit_3() {
  _sd="$TMPDIR_TEST/state"
  _init "$_sd"
  for _ in 1 2 3 4 5; do
    capture "$SCRIPT" tick --state-dir "$_sd"
    [ "$_CAPTURED_EXIT" = 0 ] || { _fail "tick legal" "$_CAPTURED_EXIT"; return 1; }
  done
  capture "$SCRIPT" tick --state-dir "$_sd"
  if [ "$_CAPTURED_EXIT" != 3 ]; then
    _fail "tick > 5" "esperado 3, obtido $_CAPTURED_EXIT"
    return 1
  fi
  assert_stderr_contains "loop_em_etapa" || return 1
}

scenario_check_acima_de_max_exit_3() {
  _sd="$TMPDIR_TEST/state"
  _init "$_sd"
  capture "$RW" set --state-dir "$_sd" \
    --field '.orcamentos.ciclos_consumidos_etapa_corrente' --value '6'
  capture "$SCRIPT" check --state-dir "$_sd"
  if [ "$_CAPTURED_EXIT" != 3 ]; then
    _fail "check > 5" "esperado 3, obtido $_CAPTURED_EXIT"
    return 1
  fi
}

scenario_reset_zera_contador() {
  _sd="$TMPDIR_TEST/state"
  _init "$_sd"
  capture "$SCRIPT" tick --state-dir "$_sd"
  capture "$SCRIPT" tick --state-dir "$_sd"
  capture "$SCRIPT" reset --state-dir "$_sd"
  capture "$SCRIPT" count --state-dir "$_sd"
  assert_stdout_contains "0" || return 1
}

scenario_state_ausente_falha() {
  _sd="$TMPDIR_TEST/empty"
  mkdir -p "$_sd"
  capture "$SCRIPT" tick --state-dir "$_sd"
  if [ "$_CAPTURED_EXIT" != 1 ]; then
    _fail "state ausente" "esperado 1"
    return 1
  fi
}

run_all_scenarios
