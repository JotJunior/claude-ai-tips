#!/bin/sh
# test_00c-bootstrap.sh — cobre cli/lib/00c-bootstrap.sh (FASE 12).
#
# Ref: docs/specs/cstk-cli/spec.md §FR-016*..h + SC-008/009
#      docs/specs/cstk-cli/quickstart.md Scenarios 13-16
#      docs/specs/cstk-cli/tasks.md FASE 12 (12.1-12.5)

TESTS_ROOT="${TESTS_ROOT:-$(cd "$(dirname "$0")/.." && pwd)}"
REPO_ROOT="${REPO_ROOT:-$(cd "$TESTS_ROOT/.." && pwd)}"

. "$TESTS_ROOT/lib/harness.sh"

CSTK_LIB="$REPO_ROOT/cli/lib"
export CSTK_LIB

# ==== Helpers ====

# _make_mocks <dir> [<claude_exit>] [<cstk_exit>] [<cstk_stderr>]
# Cria mocks em <dir>:
#   - claude: loga argv em <dir>/claude.argv, exit code = $2 (default 0)
#   - cstk: loga argv em <dir>/cstk.argv, exit = $3 (default 0),
#           stderr = $4 (default empty). Tambem instala agente-00c.md em
#           HOME/.claude/commands/ se exit=0 (simulando sucesso de install).
#   - jq: real (link para o jq do sistema), porque precisamos validar JSON
_make_mocks() {
  _mm_dir=$1
  _mm_claude_exit=${2:-0}
  _mm_cstk_exit=${3:-0}
  _mm_cstk_stderr=${4:-}
  _mm_install_target=${5:-}
  mkdir -p -- "$_mm_dir"

  # claude mock: registra argv + exit
  cat > "$_mm_dir/claude" <<MOCK
#!/bin/sh
# Mock claude para tests
printf '%s\n' "\$0" > "$_mm_dir/claude.argv"
for _a in "\$@"; do
  printf '%s\n' "\$_a" >> "$_mm_dir/claude.argv"
done
exit $_mm_claude_exit
MOCK
  chmod +x "$_mm_dir/claude"

  # cstk mock (apenas para subcomando 'install' aninhado em FR-016d c)
  cat > "$_mm_dir/cstk" <<MOCK
#!/bin/sh
printf '%s\n' "\$@" > "$_mm_dir/cstk.argv"
if [ "\$1" = "install" ]; then
  if [ -n "$_mm_cstk_stderr" ]; then
    printf '%s\n' "$_mm_cstk_stderr" >&2
  fi
  if [ "$_mm_cstk_exit" = 0 ] && [ -n "$_mm_install_target" ]; then
    mkdir -p -- "\$(dirname "$_mm_install_target")"
    printf '# agente-00c v1\n' > "$_mm_install_target"
  fi
  exit $_mm_cstk_exit
fi
exit 0
MOCK
  chmod +x "$_mm_dir/cstk"

  # jq: link para o jq real (precisamos validar JSON nos testes).
  # Detecta jq do host. Se ausente no host, link nao e criado e os testes
  # de stack JSON serao skippados.
  if command -v jq >/dev/null 2>&1; then
    _mm_jq_real=$(command -v jq)
    ln -s -- "$_mm_jq_real" "$_mm_dir/jq" 2>/dev/null || cp -- "$_mm_jq_real" "$_mm_dir/jq"
  fi
}

# Invoca bootstrap_00c_main com PATH controlado e capture.
# Args: <home> <mockdir> <args...>
_run_00c() {
  _r_home=$1; shift
  _r_mock=$1; shift
  capture env \
    HOME="$_r_home" \
    PATH="$_r_mock:/usr/bin:/bin" \
    CSTK_LIB="$CSTK_LIB" \
    CSTK_00C_FORCE_TTY=1 \
    CSTK_BIN="$_r_mock/cstk" \
    sh -c '
      . "$CSTK_LIB/00c-bootstrap.sh"; bootstrap_00c_main "$@"
    ' 00c_test "$@"
}

# ==== Scenario: arg vazio -> exit 2 (FR-016, parse_args) ====

