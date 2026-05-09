#!/bin/sh
# test_bloqueios.sh — cobre global/skills/agente-00c-runtime/scripts/bloqueios.sh.

TESTS_ROOT="${TESTS_ROOT:-$(cd "$(dirname "$0")" && pwd)}"
REPO_ROOT="${REPO_ROOT:-$(cd "$TESTS_ROOT/.." && pwd)}"

. "$TESTS_ROOT/lib/harness.sh"

SCRIPT="$REPO_ROOT/global/skills/agente-00c-runtime/scripts/bloqueios.sh"
RW="$REPO_ROOT/global/skills/agente-00c-runtime/scripts/state-rw.sh"
DEC="$REPO_ROOT/global/skills/agente-00c-runtime/scripts/state-decisions.sh"

if ! command -v jq >/dev/null 2>&1; then
  printf '# test_bloqueios.sh: jq ausente — pulando suite\n'
  exit 0
fi

# ==== helpers ====

# _setup_with_decisao DIR -> init state + registra dec-001 valida
_setup_with_decisao() {
  capture "$RW" init --state-dir "$1" \
    --execucao-id "exec-block-test" \
    --projeto-alvo-path "/tmp/p" \
    --descricao "POC bloqueios test"
  [ "$_CAPTURED_EXIT" = 0 ] || return 1
  capture "$DEC" register --state-dir "$1" \
    --agente "clarify-answerer" --etapa "clarify" \
    --contexto "Pergunta sobre stack — nao decidida" \
    --opcoes '["Go","Node"]' --escolha "pause-humano" \
    --justificativa "Score 0 — nenhuma fonte suporta as opcoes" \
    --score 0
  [ "$_CAPTURED_EXIT" = 0 ] || return 1
}

_register_block_default() {
  capture "$SCRIPT" register --state-dir "$1" \
    --decisao-id "${2:-dec-001}" \
    --pergunta "Qual stack escolher para a feature, Go ou Node?" \
    --contexto-para-resposta "Briefing nao define; stack-sugerida vazia"
}

# ==== Scenarios ====

scenario_register_basico_gera_block_001() {
  _sd="$TMPDIR_TEST/state"
  _setup_with_decisao "$_sd" || { _error "fixture" ""; return 2; }
  _register_block_default "$_sd"
  if [ "$_CAPTURED_EXIT" != 0 ]; then
    _fail "register" "$_CAPTURED_EXIT; $_CAPTURED_STDERR"
    return 1
  fi
  assert_stdout_contains "block-001" || return 1
}

scenario_register_atualiza_status_para_aguardando_humano() {
  _sd="$TMPDIR_TEST/state"
  _setup_with_decisao "$_sd" || { _error "fixture" ""; return 2; }
  _register_block_default "$_sd"
  capture "$RW" get --state-dir "$_sd" --field '.execucao.status'
  assert_stdout_contains "aguardando_humano" || return 1
  capture "$RW" get --state-dir "$_sd" --field '.metricas_acumuladas.bloqueios_humanos_total'
  assert_stdout_contains "1" || return 1
}

scenario_register_decisao_inexistente_falha_fk() {
  _sd="$TMPDIR_TEST/state"
  capture "$RW" init --state-dir "$_sd" --execucao-id "x" --projeto-alvo-path "/tmp/p" --descricao "x x x x x x x x x x"
  capture "$SCRIPT" register --state-dir "$_sd" \
    --decisao-id "dec-fantasma" \
    --pergunta "Pergunta longa o suficiente para passar (>=20 chars)" \
    --contexto-para-resposta "ctx"
  if [ "$_CAPTURED_EXIT" != 1 ]; then
    _fail "FK violation" "esperado 1, obtido $_CAPTURED_EXIT"
    return 1
  fi
  assert_stderr_contains "decisao_id nao existe" || return 1
}

