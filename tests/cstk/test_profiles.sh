#!/bin/sh
# test_profiles.sh — cobre cli/lib/profiles.sh
#
# Cenarios:
#   - profiles_parse: skip blank/comment, output TSV, malformed aborta
#   - list_profiles: nomes unicos ordenados
#   - resolve_profile: profile flat (sdd-like), profile aninhado, profile `all`
#     (multi-nivel), cherry-pick union via shell, profile inexistente,
#     ciclo (fixture maliciosa), catalog inexistente, dedup de skills duplicadas

TESTS_ROOT="${TESTS_ROOT:-$(cd "$(dirname "$0")/.." && pwd)}"
REPO_ROOT="${REPO_ROOT:-$(cd "$TESTS_ROOT/.." && pwd)}"

. "$TESTS_ROOT/lib/harness.sh"

CSTK_LIB="$REPO_ROOT/cli/lib"
export CSTK_LIB

# Helper: escreve um catalog de profiles a partir das linhas passadas.
_seed_catalog() {
  _path=$1; shift
  mkdir -p "$(dirname "$_path")"
  {
    printf '# cstk profiles catalog\n'
    for line in "$@"; do
      printf '%s\n' "$line"
    done
  } > "$_path"
}

# Catalog "padrao" minimo, espelhando data-model.md mas com skills concretas.
_seed_default_catalog() {
  _seed_catalog "$1" \
    "sdd:briefing" \
    "sdd:specify" \
    "sdd:plan" \
    "complementary:advisor" \
    "complementary:bugfix" \
    "language-go:go-test-runner" \
    "language-go:go-build-helper" \
    "all:sdd" \
    "all:complementary" \
    "all:language-go"
}

# ==== profiles_parse ====

scenario_parse_pula_blank_e_comentarios() {
  _c="$TMPDIR_TEST/profiles.txt"
  _seed_catalog "$_c" \
    "" \
    "# header" \
    "sdd:briefing" \
    "" \
    "# midcomment" \
    "sdd:specify"
  capture sh -c ". $CSTK_LIB/profiles.sh && profiles_parse $_c"
  if [ "$_CAPTURED_EXIT" != "0" ]; then
    _fail "parse exit" "$_CAPTURED_EXIT; stderr=$_CAPTURED_STDERR"
    return 1
  fi
  _count=$(printf '%s\n' "$_CAPTURED_STDOUT" | wc -l | awk '{print $1}')
  if [ "$_count" != "2" ]; then
    _fail "parse count" "esperado 2 linhas, obtido $_count: $_CAPTURED_STDOUT"
    return 1
  fi
  echo "$_CAPTURED_STDOUT" | grep -q '^sdd	briefing$' || { _fail "parse linha 1" "ausente"; return 1; }
  echo "$_CAPTURED_STDOUT" | grep -q '^sdd	specify$' || { _fail "parse linha 2" "ausente"; return 1; }
}

scenario_parse_malformado_aborta() {
  _c="$TMPDIR_TEST/profiles.txt"
  _seed_catalog "$_c" \
    "sdd:briefing" \
    "linha-sem-dois-pontos"
  capture sh -c ". $CSTK_LIB/profiles.sh && profiles_parse $_c"
  if [ "$_CAPTURED_EXIT" != "1" ]; then
    _fail "parse malformado exit" "esperado 1, obtido $_CAPTURED_EXIT"
    return 1
  fi
  assert_stderr_contains "malformada" || return 1
}

scenario_parse_arquivo_inexistente_aborta() {
  capture sh -c ". $CSTK_LIB/profiles.sh && profiles_parse $TMPDIR_TEST/nao-existe.txt"
  if [ "$_CAPTURED_EXIT" != "1" ]; then
    _fail "parse inexistente exit" "esperado 1, obtido $_CAPTURED_EXIT"
    return 1
  fi
  assert_stderr_contains "nao encontrado" || return 1
}

# ==== list_profiles ====

scenario_list_profiles_unicos_ordenados() {
  _c="$TMPDIR_TEST/profiles.txt"
  _seed_default_catalog "$_c"
  capture sh -c ". $CSTK_LIB/profiles.sh && list_profiles $_c"
  if [ "$_CAPTURED_EXIT" != "0" ]; then
    _fail "list exit" "$_CAPTURED_EXIT"
    return 1
  fi
  _expected="all
complementary
language-go
sdd"
  if [ "$_CAPTURED_STDOUT" != "$_expected" ]; then
    _fail "list ordem/unicidade" "esperado <$_expected>, obtido <$_CAPTURED_STDOUT>"
    return 1
  fi
}

# ==== resolve_profile: profile direto sem nesting ====

scenario_resolve_sdd_default() {
  _c="$TMPDIR_TEST/profiles.txt"
  _seed_default_catalog "$_c"
  capture sh -c ". $CSTK_LIB/profiles.sh && resolve_profile $_c sdd"
  if [ "$_CAPTURED_EXIT" != "0" ]; then
    _fail "resolve sdd exit" "$_CAPTURED_EXIT; stderr=$_CAPTURED_STDERR"
    return 1
  fi
  _expected="briefing
plan
specify"
  if [ "$_CAPTURED_STDOUT" != "$_expected" ]; then
    _fail "resolve sdd valor" "esperado <$_expected>, obtido <$_CAPTURED_STDOUT>"
    return 1
  fi
}

# ==== resolve_profile: profile `all` com nesting multi-nivel ====

