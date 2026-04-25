#!/bin/sh
# test_hash.sh — cobre cli/lib/hash.sh
#
# Contrato:
#   hash_dir <dir>    imprime SHA-256 hex de manifest canonico
#   Deterministico: mesmo conteudo -> mesmo hash, independente de:
#     - mtime dos arquivos
#     - permissoes
#     - ordem de criacao
#   Arquivos diferentes -> hashes diferentes.

TESTS_ROOT="${TESTS_ROOT:-$(cd "$(dirname "$0")/.." && pwd)}"
REPO_ROOT="${REPO_ROOT:-$(cd "$TESTS_ROOT/.." && pwd)}"

. "$TESTS_ROOT/lib/harness.sh"

CSTK_LIB="$REPO_ROOT/cli/lib"
export CSTK_LIB

scenario_hash_dir_basico() {
  _d="$TMPDIR_TEST/d1"
  mkdir -p "$_d"
  printf 'hello\n' > "$_d/a.txt"
  printf 'world\n' > "$_d/b.txt"
  capture sh -c ". $CSTK_LIB/hash.sh && hash_dir $_d"
  if [ "$_CAPTURED_EXIT" != "0" ]; then
    _fail "hash_dir exit" "$_CAPTURED_EXIT; stderr=$_CAPTURED_STDERR"
    return 1
  fi
  echo "$_CAPTURED_STDOUT" | grep -qE '^[0-9a-f]{64}$' || {
    _fail "hash_dir formato" "stdout nao e hash hex: $_CAPTURED_STDOUT"
    return 1
  }
}

scenario_hash_dir_determinista_mesmo_conteudo() {
  _d1="$TMPDIR_TEST/d_a"
  _d2="$TMPDIR_TEST/d_b"
  mkdir -p "$_d1" "$_d2"
  printf 'foo\n' > "$_d1/one.txt"
  printf 'bar\n' > "$_d1/two.txt"
  # Mesmo conteudo, ordem de criacao invertida
  printf 'bar\n' > "$_d2/two.txt"
  printf 'foo\n' > "$_d2/one.txt"
  _h1=$(sh -c ". $CSTK_LIB/hash.sh && hash_dir $_d1")
  _h2=$(sh -c ". $CSTK_LIB/hash.sh && hash_dir $_d2")
  if [ "$_h1" != "$_h2" ]; then
    _fail "hash_dir determinismo" "hashes divergem apesar de conteudo igual: $_h1 vs $_h2"
    return 1
  fi
}

scenario_hash_dir_conteudo_diferente_muda_hash() {
  _d1="$TMPDIR_TEST/d_c"
  _d2="$TMPDIR_TEST/d_d"
  mkdir -p "$_d1" "$_d2"
  printf 'same-name\n' > "$_d1/x.txt"
  printf 'different\n' > "$_d2/x.txt"
  _h1=$(sh -c ". $CSTK_LIB/hash.sh && hash_dir $_d1")
  _h2=$(sh -c ". $CSTK_LIB/hash.sh && hash_dir $_d2")
  if [ "$_h1" = "$_h2" ]; then
    _fail "hash_dir sensibilidade conteudo" "hashes iguais para conteudos distintos"
    return 1
  fi
}

scenario_hash_dir_mtime_nao_muda_hash() {
  _d="$TMPDIR_TEST/d_mt"
  mkdir -p "$_d"
  printf 'content\n' > "$_d/a.txt"
  _h1=$(sh -c ". $CSTK_LIB/hash.sh && hash_dir $_d")
  # Mudar mtime sem alterar conteudo
  touch -t 202001010000 "$_d/a.txt"
  _h2=$(sh -c ". $CSTK_LIB/hash.sh && hash_dir $_d")
  if [ "$_h1" != "$_h2" ]; then
    _fail "hash_dir mtime sensivel" "hash mudou apenas por mtime: $_h1 vs $_h2"
    return 1
  fi
}

scenario_hash_dir_path_diferente_muda_hash() {
  # Mesmo conteudo, nome de arquivo diferente -> hash diferente.
  _d1="$TMPDIR_TEST/d_p1"
  _d2="$TMPDIR_TEST/d_p2"
  mkdir -p "$_d1" "$_d2"
  printf 'x\n' > "$_d1/alpha.txt"
  printf 'x\n' > "$_d2/beta.txt"
  _h1=$(sh -c ". $CSTK_LIB/hash.sh && hash_dir $_d1")
  _h2=$(sh -c ". $CSTK_LIB/hash.sh && hash_dir $_d2")
  if [ "$_h1" = "$_h2" ]; then
    _fail "hash_dir path-sensibilidade" "hashes iguais apesar de nomes diferentes"
    return 1
  fi
}

scenario_hash_dir_arg_invalido() {
  capture sh -c ". $CSTK_LIB/hash.sh && hash_dir"
  if [ "$_CAPTURED_EXIT" != "2" ]; then
    _fail "hash_dir sem arg" "exit esperado 2, obtido $_CAPTURED_EXIT"
    return 1
  fi
}

scenario_hash_dir_dir_inexistente() {
  capture sh -c ". $CSTK_LIB/hash.sh && hash_dir /nao/existe/nunca"
  if [ "$_CAPTURED_EXIT" != "1" ]; then
    _fail "hash_dir dir inexistente" "exit esperado 1, obtido $_CAPTURED_EXIT"
    return 1
  fi
}

run_all_scenarios
