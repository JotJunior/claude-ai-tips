#!/bin/sh
# test_update-extra-kinds.sh — cobre update de catalog/commands/ e
# catalog/agents/, espelhando o fluxo do install mas com semantica de update
# (idempotencia, edit local, --force, --keep, third-party).
#
# Escopo:
#   - update aplica novos hashes em commands/agents quando release muda
#   - update e idempotente (release == manifest -> zero writes)
#   - update detecta edit local em commands/agents e respeita --force/--keep
#   - update preserva .md third-party (sem manifest entry) por default
#   - update --force sobrescreve third-party (caminho de recuperacao quando
#     manifest dedicado por kind ficou ausente em upgrades historicos)
#   - dry-run nao escreve
#   - tarball SEM commands/agents nao gera erro

TESTS_ROOT="${TESTS_ROOT:-$(cd "$(dirname "$0")/.." && pwd)}"
REPO_ROOT="${REPO_ROOT:-$(cd "$TESTS_ROOT/.." && pwd)}"

. "$TESTS_ROOT/lib/harness.sh"

CSTK_LIB="$REPO_ROOT/cli/lib"
export CSTK_LIB

# _make_release_extras_v1: tarball com 1 skill + 2 commands + 2 agents (v1).
_make_release_extras_v1() {
  _mr_dir=$1
  _mr_root="$_mr_dir/cstk-extras-v1"
  mkdir -p "$_mr_root/catalog/skills/foo" \
           "$_mr_root/catalog/commands" \
           "$_mr_root/catalog/agents" || return 1
  printf 'extras-v1\n' > "$_mr_root/catalog/VERSION"
  printf 'sdd:foo\n' > "$_mr_root/catalog/profiles.txt"
  printf '# foo skill v1\n' > "$_mr_root/catalog/skills/foo/SKILL.md"
  printf '# cmd-a v1\n' > "$_mr_root/catalog/commands/cmd-a.md"
  printf '# cmd-b v1\n' > "$_mr_root/catalog/commands/cmd-b.md"
  printf '# agent-a v1\n' > "$_mr_root/catalog/agents/agent-a.md"
  printf '# agent-b v1\n' > "$_mr_root/catalog/agents/agent-b.md"
  (cd "$_mr_dir" && tar -czf cstk-extras-v1.tar.gz cstk-extras-v1) || return 1
  if command -v sha256sum >/dev/null 2>&1; then
    (cd "$_mr_dir" && sha256sum cstk-extras-v1.tar.gz > cstk-extras-v1.tar.gz.sha256) || return 1
  else
    (cd "$_mr_dir" && shasum -a 256 cstk-extras-v1.tar.gz > cstk-extras-v1.tar.gz.sha256) || return 1
  fi
  return 0
}

# _make_release_extras_v2: mesmos nomes, conteudo diferente. Forca update.
_make_release_extras_v2() {
  _mr_dir=$1
  _mr_root="$_mr_dir/cstk-extras-v2"
  mkdir -p "$_mr_root/catalog/skills/foo" \
           "$_mr_root/catalog/commands" \
           "$_mr_root/catalog/agents" || return 1
  printf 'extras-v2\n' > "$_mr_root/catalog/VERSION"
  printf 'sdd:foo\n' > "$_mr_root/catalog/profiles.txt"
  printf '# foo skill v2 (updated)\n' > "$_mr_root/catalog/skills/foo/SKILL.md"
  printf '# cmd-a v2 (updated)\n' > "$_mr_root/catalog/commands/cmd-a.md"
  printf '# cmd-b v2 (updated)\n' > "$_mr_root/catalog/commands/cmd-b.md"
  printf '# agent-a v2 (updated)\n' > "$_mr_root/catalog/agents/agent-a.md"
  printf '# agent-b v2 (updated)\n' > "$_mr_root/catalog/agents/agent-b.md"
  (cd "$_mr_dir" && tar -czf cstk-extras-v2.tar.gz cstk-extras-v2) || return 1
  if command -v sha256sum >/dev/null 2>&1; then
    (cd "$_mr_dir" && sha256sum cstk-extras-v2.tar.gz > cstk-extras-v2.tar.gz.sha256) || return 1
  else
    (cd "$_mr_dir" && shasum -a 256 cstk-extras-v2.tar.gz > cstk-extras-v2.tar.gz.sha256) || return 1
  fi
  return 0
}