scenario_arg_vazio_exit_2() {
  _h="$TMPDIR_TEST/h"; mkdir -p "$_h"
  _m="$TMPDIR_TEST/mock"; _make_mocks "$_m"

  _run_00c "$_h" "$_m"
  [ "$_CAPTURED_EXIT" = 2 ] || { _fail "exit" "esperado 2, obtido $_CAPTURED_EXIT"; return 1; }
  assert_stderr_contains "<path> e obrigatorio" || return 1
}

# ==== Scenario: --help nao toca disco e sai 0 (FR-016, plan FASE 12 12.6.1) ====

scenario_help_imprime_uso() {
  _h="$TMPDIR_TEST/h"; mkdir -p "$_h"
  _m="$TMPDIR_TEST/mock"; _make_mocks "$_m"

  _run_00c "$_h" "$_m" --help
  [ "$_CAPTURED_EXIT" = 0 ] || { _fail "exit" "esperado 0, obtido $_CAPTURED_EXIT"; return 1; }
  # cstk 00c --help imprime para stdout (cat heredoc).
  assert_stdout_contains "Bootstrap interativo" || return 1
  assert_stdout_contains "PRE-REQUISITOS" || return 1
  assert_stdout_contains "TTY interativo" || return 1
  assert_stdout_contains "EXIT CODES" || return 1
}

# ==== Scenario: path traversal '..' -> exit 2 (FR-016b) ====

scenario_path_traversal_exit_2() {
  _h="$TMPDIR_TEST/h"; mkdir -p "$_h"
  _m="$TMPDIR_TEST/mock"; _make_mocks "$_m"

  _run_00c "$_h" "$_m" "../foo"
  [ "$_CAPTURED_EXIT" = 2 ] || { _fail "exit" "esperado 2, obtido $_CAPTURED_EXIT"; return 1; }
  assert_stderr_contains "path traversal" || return 1
}

# ==== Scenario: zona de sistema proibida -> exit 2 (FR-016b) ====

scenario_zona_proibida_exit_2() {
  _h="$TMPDIR_TEST/h"; mkdir -p "$_h"
  _m="$TMPDIR_TEST/mock"; _make_mocks "$_m"

  _run_00c "$_h" "$_m" "/etc/foo"
  [ "$_CAPTURED_EXIT" = 2 ] || { _fail "exit" "esperado 2, obtido $_CAPTURED_EXIT"; return 1; }
  assert_stderr_contains "zona de sistema proibida" || return 1
}

# ==== Scenario: TTY ausente -> exit 2 (FR-016a) ====
# Bypass CSTK_00C_FORCE_TTY=0 para forcar o check real.

scenario_tty_ausente_exit_2() {
  _h="$TMPDIR_TEST/h"; mkdir -p "$_h"
  _m="$TMPDIR_TEST/mock"; _make_mocks "$_m"
  _p="$_h/poc"

  capture env \
    HOME="$_h" \
    PATH="$_m:/usr/bin:/bin" \
    CSTK_LIB="$CSTK_LIB" \
    CSTK_00C_FORCE_TTY=0 \
    sh -c '. "$CSTK_LIB/00c-bootstrap.sh"; bootstrap_00c_main "$@"' \
    00c_test "$_p" </dev/null
  [ "$_CAPTURED_EXIT" = 2 ] || { _fail "exit" "esperado 2, obtido $_CAPTURED_EXIT"; return 1; }
  assert_stderr_contains "TTY interativo" || return 1
}

# ==== Scenario: dir nao-vazio -> exit 1 SEM prompt (FR-016b, SC-009) ====

scenario_dir_nao_vazio_exit_1() {
  _h="$TMPDIR_TEST/h"; mkdir -p "$_h"
  _m="$TMPDIR_TEST/mock"; _make_mocks "$_m"
  # Cria dir alvo nao-vazio
  _p="$_h/poc-existing"
  mkdir -p "$_p"
  printf 'existing\n' > "$_p/file.txt"

  _run_00c "$_h" "$_m" "$_p"
  [ "$_CAPTURED_EXIT" = 1 ] || { _fail "exit" "esperado 1, obtido $_CAPTURED_EXIT"; return 1; }
  assert_stderr_contains "ja existe e nao esta vazio" || return 1
  assert_stderr_contains "/agente-00c-resume" || return 1
  # Regressao: nao deve ter prompt
  ! grep -q "y/N" "$_CAPTURED_STDERR" 2>/dev/null || return 1
}

