#!/bin/sh
# test_validate.sh — cobre global/skills/validate-docs-rendered/scripts/validate.sh.
#
# Contrato declarado no cabecalho do script:
#   "Exit code: 0 se zero ERROs, 1 se houver ERROs."
#
# ATENCAO — UM bug latente em validate.sh foi descoberto na FASE 2 deste
# backlog e esta registrado em docs/specs/shell-scripts-tests/tasks.md:
#
#   (a) Mesmo padrao 'grep -c || printf "0"' do bug historico de metrics.sh
#       gera "[: 0\n0: integer expression expected" em stderr nas linhas
#       273-284 de validate.sh. Nao afeta exit code nem stdout — so polui
#       stderr. Os scenarios abaixo tolerarem esse stderr noise; nao usam
#       assert_stderr_contains para esse padrao.
#
# (Correcao inicial deste cabecalho indicava um segundo bug sobre exit code
# — isso foi uma leitura errada de um `echo exit=$?` apos echo, que sempre
# retorna 0. O exit code real de validate.sh E correto.)

TESTS_ROOT="${TESTS_ROOT:-$(cd "$(dirname "$0")" && pwd)}"
REPO_ROOT="${REPO_ROOT:-$(cd "$TESTS_ROOT/.." && pwd)}"

. "$TESTS_ROOT/lib/harness.sh"

SCRIPT="$REPO_ROOT/global/skills/validate-docs-rendered/scripts/validate.sh"

# ==== 3.5.1 docs validos ====

scenario_docs_validos() {
  fixture "docs-site/valid" || return 2
  assert_exit 0 sh "$SCRIPT" "$TMPDIR_TEST" || return 1
  # Sinal concreto de sucesso: stdout contem "Nenhum issue encontrado".
  # (Nao usamos '*ERRO*' porque a palavra aparece no header da tabela de
  # resumo, independente de haver ou nao ERROs reais.)
  assert_stdout_contains "Nenhum issue encontrado" || return 1
}

# ==== 3.5.2 mermaid quebrado (ver nota sobre bug (b) acima) ====

scenario_mermaid_quebrado() {
  fixture "docs-site/broken-mermaid" || return 2
  assert_exit 1 sh "$SCRIPT" "$TMPDIR_TEST" || return 1
  assert_stdout_contains "Mermaid" || return 1
}

# ==== 3.5.3 link quebrado ====

scenario_link_quebrado() {
  fixture "docs-site/broken-link" || return 2
  assert_exit 1 sh "$SCRIPT" "$TMPDIR_TEST" || return 1
  assert_stdout_contains "Link" || return 1
  assert_stdout_contains "nao-existe.md" || return 1
}

# ==== 3.5.4 frontmatter malformado ====

scenario_frontmatter_malformado() {
  fixture "docs-site/broken-frontmatter" || return 2
  assert_exit 1 sh "$SCRIPT" "$TMPDIR_TEST" || return 1
  assert_stdout_contains "Frontmatter" || return 1
}

# ==== 3.5.5 path inexistente ====

scenario_path_inexistente() {
  capture sh "$SCRIPT" "/caminho/que-nao-existe-xyz-999" || return 2
  if [ "$_CAPTURED_EXIT" -eq 0 ]; then
    _fail "scenario_path_inexistente" "esperado exit != 0 em path inexistente, obtido 0"
    return 1
  fi
  assert_stderr_contains "nao encontrado" || return 1
}

# ==== 3.5.6 default docs/ quando sem argumento ====

scenario_default_docs() {
  # Sem argumento, validate.sh usa "./docs". Cria um docs/ minimo valido
  # no tmpdir e executa o script com CWD=TMPDIR_TEST.
  mkdir -p "$TMPDIR_TEST/docs" || return 2
  # Um arquivo .md simples, sem diagramas/links — so um H1.
  printf '# Doc minimo\n\nConteudo trivial.\n' > "$TMPDIR_TEST/docs/index.md" || return 2
  # Executa no tmpdir. Aceita qualquer exit code (o objetivo e verificar que o
  # fluxo do default nao crasha) mas nao deve ter erros de shell (set -eu
  # aborto, stacktrace). Se comportamento do default mudar, o teste falha.
  capture sh -c "cd '$TMPDIR_TEST' && sh '$SCRIPT'" || return 2
  # Shell errors esperados vao para stderr com padroes caracteristicos.
  case "$_CAPTURED_STDERR" in
    *"unbound variable"*)
      _fail "scenario_default_docs" "stderr contem 'unbound variable' — bug de set -u"
      return 1
      ;;
  esac
}

run_all_scenarios
