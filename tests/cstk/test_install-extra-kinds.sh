#!/bin/sh
# test_install-extra-kinds.sh — cobre distribuicao de catalog/commands/ e
# catalog/agents/ pelo install + visibilidade no doctor.
#
# Escopo (agente-00c FASE 1.2):
#   - install copia .md soltos de catalog/commands/ -> ~/.claude/commands/
#   - install copia .md soltos de catalog/agents/   -> ~/.claude/agents/
#   - manifest dedicado por kind (~/.claude/<kind>/.cstk-manifest)
#   - re-install vira "updated" para .md inalterados
#   - .md pre-existente sem entry no manifest e PRESERVADO (third-party)
#   - dry-run nao escreve
#   - doctor varre os 3 kinds e reporta drift especifico
#   - tarball SEM commands/agents nao gera erro (campos sao opcionais)

TESTS_ROOT="${TESTS_ROOT:-$(cd "$(dirname "$0")/.." && pwd)}"
REPO_ROOT="${REPO_ROOT:-$(cd "$TESTS_ROOT/.." && pwd)}"

. "$TESTS_ROOT/lib/harness.sh"

CSTK_LIB="$REPO_ROOT/cli/lib"
export CSTK_LIB

# _make_release_with_extras: tarball com 1 skill (foo) + 2 commands + 2 agents.
_make_release_with_extras() {
  _mr_dir=$1
  _mr_root="$_mr_dir/cstk-extras-v1"
  mkdir -p "$_mr_root/catalog/skills/foo" \
           "$_mr_root/catalog/commands" \
           "$_mr_root/catalog/agents" || return 1
  printf 'extras-v1\n' > "$_mr_root/catalog/VERSION"
  printf 'sdd:foo\n' > "$_mr_root/catalog/profiles.txt"
  printf '# foo skill\n' > "$_mr_root/catalog/skills/foo/SKILL.md"
  printf '# /agente-00c command\n' > "$_mr_root/catalog/commands/agente-00c.md"
  printf '# /agente-00c-abort command\n' > "$_mr_root/catalog/commands/agente-00c-abort.md"
  printf '# orchestrator agent\n' > "$_mr_root/catalog/agents/agente-00c-orchestrator.md"
  printf '# clarify-asker agent\n' > "$_mr_root/catalog/agents/agente-00c-clarify-asker.md"
  (cd "$_mr_dir" && tar -czf cstk-extras-v1.tar.gz cstk-extras-v1) || return 1
  if command -v sha256sum >/dev/null 2>&1; then
    (cd "$_mr_dir" && sha256sum cstk-extras-v1.tar.gz > cstk-extras-v1.tar.gz.sha256) || return 1
  else
    (cd "$_mr_dir" && shasum -a 256 cstk-extras-v1.tar.gz > cstk-extras-v1.tar.gz.sha256) || return 1
  fi
  return 0
}

# _make_release_skills_only: tarball SEM commands/agents (caso historico).
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

_run_doctor() {
  _h=$1; shift
  capture env HOME="$_h" CSTK_LIB="$CSTK_LIB" sh -c '
    . "$CSTK_LIB/doctor.sh"; doctor_main "$@"
  ' doctor_test "$@"
}

# ==== Install distribui commands + agents ====

