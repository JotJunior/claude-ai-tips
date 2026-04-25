#!/bin/sh
# test_bootstrap.sh — cobre cli/install.sh (one-liner bootstrap).
#
# Cobre Scenario 1 (parte inicial — instalacao do binario), checksum mismatch,
# tarball malformado (sem cli/), CSTK_RELEASE_URL como override de fixture
# offline, deteccao de PATH, idempotencia (re-run substitui binario).

TESTS_ROOT="${TESTS_ROOT:-$(cd "$(dirname "$0")/.." && pwd)}"
REPO_ROOT="${REPO_ROOT:-$(cd "$TESTS_ROOT/.." && pwd)}"

. "$TESTS_ROOT/lib/harness.sh"

BOOTSTRAP="$REPO_ROOT/cli/install.sh"

# _make_bootstrap_fixture: monta release mock contendo cli/cstk + cli/lib/.
# Copia da arvore real do repo (e o cenario realista — o tarball que o
# release pipeline da FASE 9 vai gerar contem exatamente isso).
_make_bootstrap_fixture() {
  _mbf_dir=$1
  _mbf_tag=${2:-v0.1.0-test}
  _mbf_root="$_mbf_dir/cstk-$_mbf_tag"
  mkdir -p "$_mbf_root/cli/lib"
  cp -- "$REPO_ROOT/cli/cstk" "$_mbf_root/cli/cstk" || return 1
  cp -- "$REPO_ROOT/cli/lib/"*.sh "$_mbf_root/cli/lib/" || return 1
  printf '%s\n' "$_mbf_tag" > "$_mbf_root/VERSION"
  (cd "$_mbf_dir" && tar -czf "cstk-$_mbf_tag.tar.gz" "cstk-$_mbf_tag") || return 1
  if command -v sha256sum >/dev/null 2>&1; then
    (cd "$_mbf_dir" && sha256sum "cstk-$_mbf_tag.tar.gz" > "cstk-$_mbf_tag.tar.gz.sha256") || return 1
  else
    (cd "$_mbf_dir" && shasum -a 256 "cstk-$_mbf_tag.tar.gz" > "cstk-$_mbf_tag.tar.gz.sha256") || return 1
  fi
  return 0
}

_run_bootstrap() {
  _rb_home=$1; shift
  _rb_url=$1; shift
  capture env \
    HOME="$_rb_home" \
    INSTALL_BIN="$_rb_home/.local/bin" \
    INSTALL_LIB="$_rb_home/.local/share/cstk" \
    CSTK_RELEASE_URL="$_rb_url" \
    PATH="$PATH" \
    sh "$BOOTSTRAP"
}

# ==== Happy path: instalacao limpa ====

scenario_bootstrap_fresh_install() {
  _h="$TMPDIR_TEST/home"
  _r="$TMPDIR_TEST/release"
  _make_bootstrap_fixture "$_r" v0.1.0-test \
    || { _error "fixture" "tarball build falhou"; return 2; }

  _url="file://$_r/cstk-v0.1.0-test.tar.gz"
  _run_bootstrap "$_h" "$_url"

  if [ "$_CAPTURED_EXIT" != 0 ]; then
    _fail "bootstrap exit" "esperado 0, obtido $_CAPTURED_EXIT; stderr=$_CAPTURED_STDERR"
    return 1
  fi
  [ -x "$_h/.local/bin/cstk" ] || { _fail "binario ausente" ""; return 1; }
  [ -d "$_h/.local/share/cstk/lib" ] || { _fail "lib dir ausente" ""; return 1; }
  [ -f "$_h/.local/share/cstk/lib/manifest.sh" ] || { _fail "lib/manifest.sh ausente" ""; return 1; }
  [ -f "$_h/.local/share/cstk/VERSION" ] || { _fail "VERSION ausente" ""; return 1; }
  _v=$(cat "$_h/.local/share/cstk/VERSION")
  if [ "$_v" != "v0.1.0-test" ]; then
    _fail "VERSION conteudo" "esperado v0.1.0-test, obtido '$_v'"
    return 1
  fi
}

