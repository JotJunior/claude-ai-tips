---
name: agente-00c-runtime
description: |
  Biblioteca interna de scripts POSIX consumida pelos agentes custom do
  agente-00C (orchestrator, clarify-asker, clarify-answerer). NAO e
  user-invocavel — usuarios usam `/agente-00c`, `/agente-00c-resume` e
  `/agente-00c-abort`. Esta skill apenas empacota helpers de estado
  (state.json), validacao de schema, backups por onda e lock
  anti-concorrencia.
allowed-tools:
  - Bash
  - Read
---

# Agente-00C Runtime

Scripts POSIX que implementam as primitivas de estado da pipeline 00C.
Consumidos via tool Bash pelos agentes em `~/.claude/agents/agente-00c-*.md`.

## Layout

```
~/.claude/skills/agente-00c-runtime/
└── scripts/
    ├── state-rw.sh        # init/read/write/get/set/sha256/path-validate
    ├── state-validate.sh  # FR-008: schema + invariantes (read-only)
    └── state-lock.sh      # acquire/release/check (mkdir atomico)
```

## Convencao de path do estado

```
<projeto-alvo>/.claude/agente-00c-state/
├── state.json
├── state.json.sha256
├── .lock/                 # diretorio criado por mkdir atomico
└── state-history/
    └── onda-NNN-<iso8601>.json
```

Todos os scripts aceitam `--state-dir <path>` apontando para o diretorio
acima — nao para o `state.json` diretamente.

## Dependencia: jq

Os helpers de leitura/escrita de state.json **exigem** `jq` no PATH. Sem
jq, os scripts falham com mensagem clara orientando instalacao
(`brew install jq` no macOS / `apt install jq` em Debian/Ubuntu). Esta e
uma excecao escopada ao Principio II do toolkit (POSIX sh puro), alinhada
com o carve-out 1.1.0 da constitution para JSON estruturado.

## NAO e skill user-invocavel

Esta skill NAO tem trigger automatico — `description` indica claramente
que e infraestrutura interna. Nao deve aparecer como sugestao para o
operador. A presenca em `~/.claude/skills/` e necessaria apenas porque o
mecanismo de `cstk install` so distribui artefatos sob `global/skills/`,
`global/commands/` ou `global/agents/`.

## Estado atual

**FASE 2 do backlog em `docs/specs/agente-00c/tasks.md`.** Implementacao
operacional dos 3 scripts entregue como esqueleto + cobertura de testes
em `tests/test_state-*.sh`.
