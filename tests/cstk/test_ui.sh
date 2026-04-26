#!/bin/sh
# test_ui.sh — cobre cli/lib/ui.sh (FASE 8.1)
#
# Cobre Scenario 11 (TTY + toggles + confirmacao via CSTK_FORCE_INTERACTIVE),
# Scenario 12 (pipe sem TTY -> exit 2), helpers puros (_ui_apply_toggle,
# _ui_resolve_skills) e integracao install/update --interactive.

TESTS_ROOT="${TESTS_ROOT:-$(cd "$(dirname "$0")/.." && pwd)}"
REPO_ROOT="${REPO_ROOT:-$(cd "$TESTS_ROOT/.." && pwd)}"

. "$TESTS_ROOT/lib/harness.sh"

CSTK_LIB="$REPO_ROOT/cli/lib"
export CSTK_LIB

# _make_profiles_fixture: cria catalog/profiles.txt com 2 profiles.
_make_profiles_fixture() {
  _mpf_path=$1
  {
    printf '# fixture profiles\n'
    printf 'sdd:specify\n'
    printf 'sdd:plan\n'
    printf 'all:bugfix\n'
    printf 'all:specify\n'
  } > "$_mpf_path"
}

# _make_release_fixture: monta um tarball mock parecido com o de test_install.sh
# para integration tests.
_make_release_fixture() {
  _mrf_dir=$1
  _mrf_root="$_mrf_dir/cstk-test-v0.1.0"
  mkdir -p "$_mrf_root/catalog/skills/specify" \
           "$_mrf_root/catalog/skills/plan" \
           "$_mrf_root/catalog/skills/bugfix" \
           "$_mrf_root/catalog/skills/extra"
  printf '0.1.0-test\n' > "$_mrf_root/catalog/VERSION"
  _make_profiles_fixture "$_mrf_root/catalog/profiles.txt"
  for _s in specify plan bugfix extra; do
    printf '# %s skill\n' "$_s" > "$_mrf_root/catalog/skills/$_s/SKILL.md"
  done
  (cd "$_mrf_dir" && tar -czf cstk-test-v0.1.0.tar.gz cstk-test-v0.1.0) || return 1
  if command -v sha256sum >/dev/null 2>&1; then
    (cd "$_mrf_dir" && sha256sum cstk-test-v0.1.0.tar.gz > cstk-test-v0.1.0.tar.gz.sha256) \
      || return 1
  else
    (cd "$_mrf_dir" && shasum -a 256 cstk-test-v0.1.0.tar.gz > cstk-test-v0.1.0.tar.gz.sha256) \
      || return 1
  fi
  return 0
}

# ==== _ui_apply_toggle: helpers puros ====

scenario_ui_apply_toggle_add_simples() {
  capture sh -c '
    . "'"$CSTK_LIB"'/ui.sh"
    _ui_apply_toggle "" "1 3 5"
  '
  if [ "$_CAPTURED_EXIT" != 0 ]; then
    _fail "toggle add" "exit=$_CAPTURED_EXIT stderr=$_CAPTURED_STDERR"
    return 1
  fi
  if [ "$_CAPTURED_STDOUT" != "1 3 5" ]; then
    _fail "toggle add stdout" "esperado '1 3 5', obtido '$_CAPTURED_STDOUT'"
    return 1
  fi
}

scenario_ui_apply_toggle_remove_e_dedupe() {
  capture sh -c '
    . "'"$CSTK_LIB"'/ui.sh"
    _ui_apply_toggle "1 3 5 7" "3 7 9"
  '
  if [ "$_CAPTURED_EXIT" != 0 ]; then
    _fail "toggle remove" "$_CAPTURED_STDERR"
    return 1
  fi
  # 3 e 7 ja estavam -> removidos. 9 era novo -> adicionado. Resultado: 1 5 9.
  if [ "$_CAPTURED_STDOUT" != "1 5 9" ]; then
    _fail "toggle xor" "esperado '1 5 9', obtido '$_CAPTURED_STDOUT'"
    return 1
  fi
}

scenario_ui_apply_toggle_dedupe_input_e_sort() {
  capture sh -c '
    . "'"$CSTK_LIB"'/ui.sh"
    _ui_apply_toggle "" "10 2 10 5 2"
  '
  if [ "$_CAPTURED_EXIT" != 0 ]; then
    _fail "toggle dedup input" "$_CAPTURED_STDERR"
    return 1
  fi
  # 10 e 2 aparecem 2x no input -> dedup interno antes do XOR.
  # Resultado: 2 5 10 (todos novos, ordem numerica).
  if [ "$_CAPTURED_STDOUT" != "2 5 10" ]; then
    _fail "toggle dedup+sort" "esperado '2 5 10', obtido '$_CAPTURED_STDOUT'"
    return 1
  fi
}

