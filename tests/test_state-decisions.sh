#!/bin/sh
# test_state-decisions.sh — cobre global/skills/agente-00c-runtime/scripts/state-decisions.sh.

TESTS_ROOT="${TESTS_ROOT:-$(cd "$(dirname "$0")" && pwd)}"
REPO_ROOT="${REPO_ROOT:-$(cd "$TESTS_ROOT/.." && pwd)}"

. "$TESTS_ROOT/lib/harness.sh"

SCRIPT="$REPO_ROOT/global/skills/agente-00c-runtime/scripts/state-decisions.sh"
RW="$REPO_ROOT/global/skills/agente-00c-runtime/scripts/state-rw.sh"

if ! command -v jq >/dev/null 2>&1; then
  printf '# test_state-decisions.sh: jq ausente — pulando suite\n'
  exit 0
fi

_init_state() {
  capture "$RW" init --state-dir "$1" \
    --execucao-id "exec-test-3" --projeto-alvo-path "/tmp/p" --descricao "POC FASE 3"
}

# Wrapper para registro com defaults validos
_register_default() {
  capture "$SCRIPT" register --state-dir "$1" \
    --agente "${2:-orquestrador-00c}" \
    --etapa "${3:-briefing}" \
    --contexto "Pergunta sobre stakeholders do projeto-alvo" \
    --opcoes '["Operador unico","Time pequeno"]' \
    --escolha "Operador unico" \
    --justificativa "Briefing do 00C marca uso pessoal sem stakeholders externos"
}

scenario_register_basico_gera_dec_001() {
  _sd="$TMPDIR_TEST/state"
  _init_state "$_sd"
  [ "$_CAPTURED_EXIT" = 0 ] || { _fail "init" ""; return 1; }
  _register_default "$_sd"
  if [ "$_CAPTURED_EXIT" != 0 ]; then
    _fail "register" "$_CAPTURED_EXIT; $_CAPTURED_STDERR"
    return 1
  fi
  assert_stdout_contains "dec-001" || return 1
  capture "$SCRIPT" count --state-dir "$_sd"
  assert_stdout_contains "1" || return 1
}

scenario_register_sequencial_gera_dec_002() {
  _sd="$TMPDIR_TEST/state"
  _init_state "$_sd"
  _register_default "$_sd"
  _register_default "$_sd"
  capture "$SCRIPT" next-id --state-dir "$_sd"
  assert_stdout_contains "dec-003" || return 1
  capture "$SCRIPT" count --state-dir "$_sd"
  assert_stdout_contains "2" || return 1
}

scenario_contexto_curto_violacao_principio_i() {
  _sd="$TMPDIR_TEST/state"
  _init_state "$_sd"
  capture "$SCRIPT" register --state-dir "$_sd" \
    --agente "x" --etapa "briefing" \
    --contexto "curto" \
    --opcoes '["A"]' --escolha "A" \
    --justificativa "justificativa de tamanho ok aqui sim"
  if [ "$_CAPTURED_EXIT" != 1 ]; then
    _fail "contexto curto" "esperado 1, obtido $_CAPTURED_EXIT"
    return 1
  fi
  assert_stderr_contains "violacao Principio I" || return 1
  assert_stderr_contains "contexto" || return 1
}

scenario_justificativa_curta_violacao_principio_i() {
  _sd="$TMPDIR_TEST/state"
  _init_state "$_sd"
  capture "$SCRIPT" register --state-dir "$_sd" \
    --agente "x" --etapa "briefing" \
    --contexto "contexto longo o suficiente — 20+ chars" \
    --opcoes '["A"]' --escolha "A" \
    --justificativa "curta"
  if [ "$_CAPTURED_EXIT" != 1 ]; then
    _fail "justif curta" "esperado 1, obtido $_CAPTURED_EXIT"
    return 1
  fi
  assert_stderr_contains "justificativa" || return 1
}

scenario_opcoes_vazias_violacao_principio_i() {
  _sd="$TMPDIR_TEST/state"
  _init_state "$_sd"
  capture "$SCRIPT" register --state-dir "$_sd" \
    --agente "x" --etapa "briefing" \
    --contexto "contexto longo o suficiente — 20+ chars" \
    --opcoes '[]' --escolha "A" \
    --justificativa "justificativa de tamanho ok aqui sim"
  if [ "$_CAPTURED_EXIT" != 1 ]; then
    _fail "opcoes vazias" "esperado 1, obtido $_CAPTURED_EXIT"
    return 1
  fi
  assert_stderr_contains "opcoes_consideradas" || return 1
}

