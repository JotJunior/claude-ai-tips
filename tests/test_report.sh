#!/bin/sh
# test_report.sh — cobre global/skills/agente-00c-runtime/scripts/report.sh.

TESTS_ROOT="${TESTS_ROOT:-$(cd "$(dirname "$0")" && pwd)}"
REPO_ROOT="${REPO_ROOT:-$(cd "$TESTS_ROOT/.." && pwd)}"
. "$TESTS_ROOT/lib/harness.sh"

SCRIPT="$REPO_ROOT/global/skills/agente-00c-runtime/scripts/report.sh"
RW="$REPO_ROOT/global/skills/agente-00c-runtime/scripts/state-rw.sh"
ON="$REPO_ROOT/global/skills/agente-00c-runtime/scripts/state-ondas.sh"
DEC="$REPO_ROOT/global/skills/agente-00c-runtime/scripts/state-decisions.sh"

if ! command -v jq >/dev/null 2>&1; then
  printf '# test_report.sh: jq ausente — pulando\n'
  exit 0
fi

_init() {
  capture "$RW" init --state-dir "$1" --execucao-id "exec-rep" \
    --projeto-alvo-path "/tmp/p" --descricao "POC report tests"
}

_run_wave_with_decision() {
  capture "$ON" start --state-dir "$1"
  capture "$DEC" register --state-dir "$1" \
    --agente "${2:-orquestrador-00c}" --etapa "briefing" \
    --contexto "Decisao de teste para popular relatorio de cenario" \
    --opcoes '["A","B"]' --escolha "A" \
    --justificativa "Justificativa de tamanho ok aqui sim para teste"
  capture "$ON" end --state-dir "$1" --motivo-termino etapa_concluida_avancando
}

scenario_generate_inclui_6_secoes() {
  _sd="$TMPDIR_TEST/state"
  _init "$_sd"
  _run_wave_with_decision "$_sd"
  capture "$SCRIPT" generate --state-dir "$_sd"
  [ "$_CAPTURED_EXIT" = 0 ] || { _fail "generate" "$_CAPTURED_STDERR"; return 1; }
  assert_stdout_contains "## 1. Resumo Executivo" || return 1
  assert_stdout_contains "## 2. Linha do Tempo" || return 1
  assert_stdout_contains "## 3. Decisoes" || return 1
  assert_stdout_contains "## 4. Bloqueios Humanos" || return 1
  assert_stdout_contains "## 5. Sugestoes para Skills Globais" || return 1
  assert_stdout_contains "## 6. Licoes Aprendidas" || return 1
  assert_stdout_contains "Apendice A" || return 1
}

scenario_generate_renderiza_decisao() {
  _sd="$TMPDIR_TEST/state"
  _init "$_sd"
  _run_wave_with_decision "$_sd"
  capture "$SCRIPT" generate --state-dir "$_sd"
  assert_stdout_contains "dec-001" || return 1
  assert_stdout_contains "**Contexto**" || return 1
  assert_stdout_contains "**Escolha**: A" || return 1
}

scenario_generate_paragrafo_resumo_inserido() {
  _sd="$TMPDIR_TEST/state"
  _init "$_sd"
  _run_wave_with_decision "$_sd"
  capture "$SCRIPT" generate --state-dir "$_sd" \
    --paragrafo-resumo "Sumario customizado da execucao com 1 onda."
  assert_stdout_contains "Sumario customizado da execucao com 1 onda" || return 1
}

scenario_generate_licoes_so_em_final() {
  _sd="$TMPDIR_TEST/state"
  _init "$_sd"
  _run_wave_with_decision "$_sd"
  # Sem --final: placeholder
  capture "$SCRIPT" generate --state-dir "$_sd"
  assert_stdout_contains "Sera preenchido no relatorio final" || return 1
  # Com --final + texto
  capture "$SCRIPT" generate --state-dir "$_sd" --final \
    --licoes-aprendidas "Aprendi muito nessa execucao."
  assert_stdout_contains "Aprendi muito nessa execucao" || return 1
}

scenario_generate_sem_ondas_lista_vazia_explicita() {
  _sd="$TMPDIR_TEST/state"
  _init "$_sd"
  capture "$SCRIPT" generate --state-dir "$_sd"
  [ "$_CAPTURED_EXIT" = 0 ] || { _fail "generate" "$_CAPTURED_STDERR"; return 1; }
  assert_stdout_contains "nenhuma onda completa ainda" || return 1
}

scenario_generate_sem_decisoes_explicito() {
  _sd="$TMPDIR_TEST/state"
  _init "$_sd"
  capture "$SCRIPT" generate --state-dir "$_sd"
  assert_stdout_contains "Nenhuma decisao registrada" || return 1
}

scenario_generate_sem_bloqueios_explicito() {
  _sd="$TMPDIR_TEST/state"
  _init "$_sd"
  capture "$SCRIPT" generate --state-dir "$_sd"
  assert_stdout_contains "Nenhum bloqueio humano nesta execucao" || return 1
}

scenario_generate_sem_sugestoes_explicito() {
  _sd="$TMPDIR_TEST/state"
  _init "$_sd"
  capture "$SCRIPT" generate --state-dir "$_sd"
  assert_stdout_contains "Nenhuma sugestao para skills globais nesta execucao" || return 1
}

scenario_validate_completo_exit_0() {
  _sd="$TMPDIR_TEST/state"
  _init "$_sd"
  _run_wave_with_decision "$_sd"
  _rf="$TMPDIR_TEST/report.md"
  capture "$SCRIPT" generate --state-dir "$_sd"
  printf '%s\n' "$_CAPTURED_STDOUT" > "$_rf"
  capture "$SCRIPT" validate --report-file "$_rf"
  [ "$_CAPTURED_EXIT" = 0 ] || { _fail "validate completo" "$_CAPTURED_STDERR"; return 1; }
}

scenario_validate_incompleto_exit_1() {
  _rf="$TMPDIR_TEST/incomplete.md"
  printf '# Header only\n\n## 1. Resumo Executivo\n\nstub\n' > "$_rf"
  capture "$SCRIPT" validate --report-file "$_rf"
  if [ "$_CAPTURED_EXIT" != 1 ]; then
    _fail "validate incompleto" "esperado 1"
    return 1
  fi
  assert_stderr_contains "secoes faltando" || return 1
}

scenario_validate_arquivo_inexistente_falha() {
  capture "$SCRIPT" validate --report-file "$TMPDIR_TEST/nope.md"
  if [ "$_CAPTURED_EXIT" = 0 ]; then
    _fail "arquivo inexistente" "esperado != 0"
    return 1
  fi
}

run_all_scenarios