scenario_install_distribui_commands_e_agents() {
  _h="$TMPDIR_TEST/home"
  _r="$TMPDIR_TEST/release"
  _make_release_with_extras "$_r" || { _error "fixture" ""; return 2; }
  _run_install "$_h" --from "file://$_r/cstk-extras-v1.tar.gz"
  if [ "$_CAPTURED_EXIT" != 0 ]; then
    _fail "install exit" "esperado 0, obtido $_CAPTURED_EXIT; stderr=$_CAPTURED_STDERR"
    return 1
  fi
  # Skills (fluxo legado)
  [ -f "$_h/.claude/skills/foo/SKILL.md" ] || { _fail "skill foo ausente" ""; return 1; }
  # Commands
  [ -f "$_h/.claude/commands/agente-00c.md" ] || { _fail "command agente-00c ausente" ""; return 1; }
  [ -f "$_h/.claude/commands/agente-00c-abort.md" ] || { _fail "command abort ausente" ""; return 1; }
  # Agents
  [ -f "$_h/.claude/agents/agente-00c-orchestrator.md" ] || { _fail "agent orchestrator ausente" ""; return 1; }
  [ -f "$_h/.claude/agents/agente-00c-clarify-asker.md" ] || { _fail "agent clarify-asker ausente" ""; return 1; }
  # Manifests dedicados por kind
  [ -f "$_h/.claude/commands/.cstk-manifest" ] || { _fail "manifest commands ausente" ""; return 1; }
  [ -f "$_h/.claude/agents/.cstk-manifest" ] || { _fail "manifest agents ausente" ""; return 1; }
  grep -q '^agente-00c	extras-v1	' "$_h/.claude/commands/.cstk-manifest" \
    || { _fail "commands manifest sem agente-00c" ""; return 1; }
  grep -q '^agente-00c-orchestrator	extras-v1	' "$_h/.claude/agents/.cstk-manifest" \
    || { _fail "agents manifest sem orchestrator" ""; return 1; }
  # Summary reporta os contadores
  assert_stderr_contains "commands: installed=2" || return 1
  assert_stderr_contains "agents: installed=2" || return 1
}

# ==== Re-install vira update (sem reinstalacao) ====

scenario_install_extra_kinds_reinstall_e_update() {
  _h="$TMPDIR_TEST/home"
  _r="$TMPDIR_TEST/release"
  _make_release_with_extras "$_r" || { _error "fixture" ""; return 2; }
  _run_install "$_h" --from "file://$_r/cstk-extras-v1.tar.gz"
  [ "$_CAPTURED_EXIT" = 0 ] || { _fail "primeira install" "$_CAPTURED_STDERR"; return 1; }
  _run_install "$_h" --from "file://$_r/cstk-extras-v1.tar.gz"
  if [ "$_CAPTURED_EXIT" != 0 ]; then
    _fail "re-install exit" "$_CAPTURED_EXIT"
    return 1
  fi
  assert_stderr_contains "commands: installed=0 updated=2" || return 1
  assert_stderr_contains "agents: installed=0 updated=2" || return 1
}

# ==== Preservacao de .md third-party ====

scenario_install_extra_kinds_preserva_third_party() {
  _h="$TMPDIR_TEST/home"
  _r="$TMPDIR_TEST/release"
  _make_release_with_extras "$_r" || { _error "fixture" ""; return 2; }
  # Pre-cria command com mesmo nome SEM passar pelo cstk (third-party)
  mkdir -p "$_h/.claude/commands"
  printf 'CONTEUDO TERCEIRO\n' > "$_h/.claude/commands/agente-00c.md"

  _run_install "$_h" --from "file://$_r/cstk-extras-v1.tar.gz"
  [ "$_CAPTURED_EXIT" = 0 ] || { _fail "install exit" "$_CAPTURED_STDERR"; return 1; }
  # agente-00c third-party permanece intacto
  grep -q 'CONTEUDO TERCEIRO' "$_h/.claude/commands/agente-00c.md" \
    || { _fail "third-party sobrescrita" ""; return 1; }
  # agente-00c-abort instalado normalmente
  [ -f "$_h/.claude/commands/agente-00c-abort.md" ] || { _fail "abort ausente" ""; return 1; }
  # agente-00c NAO entra no manifest (preservada)
  grep -q '^agente-00c	' "$_h/.claude/commands/.cstk-manifest" \
    && { _fail "third-party entrou no manifest" ""; return 1; }
  assert_stderr_contains "commands: installed=1 updated=0 preserved=1" || return 1
}

# ==== Dry-run nao escreve ====

scenario_install_extra_kinds_dry_run_zero_writes() {
  _h="$TMPDIR_TEST/home-dry"
  _r="$TMPDIR_TEST/release"
  _make_release_with_extras "$_r" || { _error "fixture" ""; return 2; }
  _run_install "$_h" --from "file://$_r/cstk-extras-v1.tar.gz" --dry-run
  [ "$_CAPTURED_EXIT" = 0 ] || { _fail "dry-run exit" "$_CAPTURED_STDERR"; return 1; }
  if [ -d "$_h/.claude/commands" ]; then
    _fail "dry-run criou commands" "$_h/.claude/commands existe"
    return 1
  fi
  if [ -d "$_h/.claude/agents" ]; then
    _fail "dry-run criou agents" "$_h/.claude/agents existe"
    return 1
  fi
  # Reporta contagem prevista
  assert_stderr_contains "commands: installed=2" || return 1
  assert_stderr_contains "agents: installed=2" || return 1
}