# ==== Scenario: claude ausente -> exit 1 (FR-016d a) ====

scenario_claude_ausente_exit_1() {
  _h="$TMPDIR_TEST/h"; mkdir -p "$_h"
  _m="$TMPDIR_TEST/mock"; _make_mocks "$_m"
  # Remove claude do mock
  rm -f "$_m/claude"
  _p="$_h/poc-no-claude"

  _run_00c "$_h" "$_m" "$_p"
  [ "$_CAPTURED_EXIT" = 1 ] || { _fail "exit" "esperado 1, obtido $_CAPTURED_EXIT"; return 1; }
  assert_stderr_contains "Claude Code CLI nao encontrado" || return 1
}

# ==== Scenario: jq ausente -> exit 1 (FR-016d b) ====

scenario_jq_ausente_exit_1() {
  _h="$TMPDIR_TEST/h"; mkdir -p "$_h"
  _m="$TMPDIR_TEST/mock"; _make_mocks "$_m"
  # Sistemas tipo macOS tem /usr/bin/jq; remover do mock nao basta porque
  # PATH=mock:/usr/bin:/bin ainda encontra jq. Shadow com stub que exit 127
  # (jq presente mas nao funcional — o lib usa `jq --version` para detectar).
  # IMPORTANTE: rm -f ANTES do cat porque _make_mocks criou um SYMLINK para
  # o jq real; sem rm, `cat > $_m/jq` segue o symlink e escreve no jq real
  # (que e read-only fora de root, falhando silenciosamente).
  rm -f "$_m/jq"
  cat > "$_m/jq" <<'STUB'
#!/bin/sh
exit 127
STUB
  chmod +x "$_m/jq"
  _p="$_h/poc-no-jq"

  _run_00c "$_h" "$_m" "$_p"
  [ "$_CAPTURED_EXIT" = 1 ] || { _fail "exit" "esperado 1, obtido $_CAPTURED_EXIT"; return 1; }
  assert_stderr_contains "jq nao encontrado" || return 1
}

# ==== Scenario: agente-00c.md ausente, prompt N -> exit 1 (FR-016d c) ====

scenario_agente00c_ausente_prompt_n() {
  _h="$TMPDIR_TEST/h"; mkdir -p "$_h"
  _m="$TMPDIR_TEST/mock"; _make_mocks "$_m"
  _p="$_h/poc-no-agente"

  # Resposta 'n' no stdin para o prompt
  capture env \
    HOME="$_h" \
    PATH="$_m:/usr/bin:/bin" \
    CSTK_LIB="$CSTK_LIB" \
    CSTK_00C_FORCE_TTY=1 \
    CSTK_BIN="$_m/cstk" \
    sh -c '. "$CSTK_LIB/00c-bootstrap.sh"; bootstrap_00c_main "$@"' \
    00c_test "$_p" <<EOF
n
EOF
  [ "$_CAPTURED_EXIT" = 1 ] || { _fail "exit" "esperado 1, obtido $_CAPTURED_EXIT"; return 1; }
  assert_stderr_contains "requer comando agente-00c instalado" || return 1
}

# ==== Scenario: agente-00c.md ausente, prompt Y + install OK ====
# Ate o fim do install: deve prosseguir para os prompts subsequentes.
# Como o stdin acaba apos `Y`, os proximos prompts retornam EOF
# (descricao recebe linha vazia). Validamos que o install foi disparado.

scenario_agente00c_ausente_prompt_y_install_ok() {
  _h="$TMPDIR_TEST/h"; mkdir -p "$_h"
  _target_md="$_h/.claude/commands/agente-00c.md"
  _m="$TMPDIR_TEST/mock"; _make_mocks "$_m" 0 0 "" "$_target_md"
  _p="$_h/poc-with-install"

  capture env \
    HOME="$_h" \
    PATH="$_m:/usr/bin:/bin" \
    CSTK_LIB="$CSTK_LIB" \
    CSTK_00C_FORCE_TTY=1 \
    CSTK_BIN="$_m/cstk" \
    sh -c '. "$CSTK_LIB/00c-bootstrap.sh"; bootstrap_00c_main "$@"' \
    00c_test "$_p" <<EOF
Y

EOF
  # Install foi disparado
  [ -f "$_m/cstk.argv" ] || { _fail "cstk install nao foi disparado"; return 1; }
  grep -q "install" "$_m/cstk.argv" || { _fail "cstk argv nao tem install"; return 1; }
  # Agente-00c.md foi criado pelo mock
  [ -f "$_target_md" ] || { _fail "agente-00c.md nao foi criado pelo mock"; return 1; }
}

