#!/bin/sh
# test_retro.sh — cobre global/skills/agente-00c-runtime/scripts/retro.sh.

TESTS_ROOT="${TESTS_ROOT:-$(cd "$(dirname "$0")" && pwd)}"
REPO_ROOT="${REPO_ROOT:-$(cd "$TESTS_ROOT/.." && pwd)}"
. "$TESTS_ROOT/lib/harness.sh"

SCRIPT="$REPO_ROOT/global/skills/agente-00c-runtime/scripts/retro.sh"
RW="$REPO_ROOT/global/skills/agente-00c-runtime/scripts/state-rw.sh"

if ! command -v jq >/dev/null 2>&1; then
  printf '# test_retro.sh: jq ausente — pulando\n'
  exit 0
fi

_init() {
  capture "$RW" init --state-dir "$1" --execucao-id "x" \
    --projeto-alvo-path "/tmp/p" --descricao "POC retro tests"
}

scenario_count_inicial_0_2() {
  _sd="$TMPDIR_TEST/state"
  _init "$_sd"
  capture "$SCRIPT" count --state-dir "$_sd"
  assert_stdout_contains "0/2" || return 1
}

scenario_check_inicial_passa() {
  _sd="$TMPDIR_TEST/state"
  _init "$_sd"
  capture "$SCRIPT" check --state-dir "$_sd"
  [ "$_CAPTURED_EXIT" = 0 ] || { _fail "check 0/2" "$_CAPTURED_EXIT"; return 1; }
}

scenario_consume_incrementa() {
  _sd="$TMPDIR_TEST/state"
  _init "$_sd"
  capture "$SCRIPT" consume --state-dir "$_sd"
  assert_stdout_contains "1" || return 1
  capture "$SCRIPT" consume --state-dir "$_sd"
  assert_stdout_contains "2" || return 1
  capture "$SCRIPT" count --state-dir "$_sd"
  assert_stdout_contains "2/2" || return 1
}

scenario_check_no_limite_exit_3() {
  _sd="$TMPDIR_TEST/state"
  _init "$_sd"
  capture "$SCRIPT" consume --state-dir "$_sd"
  capture "$SCRIPT" consume --state-dir "$_sd"
  capture "$SCRIPT" check --state-dir "$_sd"
  if [ "$_CAPTURED_EXIT" != 3 ]; then
    _fail "check 2/2" "esperado 3, obtido $_CAPTURED_EXIT"
    return 1
  fi
}

scenario_consume_terceira_vez_exit_3_sem_modificar() {
  _sd="$TMPDIR_TEST/state"
  _init "$_sd"
  capture "$SCRIPT" consume --state-dir "$_sd"
  capture "$SCRIPT" consume --state-dir "$_sd"
  _before=$(jq -r '.orcamentos.retro_execucoes_consumidas' "$_sd/state.json")
  capture "$SCRIPT" consume --state-dir "$_sd"
  if [ "$_CAPTURED_EXIT" != 3 ]; then
    _fail "consume 3rd" "esperado 3, obtido $_CAPTURED_EXIT"
    return 1
  fi
  assert_stderr_contains "consume negado" || return 1
  _after=$(jq -r '.orcamentos.retro_execucoes_consumidas' "$_sd/state.json")
  if [ "$_before" != "$_after" ]; then
    _fail "consume negado MUTOU estado" "before=$_before after=$_after"
    return 1
  fi
}

scenario_reset_zera() {
  _sd="$TMPDIR_TEST/state"
  _init "$_sd"
  capture "$SCRIPT" consume --state-dir "$_sd"
  capture "$SCRIPT" consume --state-dir "$_sd"
  capture "$SCRIPT" reset --state-dir "$_sd"
  capture "$SCRIPT" count --state-dir "$_sd"
  assert_stdout_contains "0/2" || return 1
}

scenario_state_ausente_falha() {
  _sd="$TMPDIR_TEST/empty"
  mkdir -p "$_sd"
  capture "$SCRIPT" check --state-dir "$_sd"
  if [ "$_CAPTURED_EXIT" != 1 ]; then
    _fail "state ausente" "esperado 1"
    return 1
  fi
}

run_all_scenarios
