#!/bin/sh
# test_spawn-tracker.sh — cobre global/skills/agente-00c-runtime/scripts/spawn-tracker.sh.

TESTS_ROOT="${TESTS_ROOT:-$(cd "$(dirname "$0")" && pwd)}"
REPO_ROOT="${REPO_ROOT:-$(cd "$TESTS_ROOT/.." && pwd)}"

. "$TESTS_ROOT/lib/harness.sh"

SCRIPT="$REPO_ROOT/global/skills/agente-00c-runtime/scripts/spawn-tracker.sh"
RW="$REPO_ROOT/global/skills/agente-00c-runtime/scripts/state-rw.sh"

if ! command -v jq >/dev/null 2>&1; then
  printf '# test_spawn-tracker.sh: jq ausente — pulando suite\n'
  exit 0
fi

_init_state() {
  capture "$RW" init --state-dir "$1" \
    --execucao-id "exec-spawn-test" --projeto-alvo-path "/tmp/p" --descricao "POC spawn"
}

scenario_inicial_profundidade_1() {
  _sd="$TMPDIR_TEST/state"
  _init_state "$_sd"
  capture "$SCRIPT" current --state-dir "$_sd"
  assert_stdout_contains "1" || return 1
}

scenario_check_inicial_passa() {
  _sd="$TMPDIR_TEST/state"
  _init_state "$_sd"
  capture "$SCRIPT" check --state-dir "$_sd"
  [ "$_CAPTURED_EXIT" = 0 ] || { _fail "check inicial" "$_CAPTURED_EXIT"; return 1; }
}

scenario_enter_incrementa_e_persiste() {
  _sd="$TMPDIR_TEST/state"
  _init_state "$_sd"
  capture "$SCRIPT" enter --state-dir "$_sd"
  [ "$_CAPTURED_EXIT" = 0 ] || { _fail "enter" "$_CAPTURED_STDERR"; return 1; }
  assert_stdout_contains "2" || return 1
  capture "$SCRIPT" current --state-dir "$_sd"
  assert_stdout_contains "2" || return 1
  capture "$RW" get --state-dir "$_sd" --field '.metricas_acumuladas.subagentes_spawned'
  assert_stdout_contains "1" || return 1
}

scenario_enter_max_atingida_atualizada() {
  _sd="$TMPDIR_TEST/state"
  _init_state "$_sd"
  capture "$SCRIPT" enter --state-dir "$_sd"
  capture "$SCRIPT" enter --state-dir "$_sd"
  capture "$RW" get --state-dir "$_sd" --field '.metricas_acumuladas.profundidade_max_atingida'
  assert_stdout_contains "3" || return 1
}

scenario_enter_excedendo_max_exit_3_sem_modificar_estado() {
  _sd="$TMPDIR_TEST/state"
  _init_state "$_sd"
  capture "$SCRIPT" enter --state-dir "$_sd"  # 1->2
  capture "$SCRIPT" enter --state-dir "$_sd"  # 2->3
  # Snapshot do estado antes do enter ilegal
  _before=$(jq -c '.orcamentos.profundidade_corrente_subagentes' "$_sd/state.json")
  capture "$SCRIPT" enter --state-dir "$_sd"  # 3->4 negado
  if [ "$_CAPTURED_EXIT" != 3 ]; then
    _fail "enter ilegal exit" "esperado 3, obtido $_CAPTURED_EXIT"
    return 1
  fi
  assert_stderr_contains "MAX 3" || return 1
  _after=$(jq -c '.orcamentos.profundidade_corrente_subagentes' "$_sd/state.json")
  if [ "$_before" != "$_after" ]; then
    _fail "enter negado MUTOU estado" "before=$_before after=$_after"
    return 1
  fi
}

scenario_check_no_limite_exit_3() {
  _sd="$TMPDIR_TEST/state"
  _init_state "$_sd"
  capture "$SCRIPT" enter --state-dir "$_sd"
  capture "$SCRIPT" enter --state-dir "$_sd"
  capture "$SCRIPT" check --state-dir "$_sd"
  if [ "$_CAPTURED_EXIT" != 3 ]; then
    _fail "check no limite" "esperado 3, obtido $_CAPTURED_EXIT"
    return 1
  fi
}

scenario_leave_decrementa() {
  _sd="$TMPDIR_TEST/state"
  _init_state "$_sd"
  capture "$SCRIPT" enter --state-dir "$_sd"
  capture "$SCRIPT" leave --state-dir "$_sd"
  assert_stdout_contains "1" || return 1
}

scenario_leave_idempotente_no_minimo() {
  _sd="$TMPDIR_TEST/state"
  _init_state "$_sd"
  capture "$SCRIPT" leave --state-dir "$_sd"
  [ "$_CAPTURED_EXIT" = 0 ] || { _fail "leave inicial" "$_CAPTURED_EXIT"; return 1; }
  assert_stdout_contains "1" || return 1
  capture "$SCRIPT" current --state-dir "$_sd"
  assert_stdout_contains "1" || return 1
}

scenario_state_ausente_falha() {
  _sd="$TMPDIR_TEST/empty"
  mkdir -p "$_sd"
  capture "$SCRIPT" check --state-dir "$_sd"
  if [ "$_CAPTURED_EXIT" != 1 ]; then
    _fail "state ausente" "esperado 1, obtido $_CAPTURED_EXIT"
    return 1
  fi
}

run_all_scenarios
