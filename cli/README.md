# cstk — Claude Specs Toolkit CLI

CLI em POSIX sh para instalar, atualizar e auditar skills do toolkit. Este
diretorio contem o codigo fonte do CLI; a documentacao de design completa
vive em [`../docs/specs/cstk-cli/`](../docs/specs/cstk-cli/).

**Status atual**: FASE 1.1 do backlog — scaffold + dispatch funcionais.
Subcomandos `install`, `update`, `self-update`, `list`, `doctor` ainda nao
implementados; tentativas de invoca-los retornam exit 1 com mensagem clara.

## Layout

```
cli/
├── cstk         # executavel principal (POSIX sh)
├── VERSION      # tag de versao (dev: "0.0.0-dev"; release: preenchida pelo build)
├── lib/         # bibliotecas modulares por subcomando
└── README.md    # este arquivo
```

## Uso em dev (antes de release)

```sh
# Da raiz do repo:
./cli/cstk --version        # → cstk 0.0.0-dev
./cli/cstk --help
./cli/cstk help install     # aponta para o contrato
```

## Instalacao (quando release estiver pronta)

O one-liner de bootstrap sera documentado em `README.md` na raiz do repo
apos FASE 3.2 do backlog (`cli/install.sh`).

## Convencoes

- POSIX sh: `#!/bin/sh`, `set -eu`, sem bash-isms (Constitution 1.1.0 §II).
- Saida de dados em stdout; mensagens humanas + summaries em stderr.
- Exit codes: 0 OK, 1 erro geral, 2 uso, 3 lock, 4 edit local, 10 check-available.
- `$CSTK_LIB` override localiza lib/ durante testes.
- `$CSTK_VERSION_FILE` override localiza VERSION durante testes.

## Desenvolvimento

Veja [`../docs/specs/cstk-cli/tasks.md`](../docs/specs/cstk-cli/tasks.md) para
o backlog. Rodar testes:

```sh
sh tests/cstk/test_cstk-main.sh    # direto (FASE 1.1)
./tests/run.sh cstk                # via suite (apos FASE 9.3.1)
```
