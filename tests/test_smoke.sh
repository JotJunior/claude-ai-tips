#!/bin/sh
# test_smoke.sh — verifica que o runner descobre test_*.sh no diretorio.
# Nao testa nenhum script do toolkit; existe apenas para sanidade do pipeline.
#
# Esperado: quando rodado via tests/run.sh, aparece '# test_smoke.sh' na saida
# seguido da linha 'ok 1 - test_smoke.sh :: scenario_smoke'.
#
# Este arquivo serve como modelo minimo de um test case valido.

# NOTA: deliberadamente NAO usamos 'set -eu' em arquivos de teste. O harness
# sinaliza falha via return codes explicitos (0/1/2); set -e mataria o
# scenario no meio de assertion que testa condicao de falha, e set -u
# quebra acesso defensivo a variaveis como _CAPTURED_STDOUT antes da
# primeira captura. Scenarios DEVEM usar '|| return 1' apos cada assert.

. "${TESTS_ROOT:-$(cd "$(dirname "$0")" && pwd)}/lib/harness.sh"

scenario_smoke() {
  # Scenario mais simples possivel: uma unica assercao sobre 'true'.
  assert_exit 0 true || return 1
}

run_all_scenarios