# _make_release_skills_only: tarball SEM commands/agents.
_make_release_skills_only() {
  _mr_dir=$1
  _mr_root="$_mr_dir/cstk-skills-only-v1"
  mkdir -p "$_mr_root/catalog/skills/foo" || return 1
  printf 'skills-only-v1\n' > "$_mr_root/catalog/VERSION"
  printf 'sdd:foo\n' > "$_mr_root/catalog/profiles.txt"
  printf '# foo\n' > "$_mr_root/catalog/skills/foo/SKILL.md"
  (cd "$_mr_dir" && tar -czf cstk-skills-only-v1.tar.gz cstk-skills-only-v1) || return 1
  if command -v sha256sum >/dev/null 2>&1; then
    (cd "$_mr_dir" && sha256sum cstk-skills-only-v1.tar.gz > cstk-skills-only-v1.tar.gz.sha256) || return 1
  else
    (cd "$_mr_dir" && shasum -a 256 cstk-skills-only-v1.tar.gz > cstk-skills-only-v1.tar.gz.sha256) || return 1
  fi
  return 0
}

_run_install() {
  _ri_home=$1; shift
  mkdir -p "$_ri_home"
  capture env HOME="$_ri_home" CSTK_LIB="$CSTK_LIB" sh -c '
    . "$CSTK_LIB/install.sh"
    install_main "$@"
  ' install_test "$@"
}

_run_update() {
  _ru_home=$1; shift
  mkdir -p "$_ru_home"
  capture env HOME="$_ru_home" CSTK_LIB="$CSTK_LIB" sh -c '
    . "$CSTK_LIB/update.sh"
    update_main "$@"
  ' update_test "$@"
}

# ==== Idempotencia: release == manifest -> uptodate, zero writes ====

scenario_update_extra_kinds_idempotente() {
  _h="$TMPDIR_TEST/home"
  _r="$TMPDIR_TEST/release"
  _make_release_extras_v1 "$_r" || { _error "fixture" ""; return 2; }
  _run_install "$_h" --from "file://$_r/cstk-extras-v1.tar.gz"
  [ "$_CAPTURED_EXIT" = 0 ] || { _fail "install" "$_CAPTURED_STDERR"; return 1; }

  # Snapshot mtimes pos-install
  _mtime_cmd_pre=$(stat -f '%m' "$_h/.claude/commands/cmd-a.md" 2>/dev/null || stat -c '%Y' "$_h/.claude/commands/cmd-a.md")
  _mtime_agent_pre=$(stat -f '%m' "$_h/.claude/agents/agent-a.md" 2>/dev/null || stat -c '%Y' "$_h/.claude/agents/agent-a.md")

  sleep 1

  _run_update "$_h" --from "file://$_r/cstk-extras-v1.tar.gz"
  [ "$_CAPTURED_EXIT" = 0 ] || { _fail "update exit" "esperado 0, obtido $_CAPTURED_EXIT; stderr=$_CAPTURED_STDERR"; return 1; }

  # Counters: tudo uptodate
  assert_stderr_contains "commands: installed=0 updated=0 uptodate=2" || return 1
  assert_stderr_contains "agents: installed=0 updated=0 uptodate=2" || return 1

  # mtimes preservados (idempotencia real, sem touch)
  _mtime_cmd_pos=$(stat -f '%m' "$_h/.claude/commands/cmd-a.md" 2>/dev/null || stat -c '%Y' "$_h/.claude/commands/cmd-a.md")
  _mtime_agent_pos=$(stat -f '%m' "$_h/.claude/agents/agent-a.md" 2>/dev/null || stat -c '%Y' "$_h/.claude/agents/agent-a.md")
  if [ "$_mtime_cmd_pre" != "$_mtime_cmd_pos" ]; then
    _fail "cmd-a mtime mudou" "pre=$_mtime_cmd_pre pos=$_mtime_cmd_pos (esperado idempotente)"
    return 1
  fi
  if [ "$_mtime_agent_pre" != "$_mtime_agent_pos" ]; then
    _fail "agent-a mtime mudou" "pre=$_mtime_agent_pre pos=$_mtime_agent_pos"
    return 1
  fi
}

