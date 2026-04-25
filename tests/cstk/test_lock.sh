#!/bin/sh
# test_lock.sh — cobre cli/lib/lock.sh
#
# Contrato:
#   acquire_lock <path>   cria diretorio-lock atomico; exit 0 em sucesso,
#                         exit 3 se ja detido
#   release_lock          remove diretorio-lock (idempotente)

TESTS_ROOT="${TESTS_ROOT:-$(cd "$(dirname "$0")/.." && pwd)}"
REPO_ROOT="${REPO_ROOT:-$(cd "$TESTS_ROOT/.." && pwd)}"

. "$TESTS_ROOT/lib/harness.sh"

CSTK_LIB="$REPO_ROOT/cli/lib"
export CSTK_LIB

scenario_acquire_sucesso() {
  _lock="$TMPDIR_TEST/l1.lock"
  capture sh -c ". $CSTK_LIB/lock.sh && acquire_lock $_lock"
  if [ "$_CAPTURED_EXIT" != "0" ]; then
    _fail "acquire_lock exit" "$_CAPTURED_EXIT; stderr=$_CAPTURED_STDERR"
    return 1
  fi
  # Apos subshell terminar, trap EXIT ja deve ter rodado release_lock.
  # O diretorio lock pode ou nao persistir dependendo de timing; o importante
  # e o exit 0.
}

scenario_acquire_ja_detido_exit3() {
  _lock="$TMPDIR_TEST/l2.lock"
  mkdir "$_lock"  # simula lock ja detido
  capture sh -c ". $CSTK_LIB/lock.sh && acquire_lock $_lock"
  if [ "$_CAPTURED_EXIT" != "3" ]; then
    _fail "acquire_lock ocupado" "exit esperado 3, obtido $_CAPTURED_EXIT"
    return 1
  fi
  assert_stderr_contains "lock ja detido" || return 1
  assert_stderr_contains "rmdir" || return 1
}

scenario_release_limpa_lock() {
  _lock="$TMPDIR_TEST/l3.lock"
  # Roda acquire + release num subshell; apos subshell terminar,
  # lock dir NAO deve existir (foi liberado pelo trap OU por release_lock).
  sh -c ". $CSTK_LIB/lock.sh && acquire_lock $_lock && release_lock"
  if [ -d "$_lock" ]; then
    _fail "release_lock nao limpou" "diretorio $_lock ainda existe"
    return 1
  fi
}

scenario_trap_limpa_em_saida_normal() {
  _lock="$TMPDIR_TEST/l4.lock"
  # Roda acquire em subshell; ao terminar, trap EXIT deve remover lock.
  sh -c ". $CSTK_LIB/lock.sh && acquire_lock $_lock"
  if [ -d "$_lock" ]; then
    _fail "trap EXIT nao rodou" "lock $_lock persiste apos saida normal"
    return 1
  fi
}

scenario_release_idempotente() {
  # Chamar release_lock quando nenhum lock foi adquirido nao deve falhar.
  capture sh -c ". $CSTK_LIB/lock.sh && release_lock"
  if [ "$_CAPTURED_EXIT" != "0" ]; then
    _fail "release_lock sem acquire" "exit esperado 0, obtido $_CAPTURED_EXIT"
    return 1
  fi
}

scenario_acquire_arg_faltando() {
  capture sh -c ". $CSTK_LIB/lock.sh && acquire_lock"
  if [ "$_CAPTURED_EXIT" != "2" ]; then
    _fail "acquire_lock sem arg" "exit esperado 2, obtido $_CAPTURED_EXIT"
    return 1
  fi
}

scenario_acquire_parent_inexistente() {
  capture sh -c ". $CSTK_LIB/lock.sh && acquire_lock /nao/existe/jamais/x.lock"
  if [ "$_CAPTURED_EXIT" != "1" ]; then
    _fail "acquire_lock parent ausente" "exit esperado 1, obtido $_CAPTURED_EXIT"
    return 1
  fi
  assert_stderr_contains "nao existe" || return 1
}

run_all_scenarios