scenario_opcoes_nao_array_falha() {
  _sd="$TMPDIR_TEST/state"
  _init_state "$_sd"
  capture "$SCRIPT" register --state-dir "$_sd" \
    --agente "x" --etapa "briefing" \
    --contexto "contexto longo o suficiente — 20+ chars" \
    --opcoes '"notarray"' --escolha "A" \
    --justificativa "justificativa de tamanho ok aqui sim"
  if [ "$_CAPTURED_EXIT" != 1 ]; then
    _fail "opcoes nao-array" "esperado 1, obtido $_CAPTURED_EXIT"
    return 1
  fi
}

scenario_score_invalido_falha() {
  _sd="$TMPDIR_TEST/state"
  _init_state "$_sd"
  capture "$SCRIPT" register --state-dir "$_sd" \
    --agente "x" --etapa "briefing" \
    --contexto "contexto longo o suficiente — 20+ chars" \
    --opcoes '["A","B"]' --escolha "A" \
    --justificativa "justificativa de tamanho ok aqui sim" \
    --score 7
  if [ "$_CAPTURED_EXIT" != 2 ]; then
    _fail "score 7" "esperado 2, obtido $_CAPTURED_EXIT"
    return 1
  fi
}

scenario_score_valido_persiste() {
  _sd="$TMPDIR_TEST/state"
  _init_state "$_sd"
  capture "$SCRIPT" register --state-dir "$_sd" \
    --agente "clarify-answerer" --etapa "clarify" \
    --contexto "Q1: stack-sugerida — Go ou Node?" \
    --opcoes '["Go","Node"]' --escolha "Go" \
    --justificativa "Briefing menciona Go; stack-sugerida tambem" \
    --score 3
  [ "$_CAPTURED_EXIT" = 0 ] || { _fail "register" "$_CAPTURED_STDERR"; return 1; }
  capture "$RW" get --state-dir "$_sd" --field '.decisoes[-1].score_justificativa'
  assert_stdout_contains "3" || return 1
}

scenario_count_filtra_por_agente() {
  _sd="$TMPDIR_TEST/state"
  _init_state "$_sd"
  _register_default "$_sd" "orquestrador-00c"
  _register_default "$_sd" "clarify-asker"
  _register_default "$_sd" "clarify-asker"
  capture "$SCRIPT" count --state-dir "$_sd"
  assert_stdout_contains "3" || return 1
  capture "$SCRIPT" count --state-dir "$_sd" --agente "clarify-asker"
  assert_stdout_contains "2" || return 1
}

scenario_list_imprime_tsv() {
  _sd="$TMPDIR_TEST/state"
  _init_state "$_sd"
  _register_default "$_sd"
  capture "$SCRIPT" list --state-dir "$_sd"
  [ "$_CAPTURED_EXIT" = 0 ] || { _fail "list" "$_CAPTURED_EXIT"; return 1; }
  # Formato: id\tonda_id\tagente\tetapa\tescolha
  assert_stdout_contains "dec-001	" || return 1
  assert_stdout_contains "	orquestrador-00c	" || return 1
  assert_stdout_contains "	briefing	" || return 1
  assert_stdout_contains "	Operador unico" || return 1
}

scenario_metricas_acumuladas_decisoes_total_incrementa() {
  _sd="$TMPDIR_TEST/state"
  _init_state "$_sd"
  _register_default "$_sd"
  capture "$RW" get --state-dir "$_sd" --field '.metricas_acumuladas.decisoes_total'
  assert_stdout_contains "1" || return 1
  _register_default "$_sd"
  capture "$RW" get --state-dir "$_sd" --field '.metricas_acumuladas.decisoes_total'
  assert_stdout_contains "2" || return 1
}

scenario_register_state_ausente_falha() {
  _sd="$TMPDIR_TEST/empty"
  mkdir -p "$_sd"
  _register_default "$_sd"
  if [ "$_CAPTURED_EXIT" != 1 ]; then
    _fail "state ausente" "esperado 1, obtido $_CAPTURED_EXIT"
    return 1
  fi
}

run_all_scenarios
