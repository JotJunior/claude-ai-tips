#!/bin/sh
# smoke.sh — smoke test do cstk + cstk 00c em container limpo.
#
# Roda dentro do Dockerfile.smoke. Valida:
#   1. Bootstrap one-liner via fixture local (FASE 11.2.5, SC-005 baseline)
#   2. cstk --version reporta tag esperada
#   3. cstk doctor clean
#   4. cstk install instala skills + commands + agents
#   5. cstk 00c --help imprime ajuda completa
#   6. cstk 00c rejeita arg vazio (exit 2)
#   7. cstk 00c rejeita zona proibida (exit 2)
#   8. cstk 00c rejeita TTY ausente (exit 2)
#   9. cstk 00c happy path com mock claude (SC-008)
#  10. cstk 00c respeita validacoes mesmo com --yes
#
# Pre-requisitos: container Dockerfile.smoke com mounts:
#   /fixtures/cstk-X.Y.Z.tar.gz + .sha256 + install.sh
#   /smoke/smoke.sh (este arquivo)

set -eu

FIXTURE_DIR=/fixtures
INSTALLER_DIR=/installer
EXPECTED_VERSION="${EXPECTED_VERSION:-3.5.0}"
TARBALL="$FIXTURE_DIR/cstk-${EXPECTED_VERSION}.tar.gz"
INSTALLER="$INSTALLER_DIR/install.sh"
PASS=0
FAIL=0

_section() {
  printf '\n========== %s ==========\n' "$1" >&2
}

_pass() {
  printf '  [PASS] %s\n' "$1" >&2
  PASS=$((PASS + 1))
}

_fail() {
  printf '  [FAIL] %s\n' "$1" >&2
  if [ -n "${2:-}" ]; then
    printf '         %s\n' "$2" >&2
  fi
  FAIL=$((FAIL + 1))
}

# ==== 1. Verifica fixtures montados ====

_section "1. Fixtures montados"
if [ ! -f "$TARBALL" ]; then
  _fail "tarball ausente: $TARBALL"
  exit 1
fi
if [ ! -f "$INSTALLER" ]; then
  _fail "installer ausente: $INSTALLER"
  exit 1
fi
_pass "tarball + installer presentes"

# ==== 2. Bootstrap via install.sh com fixture local ====

_section "2. Bootstrap (install.sh)"
# Copia para tmpdir gravavel; CSTK_RELEASE_URL aponta para file:// local
SETUP_DIR=$(mktemp -d)
cp "$TARBALL" "$TARBALL.sha256" "$SETUP_DIR/"

if CSTK_RELEASE_URL="file://$SETUP_DIR/cstk-${EXPECTED_VERSION}.tar.gz" \
   sh "$INSTALLER" >/tmp/install.log 2>&1; then
  _pass "install.sh exit 0"
else
  _fail "install.sh falhou" "ver /tmp/install.log"
  cat /tmp/install.log >&2
  exit 1
fi

# ==== 3. cstk --version ====

_section "3. cstk --version"
if [ ! -x "$HOME/.local/bin/cstk" ]; then
  _fail "binario cstk ausente apos install.sh"
  exit 1
fi
ACTUAL_VERSION=$("$HOME/.local/bin/cstk" --version 2>&1 || true)
if printf '%s\n' "$ACTUAL_VERSION" | grep -q "$EXPECTED_VERSION"; then
  _pass "cstk reporta versao $EXPECTED_VERSION"
else
  _fail "versao esperada $EXPECTED_VERSION" "atual: $ACTUAL_VERSION"
fi

# ==== 4. cstk install (skills + commands + agents) ====

_section "4. cstk install --profile all"
# IMPORTANTE: aponta para fixture local (file://) via CSTK_RELEASE_URL.
# Sem isso, `cstk install` consulta GitHub API e baixa a ultima release
# publicada (v3.3.0) que nao tem agente-00c. Tambem usado em prompts
# automatic-install do `cstk 00c` no caminho 12.2.5.
export CSTK_RELEASE_URL="file://$SETUP_DIR/cstk-${EXPECTED_VERSION}.tar.gz"

# `--profile all` instala TODAS as skills (sdd + complementary +
# agente-00c-runtime + review-features). E o profile esperado para quem
# usa `cstk 00c` porque o orquestrador requer agente-00c-runtime no
# runtime (mesmo que o nosso smoke pare em mock claude e nao chame o
# orquestrador). Commands e agents sao instalados sempre, sem filtro
# de profile (FASE 1.2).
if cstk install --profile all >/tmp/cstk-install.log 2>&1; then
  _pass "cstk install --profile all exit 0"
else
  _fail "cstk install --profile all falhou" "ver /tmp/cstk-install.log"
  cat /tmp/cstk-install.log >&2
fi

if [ -f "$HOME/.claude/commands/agente-00c.md" ]; then
  _pass "agente-00c.md instalado em ~/.claude/commands/"
else
  _fail "agente-00c.md NAO instalado" "ls ~/.claude/commands/"
  ls "$HOME/.claude/commands/" 2>&1 || true
fi

if [ -f "$HOME/.claude/agents/agente-00c-orchestrator.md" ]; then
  _pass "agente-00c-orchestrator.md instalado em ~/.claude/agents/"
else
  _fail "orchestrator agent NAO instalado"
fi

if [ -d "$HOME/.claude/skills/agente-00c-runtime" ]; then
  _pass "agente-00c-runtime skill instalada"
else
  _fail "agente-00c-runtime NAO instalado"
fi

# ==== 5. cstk doctor ====

_section "5. cstk doctor"
if cstk doctor >/tmp/cstk-doctor.log 2>&1; then
  _pass "cstk doctor exit 0 (sem drift)"