scenario_ui_apply_toggle_input_invalido() {
  capture sh -c '
    . "'"$CSTK_LIB"'/ui.sh"
    _ui_apply_toggle "1" "abc"
  '
  if [ "$_CAPTURED_EXIT" = 0 ]; then
    _fail "toggle invalido" "esperado exit nao-zero para input com letras"
    return 1
  fi
}

scenario_ui_apply_toggle_input_vazio_preserva() {
  capture sh -c '
    . "'"$CSTK_LIB"'/ui.sh"
    _ui_apply_toggle "1 2 3" ""
  '
  if [ "$_CAPTURED_EXIT" != 0 ]; then
    _fail "toggle vazio" "$_CAPTURED_STDERR"
    return 1
  fi
  if [ "$_CAPTURED_STDOUT" != "1 2 3" ]; then
    _fail "toggle vazio preserva" "esperado '1 2 3', obtido '$_CAPTURED_STDOUT'"
    return 1
  fi
}

# ==== _ui_resolve_skills: expansao de profiles + cherry-pick ====

scenario_ui_resolve_profile_expand() {
  _profiles="$TMPDIR_TEST/profiles.txt"
  _make_profiles_fixture "$_profiles"
  capture sh -c '
    . "'"$CSTK_LIB"'/ui.sh"
    _index="profile	1	sdd
profile	2	all
skill	3	specify
skill	4	plan
skill	5	bugfix"
    _ui_resolve_skills "1" "$_index" "'"$_profiles"'"
  '
  if [ "$_CAPTURED_EXIT" != 0 ]; then
    _fail "resolve profile" "$_CAPTURED_STDERR"
    return 1
  fi
  # Profile sdd expande para specify + plan
  printf '%s\n' "$_CAPTURED_STDOUT" | grep -qx 'specify' \
    || { _fail "resolve sdd specify" "stdout=$_CAPTURED_STDOUT"; return 1; }
  printf '%s\n' "$_CAPTURED_STDOUT" | grep -qx 'plan' \
    || { _fail "resolve sdd plan" ""; return 1; }
}

scenario_ui_resolve_profile_e_skill_union() {
  _profiles="$TMPDIR_TEST/profiles.txt"
  _make_profiles_fixture "$_profiles"
  capture sh -c '
    . "'"$CSTK_LIB"'/ui.sh"
    _index="profile	1	sdd
profile	2	all
skill	3	specify
skill	4	plan
skill	5	bugfix"
    _ui_resolve_skills "1 5" "$_index" "'"$_profiles"'"
  '
  if [ "$_CAPTURED_EXIT" != 0 ]; then
    _fail "resolve union" "$_CAPTURED_STDERR"
    return 1
  fi
  # sdd (specify+plan) U bugfix = {specify, plan, bugfix}
  for _expected in specify plan bugfix; do
    printf '%s\n' "$_CAPTURED_STDOUT" | grep -qx "$_expected" \
      || { _fail "resolve union $_expected" "stdout=$_CAPTURED_STDOUT"; return 1; }
  done
}

scenario_ui_resolve_numero_invalido_warn_e_continua() {
  _profiles="$TMPDIR_TEST/profiles.txt"
  _make_profiles_fixture "$_profiles"
  capture sh -c '
    . "'"$CSTK_LIB"'/ui.sh"
    _index="skill	1	specify"
    _ui_resolve_skills "1 99" "$_index" "'"$_profiles"'"
  '
  if [ "$_CAPTURED_EXIT" != 0 ]; then
    _fail "resolve invalido continua" "$_CAPTURED_STDERR"
    return 1
  fi
  # Numero 99 nao existe -> warn em stderr; specify ainda volta.
  printf '%s\n' "$_CAPTURED_STDOUT" | grep -qx 'specify' \
    || { _fail "resolve specify" "stdout=$_CAPTURED_STDOUT"; return 1; }
  case "$_CAPTURED_STDERR" in
    *"numero invalido"*) ;;
    *) _fail "resolve warn" "esperado warn em stderr, stderr=$_CAPTURED_STDERR"; return 1 ;;
  esac
}

# ==== Scenario 12: --interactive sem TTY -> exit 2 ====

