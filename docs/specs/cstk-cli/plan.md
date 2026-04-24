# Implementation Plan: cstk CLI

**Feature**: `cstk-cli` | **Date**: 2026-04-22 | **Spec**: [spec.md](./spec.md)

## Summary

A feature introduz `cstk` — CLI POSIX sh para instalar, atualizar e auditar skills
do toolkit em escopo global (`~/.claude/skills/`) ou de projeto (`./.claude/skills/`),
com self-update do proprio binario. Abordagem tecnica: shell script unico orquestrando
`curl` + `tar` + `sha256sum` + `awk`, consumindo GitHub Releases como fonte de verdade
(tarball versionado + checksum), com manifest TSV plain-text para rastrear o estado
instalado. Dependencia opcional em `jq` apenas para o fluxo de hooks em escopo de
projeto (com fallback manual-paste). Arquitetura alinhada com Principios I (SDD
recursivo), II (POSIX puro), IV (zero telemetria) e V (profundidade) da constituicao.

## Technical Context

**Language/Version**: POSIX sh (`#!/bin/sh`, `set -eu`) — compatibilidade com
dash/ash/bash-em-modo-POSIX. Nao usa bash-isms (sem arrays, sem `[[ ]]`, sem `<<<`).
**Primary Dependencies**: Ferramentas POSIX canonicas (`curl`, `tar`, `awk`, `grep`,
`sed`, `mv`, `find`, `mkdir`, `sort`, `date`). SHA: `sha256sum` (linux) ou `shasum -a
256` (macOS) — CLI detecta no boot. Dep OPCIONAL: `jq` (apenas para merge de
`settings.json` em perfis language-*, com fallback).
**Storage**: Filesystem local. Nao ha DB. Manifest em `<scope>/.cstk-manifest` (TSV),
catalog embedded no tarball de release, CLI binario em `~/.local/bin/cstk` +
biblioteca em `~/.local/share/cstk/lib/`.
**Testing**: Suite `tests/` ja existente no repo (POSIX sh puro, ver
`docs/specs/shell-scripts-tests/`). Novo diretorio `tests/cstk/` com scenarios do
`quickstart.md` como testes automatizados. Principio de "um `.sh` novo = um
`test_<nome>.sh` novo" aplica (ver CLAUDE.md).
**Target Platform**: Desktop dev (macOS, Linux). Nao ha plataforma server. Shell
POSIX garante portabilidade; sem dep em GNU extensions alem das ja documentadas em
`cli/lib/compat.sh`.
**Project Type**: CLI (single binary user-space, sem daemon, sem servidor).
**Performance Goals**: Instalacao inicial < 30s em banda larga tipica (SC-001).
Update sem mudancas = zero writes (SC-002). Hash de skill < 100ms por skill em HDD
padrao (20 skills = < 2s total, aceitavel para `doctor` e `update`).
**Constraints**:
- Zero toolchain de build (nao compilar nada) — distribuicao = tarball + `chmod +x`.
- Zero telemetria (Principio IV).
- Zero dependencia obrigatoria fora do POSIX canonico + `curl` + `sha256sum`.
- `jq` e a UNICA dep opcional aceita, exclusivamente para merge de JSON na feature
  de hooks (documentada como Constitution Exception abaixo).
**Scale/Scope**: Single-user, single-machine. Catalog atual = ~20 skills global +
skills language-related (Go, .NET). Ordem de magnitude de crescimento esperado:
< 100 skills ao longo da vida do toolkit. Nada exige otimizacao alem do POSIX
naive.

## Constitution Check

*GATE: Deve passar antes do Phase 0. Re-checar apos Phase 1.*

### First pass (pre Phase 0)

| Principio | Status | Notas |
|-----------|--------|-------|
| I. SDD recursivo | PASS | Esta feature esta no pipeline SDD: spec → clarify → plan (aqui). Create-tasks e analyze virao antes da execucao. |
| II. POSIX sh puro, zero deps | PASS | CLI em POSIX sh; dep obrigatoria apenas em POSIX canonico + `curl`/`tar`/`sha256sum`. `jq` opcional — ver secao Complexity Tracking. |
| III. Formato canonico de skill | N/A | `cstk` e CLI, nao skill. Nao carrega SKILL.md. |
| IV. Zero coleta remota | PASS | Trafego HTTP apenas para GitHub (fetch iniciado pelo usuario); zero analytics/telemetria. |
| V. Profundidade > adocao | PASS | Feature reduz retrabalho documentado no CLAUDE.md (drift source vs installed) — objetivo direto do Principio V. |

