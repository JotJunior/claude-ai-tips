#!/bin/sh
# test_http.sh — cobre cli/lib/http.sh
#
# Contrato:
#   http_download <url> <dest>    exit 0 sucesso, 1 erro (timeout/404/offline),
#                                 2 args faltando
#   http_check_url <url>          exit 0 acessivel, 1 nao
#
# Estrategia de teste: usa file:// URLs (suportado por curl em qualquer build
# minimamente normal), que funciona 100% offline. Evita dependencia em rede
# e em servidores externos.

TESTS_ROOT="${TESTS_ROOT:-$(cd "$(dirname "$0")/.." && pwd)}"
REPO_ROOT="${REPO_ROOT:-$(cd "$TESTS_ROOT/.." && pwd)}"

. "$TESTS_ROOT/lib/harness.sh"

CSTK_LIB="$REPO_ROOT/cli/lib"
export CSTK_LIB

# Verifica se curl suporta file:// antes de rodar cenarios que dependem disso.
# Se nao suportar, marca como ERROR (nao FAIL — ambiente inadequado).
_curl_supports_file() {
  _tmpf=$(mktemp) || return 2
  printf 'marker\n' > "$_tmpf"
  if curl -fsSL "file://$_tmpf" >/dev/null 2>&1; then
    rm -f "$_tmpf"
    return 0
  fi
  rm -f "$_tmpf"
  return 1
}

scenario_download_sucesso_via_file_url() {
  if ! _curl_supports_file; then
    _error "scenario_download_sucesso_via_file_url" "curl nao suporta file://"
    return 2
  fi
  _src="$TMPDIR_TEST/source.txt"
  _dest="$TMPDIR_TEST/dest.txt"
  printf 'payload-contents\n' > "$_src"
  capture sh -c ". $CSTK_LIB/http.sh && http_download file://$_src $_dest"
  if [ "$_CAPTURED_EXIT" != "0" ]; then
    _fail "http_download file:// exit" "$_CAPTURED_EXIT; stderr=$_CAPTURED_STDERR"
    return 1
  fi
  if [ ! -f "$_dest" ]; then
    _fail "http_download arquivo destino ausente" "$_dest"
    return 1
  fi
  if ! grep -q 'payload-contents' "$_dest"; then
    _fail "http_download conteudo" "arquivo destino nao tem payload esperado"
    return 1
  fi
}

scenario_download_url_inexistente_exit1() {
  _dest="$TMPDIR_TEST/nope.txt"
  capture sh -c ". $CSTK_LIB/http.sh && http_download file:///nao/existe/jamais.bin $_dest"
  if [ "$_CAPTURED_EXIT" != "1" ]; then
    _fail "http_download 404 exit" "esperado 1, obtido $_CAPTURED_EXIT"
    return 1
  fi
  # Arquivo parcial nao deve persistir
  if [ -f "$_dest" ]; then
    _fail "http_download deixou arquivo parcial" "$_dest"
    return 1
  fi
}

scenario_download_args_faltando_exit2() {
  capture sh -c ". $CSTK_LIB/http.sh && http_download"
  if [ "$_CAPTURED_EXIT" != "2" ]; then
    _fail "http_download sem args" "esperado 2, obtido $_CAPTURED_EXIT"
    return 1
  fi
}

scenario_check_url_sucesso() {
  if ! _curl_supports_file; then
    _error "scenario_check_url_sucesso" "curl nao suporta file://"
    return 2
  fi
  _src="$TMPDIR_TEST/check.txt"
  printf 'x\n' > "$_src"
  capture sh -c ". $CSTK_LIB/http.sh && http_check_url file://$_src"
  if [ "$_CAPTURED_EXIT" != "0" ]; then
    _fail "http_check_url existe" "exit esperado 0, obtido $_CAPTURED_EXIT"
    return 1
  fi
}

scenario_check_url_inexistente() {
  capture sh -c ". $CSTK_LIB/http.sh && http_check_url file:///nao/existe/x"
  if [ "$_CAPTURED_EXIT" = "0" ]; then
    _fail "http_check_url inexistente" "exit esperado !=0, obtido $_CAPTURED_EXIT"
    return 1
  fi
}

run_all_scenarios
