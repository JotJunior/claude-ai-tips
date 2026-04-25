#!/bin/sh
# test_tarball.sh — cobre cli/lib/tarball.sh
#
# Contrato:
#   download_and_verify <tarball_url> <sha256_url> <dest_dir>
#     0  sucesso (tarball baixado, checksum ok, extraido)
#     1  falha de rede, checksum mismatch, extract falhou
#     2  args faltando
#
# Estrategia: cria tarball + .sha256 localmente, serve via file:// URL.

TESTS_ROOT="${TESTS_ROOT:-$(cd "$(dirname "$0")/.." && pwd)}"
REPO_ROOT="${REPO_ROOT:-$(cd "$TESTS_ROOT/.." && pwd)}"

. "$TESTS_ROOT/lib/harness.sh"

CSTK_LIB="$REPO_ROOT/cli/lib"
export CSTK_LIB

_curl_supports_file() {
  _tmpf=$(mktemp) || return 2
  printf 'x\n' > "$_tmpf"
  curl -fsSL "file://$_tmpf" >/dev/null 2>&1
  _rc=$?
  rm -f "$_tmpf"
  return $_rc
}

# _make_tarball <source_dir> <tarball_path> <sha_path>
# Cria tarball.tar.gz do conteudo de source_dir + arquivo .sha256.
_make_tarball() {
  _src=$1
  _tar=$2
  _sha=$3
  (cd -- "$_src" && tar -czf "$_tar" .) || return 1
  if command -v sha256sum >/dev/null 2>&1; then
    (cd -- "$(dirname "$_tar")" && sha256sum "$(basename "$_tar")") > "$_sha"
  elif command -v shasum >/dev/null 2>&1; then
    (cd -- "$(dirname "$_tar")" && shasum -a 256 "$(basename "$_tar")") > "$_sha"
  else
    return 1
  fi
}

scenario_download_verify_sucesso() {
  if ! _curl_supports_file; then
    _error "scenario_download_verify_sucesso" "curl nao suporta file://"
    return 2
  fi
  # Setup: dir fonte com 2 arquivos
  _src="$TMPDIR_TEST/src"
  mkdir "$_src"
  printf 'file-a\n' > "$_src/a.txt"
  printf 'file-b\n' > "$_src/b.txt"
  _tar="$TMPDIR_TEST/archive.tar.gz"
  _sha="$TMPDIR_TEST/archive.tar.gz.sha256"
  _make_tarball "$_src" "$_tar" "$_sha" || {
    _error "scenario_download_verify_sucesso" "_make_tarball falhou"
    return 2
  }
  _dest="$TMPDIR_TEST/extracted"
  capture sh -c ". $CSTK_LIB/tarball.sh && download_and_verify file://$_tar file://$_sha $_dest"
  if [ "$_CAPTURED_EXIT" != "0" ]; then
    _fail "download_and_verify exit" "$_CAPTURED_EXIT; stderr=$_CAPTURED_STDERR"
    return 1
  fi
  if [ ! -f "$_dest/a.txt" ] || [ ! -f "$_dest/b.txt" ]; then
    _fail "download_and_verify extracao" "arquivos esperados ausentes em $_dest"
    return 1
  fi
  if ! grep -q 'file-a' "$_dest/a.txt"; then
    _fail "download_and_verify conteudo" "a.txt nao contem esperado"
    return 1
  fi
}

scenario_checksum_mismatch_exit1() {
  if ! _curl_supports_file; then
    _error "scenario_checksum_mismatch_exit1" "curl nao suporta file://"
    return 2
  fi
  _src="$TMPDIR_TEST/src2"
  mkdir "$_src"
  printf 'real-content\n' > "$_src/x.txt"
  _tar="$TMPDIR_TEST/archive2.tar.gz"
  _sha="$TMPDIR_TEST/archive2.tar.gz.sha256"
  (cd "$_src" && tar -czf "$_tar" .)
  # Inserir checksum deliberadamente errado
  printf 'deadbeef%s  archive2.tar.gz\n' 'deadbeefdeadbeefdeadbeefdeadbeefdeadbeefdeadbeefdeadbeef' > "$_sha"
  _dest="$TMPDIR_TEST/ext2"
  capture sh -c ". $CSTK_LIB/tarball.sh && download_and_verify file://$_tar file://$_sha $_dest"
  if [ "$_CAPTURED_EXIT" != "1" ]; then
    _fail "mismatch exit" "esperado 1, obtido $_CAPTURED_EXIT"
    return 1
  fi
  assert_stderr_contains "MISMATCH" || return 1
  # FR-010a: nenhuma escrita em dest em caso de mismatch
  if [ -d "$_dest" ]; then
    _fail "FR-010a" "dest $_dest foi criado apesar de mismatch"
    return 1
  fi
}

scenario_tarball_url_invalida_exit1() {
  _dest="$TMPDIR_TEST/ext3"
  capture sh -c ". $CSTK_LIB/tarball.sh && download_and_verify file:///nao/existe.tar.gz file:///nao/existe.sha256 $_dest"
  if [ "$_CAPTURED_EXIT" != "1" ]; then
    _fail "url invalida" "esperado 1, obtido $_CAPTURED_EXIT"
    return 1
  fi
  if [ -d "$_dest" ]; then
    _fail "dest nao deve existir" "$_dest criado em erro"
    return 1
  fi
}

scenario_args_faltando_exit2() {
  capture sh -c ". $CSTK_LIB/tarball.sh && download_and_verify"
  if [ "$_CAPTURED_EXIT" != "2" ]; then
    _fail "sem args" "esperado 2, obtido $_CAPTURED_EXIT"
    return 1
  fi
}

run_all_scenarios
