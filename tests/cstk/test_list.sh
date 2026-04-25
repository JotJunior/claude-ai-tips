#!/bin/sh
# test_list.sh — cobre cli/lib/list.sh
#
# Cobre listagem local (clean/edited/missing), --available (catalog),
# format pretty vs tsv, default por TTY, --scope global/project,
# manifest ausente, args invalidos.

TESTS_ROOT="${TESTS_ROOT:-$(cd "$(dirname "$0")/.." && pwd)}"
REPO_ROOT="${REPO_ROOT:-$(cd "$TESTS_ROOT/.." && pwd)}"

. "$TESTS_ROOT/lib/harness.sh"

CSTK_LIB="$REPO_ROOT/cli/lib"
export CSTK_LIB

_make_release() {
  _mr_dir=$1
  _mr_root="$_mr_dir/cstk-v1"
  mkdir -p "$_mr_root/catalog/skills/foo" \
           "$_mr_root/catalog/skills/bar" \
           "$_mr_root/catalog/skills/baz" \
           "$_mr_root/catalog/language/go/skills/golang-helper" || return 1
  printf 'v1\n' > "$_mr_root/catalog/VERSION"
  printf 'sdd:foo\nsdd:bar\n' > "$_mr_root/catalog/profiles.txt"
  printf '# foo v1\n' > "$_mr_root/catalog/skills/foo/SKILL.md"
  printf '# bar v1\n' > "$_mr_root/catalog/skills/bar/SKILL.md"
  printf '# baz v1\n' > "$_mr_root/catalog/skills/baz/SKILL.md"
  printf '# go helper\n' > "$_mr_root/catalog/language/go/skills/golang-helper/SKILL.md"
  (cd "$_mr_dir" && tar -czf cstk-v1.tar.gz cstk-v1) || return 1
  if command -v sha256sum >/dev/null 2>&1; then
    (cd "$_mr_dir" && sha256sum cstk-v1.tar.gz > cstk-v1.tar.gz.sha256) || return 1
  else
    (cd "$_mr_dir" && shasum -a 256 cstk-v1.tar.gz > cstk-v1.tar.gz.sha256) || return 1
  fi
  return 0
}

_install_v1() {
  capture env HOME="$1" CSTK_LIB="$CSTK_LIB" sh -c '
    . "$CSTK_LIB/install.sh"; install_main --from "$1"
  ' install_test "file://$2/cstk-v1.tar.gz"
}

_run_list() {
  _h=$1; shift
  capture env HOME="$_h" CSTK_LIB="$CSTK_LIB" sh -c '
    . "$CSTK_LIB/list.sh"; list_main "$@"
  ' list_test "$@"
}

# ==== Listagem local: clean ====

scenario_list_local_clean_tsv() {
  _h="$TMPDIR_TEST/h"
  _r="$TMPDIR_TEST/r"
  _make_release "$_r" || { _error "fixture" ""; return 2; }
  _install_v1 "$_h" "$_r"
  [ "$_CAPTURED_EXIT" = 0 ] || { _fail "install" ""; return 1; }

  _run_list "$_h" --format tsv
  if [ "$_CAPTURED_EXIT" != 0 ]; then
    _fail "list exit" "$_CAPTURED_EXIT; $_CAPTURED_STDERR"
    return 1
  fi
  # bar e foo do profile sdd, ambas clean
  echo "$_CAPTURED_STDOUT" | grep -q '^foo	v1	clean	' \
    || { _fail "tsv foo clean" "$_CAPTURED_STDOUT"; return 1; }
  echo "$_CAPTURED_STDOUT" | grep -q '^bar	v1	clean	' \
    || { _fail "tsv bar clean" "$_CAPTURED_STDOUT"; return 1; }
}

# ==== Listagem local: edited e missing ====

scenario_list_local_edit_missing() {
  _h="$TMPDIR_TEST/h"
  _r="$TMPDIR_TEST/r"
  _make_release "$_r" || { _error "fixture" ""; return 2; }
  _install_v1 "$_h" "$_r"

  # Editar foo + remover bar
  printf 'edit\n' >> "$_h/.claude/skills/foo/SKILL.md"
  rm -rf "$_h/.claude/skills/bar"

  _run_list "$_h" --format tsv
  [ "$_CAPTURED_EXIT" = 0 ] || { _fail "list exit" "$_CAPTURED_STDERR"; return 1; }
  echo "$_CAPTURED_STDOUT" | grep -q '^foo	v1	edited	' \
    || { _fail "foo edited nao detectado" "$_CAPTURED_STDOUT"; return 1; }
  echo "$_CAPTURED_STDOUT" | grep -q '^bar	v1	missing	' \
    || { _fail "bar missing nao detectado" "$_CAPTURED_STDOUT"; return 1; }
}

# ==== Format pretty tem header ====

