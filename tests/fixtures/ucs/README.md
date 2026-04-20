# Fixtures: ucs/

Fixtures de entrada para testes de `global/skills/create-use-case/scripts/next-uc-id.sh`.
Cada subdiretorio representa um estado distinto do diretorio de UCs.

| Fixture | Conteudo | Alvo de teste |
|---------|----------|---------------|
| `empty/` | diretorio sem UCs (so `.gitkeep`) | `next-uc-id.sh AUTH` deve retornar `UC-AUTH-001` |
| `with-auth/` | UC-AUTH-001 + UC-AUTH-002 | `next-uc-id.sh AUTH` deve retornar `UC-AUTH-003` |
| `multi-domain/` | UC-AUTH-001, UC-CAD-001, UC-CAD-002, UC-PED-001 | `AUTH` retorna 002; `CAD` retorna 003; `PED` retorna 002 — nao confunde dominios |

## Como usar

No test_next-uc-id.sh:

```sh
scenario_foo() {
    fixture "ucs/with-auth" || return 1
    assert_exit 0 sh "$SCRIPT" AUTH --dir="$TMPDIR_TEST" || return 1
    assert_stdout_contains "UC-AUTH-003" || return 1
}
```

Nota: o `fixture` helper copia `tests/fixtures/ucs/with-auth/.` (conteudo)
para `$TMPDIR_TEST/`. Os arquivos UC-*.md ficam no raiz do tmpdir.
O script `next-uc-id.sh` e invocado com `--dir=$TMPDIR_TEST`.

O `.gitkeep` em `empty/` existe apenas para que git versione o diretorio
vazio; o script o ignora (nao e arquivo UC-*.md).
