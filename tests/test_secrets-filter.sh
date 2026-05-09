#!/bin/sh
# test_secrets-filter.sh — cobre global/skills/agente-00c-runtime/scripts/secrets-filter.sh.

TESTS_ROOT="${TESTS_ROOT:-$(cd "$(dirname "$0")" && pwd)}"
REPO_ROOT="${REPO_ROOT:-$(cd "$TESTS_ROOT/.." && pwd)}"
. "$TESTS_ROOT/lib/harness.sh"

SCRIPT="$REPO_ROOT/global/skills/agente-00c-runtime/scripts/secrets-filter.sh"

scenario_scrub_token_com_palavra_chave() {
  capture sh -c "printf '%s' 'api_key=\"abc1234567890123456789xyz\"' | '$SCRIPT' scrub"
  assert_stdout_contains "[REDACTED]" || return 1
  case "$_CAPTURED_STDOUT" in
    *abc1234567890*) _fail "token nao redacted" ""; return 1 ;;
  esac
}

scenario_scrub_aws_key() {
  capture sh -c "printf '%s' 'AWS key: AKIAIOSFODNN7EXAMPLE present' | '$SCRIPT' scrub"
  assert_stdout_contains "[REDACTED-AWS-KEY]" || return 1
  case "$_CAPTURED_STDOUT" in
    *AKIAIOSFODNN7EXAMPLE*) _fail "AWS nao redacted" ""; return 1 ;;
  esac
}

scenario_scrub_bearer_token() {
  capture sh -c "printf '%s' 'Authorization: Bearer eyJhbGciOiJI.deadbeef' | '$SCRIPT' scrub"
  assert_stdout_contains "Bearer [REDACTED]" || return 1
  case "$_CAPTURED_STDOUT" in
    *eyJhbG*) _fail "bearer nao redacted" ""; return 1 ;;
  esac
}

scenario_scrub_basic_auth_em_url() {
  capture sh -c "printf '%s' 'https://admin:supersecret@db.example.com/foo' | '$SCRIPT' scrub"
  assert_stdout_contains "https://[REDACTED]@db.example.com" || return 1
  case "$_CAPTURED_STDOUT" in
    *supersecret*) _fail "basic auth nao redacted" ""; return 1 ;;
  esac
}

scenario_scrub_env_file() {
  _env="$TMPDIR_TEST/.env"
  printf 'DB_PASSWORD=mysupersecretpwd\nAPI=abcdef1234567890\n' > "$_env"
  capture sh -c "printf '%s' 'leaking mysupersecretpwd here and abcdef1234567890 there' | '$SCRIPT' scrub --env-file '$_env'"
  case "$_CAPTURED_STDOUT" in
    *mysupersecretpwd*) _fail "env DB_PASSWORD nao redacted" ""; return 1 ;;
    *abcdef1234567890*) _fail "env API nao redacted" ""; return 1 ;;
  esac
  assert_stdout_contains "[REDACTED-ENV]" || return 1
}

scenario_scrub_env_valor_curto_ignorado() {
  # Valores < 8 chars sao ignorados (alta taxa de falsos positivos)
  _env="$TMPDIR_TEST/.env"
  printf 'SHORT=ab\n' > "$_env"
  capture sh -c "printf '%s' 'has ab in middle' | '$SCRIPT' scrub --env-file '$_env'"
  assert_stdout_contains "has ab in middle" || return 1
  # Nao deve ter aplicado [REDACTED-ENV]
  case "$_CAPTURED_STDOUT" in
    *REDACTED*) _fail "valor curto foi redacted indevidamente" ""; return 1 ;;
  esac
}

scenario_scrub_hash_git_nao_redacted() {
  # Hashes git (40 chars hex) sem palavra-chave NAO devem ser redacted
  capture sh -c "printf '%s' 'commit abcdef1234567890abcdef1234567890abcdef12 fixed' | '$SCRIPT' scrub"
  assert_stdout_contains "abcdef1234567890abcdef" || return 1
}

scenario_check_detecta_secret() {
  capture sh -c "printf '%s' 'api_key=abcdef1234567890123456789' | '$SCRIPT' check"
  if [ "$_CAPTURED_EXIT" != 1 ]; then
    _fail "check com secret" "esperado 1, obtido $_CAPTURED_EXIT"
    return 1
  fi
  assert_stderr_contains "SECRETS DETECTADOS" || return 1
}

scenario_check_input_limpo_exit_0() {
  capture sh -c "printf '%s' 'just plain text without secrets' | '$SCRIPT' check"
  [ "$_CAPTURED_EXIT" = 0 ] || { _fail "check limpo" "$_CAPTURED_EXIT"; return 1; }
}

run_all_scenarios