else
  _fail "cstk doctor reportou drift" "ver /tmp/cstk-doctor.log"
  cat /tmp/cstk-doctor.log >&2
fi

# ==== 6. cstk 00c --help ====

_section "6. cstk 00c --help"
HELP_OUTPUT=$(cstk 00c --help 2>&1 || true)
if printf '%s\n' "$HELP_OUTPUT" | grep -q "Bootstrap interativo"; then
  _pass "--help imprime header"
else
  _fail "--help sem 'Bootstrap interativo'" "$HELP_OUTPUT"
fi
if printf '%s\n' "$HELP_OUTPUT" | grep -q "TTY interativo"; then
  _pass "--help menciona TTY interativo (CHK065)"
else
  _fail "--help sem TTY mention"
fi
if printf '%s\n' "$HELP_OUTPUT" | grep -q "EXIT CODES"; then
  _pass "--help lista exit codes"
else
  _fail "--help sem EXIT CODES"
fi

# ==== 7. cstk 00c arg vazio ====

_section "7. cstk 00c (arg vazio)"
set +e
cstk 00c >/dev/null 2>&1
RC=$?
set -e
if [ "$RC" = 2 ]; then
  _pass "arg vazio -> exit 2"
else
  _fail "arg vazio: esperado exit 2" "obtido: $RC"
fi

# ==== 8. cstk 00c zona proibida ====

_section "8. cstk 00c /etc/foo (zona proibida)"
set +e
CSTK_00C_FORCE_TTY=1 cstk 00c /etc/foo >/dev/null 2>&1
RC=$?
set -e
if [ "$RC" = 2 ]; then
  _pass "/etc/foo -> exit 2"
else
  _fail "/etc/foo: esperado exit 2" "obtido: $RC"
fi

# ==== 9. cstk 00c TTY ausente ====

_section "9. cstk 00c sem TTY"
# Sem CSTK_00C_FORCE_TTY, com stdin redirecionado.
set +e
cstk 00c "$HOME/poc-no-tty" </dev/null >/dev/null 2>&1
RC=$?
set -e
if [ "$RC" = 2 ]; then
  _pass "TTY ausente -> exit 2"
else
  _fail "TTY ausente: esperado exit 2" "obtido: $RC"
fi

# ==== 10. cstk 00c happy path com mock claude ====

_section "10. cstk 00c happy path (mock claude)"
# Cria mock claude no PATH (PRECEDE binario real se existisse).
MOCK_DIR=$(mktemp -d)
cat > "$MOCK_DIR/claude" <<'MOCK'
#!/bin/sh
# mock claude — registra argv em /tmp/claude.argv
{
  printf 'invoked-with:\n'
  for a in "$@"; do
    printf '  argv:%s\n' "$a"
  done
} > /tmp/claude.argv
exit 0
MOCK
chmod +x "$MOCK_DIR/claude"

# Stdin com inputs para os 3 prompts + descricao
PATH="$MOCK_DIR:$PATH" \
CSTK_00C_FORCE_TTY=1 \
cstk 00c "$HOME/poc-happy" --yes >/tmp/00c-happy.log 2>&1 <<EOF
POC de chatbot OAuth via cstk 00c smoke test
{"runtime":"node20","ui":"react"}
https://api.example.com

EOF
RC=$?

if [ "$RC" = 0 ]; then
  _pass "cstk 00c happy path exit 0"
else
  _fail "cstk 00c happy path falhou" "exit=$RC; log:"
  cat /tmp/00c-happy.log >&2
fi

if [ -f /tmp/claude.argv ]; then
  _pass "mock claude foi invocado"
  if grep -q "/agente-00c" /tmp/claude.argv; then
    _pass "argv contem /agente-00c"
  else
    _fail "argv sem /agente-00c"
    cat /tmp/claude.argv >&2
  fi
  if grep -q "POC de chatbot OAuth via cstk 00c smoke test" /tmp/claude.argv; then
    _pass "argv contem descricao"
  else
    _fail "argv sem descricao"
    cat /tmp/claude.argv >&2
  fi
  if grep -q "node20" /tmp/claude.argv; then
    _pass "argv contem stack JSON (com aspas duplas internas)"
  else
    _fail "argv sem stack JSON"
    cat /tmp/claude.argv >&2
  fi
  if grep -q -- "--whitelist" /tmp/claude.argv; then
    _pass "argv contem --whitelist"
  else
    _fail "argv sem --whitelist"
  fi
  if grep -q -- "--projeto-alvo-path" /tmp/claude.argv; then
    _pass "argv contem --projeto-alvo-path"
  else
    _fail "argv sem --projeto-alvo-path"
  fi
else
  _fail "mock claude NAO foi invocado"
  cat /tmp/00c-happy.log >&2
fi

# Whitelist persistida com chmod 600?
WL_FILE="$HOME/poc-happy/.agente-00c-whitelist.txt"
if [ -f "$WL_FILE" ]; then
  _pass "whitelist file persistido em $WL_FILE"
  PERMS=$(stat -c '%a' "$WL_FILE" 2>/dev/null || stat -f '%A' "$WL_FILE" 2>/dev/null)
  if [ "$PERMS" = "600" ]; then
    _pass "whitelist com chmod 600"
  else
    _fail "whitelist com perms erradas" "esperado 600, obtido $PERMS"
  fi
else
  _fail "whitelist NAO persistido"
fi

# Lock liberado apos exec?
if [ ! -d "$HOME/poc-happy/.cstk-00c.lock" ]; then
  _pass "lock per-path liberado apos exec"
else
  _fail "lock per-path NAO foi liberado"
fi

# ==== Resumo ====

_section "Resumo"
printf 'PASS=%d  FAIL=%d\n' "$PASS" "$FAIL" >&2

if [ "$FAIL" -gt 0 ]; then
  exit 1
fi
exit 0