scenario_ui_require_tty_pipe_aborta() {
  # capture redireciona stdin do shell filho (-> nao-TTY) automaticamente.
  capture sh -c '
    . "'"$CSTK_LIB"'/ui.sh"
    require_tty
  '
  # require_tty retorna 1 quando nao-TTY (caller mapeia exit 2)
  if [ "$_CAPTURED_EXIT" = 0 ]; then
    _fail "require_tty pipe" "esperado nao-zero, obtido 0"
    return 1
  fi
  assert_stderr_contains "requires a TTY" || return 1
}

scenario_ui_require_tty_force_bypass() {
  capture sh -c '
    CSTK_FORCE_INTERACTIVE=1
    . "'"$CSTK_LIB"'/ui.sh"
    require_tty
  '
  if [ "$_CAPTURED_EXIT" != 0 ]; then
    _fail "force bypass" "esperado 0, obtido $_CAPTURED_EXIT; stderr=$_CAPTURED_STDERR"
    return 1
  fi
}

# ==== Scenario 11: TTY + toggles + confirmacao (via CSTK_FORCE_INTERACTIVE) ====

scenario_ui_select_happy_path_via_force() {
  _profiles="$TMPDIR_TEST/profiles.txt"
  _make_profiles_fixture "$_profiles"
  # Profiles list = sort -u(sdd, all) = all, sdd  -> all=#1, sdd=#2
  # Skills mantem ordem do input (sem sort) -> specify=#3, plan=#4, bugfix=#5, extra=#6
  # Selecionar sdd (#2) + bugfix (#5) -> resolved = {specify, plan, bugfix}
  # Input: "2 5" + ENTER (concluir toggles) + "y" (confirmar)
  capture env CSTK_LIB="$CSTK_LIB" CSTK_FORCE_INTERACTIVE=1 sh -c '
    . "$CSTK_LIB/ui.sh"
    skills_list="specify
plan
bugfix
extra"
    ui_select_interactive "'"$_profiles"'" "$skills_list" install
  ' <<EOF
2 5

y
EOF
  if [ "$_CAPTURED_EXIT" != 0 ]; then
    _fail "happy path exit" "esperado 0, obtido $_CAPTURED_EXIT; stderr=$_CAPTURED_STDERR"
    return 1
  fi
  for _s in specify plan bugfix; do
    printf '%s\n' "$_CAPTURED_STDOUT" | grep -qx "$_s" \
      || { _fail "happy path skill $_s" "stdout=$_CAPTURED_STDOUT"; return 1; }
  done
  # extra NAO deve estar no output (nao foi selecionada)
  if printf '%s\n' "$_CAPTURED_STDOUT" | grep -qx 'extra'; then
    _fail "happy path extra" "extra apareceu sem ser selecionada"
    return 1
  fi
}

scenario_ui_select_toggle_remove() {
  _profiles="$TMPDIR_TEST/profiles.txt"
  _make_profiles_fixture "$_profiles"
  # Profile all=#1, sdd=#2; skills mantem ordem do input:
  # specify=#3, plan=#4, bugfix=#5, extra=#6.
  # Toggle "5 6" -> selecao {5,6} (bugfix+extra).
  # Toggle "6" -> remove extra -> selecao {5} (bugfix).
  # ENTER vazio conclui loop, "y" confirma.
  capture env CSTK_LIB="$CSTK_LIB" CSTK_FORCE_INTERACTIVE=1 sh -c '
    . "$CSTK_LIB/ui.sh"
    skills_list="specify
plan
bugfix
extra"
    ui_select_interactive "'"$_profiles"'" "$skills_list" install
  ' <<EOF
5 6
6

y
EOF
  if [ "$_CAPTURED_EXIT" != 0 ]; then
    _fail "toggle remove exit" "$_CAPTURED_EXIT; stderr=$_CAPTURED_STDERR"
    return 1
  fi
  printf '%s\n' "$_CAPTURED_STDOUT" | grep -qx 'bugfix' \
    || { _fail "toggle remove bugfix" "stdout=$_CAPTURED_STDOUT"; return 1; }
  if printf '%s\n' "$_CAPTURED_STDOUT" | grep -qx 'extra'; then
    _fail "toggle remove extra" "extra deveria ter saido do set"
    return 1
  fi
}