scenario_list_pretty_header() {
  _h="$TMPDIR_TEST/h"
  _r="$TMPDIR_TEST/r"
  _make_release "$_r" || { _error "fixture" ""; return 2; }
  _install_v1 "$_h" "$_r"

  _run_list "$_h" --format pretty
  [ "$_CAPTURED_EXIT" = 0 ] || { _fail "list exit" "$_CAPTURED_STDERR"; return 1; }
  echo "$_CAPTURED_STDOUT" | grep -qE '^SKILL +VERSION +STATUS +INSTALLED' \
    || { _fail "pretty header ausente" "$_CAPTURED_STDOUT"; return 1; }
  # Linha de skill em pretty (data truncada para 10 chars)
  echo "$_CAPTURED_STDOUT" | grep -qE '^foo +v1 +clean +[0-9]{4}-[0-9]{2}-[0-9]{2}' \
    || { _fail "pretty data row" "$_CAPTURED_STDOUT"; return 1; }
}

# ==== Default format = tsv quando nao-TTY (pipe) ====

scenario_list_default_format_pipe_tsv() {
  _h="$TMPDIR_TEST/h"
  _r="$TMPDIR_TEST/r"
  _make_release "$_r" || { _error "fixture" ""; return 2; }
  _install_v1 "$_h" "$_r"

  # Sem --format, em pipe (capture redireciona para arquivo, fd1 nao e TTY)
  _run_list "$_h"
  [ "$_CAPTURED_EXIT" = 0 ] || { _fail "list exit" "$_CAPTURED_STDERR"; return 1; }
  # Output deve ser TSV (sem header SKILL)
  case "$_CAPTURED_STDOUT" in
    SKILL*|*"SKILL "*)
      _fail "default pipe deveria ser tsv" "header pretty apareceu: $_CAPTURED_STDOUT"
      return 1
      ;;
  esac
  # Mas deve ter as linhas TSV
  echo "$_CAPTURED_STDOUT" | grep -q '	v1	clean	' \
    || { _fail "default pipe sem tsv" "$_CAPTURED_STDOUT"; return 1; }
}

# ==== --available baixa catalog e lista ====

scenario_list_available_catalog() {
  _h="$TMPDIR_TEST/h"
  _r="$TMPDIR_TEST/r"
  _make_release "$_r" || { _error "fixture" ""; return 2; }
  # Nao precisa de install — --available so le catalog
  _run_list "$_h" --available --from "file://$_r/cstk-v1.tar.gz" --format tsv
  [ "$_CAPTURED_EXIT" = 0 ] || { _fail "available exit" "$_CAPTURED_EXIT; $_CAPTURED_STDERR"; return 1; }
  for s in foo bar baz; do
    echo "$_CAPTURED_STDOUT" | grep -q "^$s	global$" \
      || { _fail "skill $s ausente em --available" "$_CAPTURED_STDOUT"; return 1; }
  done
  # Skill de language deve aparecer com origin language-go
  echo "$_CAPTURED_STDOUT" | grep -q '^golang-helper	language-go$' \
    || { _fail "language skill nao listada" "$_CAPTURED_STDOUT"; return 1; }
}

# ==== --available sem URL e sem env => exit 1 ====

scenario_list_available_sem_url() {
  capture env -i HOME="$TMPDIR_TEST/h" CSTK_LIB="$CSTK_LIB" PATH="$PATH" sh -c '
    . "$CSTK_LIB/list.sh"; list_main --available
  '
  if [ "$_CAPTURED_EXIT" != 1 ]; then
    _fail "available sem url exit" "esperado 1, obtido $_CAPTURED_EXIT"
    return 1
  fi
  assert_stderr_contains "URL ausente" || return 1
}

# ==== Manifest ausente: warn + exit 0 ====

scenario_list_manifest_ausente() {
  _h="$TMPDIR_TEST/h"
  _run_list "$_h" --format tsv
  if [ "$_CAPTURED_EXIT" != 0 ]; then
    _fail "manifest ausente exit" "esperado 0, obtido $_CAPTURED_EXIT"
    return 1
  fi
  assert_stderr_contains "manifest ausente" || return 1
  if [ -n "$_CAPTURED_STDOUT" ]; then
    _fail "stdout deveria estar vazio" "$_CAPTURED_STDOUT"
    return 1
  fi
}

# ==== Help ====

scenario_list_help() {
  _run_list "$TMPDIR_TEST/h" --help
  [ "$_CAPTURED_EXIT" = 0 ] || { _fail "help exit" "$_CAPTURED_EXIT"; return 1; }
  assert_stderr_contains "cstk list" || return 1
}

# ==== Args invalidos ====

scenario_list_format_invalido() {
  _run_list "$TMPDIR_TEST/h" --format yaml
  if [ "$_CAPTURED_EXIT" != 2 ]; then
    _fail "--format yaml exit" "esperado 2, obtido $_CAPTURED_EXIT"
    return 1
  fi
}

scenario_list_scope_invalido() {
  _run_list "$TMPDIR_TEST/h" --scope tudo
  if [ "$_CAPTURED_EXIT" != 2 ]; then
    _fail "--scope tudo exit" "esperado 2, obtido $_CAPTURED_EXIT"
    return 1
  fi
}

run_all_scenarios