# ==== Update real: release muda -> atualiza commands/agents ====

scenario_update_extra_kinds_atualiza_quando_release_muda() {
  _h="$TMPDIR_TEST/home"
  _r1="$TMPDIR_TEST/release-v1"
  _r2="$TMPDIR_TEST/release-v2"
  _make_release_extras_v1 "$_r1" || { _error "fixture v1" ""; return 2; }
  _make_release_extras_v2 "$_r2" || { _error "fixture v2" ""; return 2; }
  _run_install "$_h" --from "file://$_r1/cstk-extras-v1.tar.gz"
  [ "$_CAPTURED_EXIT" = 0 ] || { _fail "install" "$_CAPTURED_STDERR"; return 1; }

  _run_update "$_h" --from "file://$_r2/cstk-extras-v2.tar.gz"
  [ "$_CAPTURED_EXIT" = 0 ] || { _fail "update exit" "$_CAPTURED_EXIT; stderr=$_CAPTURED_STDERR"; return 1; }

  # Counter: tudo updated
  assert_stderr_contains "commands: installed=0 updated=2 uptodate=0" || return 1
  assert_stderr_contains "agents: installed=0 updated=2 uptodate=0" || return 1

  # Conteudo refletindo v2
  grep -q 'v2 (updated)' "$_h/.claude/commands/cmd-a.md" \
    || { _fail "cmd-a sem conteudo v2" "$(cat "$_h/.claude/commands/cmd-a.md")"; return 1; }
  grep -q 'v2 (updated)' "$_h/.claude/agents/agent-a.md" \
    || { _fail "agent-a sem conteudo v2" "$(cat "$_h/.claude/agents/agent-a.md")"; return 1; }

  # Manifest atualizado
  grep -q '^cmd-a	extras-v2	' "$_h/.claude/commands/.cstk-manifest" \
    || { _fail "manifest commands nao tem extras-v2" "$(cat "$_h/.claude/commands/.cstk-manifest")"; return 1; }
}

# ==== Third-party (sem manifest entry) -> preserved sem --force ====

scenario_update_extra_kinds_preserva_third_party_sem_force() {
  _h="$TMPDIR_TEST/home"
  _r="$TMPDIR_TEST/release"
  _make_release_extras_v1 "$_r" || { _error "fixture" ""; return 2; }

  # Pre-cria cmd-a SEM passar pelo cstk (simula situacao do user real: arquivo
  # presente em disco mas manifest dedicado por kind ausente)
  mkdir -p "$_h/.claude/commands" "$_h/.claude/skills"
  printf 'CONTEUDO LEGADO\n' > "$_h/.claude/commands/cmd-a.md"

  # Manifest principal vazio: simula instalacao parcial sem extras
  mkdir -p "$_h/.claude/skills"
  printf '# cstk manifest v1\n' > "$_h/.claude/skills/.cstk-manifest"

  _run_update "$_h" --from "file://$_r/cstk-extras-v1.tar.gz"
  [ "$_CAPTURED_EXIT" = 0 ] || { _fail "update exit" "$_CAPTURED_EXIT; stderr=$_CAPTURED_STDERR"; return 1; }

  # Conteudo legado preservado
  grep -q 'CONTEUDO LEGADO' "$_h/.claude/commands/cmd-a.md" \
    || { _fail "third-party sobrescrita" ""; return 1; }
  # Counter: cmd-a preserved, cmd-b installed
  assert_stderr_contains "preserved=1" || return 1
  assert_stderr_contains "use --force" || return 1
}

# ==== --force sobrescreve third-party (caminho de recuperacao) ====

