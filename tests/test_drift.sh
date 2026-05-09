#!/bin/sh
# test_drift.sh — cobre global/skills/agente-00c-runtime/scripts/drift.sh.

TESTS_ROOT="${TESTS_ROOT:-$(cd "$(dirname "$0")" && pwd)}"
REPO_ROOT="${REPO_ROOT:-$(cd "$TESTS_ROOT/.." && pwd)}"
. "$TESTS_ROOT/lib/harness.sh"

SCRIPT="$REPO_ROOT/global/skills/agente-00c-runtime/scripts/drift.sh"
RW="$REPO_ROOT/global/skills/agente-00c-runtime/scripts/state-rw.sh"
ON="$REPO_ROOT/global/skills/agente-00c-runtime/scripts/state-ondas.sh"
DEC="$REPO_ROOT/global/skills/agente-00c-runtime/scripts/state-decisions.sh"

if ! command -v jq >/dev/null 2>&1; then
  printf '# test_drift.sh: jq ausente — pulando\n'
  exit 0
fi

_init() {
  capture "$RW" init --state-dir "$1" --execucao-id "x" \
    --projeto-alvo-path "/tmp/p" --descricao "POC drift tests"
}

# Cria 1 onda completa com 1 decisao tendo o contexto especificado
_run_wave() {
  capture "$ON" start --state-dir "$1"
  capture "$DEC" register --state-dir "$1" \
    --agente "x" --etapa "specify" \
    --contexto "$2" --opcoes '["A"]' --escolha "A" \
    --justificativa "justificativa de tamanho ok aqui sim"
  capture "$ON" end --state-dir "$1" --motivo-termino etapa_concluida_avancando
}

scenario_init_grava_aspectos() {
  _sd="$TMPDIR_TEST/state"
  _init "$_sd"
  capture "$SCRIPT" init --state-dir "$_sd" --aspectos '["slack","bot","threads"]'
  [ "$_CAPTURED_EXIT" = 0 ] || { _fail "init" "$_CAPTURED_STDERR"; return 1; }
  capture "$SCRIPT" aspectos --state-dir "$_sd"
  assert_stdout_contains "slack" || return 1
  assert_stdout_contains "bot" || return 1
  assert_stdout_contains "threads" || return 1
}

scenario_init_array_pequeno_falha() {
  _sd="$TMPDIR_TEST/state"
  _init "$_sd"
  capture "$SCRIPT" init --state-dir "$_sd" --aspectos '["a","b"]'
  if [ "$_CAPTURED_EXIT" != 1 ]; then
    _fail "init <3 aspectos" "esperado 1, obtido $_CAPTURED_EXIT"
    return 1
  fi
}

scenario_init_array_grande_falha() {
  _sd="$TMPDIR_TEST/state"
  _init "$_sd"
  capture "$SCRIPT" init --state-dir "$_sd" \
    --aspectos '["a","b","c","d","e","f","g","h"]'
  if [ "$_CAPTURED_EXIT" != 1 ]; then
    _fail "init >7 aspectos" "esperado 1"
    return 1
  fi
}

scenario_init_duplicado_falha_congelado() {
  _sd="$TMPDIR_TEST/state"
  _init "$_sd"
  capture "$SCRIPT" init --state-dir "$_sd" --aspectos '["a","b","c"]'
  capture "$SCRIPT" init --state-dir "$_sd" --aspectos '["x","y","z"]'
  if [ "$_CAPTURED_EXIT" != 1 ]; then
    _fail "init duplicado" "esperado 1"
    return 1
  fi
  assert_stderr_contains "ja foi gravado" || return 1
}

scenario_check_sem_aspectos_disable() {
  _sd="$TMPDIR_TEST/state"
  _init "$_sd"
  capture "$SCRIPT" check --state-dir "$_sd"
  [ "$_CAPTURED_EXIT" = 0 ] || { _fail "exit" "$_CAPTURED_EXIT"; return 1; }
  assert_stdout_contains "0" || return 1
  assert_stderr_contains "nao inicializado" || return 1
}

scenario_check_drift_zero_quando_aspectos_tocados() {
  _sd="$TMPDIR_TEST/state"
  _init "$_sd"
  capture "$SCRIPT" init --state-dir "$_sd" --aspectos '["slack","bot","threads"]'
  _run_wave "$_sd" "Bot Slack para sumarizar threads"
  capture "$SCRIPT" check --state-dir "$_sd"
  [ "$_CAPTURED_EXIT" = 0 ] || { _fail "drift c/ aspectos" "$_CAPTURED_EXIT"; return 1; }
  assert_stdout_contains "0" || return 1
}

scenario_check_warn_em_3_ondas_drift() {
  _sd="$TMPDIR_TEST/state"
  _init "$_sd"
  capture "$SCRIPT" init --state-dir "$_sd" --aspectos '["slack","bot","threads"]'
  for _ in 1 2 3; do
    _run_wave "$_sd" "Decidir lib de logging para microservico"
  done
  capture "$SCRIPT" check --state-dir "$_sd"
  [ "$_CAPTURED_EXIT" = 0 ] || { _fail "warn deve exit 0" "$_CAPTURED_EXIT"; return 1; }
  assert_stdout_contains "3" || return 1
  assert_stderr_contains "AVISO" || return 1
}

scenario_check_abort_em_5_ondas_drift() {
  _sd="$TMPDIR_TEST/state"
  _init "$_sd"
  capture "$SCRIPT" init --state-dir "$_sd" --aspectos '["slack","bot","threads"]'
  for _ in 1 2 3 4 5; do
    _run_wave "$_sd" "Decidir lib de logging para microservico"
  done
  capture "$SCRIPT" check --state-dir "$_sd"
  if [ "$_CAPTURED_EXIT" != 3 ]; then
    _fail "abort 5 ondas" "esperado 3, obtido $_CAPTURED_EXIT"
    return 1
  fi
  assert_stderr_contains "desvio_de_finalidade" || return 1
}

scenario_check_drift_resetado_ao_tocar_aspecto() {
  _sd="$TMPDIR_TEST/state"
  _init "$_sd"
  capture "$SCRIPT" init --state-dir "$_sd" --aspectos '["slack","bot","threads"]'
  for _ in 1 2 3; do
    _run_wave "$_sd" "Decidir lib de logging para microservico"
  done
  # Onda 4 toca aspecto
  _run_wave "$_sd" "Bot Slack agora discute integracao com threads"
  capture "$SCRIPT" check --state-dir "$_sd"
  [ "$_CAPTURED_EXIT" = 0 ] || { _fail "exit" "$_CAPTURED_EXIT"; return 1; }
  # Drift conta do FINAL para o INICIO; onda 4 toca → count=0
  assert_stdout_contains "0" || return 1
}

run_all_scenarios