scenario_ui_select_confirm_negativo_aborta() {
  _profiles="$TMPDIR_TEST/profiles.txt"
  _make_profiles_fixture "$_profiles"
  capture env CSTK_LIB="$CSTK_LIB" CSTK_FORCE_INTERACTIVE=1 sh -c '
    . "$CSTK_LIB/ui.sh"
    skills_list="specify
plan"
    ui_select_interactive "'"$_profiles"'" "$skills_list" install
  ' <<EOF
1

n
EOF
  if [ "$_CAPTURED_EXIT" = 0 ]; then
    _fail "confirm n" "esperado nao-zero, obtido 0"
    return 1
  fi
  assert_stderr_contains "cancelado pelo usuario" || return 1
}

scenario_ui_select_quit_no_loop_aborta() {
  _profiles="$TMPDIR_TEST/profiles.txt"
  _make_profiles_fixture "$_profiles"
  capture env CSTK_LIB="$CSTK_LIB" CSTK_FORCE_INTERACTIVE=1 sh -c '
    . "$CSTK_LIB/ui.sh"
    skills_list="specify
plan"
    ui_select_interactive "'"$_profiles"'" "$skills_list" install
  ' <<EOF
q
EOF
  if [ "$_CAPTURED_EXIT" = 0 ]; then
    _fail "q aborta" "esperado nao-zero, obtido 0"
    return 1
  fi
}

scenario_ui_select_modo_update_sem_profiles() {
  # Modo update: profiles_path vazio. Lista APENAS skills do manifest.
  capture env CSTK_LIB="$CSTK_LIB" CSTK_FORCE_INTERACTIVE=1 sh -c '
    . "$CSTK_LIB/ui.sh"
    skills_list="specify
plan
bugfix"
    ui_select_interactive "" "$skills_list" update
  ' <<EOF
1

y
EOF
  if [ "$_CAPTURED_EXIT" != 0 ]; then
    _fail "update mode exit" "$_CAPTURED_EXIT; stderr=$_CAPTURED_STDERR"
    return 1
  fi
  # skills sao listadas em ordem de skills_list -> #1 = specify (sort -u no
  # skill list seria... wait, _ui_build_index nao faz sort, mantem ordem da
  # input). Skills_list tem specify primeiro -> #1 = specify.
  printf '%s\n' "$_CAPTURED_STDOUT" | grep -qx 'specify' \
    || { _fail "update mode specify" "stdout=$_CAPTURED_STDOUT"; return 1; }
  # Menu nao deve ter linha "Profiles:" porque profiles_path vazio
  case "$_CAPTURED_STDERR" in
    *"Profiles:"*)
      _fail "update mode sem profiles" "stderr contem 'Profiles:' indevido"
      return 1
      ;;
  esac
}

# ==== Integracao com install --interactive ====

scenario_ui_install_interactive_ttyless_exit_2() {
  # Sem TTY, com fixture release valida -> install --interactive deve falhar
  # cedo com exit 2 e msg de TTY. Nada e baixado.
  _h="$TMPDIR_TEST/home"
  _r="$TMPDIR_TEST/release"
  _make_release_fixture "$_r" || { _error "fixture" "tarball build falhou"; return 2; }
  capture env HOME="$_h" CSTK_LIB="$CSTK_LIB" sh -c '
    . "$CSTK_LIB/install.sh"
    install_main --from "file://'"$_r"'/cstk-test-v0.1.0.tar.gz" --interactive
  '
  if [ "$_CAPTURED_EXIT" != 2 ]; then
    _fail "install -i ttyless exit" "esperado 2, obtido $_CAPTURED_EXIT; stderr=$_CAPTURED_STDERR"
    return 1
  fi
  assert_stderr_contains "requires a TTY" || return 1
  # Nada criado em $_h
  if [ -d "$_h/.claude" ]; then
    _fail "install -i ttyless side-effect" "criou .claude indevidamente"
    return 1
  fi
}

