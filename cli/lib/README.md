# cli/lib/ — Bibliotecas modulares por subcomando

Cada subcomando do `cstk` tem sua biblioteca `<comando>.sh` aqui. O
`cstk` principal sourcea a lib correspondente via convencao:

- `cstk install ...` → sourcea `install.sh` e chama `install_main "$@"`
- `cstk self-update ...` → sourcea `self-update.sh` e chama `self_update_main "$@"`
  (hifens no nome do comando viram underscores no nome da funcao)

## Libs planejadas (ordem de implementacao conforme tasks.md)

| Arquivo | Fase | Responsabilidade |
|---------|------|------------------|
| `common.sh` | 1.2 | `log_info`/`log_warn`/`log_error`, detect TTY, constantes |
| `compat.sh` | 1.2 | detect `sha256sum` vs `shasum`; date portable |
| `http.sh` | 1.2 | wrappers `curl` com error mapping |
| `lock.sh` | 1.2 | lockfile via `mkdir` + trap cleanup |
| `tarball.sh` | 1.2 | download + extract em tempdir |
| `hash.sh` | 1.2 | hash determinista de diretorio (tar + sha256) |
| `manifest.sh` | 2.1 | TSV manifest de skills instaladas |
| `profiles.sh` | 2.2 | resolve perfis para set de skills |
| `install.sh` | 3.1 | comando install |
| `update.sh` | 4.1 | comando update com politica de conflito |
| `self-update.sh` | 5.1 | comando self-update atomico |
| `list.sh` | 6.1 | comando list |
| `doctor.sh` | 6.2 | comando doctor |
| `hooks.sh` | 7.1 | deteccao de jq + merge settings.json (**unico arquivo com `jq`**, condicao b do carve-out 1.1.0) |
| `ui.sh` | 8.1 | modo interativo numerado |

## Convencoes

- POSIX sh; sem bash-isms; Principio II da Constitution 1.1.0 integral.
- Cada lib define `<cmd>_main "$@"` como entry point.
- Libs de suporte (`common`, `compat`, `http`, `lock`, `tarball`, `hash`,
  `manifest`, `profiles`) definem funcoes utilitarias (sem `_main`).
- Libs usam as constantes `CSTK_EXIT_*` definidas em `cli/cstk`.
- Sourcing: comandos em `cli/cstk`; libs de suporte sao sourceadas pelas
  libs de comando conforme dependencia.
