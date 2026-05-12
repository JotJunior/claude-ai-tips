#!/bin/sh
# test_pipeline.sh — cobre global/skills/agente-00c-runtime/scripts/pipeline.sh.

TESTS_ROOT="${TESTS_ROOT:-$(cd "$(dirname "$0")" && pwd)}"
REPO_ROOT="${REPO_ROOT:-$(cd "$TESTS_ROOT/.." && pwd)}"

. "$TESTS_ROOT/lib/harness.sh"

SCRIPT="$REPO_ROOT/global/skills/agente-00c-runtime/scripts/pipeline.sh"

scenario_stages_lista_10_etapas_em_ordem() {
  capture "$SCRIPT" stages
  [ "$_CAPTURED_EXIT" = 0 ] || { _fail "stages exit" "$_CAPTURED_EXIT"; return 1; }
  _expected="briefing
constitution
specify
clarify
plan
checklist
create-tasks
execute-task
review-task
review-features"
  if [ "$_CAPTURED_STDOUT" != "$_expected" ]; then
    _fail "stages output" "ordem ou conteudo divergente:
got=
$_CAPTURED_STDOUT
expected=
$_expected"
    return 1
  fi
}

scenario_next_stage_avanca_linear() {
  capture "$SCRIPT" next-stage --current briefing
  assert_stdout_contains "constitution" || return 1
  capture "$SCRIPT" next-stage --current plan
  assert_stdout_contains "checklist" || return 1
}

scenario_next_stage_na_ultima_imprime_vazio() {
  capture "$SCRIPT" next-stage --current review-features
  [ "$_CAPTURED_EXIT" = 0 ] || { _fail "exit" ""; return 1; }
  if [ -n "$_CAPTURED_STDOUT" ]; then
    _fail "next na ultima" "esperado vazio, obtido: $_CAPTURED_STDOUT"
    return 1
  fi
}

scenario_prev_stage_volta_linear() {
  capture "$SCRIPT" prev-stage --current specify
  assert_stdout_contains "constitution" || return 1
}

scenario_prev_stage_na_primeira_imprime_vazio() {
  capture "$SCRIPT" prev-stage --current briefing
  [ "$_CAPTURED_EXIT" = 0 ] || { _fail "exit" ""; return 1; }
  if [ -n "$_CAPTURED_STDOUT" ]; then
    _fail "prev na primeira" "esperado vazio, obtido: $_CAPTURED_STDOUT"
    return 1
  fi
}

scenario_etapa_invalida_falha() {
  capture "$SCRIPT" next-stage --current xyz-fake
  if [ "$_CAPTURED_EXIT" = 0 ]; then
    _fail "etapa invalida" "esperado != 0"
    return 1
  fi
  assert_stderr_contains "etapa desconhecida" || return 1
}

scenario_detect_completion_briefing() {
  _fd="$TMPDIR_TEST/feat"
  mkdir -p "$_fd"
  capture "$SCRIPT" detect-completion --feature-dir "$_fd" --stage briefing
  if [ "$_CAPTURED_EXIT" != 1 ]; then
    _fail "no briefing.md" "esperado 1, obtido $_CAPTURED_EXIT"
    return 1
  fi
  printf '# briefing\n' > "$_fd/briefing.md"
  capture "$SCRIPT" detect-completion --feature-dir "$_fd" --stage briefing
  if [ "$_CAPTURED_EXIT" != 0 ]; then
    _fail "with briefing.md" "esperado 0, obtido $_CAPTURED_EXIT"
    return 1
  fi
}

# ==== Issue #3: briefing aceita path do /initialize-docs via --projeto-alvo-path ====
scenario_detect_completion_briefing_aceita_path_initialize_docs() {
  _fd="$TMPDIR_TEST/feat"
  _pap="$TMPDIR_TEST/pap"
  mkdir -p "$_fd" "$_pap/docs/01-briefing-discovery"

  # Sem briefing em nenhum lugar -> exit 1
  capture "$SCRIPT" detect-completion --feature-dir "$_fd" --stage briefing \
    --projeto-alvo-path "$_pap"
  [ "$_CAPTURED_EXIT" = 1 ] || {
    _fail "sem briefing" "esperado 1, obtido $_CAPTURED_EXIT"
    return 1
  }

  # Briefing SO no path do /initialize-docs -> exit 0 (com PAP)
  printf '# briefing\n' > "$_pap/docs/01-briefing-discovery/briefing.md"
  capture "$SCRIPT" detect-completion --feature-dir "$_fd" --stage briefing \
    --projeto-alvo-path "$_pap"
  [ "$_CAPTURED_EXIT" = 0 ] || {
    _fail "briefing em PAP" "esperado 0, obtido $_CAPTURED_EXIT"
    return 1
  }

  # Sem --projeto-alvo-path, ainda exige briefing.md no feature-dir
  capture "$SCRIPT" detect-completion --feature-dir "$_fd" --stage briefing
  [ "$_CAPTURED_EXIT" = 1 ] || {
    _fail "sem PAP, briefing.md fora do FD" "esperado 1, obtido $_CAPTURED_EXIT"
    return 1
  }
}