scenario_ui_install_interactive_force_seleciona_e_instala() {
  # Com CSTK_FORCE_INTERACTIVE=1, install --interactive le stdin e instala.
  _h="$TMPDIR_TEST/home"
  _r="$TMPDIR_TEST/release"
  _make_release_fixture "$_r" || { _error "fixture" "tarball build falhou"; return 2; }
  # Profiles disponiveis: all, sdd. Skills: bugfix, extra, plan, specify (sort -u).
  # Index: profile all=#1, sdd=#2, skill bugfix=#3, extra=#4, plan=#5, specify=#6.
  # Selecionar sdd (#2) -> resolve para specify+plan.
  capture env HOME="$_h" CSTK_LIB="$CSTK_LIB" CSTK_FORCE_INTERACTIVE=1 sh -c '
    . "$CSTK_LIB/install.sh"
    install_main --from "file://'"$_r"'/cstk-test-v0.1.0.tar.gz" --interactive
  ' <<EOF
2

y
EOF
  if [ "$_CAPTURED_EXIT" != 0 ]; then
    _fail "install -i force exit" "$_CAPTURED_EXIT; stderr=$_CAPTURED_STDERR"
    return 1
  fi
  [ -f "$_h/.claude/skills/specify/SKILL.md" ] \
    || { _fail "install -i specify" "specify nao instalada"; return 1; }
  [ -f "$_h/.claude/skills/plan/SKILL.md" ] \
    || { _fail "install -i plan" "plan nao instalada"; return 1; }
  # bugfix NAO selecionada nesta selecao
  [ -e "$_h/.claude/skills/bugfix" ] \
    && { _fail "install -i bugfix" "bugfix instalada por engano"; return 1; }
  assert_stderr_contains "installed: 2" || return 1
}

# ==== Integracao com update --interactive ====

scenario_ui_update_interactive_ttyless_exit_2() {
  _h="$TMPDIR_TEST/home"
  _r="$TMPDIR_TEST/release"
  _make_release_fixture "$_r" || { _error "fixture" "tarball build falhou"; return 2; }
  # Setup: instala primeiro (modo nao-interativo) para ter manifest
  capture env HOME="$_h" CSTK_LIB="$CSTK_LIB" sh -c '
    . "$CSTK_LIB/install.sh"
    install_main --from "file://'"$_r"'/cstk-test-v0.1.0.tar.gz" --profile sdd
  '
  if [ "$_CAPTURED_EXIT" != 0 ]; then
    _error "setup install" "$_CAPTURED_STDERR"
    return 2
  fi
  # Agora update --interactive sem TTY -> exit 2.
  capture env HOME="$_h" CSTK_LIB="$CSTK_LIB" sh -c '
    . "$CSTK_LIB/update.sh"
    update_main --from "file://'"$_r"'/cstk-test-v0.1.0.tar.gz" --interactive
  '
  if [ "$_CAPTURED_EXIT" != 2 ]; then
    _fail "update -i ttyless exit" "esperado 2, obtido $_CAPTURED_EXIT; stderr=$_CAPTURED_STDERR"
    return 1
  fi
  assert_stderr_contains "requires a TTY" || return 1
}

scenario_ui_update_interactive_lista_apenas_manifest() {
  _h="$TMPDIR_TEST/home"
  _r="$TMPDIR_TEST/release"
  _make_release_fixture "$_r" || { _error "fixture" "tarball build falhou"; return 2; }
  # Instala perfil sdd (specify+plan)
  capture env HOME="$_h" CSTK_LIB="$CSTK_LIB" sh -c '
    . "$CSTK_LIB/install.sh"
    install_main --from "file://'"$_r"'/cstk-test-v0.1.0.tar.gz" --profile sdd
  '
  if [ "$_CAPTURED_EXIT" != 0 ]; then
    _error "setup install" "$_CAPTURED_STDERR"
    return 2
  fi
  # Update --interactive: deve mostrar APENAS plan e specify (do manifest),
  # NAO bugfix nem extra. Selecionar #1 e confirmar.
  capture env HOME="$_h" CSTK_LIB="$CSTK_LIB" CSTK_FORCE_INTERACTIVE=1 sh -c '
    . "$CSTK_LIB/update.sh"
    update_main --from "file://'"$_r"'/cstk-test-v0.1.0.tar.gz" --interactive
  ' <<EOF
1

y
EOF
  if [ "$_CAPTURED_EXIT" != 0 ]; then
    _fail "update -i exit" "$_CAPTURED_EXIT; stderr=$_CAPTURED_STDERR"
    return 1
  fi
  # Menu de update NAO deve ter "Profiles:" (so skills do manifest)
  case "$_CAPTURED_STDERR" in
    *"Profiles:"*) _fail "update -i sem profiles" "menu mostrou Profiles:"; return 1 ;;
  esac
  # Menu deve listar apenas skills do manifest (plan e specify; ordem do
  # manifest segue ordem de instalacao)
  case "$_CAPTURED_STDERR" in
    *"bugfix"*) _fail "update -i bugfix vazou" "bugfix nao esta no manifest"; return 1 ;;
  esac
  case "$_CAPTURED_STDERR" in
    *"extra"*) _fail "update -i extra vazou" "extra nao esta no manifest"; return 1 ;;
  esac
}

run_all_scenarios