# ==== Tarball historico (sem commands/agents) nao gera erro ====

scenario_install_skills_only_release_compativel() {
  _h="$TMPDIR_TEST/home"
  _r="$TMPDIR_TEST/release"
  _make_release_skills_only "$_r" || { _error "fixture" ""; return 2; }
  _run_install "$_h" --from "file://$_r/cstk-skills-only-v1.tar.gz"
  if [ "$_CAPTURED_EXIT" != 0 ]; then
    _fail "skills-only install exit" "$_CAPTURED_EXIT; stderr=$_CAPTURED_STDERR"
    return 1
  fi
  [ -f "$_h/.claude/skills/foo/SKILL.md" ] || { _fail "foo ausente" ""; return 1; }
  # Sem commands/agents linhas no summary (defensivo: nada criado)
  [ -d "$_h/.claude/commands" ] && { _fail "commands criada por engano" ""; return 1; }
  [ -d "$_h/.claude/agents" ] && { _fail "agents criada por engano" ""; return 1; }
  return 0
}

# ==== Doctor varre commands + agents ====

scenario_doctor_detecta_drift_em_commands_e_agents() {
  _h="$TMPDIR_TEST/home"
  _r="$TMPDIR_TEST/release"
  _make_release_with_extras "$_r" || { _error "fixture" ""; return 2; }
  _run_install "$_h" --from "file://$_r/cstk-extras-v1.tar.gz"
  [ "$_CAPTURED_EXIT" = 0 ] || { _fail "install" "$_CAPTURED_STDERR"; return 1; }

  # Drift em commands: edita agente-00c.md
  printf '\nUSER EDIT\n' >> "$_h/.claude/commands/agente-00c.md"
  # Drift em agents: deleta orchestrator
  rm -f "$_h/.claude/agents/agente-00c-orchestrator.md"
  # Drift em agents: ORPHAN
  printf '# orphan\n' > "$_h/.claude/agents/my-custom-agent.md"

  _run_doctor "$_h"
  if [ "$_CAPTURED_EXIT" != 1 ]; then
    _fail "doctor com drift exit" "esperado 1, obtido $_CAPTURED_EXIT"
    return 1
  fi
  assert_stderr_contains "[EDITED]   commands/agente-00c" || return 1
  assert_stderr_contains "[MISSING]  agents/agente-00c-orchestrator" || return 1
  assert_stderr_contains "[ORPHAN]   agents/my-custom-agent" || return 1
}

# ==== Doctor --fix limpa MISSING em commands/agents ====

scenario_doctor_fix_remove_missing_em_extra_kinds() {
  _h="$TMPDIR_TEST/home"
  _r="$TMPDIR_TEST/release"
  _make_release_with_extras "$_r" || { _error "fixture" ""; return 2; }
  _run_install "$_h" --from "file://$_r/cstk-extras-v1.tar.gz"
  [ "$_CAPTURED_EXIT" = 0 ] || { _fail "install" "$_CAPTURED_STDERR"; return 1; }
  # MISSING em agents
  rm -f "$_h/.claude/agents/agente-00c-orchestrator.md"
  _run_doctor "$_h" --fix
  if [ "$_CAPTURED_EXIT" != 0 ]; then
    _fail "doctor --fix exit" "esperado 0, obtido $_CAPTURED_EXIT"
    return 1
  fi
  assert_stderr_contains "removida entry MISSING agents/agente-00c-orchestrator" || return 1
  # Manifest agora nao lista o orchestrator
  if grep -q '^agente-00c-orchestrator	' "$_h/.claude/agents/.cstk-manifest"; then
    _fail "orchestrator ainda no manifest pos --fix" "manifest: $(cat "$_h"/.claude/agents/.cstk-manifest)"
    return 1
  fi
}

run_all_scenarios