# ==== Scenario: cstk install falha -> exit 1 + dir permanece (FR-016d c, CHK061) ====

scenario_cstk_install_falha_exit_1() {
  _h="$TMPDIR_TEST/h"; mkdir -p "$_h"
  _m="$TMPDIR_TEST/mock"; _make_mocks "$_m" 0 1 "download failed: connection refused" ""
  _p="$_h/poc-install-fails"

  capture env \
    HOME="$_h" \
    PATH="$_m:/usr/bin:/bin" \
    CSTK_LIB="$CSTK_LIB" \
    CSTK_00C_FORCE_TTY=1 \
    CSTK_BIN="$_m/cstk" \
    sh -c '. "$CSTK_LIB/00c-bootstrap.sh"; bootstrap_00c_main "$@"' \
    00c_test "$_p" <<EOF
Y
EOF
  [ "$_CAPTURED_EXIT" = 1 ] || { _fail "exit" "esperado 1, obtido $_CAPTURED_EXIT"; return 1; }
  assert_stderr_contains "cstk install falhou" || return 1
  # Dir permanece (sem rollback)
  [ -d "$_p" ] || { _fail "dir nao deveria ter sido removido"; return 1; }
}

# ==== Scenario: lock pre-existente -> exit 1 (FR-016h) ====

scenario_lock_preexistente_exit_1() {
  _h="$TMPDIR_TEST/h"; mkdir -p "$_h"
  _m="$TMPDIR_TEST/mock"; _make_mocks "$_m"
  _p="$_h/poc-locked"
  mkdir -p "$_p/.cstk-00c.lock"

  _run_00c "$_h" "$_m" "$_p"
  [ "$_CAPTURED_EXIT" = 1 ] || { _fail "exit" "esperado 1, obtido $_CAPTURED_EXIT"; return 1; }
  assert_stderr_contains "outra instancia de cstk 00c em andamento" || return 1
  # Lock pre-existente NAO deve ter sido removido
  [ -d "$_p/.cstk-00c.lock" ] || { _fail "lock removido erradamente"; return 1; }
}

# ==== Scenario: happy path com claude mock recebe argv esperada (FR-016f, SC-008) ====

scenario_happy_path_argv_correto() {
  _h="$TMPDIR_TEST/h"; mkdir -p "$_h/.claude/commands"
  printf '# agente-00c\n' > "$_h/.claude/commands/agente-00c.md"
  _m="$TMPDIR_TEST/mock"; _make_mocks "$_m"
  _p="$_h/poc-happy"

  capture env \
    HOME="$_h" \
    PATH="$_m:/usr/bin:/bin" \
    CSTK_LIB="$CSTK_LIB" \
    CSTK_00C_FORCE_TTY=1 \
    CSTK_BIN="$_m/cstk" \
    sh -c '. "$CSTK_LIB/00c-bootstrap.sh"; bootstrap_00c_main "$@"' \
    00c_test "$_p" --yes <<EOF
POC de chatbot com OAuth
{"runtime":"node20"}
https://api.example.com

EOF
  [ "$_CAPTURED_EXIT" = 0 ] || { _fail "exit" "esperado 0, obtido $_CAPTURED_EXIT"; return 1; }
  # Mock claude registrou argv?
  [ -f "$_m/claude.argv" ] || { _fail "claude nao foi invocado"; return 1; }
  # Slash command tem os 4 fragmentos esperados
  grep -q "/agente-00c" "$_m/claude.argv" || { _fail "argv sem /agente-00c"; return 1; }
  grep -q "POC de chatbot com OAuth" "$_m/claude.argv" || { _fail "argv sem descricao"; return 1; }
  grep -q -- "--stack" "$_m/claude.argv" || { _fail "argv sem --stack"; return 1; }
  grep -q -- "--whitelist" "$_m/claude.argv" || { _fail "argv sem --whitelist"; return 1; }
  grep -q -- "--projeto-alvo-path" "$_m/claude.argv" || { _fail "argv sem --projeto-alvo-path"; return 1; }
  # Lock liberado antes do exec
  [ ! -d "$_p/.cstk-00c.lock" ] || { _fail "lock nao foi liberado"; return 1; }
  # Whitelist persistida com chmod 600
  [ -f "$_p/.agente-00c-whitelist.txt" ] || { _fail "whitelist nao persistida"; return 1; }
  grep -q "https://api.example.com" "$_p/.agente-00c-whitelist.txt" || \
    { _fail "whitelist sem URL"; return 1; }
}