scenario_resolve_all_expansao_multinivel() {
  _c="$TMPDIR_TEST/profiles.txt"
  _seed_default_catalog "$_c"
  capture sh -c ". $CSTK_LIB/profiles.sh && resolve_profile $_c all"
  if [ "$_CAPTURED_EXIT" != "0" ]; then
    _fail "resolve all exit" "$_CAPTURED_EXIT; stderr=$_CAPTURED_STDERR"
    return 1
  fi
  _expected="advisor
briefing
bugfix
go-build-helper
go-test-runner
plan
specify"
  if [ "$_CAPTURED_STDOUT" != "$_expected" ]; then
    _fail "resolve all valor" "esperado <$_expected>, obtido <$_CAPTURED_STDOUT>"
    return 1
  fi
}

# ==== resolve_profile: cherry-pick union com profile (uso pelo install) ====

scenario_resolve_union_com_cherrypick() {
  # Simula o que install.sh fara: combina resolve_profile com skills explicitas
  # e dedupa via sort -u. Esta cenario valida que o output do resolver e
  # composavel com o pipeline `sort -u`.
  _c="$TMPDIR_TEST/profiles.txt"
  _seed_default_catalog "$_c"
  capture sh -c ". $CSTK_LIB/profiles.sh && {
    resolve_profile $_c sdd
    printf 'extra-skill\n'
    printf 'briefing\n'
  } | sort -u"
  if [ "$_CAPTURED_EXIT" != "0" ]; then
    _fail "union exit" "$_CAPTURED_EXIT"
    return 1
  fi
  _expected="briefing
extra-skill
plan
specify"
  if [ "$_CAPTURED_STDOUT" != "$_expected" ]; then
    _fail "union valor (briefing dedupado)" "esperado <$_expected>, obtido <$_CAPTURED_STDOUT>"
    return 1
  fi
}

# ==== resolve_profile: profile inexistente ====

scenario_resolve_profile_inexistente() {
  _c="$TMPDIR_TEST/profiles.txt"
  _seed_default_catalog "$_c"
  capture sh -c ". $CSTK_LIB/profiles.sh && resolve_profile $_c profile-fantasma"
  if [ "$_CAPTURED_EXIT" != "1" ]; then
    _fail "resolve fantasma exit" "esperado 1, obtido $_CAPTURED_EXIT"
    return 1
  fi
  assert_stderr_contains "profile desconhecido" || return 1
  if [ -n "$_CAPTURED_STDOUT" ]; then
    _fail "resolve fantasma stdout" "esperava vazio, obtido <$_CAPTURED_STDOUT>"
    return 1
  fi
}

# ==== resolve_profile: ciclo (fixture maliciosa) ====

scenario_resolve_ciclo_direto_aborta() {
  # Ciclo de tamanho 2: a -> b -> a
  _c="$TMPDIR_TEST/profiles.txt"
  _seed_catalog "$_c" \
    "a:b" \
    "b:a"
  capture sh -c ". $CSTK_LIB/profiles.sh && resolve_profile $_c a"
  if [ "$_CAPTURED_EXIT" != "1" ]; then
    _fail "ciclo direto exit" "esperado 1, obtido $_CAPTURED_EXIT"
    return 1
  fi
  assert_stderr_contains "ciclo detectado" || return 1
}

scenario_resolve_ciclo_indireto_aborta() {
  # Ciclo de tamanho 3: a -> b -> c -> a; mais skill solta para nao virar leaf
  _c="$TMPDIR_TEST/profiles.txt"
  _seed_catalog "$_c" \
    "a:skill1" \
    "a:b" \
    "b:c" \
    "c:a"
  capture sh -c ". $CSTK_LIB/profiles.sh && resolve_profile $_c a"
  if [ "$_CAPTURED_EXIT" != "1" ]; then
    _fail "ciclo indireto exit" "esperado 1, obtido $_CAPTURED_EXIT"
    return 1
  fi
  assert_stderr_contains "ciclo detectado" || return 1
}

scenario_resolve_grafo_diamante_sem_ciclo() {
  # Diamante: all -> {x, y}; x -> shared; y -> shared
  # NAO e ciclo; deve resolver com `shared` aparecendo uma unica vez.
  _c="$TMPDIR_TEST/profiles.txt"
  _seed_catalog "$_c" \
    "all:x" \
    "all:y" \
    "x:shared" \
    "y:shared" \
    "x:only-x" \
    "y:only-y"
  capture sh -c ". $CSTK_LIB/profiles.sh && resolve_profile $_c all"
  if [ "$_CAPTURED_EXIT" != "0" ]; then
    _fail "diamante exit" "esperado 0, obtido $_CAPTURED_EXIT; stderr=$_CAPTURED_STDERR"
    return 1
  fi
  _expected="only-x
only-y
shared"
  if [ "$_CAPTURED_STDOUT" != "$_expected" ]; then
    _fail "diamante valor" "esperado <$_expected>, obtido <$_CAPTURED_STDOUT>"
    return 1
  fi
}

scenario_resolve_arquivo_inexistente_aborta() {
  capture sh -c ". $CSTK_LIB/profiles.sh && resolve_profile $TMPDIR_TEST/nao-ha.txt sdd"
  if [ "$_CAPTURED_EXIT" != "1" ]; then
    _fail "resolve inexistente exit" "esperado 1, obtido $_CAPTURED_EXIT"
    return 1
  fi
  assert_stderr_contains "nao encontrado" || return 1
}

scenario_resolve_args_invalidos() {
  capture sh -c ". $CSTK_LIB/profiles.sh && resolve_profile so-um-arg"
  if [ "$_CAPTURED_EXIT" != "2" ]; then
    _fail "resolve args invalidos exit" "esperado 2, obtido $_CAPTURED_EXIT"
    return 1
  fi
}

run_all_scenarios
