#!/bin/sh
# test_next-uc-id.sh — cobre global/skills/create-use-case/scripts/next-uc-id.sh.
#
# Contrato:
#   next-uc-id.sh DOMAIN [--dir=PATH]
#     Busca UCs no DIR (default ./docs), calcula proximo UC-{DOMAIN}-NNN.
#     Sem DOMAIN: lista dominios existentes (exit 0).
#     Dir inexistente: exit nao-zero com mensagem descritiva.

TESTS_ROOT="${TESTS_ROOT:-$(cd "$(dirname "$0")" && pwd)}"
REPO_ROOT="${REPO_ROOT:-$(cd "$TESTS_ROOT/.." && pwd)}"

. "$TESTS_ROOT/lib/harness.sh"

SCRIPT="$REPO_ROOT/global/skills/create-use-case/scripts/next-uc-id.sh"

# ==== 3.3.1 dominio sem UCs ====

scenario_dominio_sem_ucs() {
  fixture "ucs/empty" || return 2
  assert_exit 0 sh "$SCRIPT" "AUTH" "--dir=$TMPDIR_TEST" || return 1
  assert_stdout_contains "UC-AUTH-001" || return 1
}

# ==== 3.3.2 dominio com UCs ====

scenario_dominio_com_ucs() {
  fixture "ucs/with-auth" || return 2
  assert_exit 0 sh "$SCRIPT" "AUTH" "--dir=$TMPDIR_TEST" || return 1
  # Fixture tem UC-AUTH-001 e UC-AUTH-002 -> proximo = 003
  assert_stdout_contains "UC-AUTH-003" || return 1
}

# ==== 3.3.3 filtra por dominio (nao confunde com outros) ====

scenario_filtra_por_dominio() {
  fixture "ucs/multi-domain" || return 2
  # multi-domain tem: UC-AUTH-001, UC-CAD-001, UC-CAD-002, UC-PED-001
  assert_exit 0 sh "$SCRIPT" "AUTH" "--dir=$TMPDIR_TEST" || return 1
  assert_stdout_contains "UC-AUTH-002" || return 1

  assert_exit 0 sh "$SCRIPT" "CAD" "--dir=$TMPDIR_TEST" || return 1
  assert_stdout_contains "UC-CAD-003" || return 1

  assert_exit 0 sh "$SCRIPT" "PED" "--dir=$TMPDIR_TEST" || return 1
  assert_stdout_contains "UC-PED-002" || return 1
}

# ==== 3.3.4 dir inexistente ====

scenario_dir_inexistente() {
  capture sh "$SCRIPT" "AUTH" "--dir=/caminho/que-nao-existe-xyz" || return 2
  # Esperado: exit != 0, mensagem clara (sem stacktrace de shell).
  if [ "$_CAPTURED_EXIT" -eq 0 ]; then
    _fail "scenario_dir_inexistente" "esperado exit != 0, obtido 0"
    return 1
  fi
  # Mensagem deve apontar o diretorio inexistente em algum formato legivel.
  case "$_CAPTURED_STDERR" in
    *"nao-existe-xyz"*|*"encontrado"*|*"existe"*) ;;
    *)
      _fail "scenario_dir_inexistente" "stderr sem mensagem clara: $_CAPTURED_STDERR"
      return 1
      ;;
  esac
}

# ==== 3.3.5a sem argumento — exit 2 + mensagem de uso ====

scenario_sem_argumento() {
  # Contrato real (lido do script): sem DOMAIN e sem --list -> exit 2
  # com mensagem direcionando ao --list.
  assert_exit 2 sh "$SCRIPT" || return 1
  assert_stderr_contains "Uso:" || return 1
}

# ==== 3.3.5b --list lista dominios existentes ====

scenario_list_dominios() {
  fixture "ucs/multi-domain" || return 2
  # Contrato real: --list sem DOMAIN lista os dominios existentes no --dir.
  assert_exit 0 sh "$SCRIPT" "--list" "--dir=$TMPDIR_TEST" || return 1
  # Fixture multi-domain tem AUTH, CAD, PED. Todos devem aparecer.
  assert_stdout_contains "AUTH" || return 1
  assert_stdout_contains "CAD" || return 1
  assert_stdout_contains "PED" || return 1
}

run_all_scenarios