scenario_update_extra_kinds_force_sobrescreve_third_party() {
  _h="$TMPDIR_TEST/home"
  _r="$TMPDIR_TEST/release"
  _make_release_extras_v1 "$_r" || { _error "fixture" ""; return 2; }

  mkdir -p "$_h/.claude/commands" "$_h/.claude/skills"
  printf 'CONTEUDO LEGADO\n' > "$_h/.claude/commands/cmd-a.md"
  printf '# cstk manifest v1\n' > "$_h/.claude/skills/.cstk-manifest"

  _run_update "$_h" --from "file://$_r/cstk-extras-v1.tar.gz" --force
  [ "$_CAPTURED_EXIT" = 0 ] || { _fail "update --force exit" "$_CAPTURED_EXIT; stderr=$_CAPTURED_STDERR"; return 1; }

  # cmd-a substituida pela release
  grep -q 'cmd-a v1' "$_h/.claude/commands/cmd-a.md" \
    || { _fail "force nao sobrescreveu third-party" "$(cat "$_h/.claude/commands/cmd-a.md")"; return 1; }
  # Manifest dedicado por kind agora existe e tem cmd-a
  grep -q '^cmd-a	extras-v1	' "$_h/.claude/commands/.cstk-manifest" \
    || { _fail "manifest commands sem cmd-a apos --force" "$(cat "$_h/.claude/commands/.cstk-manifest")"; return 1; }
}

# ==== Edit local sem --force -> skipped_edits + exit 4 ====

scenario_update_extra_kinds_edit_local_sem_force_exit4() {
  _h="$TMPDIR_TEST/home"
  _r="$TMPDIR_TEST/release"
  _make_release_extras_v1 "$_r" || { _error "fixture" ""; return 2; }
  _run_install "$_h" --from "file://$_r/cstk-extras-v1.tar.gz"
  [ "$_CAPTURED_EXIT" = 0 ] || { _fail "install" "$_CAPTURED_STDERR"; return 1; }

  # Edit local em cmd-a (apos install — entry esta no manifest)
  printf '\nEDIT LOCAL\n' >> "$_h/.claude/commands/cmd-a.md"

  # Usa v2 para forcar tentativa de update
  _r2="$TMPDIR_TEST/release-v2"
  _make_release_extras_v2 "$_r2" || { _error "fixture v2" ""; return 2; }
  _run_update "$_h" --from "file://$_r2/cstk-extras-v2.tar.gz"
  if [ "$_CAPTURED_EXIT" != 4 ]; then
    _fail "update edit local sem --force" "esperado exit 4, obtido $_CAPTURED_EXIT; stderr=$_CAPTURED_STDERR"
    return 1
  fi
  # cmd-a preserva o edit local
  grep -q 'EDIT LOCAL' "$_h/.claude/commands/cmd-a.md" \
    || { _fail "edit local sumiu" ""; return 1; }
  assert_stderr_contains "edicao local em commands/cmd-a" || return 1
}

# ==== Edit local com --force -> overwrite ====

scenario_update_extra_kinds_edit_local_com_force() {
  _h="$TMPDIR_TEST/home"
  _r="$TMPDIR_TEST/release"
  _make_release_extras_v1 "$_r" || { _error "fixture" ""; return 2; }
  _run_install "$_h" --from "file://$_r/cstk-extras-v1.tar.gz"
  [ "$_CAPTURED_EXIT" = 0 ] || { _fail "install" "$_CAPTURED_STDERR"; return 1; }
  printf '\nEDIT LOCAL\n' >> "$_h/.claude/commands/cmd-a.md"

  _r2="$TMPDIR_TEST/release-v2"
  _make_release_extras_v2 "$_r2" || { _error "fixture v2" ""; return 2; }
  _run_update "$_h" --from "file://$_r2/cstk-extras-v2.tar.gz" --force
  [ "$_CAPTURED_EXIT" = 0 ] || { _fail "update --force exit" "$_CAPTURED_EXIT; stderr=$_CAPTURED_STDERR"; return 1; }
  # Edit local foi sobrescrito
  grep -q 'EDIT LOCAL' "$_h/.claude/commands/cmd-a.md" \
    && { _fail "force nao sobrescreveu edit local" ""; return 1; }
  grep -q 'v2 (updated)' "$_h/.claude/commands/cmd-a.md" \
    || { _fail "conteudo v2 ausente apos force" ""; return 1; }
}

# ==== Edit local com --keep -> mantem sem erro ====

