#!/bin/sh
# test_circular.sh — cobre global/skills/agente-00c-runtime/scripts/circular.sh.

TESTS_ROOT="${TESTS_ROOT:-$(cd "$(dirname "$0")" && pwd)}"
REPO_ROOT="${REPO_ROOT:-$(cd "$TESTS_ROOT/.." && pwd)}"
. "$TESTS_ROOT/lib/harness.sh"

SCRIPT="$REPO_ROOT/global/skills/agente-00c-runtime/scripts/circular.sh"
RW="$REPO_ROOT/global/skills/agente-00c-runtime/scripts/state-rw.sh"

if ! command -v jq >/dev/null 2>&1; then
  printf '# test_circular.sh: jq ausente — pulando\n'
  exit 0
fi

_init() {
  capture "$RW" init --state-dir "$1" --execucao-id "x" \
    --projeto-alvo-path "/tmp/p" --descricao "POC circular tests"
}

_push() {
  capture "$SCRIPT" push --state-dir "$1" --problema "$2" --solucao "$3"
}

scenario_push_inicial_acumula() {
  _sd="$TMPDIR_TEST/state"
  _init "$_sd"
  _push "$_sd" "Test failing on null body" "Add nil check"
  [ "$_CAPTURED_EXIT" = 0 ] || { _fail "push" "$_CAPTURED_STDERR"; return 1; }
  assert_stdout_contains "1" || return 1   # buffer size = 1
  capture "$SCRIPT" list --state-dir "$_sd"
  assert_stdout_contains "0	" || return 1
}

scenario_normalizacao_lowercase_mesmo_hash() {
  _sd="$TMPDIR_TEST/state"
  _init "$_sd"
  _push "$_sd" "TEST FAILING ON NULL BODY" "fix1"
  _ph1=$(printf '%s' "$_CAPTURED_STDOUT" | awk '{print $1}')
  _push "$_sd" "test failing on null body" "fix2"
  _ph2=$(printf '%s' "$_CAPTURED_STDOUT" | awk '{print $1}')
  if [ "$_ph1" != "$_ph2" ]; then
    _fail "normalizacao lowercase" "hashes diferem para mesmo problema case-different"
    return 1
  fi
}

scenario_normalizacao_pontuacao() {
  _sd="$TMPDIR_TEST/state"
  _init "$_sd"
  _push "$_sd" "Test, failing on null body!" "fix1"
  _ph1=$(printf '%s' "$_CAPTURED_STDOUT" | awk '{print $1}')
  _push "$_sd" "Test failing on null body" "fix2"
  _ph2=$(printf '%s' "$_CAPTURED_STDOUT" | awk '{print $1}')
  if [ "$_ph1" != "$_ph2" ]; then
    _fail "normalizacao pontuacao" "hashes diferem"
    return 1
  fi
}

scenario_buffer_fifo_max_6() {
  _sd="$TMPDIR_TEST/state"
  _init "$_sd"
  for i in 1 2 3 4 5 6 7 8; do
    _push "$_sd" "Problema $i" "Solucao $i"
  done
  _size=$(jq '.historico_movimento_circular | length' "$_sd/state.json")
  if [ "$_size" != 6 ]; then
    _fail "buffer FIFO" "esperado 6, obtido $_size"
    return 1
  fi
  # Os mais antigos (1, 2) saem; mais recentes (7, 8) entram
  capture "$SCRIPT" list --state-dir "$_sd"
  assert_stdout_contains "0	" || return 1   # 6 entries, indices 0..5
  if printf '%s' "$_CAPTURED_STDOUT" | grep -q "$(printf '%s' "Problema 1" | tr '[:upper:]' '[:lower:]')"; then
    _fail "buffer FIFO" "Problema 1 (deveria ter saido) ainda presente"
    return 1
  fi
}

scenario_detect_sem_repeticao_exit_0() {
  _sd="$TMPDIR_TEST/state"
  _init "$_sd"
  _push "$_sd" "Problema A" "Solucao 1"
  _push "$_sd" "Problema B" "Solucao 2"
  capture "$SCRIPT" detect --state-dir "$_sd"
  [ "$_CAPTURED_EXIT" = 0 ] || { _fail "sem repeticao" "$_CAPTURED_EXIT"; return 1; }
}

scenario_detect_3_repeticoes_exit_3() {
  _sd="$TMPDIR_TEST/state"
  _init "$_sd"
  _push "$_sd" "Problema A" "Solucao 1"
  _push "$_sd" "Problema B" "Solucao 2"
  _push "$_sd" "Problema A" "Solucao 3"
  _push "$_sd" "Problema B" "Solucao 4"
  _push "$_sd" "Problema A" "Solucao 5"
  capture "$SCRIPT" detect --state-dir "$_sd"
  if [ "$_CAPTURED_EXIT" != 3 ]; then
    _fail "3 repeticoes" "esperado 3, obtido $_CAPTURED_EXIT"
    return 1
  fi
  assert_stderr_contains "movimento circular detectado" || return 1
  assert_stdout_contains "	3" || return 1   # contagem de problema_hash A
}

scenario_clear_esvazia_buffer() {
  _sd="$TMPDIR_TEST/state"
  _init "$_sd"
  _push "$_sd" "Problema A" "Solucao 1"
  _push "$_sd" "Problema A" "Solucao 2"
  _push "$_sd" "Problema A" "Solucao 3"
  capture "$SCRIPT" clear --state-dir "$_sd"
  capture "$SCRIPT" detect --state-dir "$_sd"
  [ "$_CAPTURED_EXIT" = 0 ] || { _fail "apos clear" "$_CAPTURED_EXIT"; return 1; }
  _size=$(jq '.historico_movimento_circular | length' "$_sd/state.json")
  [ "$_size" = 0 ] || { _fail "buffer nao zerado" "size=$_size"; return 1; }
}

scenario_state_ausente_falha() {
  _sd="$TMPDIR_TEST/empty"
  mkdir -p "$_sd"
  capture "$SCRIPT" detect --state-dir "$_sd"
  if [ "$_CAPTURED_EXIT" != 1 ]; then
    _fail "state ausente" "esperado 1"
    return 1
  fi
}

run_all_scenarios