# ==== Issue #3: constitution aceita docs/constitution.md via --projeto-alvo-path ====
scenario_detect_completion_constitution_aceita_path_initialize_docs() {
  _fd="$TMPDIR_TEST/feat"
  _pap="$TMPDIR_TEST/pap"
  mkdir -p "$_fd" "$_pap/docs"

  # Sem constitution -> exit 1
  capture "$SCRIPT" detect-completion --feature-dir "$_fd" --stage constitution \
    --projeto-alvo-path "$_pap"
  [ "$_CAPTURED_EXIT" = 1 ] || {
    _fail "sem constitution" "esperado 1, obtido $_CAPTURED_EXIT"
    return 1
  }

  # Constitution em docs/constitution.md (path da skill constitution) -> exit 0
  printf '# constitution\n' > "$_pap/docs/constitution.md"
  capture "$SCRIPT" detect-completion --feature-dir "$_fd" --stage constitution \
    --projeto-alvo-path "$_pap"
  [ "$_CAPTURED_EXIT" = 0 ] || {
    _fail "constitution em PAP" "esperado 0, obtido $_CAPTURED_EXIT"
    return 1
  }
}

scenario_detect_completion_checklist_requer_md_dentro() {
  _fd="$TMPDIR_TEST/feat"
  mkdir -p "$_fd/checklists"
  capture "$SCRIPT" detect-completion --feature-dir "$_fd" --stage checklist
  if [ "$_CAPTURED_EXIT" != 1 ]; then
    _fail "checklists/ vazia" "esperado 1, obtido $_CAPTURED_EXIT"
    return 1
  fi
  printf 'x\n' > "$_fd/checklists/api.md"
  capture "$SCRIPT" detect-completion --feature-dir "$_fd" --stage checklist
  [ "$_CAPTURED_EXIT" = 0 ] || { _fail "com .md em checklists" "$_CAPTURED_EXIT"; return 1; }
}

scenario_detect_completion_execute_task_requer_x_em_tasks() {
  _fd="$TMPDIR_TEST/feat"
  mkdir -p "$_fd"
  printf '# tasks\n- [ ] foo\n' > "$_fd/tasks.md"
  capture "$SCRIPT" detect-completion --feature-dir "$_fd" --stage execute-task
  if [ "$_CAPTURED_EXIT" != 1 ]; then
    _fail "tasks sem [x]" "esperado 1"
    return 1
  fi
  printf '# tasks\n- [x] foo\n' > "$_fd/tasks.md"
  capture "$SCRIPT" detect-completion --feature-dir "$_fd" --stage execute-task
  [ "$_CAPTURED_EXIT" = 0 ] || { _fail "tasks com [x]" "$_CAPTURED_EXIT"; return 1; }
}

scenario_detect_completion_review_sempre_passa() {
  _fd="$TMPDIR_TEST/feat"
  mkdir -p "$_fd"
  capture "$SCRIPT" detect-completion --feature-dir "$_fd" --stage review-task
  [ "$_CAPTURED_EXIT" = 0 ] || { _fail "review-task" "$_CAPTURED_EXIT"; return 1; }
  capture "$SCRIPT" detect-completion --feature-dir "$_fd" --stage review-features
  [ "$_CAPTURED_EXIT" = 0 ] || { _fail "review-features" "$_CAPTURED_EXIT"; return 1; }
}

scenario_skill_conflict_local_vence() {
  _pap="$TMPDIR_TEST/proj"
  mkdir -p "$_pap/.claude/skills/clarify"
  # Para nao depender de ~/.claude/skills/clarify real, isolamos HOME
  _fakehome="$TMPDIR_TEST/fakehome"
  mkdir -p "$_fakehome/.claude/skills/clarify"
  capture env HOME="$_fakehome" "$SCRIPT" skill-conflict --skill clarify --projeto-alvo-path "$_pap"
  [ "$_CAPTURED_EXIT" = 0 ] || { _fail "exit" "$_CAPTURED_EXIT; $_CAPTURED_STDERR"; return 1; }
  assert_stdout_contains "status: conflict" || return 1
  assert_stdout_contains "resolution: local-wins" || return 1
}

scenario_skill_conflict_so_local() {
  _pap="$TMPDIR_TEST/proj"
  mkdir -p "$_pap/.claude/skills/skl-x"
  _fakehome="$TMPDIR_TEST/fakehome"
  mkdir -p "$_fakehome/.claude"
  capture env HOME="$_fakehome" "$SCRIPT" skill-conflict --skill skl-x --projeto-alvo-path "$_pap"
  if [ "$_CAPTURED_EXIT" != 2 ]; then
    _fail "exit" "esperado 2, obtido $_CAPTURED_EXIT"
    return 1
  fi
  assert_stdout_contains "status: only-local" || return 1
}

scenario_skill_conflict_so_global() {
  _pap="$TMPDIR_TEST/proj"
  mkdir -p "$_pap/.claude/skills"
  _fakehome="$TMPDIR_TEST/fakehome"
  mkdir -p "$_fakehome/.claude/skills/skl-y"
  capture env HOME="$_fakehome" "$SCRIPT" skill-conflict --skill skl-y --projeto-alvo-path "$_pap"
  if [ "$_CAPTURED_EXIT" != 1 ]; then
    _fail "exit" "esperado 1, obtido $_CAPTURED_EXIT"
    return 1
  fi
  assert_stdout_contains "status: only-global" || return 1
}

scenario_skill_conflict_nenhuma_exit_3() {
  _pap="$TMPDIR_TEST/proj"
  mkdir -p "$_pap/.claude/skills"
  _fakehome="$TMPDIR_TEST/fakehome"
  mkdir -p "$_fakehome/.claude"
  capture env HOME="$_fakehome" "$SCRIPT" skill-conflict --skill skl-z --projeto-alvo-path "$_pap"
  if [ "$_CAPTURED_EXIT" != 3 ]; then
    _fail "exit" "esperado 3, obtido $_CAPTURED_EXIT"
    return 1
  fi
  assert_stdout_contains "status: not-found" || return 1
}

run_all_scenarios