### Second pass (pos Phase 1)

| Principio | Status | Notas |
|-----------|--------|-------|
| I. SDD recursivo | PASS | Plan + research + data-model + contracts + quickstart produzidos. Artefatos SDD-completos. |
| II. POSIX sh puro, zero deps | PASS | Design concreto (research Decision 1-3, 7, 8) nao introduz nenhuma violacao. `jq` segue como UNICA exception, escopo confinado, documentada abaixo. Merge de JSON sem `jq` explicitamente REJEITADO em vez de mal-implementado. |
| III. Formato canonico de skill | N/A | Nenhum artefato do design e uma skill. |
| IV. Zero coleta remota | PASS | Todas as chamadas HTTP do design sao fetch explicito de release pelo usuario; nenhuma no background; nenhum metrics endpoint. |
| V. Profundidade > adocao | PASS | Design prioriza semantica solida (manifest versionado, atomic self-update, lock) sobre features "vistosas". Dry-run e doctor existem para reduzir retrabalho, alinhado com Principio V. |

## Project Structure

### Documentation (this feature)

```
docs/specs/cstk-cli/
├── spec.md
├── plan.md              # This file
├── research.md          # Phase 0: 10 decisions
├── data-model.md        # Phase 1: 5 entities
├── contracts/
│   └── cli-commands.md  # Phase 1: 7 commands
└── quickstart.md        # Phase 1: 12 scenarios
```

### Source Code (repository root)

Estrutura-alvo apos implementacao. Paths marcados (NEW) nao existem hoje.

```
/Users/jot/Projects/_lab/Jot/misc/claude-ai-tips/
├── CHANGELOG.md
├── CLAUDE.md
├── README.md
├── docs/
│   ├── 01-briefing-discovery/
│   ├── constitution.md
│   └── specs/
│       ├── cstk-cli/                # (NEW — esta feature)
│       ├── fix-validate-stderr-noise/
│       └── shell-scripts-tests/
├── global/
│   └── skills/                       # (catalog fonte — nao muda nesta feature)
│       ├── advisor/
│       ├── analyze/
│       └── ...
├── language-related/
│   ├── go/
│   │   ├── skills/
│   │   ├── hooks/
│   │   └── settings.json
│   └── dotnet/
├── tests/                             # suite POSIX ja existente
│   ├── run.sh
│   ├── test_<...>.sh                  # tests existentes
│   └── cstk/                          # (NEW) tests do CLI
│       ├── test_install.sh
│       ├── test_update.sh
│       ├── test_self-update.sh
│       ├── test_doctor.sh
│       ├── test_list.sh
│       └── fixtures/                  # releases mockadas, tarballs de teste
└── cli/                               # (NEW) codigo do CLI
    ├── cstk                            # (NEW) script principal, chmod +x
    ├── lib/
    │   ├── common.sh                   # logging, exit codes, util
    │   ├── compat.sh                   # detect sha256sum vs shasum, date formats
    │   ├── http.sh                     # curl wrappers, error mapping
    │   ├── tarball.sh                  # extract, validate, hash-dir (determ. tar)
    │   ├── manifest.sh                 # read/write/update manifest TSV
    │   ├── profiles.sh                 # resolve profile → skill set
    │   ├── lock.sh                     # mkdir lock + trap cleanup
    │   ├── install.sh                  # cmd: install
    │   ├── update.sh                   # cmd: update
    │   ├── self-update.sh              # cmd: self-update
    │   ├── doctor.sh                   # cmd: doctor
    │   ├── list.sh                     # cmd: list
    │   ├── hooks.sh                    # detect jq, merge settings.json or print
    │   └── ui.sh                       # interactive selector
    ├── install.sh                      # (NEW) bootstrap / one-liner target: baixa ultima
    │                                   # release, copia cstk + lib/ para ~/.local/bin e
    │                                   # ~/.local/share/cstk/
    └── README.md                       # (NEW) desenvolvedor-facing, nao user-facing
```

**Structure Decision**: codigo do CLI em `cli/` paralelo a `global/skills/` e
`language-related/`, para deixar claro que CLI e uma entidade separada do catalog.
Subdir `cli/lib/` agrupa scripts modulares — um arquivo por command + arquivos
utilitarios transversais. Isso alinha com o tarball layout da Decision 6 do research,
onde `cli/` e reempacotado inteiro em toda release.

Testes em `tests/cstk/` (novo subdiretorio do `tests/` ja existente) para manter
integracao com `tests/run.sh` e `--check-coverage` (regra do CLAUDE.md: todo `.sh`
em `global/skills/*/scripts/` exige teste; **extenderemos** essa regra para incluir
`cli/lib/*.sh` — anotar em `tasks.md` para atualizar `run.sh`).