# ==== Binario instalado realmente roda ====

scenario_bootstrap_binario_executavel() {
  _h="$TMPDIR_TEST/home"
  _r="$TMPDIR_TEST/release"
  _make_bootstrap_fixture "$_r" v0.2.0-test \
    || { _error "fixture" ""; return 2; }
  _run_bootstrap "$_h" "file://$_r/cstk-v0.2.0-test.tar.gz"
  [ "$_CAPTURED_EXIT" = 0 ] || { _fail "bootstrap setup" "$_CAPTURED_STDERR"; return 1; }

  capture "$_h/.local/bin/cstk" --version
  if [ "$_CAPTURED_EXIT" != 0 ]; then
    _fail "cstk --version exit" "$_CAPTURED_EXIT; stderr=$_CAPTURED_STDERR"
    return 1
  fi
  assert_stdout_contains "v0.2.0-test" || return 1
}

# ==== Re-run substitui (idempotente como upgrade) ====

scenario_bootstrap_re_run_atualiza() {
  _h="$TMPDIR_TEST/home"
  _r="$TMPDIR_TEST/release"
  _make_bootstrap_fixture "$_r" v0.1.0-test || { _error "fixture v1" ""; return 2; }
  _run_bootstrap "$_h" "file://$_r/cstk-v0.1.0-test.tar.gz"
  [ "$_CAPTURED_EXIT" = 0 ] || { _fail "primeira bootstrap" ""; return 1; }
  _v1=$(cat "$_h/.local/share/cstk/VERSION")
  [ "$_v1" = "v0.1.0-test" ] || { _fail "v1 setup" "$_v1"; return 1; }

  # Segunda release com tag diferente
  _r2="$TMPDIR_TEST/release2"
  _make_bootstrap_fixture "$_r2" v0.5.0-test || { _error "fixture v2" ""; return 2; }
  _run_bootstrap "$_h" "file://$_r2/cstk-v0.5.0-test.tar.gz"
  if [ "$_CAPTURED_EXIT" != 0 ]; then
    _fail "re-run exit" "$_CAPTURED_EXIT; stderr=$_CAPTURED_STDERR"
    return 1
  fi
  _v2=$(cat "$_h/.local/share/cstk/VERSION")
  if [ "$_v2" != "v0.5.0-test" ]; then
    _fail "VERSION nao foi atualizada" "obtido '$_v2'"
    return 1
  fi
}

# ==== Checksum mismatch (FR-010a): zero writes ====

scenario_bootstrap_checksum_mismatch_aborta() {
  _h="$TMPDIR_TEST/home"
  _r="$TMPDIR_TEST/release"
  _make_bootstrap_fixture "$_r" v0.1.0-test || { _error "fixture" ""; return 2; }
  # Corrompe o sha256 file
  printf 'deadbeefdeadbeefdeadbeefdeadbeefdeadbeefdeadbeefdeadbeefdeadbeef  cstk-v0.1.0-test.tar.gz\n' \
    > "$_r/cstk-v0.1.0-test.tar.gz.sha256"

  _run_bootstrap "$_h" "file://$_r/cstk-v0.1.0-test.tar.gz"
  if [ "$_CAPTURED_EXIT" != 1 ]; then
    _fail "checksum mismatch exit" "esperado 1, obtido $_CAPTURED_EXIT"
    return 1
  fi
  assert_stderr_contains "MISMATCH" || return 1
  # Nada criado em $_h
  [ -d "$_h/.local" ] && { _fail "checksum mismatch criou $_h/.local" ""; return 1; }
  return 0
}

# ==== Tarball sem cli/ aborta ====