# ==== Scenario: validacao URL whitelist rejeita overly broad (CHK049) ====

scenario_url_invalida_overly_broad_rejected() {
  _h="$TMPDIR_TEST/h"; mkdir -p "$_h/.claude/commands"
  printf '# agente-00c\n' > "$_h/.claude/commands/agente-00c.md"
  _m="$TMPDIR_TEST/mock"; _make_mocks "$_m"
  _p="$_h/poc-bad-url"

  # Tenta varias URLs invalidas, depois URL valida, depois encerra.
  capture env \
    HOME="$_h" \
    PATH="$_m:/usr/bin:/bin" \
    CSTK_LIB="$CSTK_LIB" \
    CSTK_00C_FORCE_TTY=1 \
    CSTK_BIN="$_m/cstk" \
    sh -c '. "$CSTK_LIB/00c-bootstrap.sh"; bootstrap_00c_main "$@"' \
    00c_test "$_p" --yes <<EOF
descricao valida com mais de 10 chars

**
*://example.com
https://*
ftp://example.com
https://example.com

EOF
  [ "$_CAPTURED_EXIT" = 0 ] || { _fail "exit" "esperado 0, obtido $_CAPTURED_EXIT"; return 1; }
  # Whitelist final deve ter apenas a URL valida
  [ -f "$_p/.agente-00c-whitelist.txt" ] || { _fail "whitelist nao persistida"; return 1; }
  ! grep -q "\*\*" "$_p/.agente-00c-whitelist.txt" || { _fail "** aceita"; return 1; }
  ! grep -q "ftp://" "$_p/.agente-00c-whitelist.txt" || { _fail "ftp aceita"; return 1; }
  grep -q "https://example.com" "$_p/.agente-00c-whitelist.txt" || \
    { _fail "URL valida nao persistida"; return 1; }
}

# ==== Scenario: stack JSON malformado rejeitado, valido aceito (FR-016c b) ====