## Complexity Tracking

### Optional-dep registry: `jq` em `cli/lib/hooks.sh` (conforme constitution 1.1.0)

**Base legal**: constitution 1.1.0 §Principio II subsecao "Optional dependencies
with graceful fallback" autoriza deps nao-POSIX quando as tres condicoes
cumulativas sao satisfeitas. Abaixo, demonstracao ponto-a-ponto de conformidade:

- **(a) Uso opcional com fallback verificavel**: CLI detecta `jq` via
  `command -v jq`. Sem `jq`, CLI imprime em stderr o bloco JSON exato para paste
  manual no `./.claude/settings.json` do projeto (FR-009d). Fallback coberto por
  teste automatizado 7.1.5 do backlog (Scenario 5 do quickstart — "install
  project sem jq").
- **(b) Confinamento em unico arquivo**: todas as referencias a `jq` residem
  exclusivamente em `cli/lib/hooks.sh`. Verificavel em qualquer momento via
  `grep -rn '\bjq\b' cli/` retornando apenas esse path. Nenhuma outra parte
  do CLI (manifest TSV, profiles, install, update, self-update, doctor, list,
  UI interativa, lock, tarball, hash) referencia `jq`.
- **(c) Declaracao explicita**: esta subsecao do plan.md (primaria), somada a
  FR-009d da [spec.md](./spec.md) e a citacao recíproca na
  [constitution](../../constitution.md) §Principio II subsecao "Optional
  dependencies with graceful fallback" que cita este caso como primeiro concreto.

**Por que o merge JSON exige `jq` quando disponivel**:

- FR-009d requer mesclar hooks da linguagem em `./.claude/settings.json` de um
  projeto sem corromper configs pre-existentes do usuario.
- Mesclagem correta de JSON arbitrario NAO e fazivel em POSIX sh puro com
  seguranca aceitavel. Tentativas com `awk`/`sed` produzem parsers parciais que
  quebram em edge cases (strings com chaves, valores multilinhas, unicode,
  nested objects).
- Sobrescrever arquivo existente foi rejeitada porque apaga configuracao
  nao-relacionada do usuario — pior que nao mesclar.
- Fallback paste-manual satisfaz condicao (a) porque mesmo sem `jq` a CLI
  entrega resultado correto (usuario aplica manualmente), apenas com UX degradada.

**Limites deste registry (nao sao sunset — sao fronteiras)**:

- O carve-out NAO se estende para outras partes do CLI (manifest, profiles,
  catalog). Estes usam TSV plain-text justamente para nao precisar de `jq`.
- Se no futuro um formato JSON for necessario em outra parte, novo caso no
  registry exige nova demonstracao das 3 condicoes naquele arquivo, nao herda
  deste.
- Caso uma solucao POSIX confiavel para merge JSON surja (ex: utility oficial em
  coreutils), considerar migrar e remover o caso do registry.

| Caso registrado | Por Que Necessario | Como satisfaz carve-out 1.1.0 |
|-----------------|-------------------|-------------------------------|
| `jq` opcional em `cli/lib/hooks.sh` | Merge seguro de JSON em settings.json pre-existente do projeto, mantendo config nao-relacionada intacta | (a) fallback paste-manual coberto por teste 7.1.5; (b) confinado em 1 arquivo, grep verificavel; (c) declarado nesta subsecao + spec.md §FR-009d + constitution §II subsecao |

## Outras notas de implementacao

### Self-update: primeira release e bootstrap

Na primeira release publicada, self-update nao tem versao anterior com que
comparar. A primeira instalacao usa um one-liner documentado no README
(`curl <url-ultima-release> | sh`) que baixa o `cli/install.sh` bootstrap. A partir
da segunda release em diante, `cstk self-update` substitui o one-liner.

### Schema versioning do manifest

Header do manifest (`# cstk manifest v1`) permite evoluir formato sem breaking. Se
uma release futura precisar de campo novo: incrementa para `v2`, CLI detecta e migra
automaticamente no primeiro write. CLI antigo lendo manifest `v2` deve abortar com
mensagem clara pedindo self-update.

### Testabilidade de self-update em CI

Scenario 6 e 7 do quickstart exigem release mock. Fixtures em
`tests/cstk/fixtures/releases/` contem tarballs pre-preparados simulando versoes
diferentes. Variavel `CSTK_RELEASE_URL` override permite apontar CLI para fixture
local em vez do GitHub real durante testes.