scenario_bootstrap_tarball_sem_cli_aborta() {
  _h="$TMPDIR_TEST/home"
  _r="$TMPDIR_TEST/release"
  _bad_root="$_r/bogus-v0.1.0"
  mkdir -p "$_bad_root/random/dir"
  printf 'no cstk here\n' > "$_bad_root/random/file.txt"
  (cd "$_r" && tar -czf cstk-v0.1.0-test.tar.gz bogus-v0.1.0)
  if command -v sha256sum >/dev/null 2>&1; then
    (cd "$_r" && sha256sum cstk-v0.1.0-test.tar.gz > cstk-v0.1.0-test.tar.gz.sha256)
  else
    (cd "$_r" && shasum -a 256 cstk-v0.1.0-test.tar.gz > cstk-v0.1.0-test.tar.gz.sha256)
  fi

  _run_bootstrap "$_h" "file://$_r/cstk-v0.1.0-test.tar.gz"
  if [ "$_CAPTURED_EXIT" != 1 ]; then
    _fail "tarball ruim exit" "esperado 1, obtido $_CAPTURED_EXIT"
    return 1
  fi
  assert_stderr_contains "tarball nao contem cli/cstk" || return 1
}

# ==== PATH check: avisa quando INSTALL_BIN nao esta no PATH ====

scenario_bootstrap_path_nao_setado_avisa() {
  _h="$TMPDIR_TEST/home"
  _r="$TMPDIR_TEST/release"
  _make_bootstrap_fixture "$_r" v0.1.0-test || { _error "fixture" ""; return 2; }
  # PATH explicitamente sem $_h/.local/bin
  capture env -i \
    HOME="$_h" \
    INSTALL_BIN="$_h/.local/bin" \
    INSTALL_LIB="$_h/.local/share/cstk" \
    CSTK_RELEASE_URL="file://$_r/cstk-v0.1.0-test.tar.gz" \
    PATH="/usr/bin:/bin" \
    sh "$BOOTSTRAP"
  [ "$_CAPTURED_EXIT" = 0 ] || { _fail "bootstrap exit" "$_CAPTURED_STDERR"; return 1; }
  assert_stderr_contains "NAO esta no PATH" || return 1
  assert_stderr_contains "export PATH" || return 1
}

scenario_bootstrap_path_ja_setado_silencia_aviso() {
  _h="$TMPDIR_TEST/home"
  _r="$TMPDIR_TEST/release"
  _make_bootstrap_fixture "$_r" v0.1.0-test || { _error "fixture" ""; return 2; }
  capture env -i \
    HOME="$_h" \
    INSTALL_BIN="$_h/.local/bin" \
    INSTALL_LIB="$_h/.local/share/cstk" \
    CSTK_RELEASE_URL="file://$_r/cstk-v0.1.0-test.tar.gz" \
    PATH="$_h/.local/bin:/usr/bin:/bin" \
    sh "$BOOTSTRAP"
  [ "$_CAPTURED_EXIT" = 0 ] || { _fail "bootstrap exit" "$_CAPTURED_STDERR"; return 1; }
  case "$_CAPTURED_STDERR" in
    *"NAO esta no PATH"*)
      _fail "aviso indevido" "PATH contem INSTALL_BIN mas warn apareceu"
      return 1
      ;;
  esac
  assert_stderr_contains "ja esta no PATH" || return 1
}

# ==== Tag inferida do filename do CSTK_RELEASE_URL ====

scenario_bootstrap_tag_inferida_do_url() {
  _h="$TMPDIR_TEST/home"
  _r="$TMPDIR_TEST/release"
  _make_bootstrap_fixture "$_r" v3.5.0 || { _error "fixture" ""; return 2; }
  _run_bootstrap "$_h" "file://$_r/cstk-v3.5.0.tar.gz"
  [ "$_CAPTURED_EXIT" = 0 ] || { _fail "bootstrap exit" "$_CAPTURED_STDERR"; return 1; }
  _v=$(cat "$_h/.local/share/cstk/VERSION")
  if [ "$_v" != "v3.5.0" ]; then
    _fail "tag inferida errada" "esperado v3.5.0, VERSION='$_v'"
    return 1
  fi
}

run_all_scenarios