scenario_register_pergunta_curta_falha() {
  _sd="$TMPDIR_TEST/state"
  _setup_with_decisao "$_sd" || { _error "fixture" ""; return 2; }
  capture "$SCRIPT" register --state-dir "$_sd" \
    --decisao-id "dec-001" --pergunta "curta?" \
    --contexto-para-resposta "ctx"
  if [ "$_CAPTURED_EXIT" != 1 ]; then
    _fail "pergunta curta" "esperado 1"
    return 1
  fi
  assert_stderr_contains "pergunta muito curta" || return 1
}

scenario_register_opcoes_invalidas_falha() {
  _sd="$TMPDIR_TEST/state"
  _setup_with_decisao "$_sd" || { _error "fixture" ""; return 2; }
  capture "$SCRIPT" register --state-dir "$_sd" \
    --decisao-id "dec-001" \
    --pergunta "Pergunta longa o suficiente para passar (>=20 chars)" \
    --contexto-para-resposta "ctx" \
    --opcoes-recomendadas '"not-array"'
  if [ "$_CAPTURED_EXIT" != 2 ]; then
    _fail "opcoes invalidas" "esperado 2, obtido $_CAPTURED_EXIT"
    return 1
  fi
}

scenario_respond_marca_respondido_e_volta_status() {
  _sd="$TMPDIR_TEST/state"
  _setup_with_decisao "$_sd" || { _error "fixture" ""; return 2; }
  _register_block_default "$_sd"
  capture "$SCRIPT" respond --state-dir "$_sd" --block-id "block-001" --resposta "Go"
  if [ "$_CAPTURED_EXIT" != 0 ]; then
    _fail "respond" "$_CAPTURED_EXIT; $_CAPTURED_STDERR"
    return 1
  fi
  capture "$RW" get --state-dir "$_sd" --field '.bloqueios_humanos[0].status'
  assert_stdout_contains "respondido" || return 1
  capture "$RW" get --state-dir "$_sd" --field '.bloqueios_humanos[0].resposta_humana'
  assert_stdout_contains "Go" || return 1
  # Sem mais bloqueios pendentes -> status volta para em_andamento
  capture "$RW" get --state-dir "$_sd" --field '.execucao.status'
  assert_stdout_contains "em_andamento" || return 1
}

scenario_respond_inexistente_falha() {
  _sd="$TMPDIR_TEST/state"
  _setup_with_decisao "$_sd" || { _error "fixture" ""; return 2; }
  capture "$SCRIPT" respond --state-dir "$_sd" --block-id "block-fantasma" --resposta "x"
  if [ "$_CAPTURED_EXIT" != 1 ]; then
    _fail "respond inexistente" "esperado 1, obtido $_CAPTURED_EXIT"
    return 1
  fi
  assert_stderr_contains "nao encontrado" || return 1
}

scenario_respond_ja_respondido_falha() {
  _sd="$TMPDIR_TEST/state"
  _setup_with_decisao "$_sd" || { _error "fixture" ""; return 2; }
  _register_block_default "$_sd"
  capture "$SCRIPT" respond --state-dir "$_sd" --block-id "block-001" --resposta "Go"
  capture "$SCRIPT" respond --state-dir "$_sd" --block-id "block-001" --resposta "Node"
  if [ "$_CAPTURED_EXIT" != 1 ]; then
    _fail "respond duplicado" "esperado 1"
    return 1
  fi
  assert_stderr_contains "nao esta em status aguardando" || return 1
}