scenario_update_extra_kinds_edit_local_com_keep() {
  _h="$TMPDIR_TEST/home"
  _r="$TMPDIR_TEST/release"
  _make_release_extras_v1 "$_r" || { _error "fixture" ""; return 2; }
  _run_install "$_h" --from "file://$_r/cstk-extras-v1.tar.gz"
  [ "$_CAPTURED_EXIT" = 0 ] || { _fail "install" "$_CAPTURED_STDERR"; return 1; }
  printf '\nEDIT LOCAL\n' >> "$_h/.claude/commands/cmd-a.md"

  _r2="$TMPDIR_TEST/release-v2"
  _make_release_extras_v2 "$_r2" || { _error "fixture v2" ""; return 2; }
  _run_update "$_h" --from "file://$_r2/cstk-extras-v2.tar.gz" --keep
  if [ "$_CAPTURED_EXIT" != 0 ]; then
    _fail "update --keep exit" "esperado 0, obtido $_CAPTURED_EXIT; stderr=$_CAPTURED_STDERR"
    return 1
  fi
  # Edit local preservado
  grep -q 'EDIT LOCAL' "$_h/.claude/commands/cmd-a.md" \
    || { _fail "keep nao preservou edit" ""; return 1; }
  assert_stderr_contains "kept=1" || return 1
}

# ==== Dry-run nao escreve ====

scenario_update_extra_kinds_dry_run_zero_writes() {
  _h="$TMPDIR_TEST/home"
  _r="$TMPDIR_TEST/release"
  _make_release_extras_v1 "$_r" || { _error "fixture v1" ""; return 2; }
  _run_install "$_h" --from "file://$_r/cstk-extras-v1.tar.gz"
  [ "$_CAPTURED_EXIT" = 0 ] || { _fail "install" "$_CAPTURED_STDERR"; return 1; }

  _r2="$TMPDIR_TEST/release-v2"
  _make_release_extras_v2 "$_r2" || { _error "fixture v2" ""; return 2; }
  _mtime_pre=$(stat -f '%m' "$_h/.claude/commands/cmd-a.md" 2>/dev/null || stat -c '%Y' "$_h/.claude/commands/cmd-a.md")
  sleep 1

  _run_update "$_h" --from "file://$_r2/cstk-extras-v2.tar.gz" --dry-run
  [ "$_CAPTURED_EXIT" = 0 ] || { _fail "dry-run exit" "$_CAPTURED_EXIT; stderr=$_CAPTURED_STDERR"; return 1; }

  # Conteudo permanece v1
  grep -q 'v1' "$_h/.claude/commands/cmd-a.md" \
    || { _fail "dry-run modificou conteudo" "$(cat "$_h/.claude/commands/cmd-a.md")"; return 1; }
  # mtime nao mudou
  _mtime_pos=$(stat -f '%m' "$_h/.claude/commands/cmd-a.md" 2>/dev/null || stat -c '%Y' "$_h/.claude/commands/cmd-a.md")
  if [ "$_mtime_pre" != "$_mtime_pos" ]; then
    _fail "dry-run mudou mtime" "pre=$_mtime_pre pos=$_mtime_pos"
    return 1
  fi
  # Counter previsto
  assert_stderr_contains "commands: installed=0 updated=2" || return 1
}

# ==== Tarball sem commands/agents nao gera erro ====

scenario_update_extra_kinds_tarball_skills_only_compativel() {
  _h="$TMPDIR_TEST/home"
  _r="$TMPDIR_TEST/release"
  _make_release_skills_only "$_r" || { _error "fixture" ""; return 2; }
  _run_install "$_h" --from "file://$_r/cstk-skills-only-v1.tar.gz"
  [ "$_CAPTURED_EXIT" = 0 ] || { _fail "install" "$_CAPTURED_STDERR"; return 1; }

  _run_update "$_h" --from "file://$_r/cstk-skills-only-v1.tar.gz"
  if [ "$_CAPTURED_EXIT" != 0 ]; then
    _fail "update skills-only exit" "$_CAPTURED_EXIT; stderr=$_CAPTURED_STDERR"
    return 1
  fi
}

run_all_scenarios
