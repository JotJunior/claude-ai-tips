#!/bin/sh
# test_compat.sh — cobre cli/lib/compat.sh
#
# Contrato:
#   sha256_file <path>   imprime 64 chars hex + \n
#   sha256_stdin         idem para stdin
#   iso_now_utc          ISO8601 UTC (ex: 2026-04-24T18:32:00Z)

TESTS_ROOT="${TESTS_ROOT:-$(cd "$(dirname "$0")/.." && pwd)}"
REPO_ROOT="${REPO_ROOT:-$(cd "$TESTS_ROOT/.." && pwd)}"

. "$TESTS_ROOT/lib/harness.sh"

CSTK_LIB="$REPO_ROOT/cli/lib"
export CSTK_LIB

# SHA-256 conhecido: de "hello\n" -> 5891b5b522d5df086d0ff0b110fbd9d21bb4fc7163af34d08286a2e846f6be03
# (Referencia: sha256sum <<<"hello")

scenario_sha256_file_hex_hash() {
  _f="$TMPDIR_TEST/hello.txt"
  printf 'hello\n' > "$_f"
  capture sh -c ". $CSTK_LIB/compat.sh && sha256_file $_f"
  if [ "$_CAPTURED_EXIT" != "0" ]; then
    _fail "sha256_file exit $_CAPTURED_EXIT" "esperado 0"
    return 1
  fi
  # Deve imprimir exatamente 64 chars hex
  echo "$_CAPTURED_STDOUT" | grep -qE '^[0-9a-f]{64}$' || {
    _fail "sha256_file formato" "stdout nao e hash hex: $_CAPTURED_STDOUT"
    return 1
  }
  if [ "$_CAPTURED_STDOUT" != "5891b5b522d5df086d0ff0b110fbd9d21bb4fc7163af34d08286a2e846f6be03" ]; then
    _fail "sha256_file valor" "hash errado para 'hello\\n': $_CAPTURED_STDOUT"
    return 1
  fi
}

scenario_sha256_stdin_hash() {
  capture sh -c ". $CSTK_LIB/compat.sh && printf 'hello\n' | sha256_stdin"
  if [ "$_CAPTURED_EXIT" != "0" ]; then
    _fail "sha256_stdin exit" "$_CAPTURED_EXIT"
    return 1
  fi
  if [ "$_CAPTURED_STDOUT" != "5891b5b522d5df086d0ff0b110fbd9d21bb4fc7163af34d08286a2e846f6be03" ]; then
    _fail "sha256_stdin valor" "hash errado: $_CAPTURED_STDOUT"
    return 1
  fi
}

scenario_sha256_file_argumento_faltando() {
  capture sh -c ". $CSTK_LIB/compat.sh && sha256_file"
  if [ "$_CAPTURED_EXIT" != "2" ]; then
    _fail "sha256_file sem arg" "exit esperado 2, obtido $_CAPTURED_EXIT"
    return 1
  fi
}

scenario_sha256_file_arquivo_inexistente() {
  capture sh -c ". $CSTK_LIB/compat.sh && sha256_file /nao/existe/jamais"
  if [ "$_CAPTURED_EXIT" != "1" ]; then
    _fail "sha256_file inexistente" "exit esperado 1, obtido $_CAPTURED_EXIT"
    return 1
  fi
  assert_stderr_contains "nao existe" || return 1
}

scenario_iso_now_utc_formato() {
  capture sh -c ". $CSTK_LIB/compat.sh && iso_now_utc"
  if [ "$_CAPTURED_EXIT" != "0" ]; then
    _fail "iso_now_utc exit" "$_CAPTURED_EXIT"
    return 1
  fi
  echo "$_CAPTURED_STDOUT" | grep -qE '^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}Z$' || {
    _fail "iso_now_utc formato" "nao bate regex ISO8601 UTC: $_CAPTURED_STDOUT"
    return 1
  }
}

run_all_scenarios