scenario_stack_json_validado() {
  _h="$TMPDIR_TEST/h"; mkdir -p "$_h/.claude/commands"
  printf '# agente-00c\n' > "$_h/.claude/commands/agente-00c.md"
  _m="$TMPDIR_TEST/mock"; _make_mocks "$_m"
  _p="$_h/poc-bad-stack"

  if [ ! -x "$_m/jq" ]; then
    _error "jq ausente no host" "instale jq para rodar este test"
    return 2
  fi

  capture env \
    HOME="$_h" \
    PATH="$_m:/usr/bin:/bin" \
    CSTK_LIB="$CSTK_LIB" \
    CSTK_00C_FORCE_TTY=1 \
    CSTK_BIN="$_m/cstk" \
    sh -c '. "$CSTK_LIB/00c-bootstrap.sh"; bootstrap_00c_main "$@"' \
    00c_test "$_p" --yes <<EOF
descricao valida com mais de 10 chars
{not json
{"runtime":"go"}

EOF
  [ "$_CAPTURED_EXIT" = 0 ] || { _fail "exit" "esperado 0, obtido $_CAPTURED_EXIT"; return 1; }
  # Stack persistida na argv do claude (compactada via jq -c)
  grep -q '"runtime":"go"' "$_m/claude.argv" || { _fail "stack nao persistida na argv"; return 1; }
}

# ==== Scenario: descricao curta -> rejeita (FR-016c a) ====

scenario_descricao_curta_rejeitada() {
  _h="$TMPDIR_TEST/h"; mkdir -p "$_h/.claude/commands"
  printf '# agente-00c\n' > "$_h/.claude/commands/agente-00c.md"
  _m="$TMPDIR_TEST/mock"; _make_mocks "$_m"
  _p="$_h/poc-short-desc"

  capture env \
    HOME="$_h" \
    PATH="$_m:/usr/bin:/bin" \
    CSTK_LIB="$CSTK_LIB" \
    CSTK_00C_FORCE_TTY=1 \
    CSTK_BIN="$_m/cstk" \
    sh -c '. "$CSTK_LIB/00c-bootstrap.sh"; bootstrap_00c_main "$@"' \
    00c_test "$_p" --yes <<EOF
abc
descricao valida com mais de 10 chars


EOF
  [ "$_CAPTURED_EXIT" = 0 ] || { _fail "exit" "esperado 0, obtido $_CAPTURED_EXIT"; return 1; }
  # Stderr deve ter warn sobre descricao curta
  assert_stderr_contains "muito curta" || return 1
}

# ==== Scenario: descricao com $ -> rejeita (FR-016c a) ====

scenario_descricao_com_dolar_rejeitada() {
  _h="$TMPDIR_TEST/h"; mkdir -p "$_h/.claude/commands"
  printf '# agente-00c\n' > "$_h/.claude/commands/agente-00c.md"
  _m="$TMPDIR_TEST/mock"; _make_mocks "$_m"
  _p="$_h/poc-dollar"

  capture env \
    HOME="$_h" \
    PATH="$_m:/usr/bin:/bin" \
    CSTK_LIB="$CSTK_LIB" \
    CSTK_00C_FORCE_TTY=1 \
    CSTK_BIN="$_m/cstk" \
    sh -c '. "$CSTK_LIB/00c-bootstrap.sh"; bootstrap_00c_main "$@"' \
    00c_test "$_p" --yes <<EOF
inject \$HOME here please
descricao valida com mais de 10 chars


EOF
  [ "$_CAPTURED_EXIT" = 0 ] || { _fail "exit" "esperado 0, obtido $_CAPTURED_EXIT"; return 1; }
  assert_stderr_contains "contem '\$'" || return 1
}

# ==== Scenario: confirmacao N (sem --yes) cancela limpo (FR-016e) ====

scenario_confirmacao_n_cancela() {
  _h="$TMPDIR_TEST/h"
  mkdir -p "$_h/.claude/commands" \
           "$_h/.claude/skills/agente-00c-runtime/scripts" \
           "$_h/.claude/agents"
  printf '# agente-00c\n' > "$_h/.claude/commands/agente-00c.md"
  # Probe da runtime: precisa existir + ser executavel (corresponde ao
  # check em _00c_check_deps que valida [ -x state-rw.sh ]).
  printf '#!/bin/sh\nexit 0\n' > "$_h/.claude/skills/agente-00c-runtime/scripts/state-rw.sh"
  chmod +x "$_h/.claude/skills/agente-00c-runtime/scripts/state-rw.sh"
  printf '#!/bin/sh\nexit 0\n' > "$_h/.claude/skills/agente-00c-runtime/scripts/state-lock.sh"
  chmod +x "$_h/.claude/skills/agente-00c-runtime/scripts/state-lock.sh"
  printf '#!/bin/sh\nexit 0\n' > "$_h/.claude/skills/agente-00c-runtime/scripts/path-guard.sh"
  chmod +x "$_h/.claude/skills/agente-00c-runtime/scripts/path-guard.sh"
  printf '# orchestrator\n' > "$_h/.claude/agents/agente-00c-orchestrator.md"
  _m="$TMPDIR_TEST/mock"; _make_mocks "$_m"
  _p="$_h/poc-cancel"

  capture env \
    HOME="$_h" \
    PATH="$_m:/usr/bin:/bin" \
    CSTK_LIB="$CSTK_LIB" \
    CSTK_00C_FORCE_TTY=1 \
    CSTK_BIN="$_m/cstk" \
    sh -c '. "$CSTK_LIB/00c-bootstrap.sh"; bootstrap_00c_main "$@"' \
    00c_test "$_p" <<EOF
descricao valida com mais de 10 chars


n
EOF
  [ "$_CAPTURED_EXIT" = 0 ] || { _fail "exit" "esperado 0, obtido $_CAPTURED_EXIT"; return 1; }
  # Claude NAO deve ter sido invocado
  [ ! -f "$_m/claude.argv" ] || { _fail "claude foi invocado mesmo com cancelamento"; return 1; }
  assert_stderr_contains "Cancelado" || return 1
}

# ==== Run all ====

run_all_scenarios "$0"