scenario_status_so_volta_quando_todos_pendentes_resolvidos() {
  _sd="$TMPDIR_TEST/state"
  _setup_with_decisao "$_sd" || { _error "fixture" ""; return 2; }
  # Cria 2 decisoes + 2 bloqueios
  capture "$DEC" register --state-dir "$_sd" \
    --agente "clarify-answerer" --etapa "clarify" \
    --contexto "Outra pergunta sem resposta clara" \
    --opcoes '["X","Y"]' --escolha "pause-humano" \
    --justificativa "Score 0 outra vez aqui" --score 0
  _register_block_default "$_sd" "dec-001"
  _register_block_default "$_sd" "dec-002"
  # Responde apenas o primeiro
  capture "$SCRIPT" respond --state-dir "$_sd" --block-id "block-001" --resposta "Go"
  capture "$RW" get --state-dir "$_sd" --field '.execucao.status'
  # Ainda 1 pendente -> mantem aguardando_humano
  assert_stdout_contains "aguardando_humano" || return 1
  # Responde o segundo
  capture "$SCRIPT" respond --state-dir "$_sd" --block-id "block-002" --resposta "X"
  capture "$RW" get --state-dir "$_sd" --field '.execucao.status'
  assert_stdout_contains "em_andamento" || return 1
}

scenario_count_e_count_pending() {
  _sd="$TMPDIR_TEST/state"
  _setup_with_decisao "$_sd" || { _error "fixture" ""; return 2; }
  capture "$DEC" register --state-dir "$_sd" \
    --agente "x" --etapa "clarify" \
    --contexto "outra decisao para FK" \
    --opcoes '["A"]' --escolha "A" \
    --justificativa "justificativa de tamanho ok aqui" --score 1
  _register_block_default "$_sd" "dec-001"
  _register_block_default "$_sd" "dec-002"
  capture "$SCRIPT" count --state-dir "$_sd"
  assert_stdout_contains "2" || return 1
  capture "$SCRIPT" count --state-dir "$_sd" --pending-only
  assert_stdout_contains "2" || return 1
  capture "$SCRIPT" respond --state-dir "$_sd" --block-id "block-001" --resposta "x"
  capture "$SCRIPT" count --state-dir "$_sd" --pending-only
  assert_stdout_contains "1" || return 1
  capture "$SCRIPT" count --state-dir "$_sd"
  assert_stdout_contains "2" || return 1
}

scenario_list_imprime_tsv_e_filtra_por_status() {
  _sd="$TMPDIR_TEST/state"
  _setup_with_decisao "$_sd" || { _error "fixture" ""; return 2; }
  _register_block_default "$_sd"
  capture "$SCRIPT" list --state-dir "$_sd"
  assert_stdout_contains "block-001	dec-001	aguardando" || return 1
  capture "$SCRIPT" respond --state-dir "$_sd" --block-id "block-001" --resposta "Go"
  capture "$SCRIPT" list --state-dir "$_sd" --status aguardando
  if [ -n "$_CAPTURED_STDOUT" ]; then
    _fail "list filtrada por aguardando" "esperado vazio (todos respondidos)"
    return 1
  fi
  capture "$SCRIPT" list --state-dir "$_sd" --status respondido
  assert_stdout_contains "block-001" || return 1
}

scenario_get_imprime_json_do_bloqueio() {
  _sd="$TMPDIR_TEST/state"
  _setup_with_decisao "$_sd" || { _error "fixture" ""; return 2; }
  _register_block_default "$_sd"
  capture "$SCRIPT" get --state-dir "$_sd" --block-id "block-001"
  assert_stdout_contains '"id": "block-001"' || return 1
  assert_stdout_contains '"status": "aguardando"' || return 1
}

scenario_get_inexistente_falha() {
  _sd="$TMPDIR_TEST/state"
  _setup_with_decisao "$_sd" || { _error "fixture" ""; return 2; }
  capture "$SCRIPT" get --state-dir "$_sd" --block-id "block-fantasma"
  if [ "$_CAPTURED_EXIT" != 1 ]; then
    _fail "get inexistente" "esperado 1"
    return 1
  fi
}

scenario_next_id_sequencial() {
  _sd="$TMPDIR_TEST/state"
  _setup_with_decisao "$_sd" || { _error "fixture" ""; return 2; }
  capture "$SCRIPT" next-id --state-dir "$_sd"
  assert_stdout_contains "block-001" || return 1
  _register_block_default "$_sd"
  capture "$SCRIPT" next-id --state-dir "$_sd"
  assert_stdout_contains "block-002" || return 1
}

run_all_scenarios
