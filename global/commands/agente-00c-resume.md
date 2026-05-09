---
description: |
  Retoma execucao 00C apos pausa por bloqueio humano (com `--resposta-bloqueio`)
  ou apos schedule entre ondas. Le o estado, valida hash de integridade
  (FR-029), aplica resposta a bloqueios pendentes (se aplicavel) e delega
  proxima onda ao agente-00c-orchestrator.
argument-hint: "[--projeto-alvo-path <path>] [--resposta-bloqueio <id>:<resposta>]"
allowed-tools:
  - Agent
  - Read
  - Write
  - Bash
---

# /agente-00c-resume

Retomada de execucao 00C conforme contrato em
`docs/specs/agente-00c/contracts/cli-invocation.md`.

## Argumentos recebidos

```
$ARGUMENTS
```

## Comportamento esperado

Execute estes passos em ordem. Use os scripts em
`~/.claude/skills/agente-00c-runtime/scripts/` para todas as operacoes
de estado — nao manipule `state.json` diretamente com jq.

### 1. Parse de argumentos

Extrair:
- `--projeto-alvo-path` (default = `cwd`)
- `--resposta-bloqueio` opcional, formato `<block-id>:<resposta>`

Defina `<SD> = <PAP>/.claude/agente-00c-state` para os comandos abaixo.

### 2. Adquirir lock

```bash
state-lock.sh acquire --state-dir <SD>
```

Exit 3 = outra execucao em andamento neste projeto. Aborte com mensagem
clara apontando para `/agente-00c-abort` ou aguardar conclusao.

### 3. Validar estado

```bash
state-validate.sh --state-dir <SD>
state-rw.sh sha256-verify --state-dir <SD>
```

Validacao falha (FR-008) OU hash divergente (FR-029) = SEM auto-correcao
(Principio III). Crie BloqueioHumano via `bloqueios.sh register` com a
ultima Decisao da execucao + diagnostico tecnico:
- Para schema invalido: `pergunta: "Estado em <SD> tem schema invalido.
  Corrigir manualmente OU autorizar abort?"`
- Para hash divergente: `pergunta: "Estado modificado externamente entre
  ondas. Aceitar estado atual OU autorizar abort?"`

Em ambos os casos, emit aviso na saida e termine sem invocar orquestrador.

### 4. Verificar status atual

```bash
status=$(state-rw.sh get --state-dir <SD> --field '.execucao.status')
```

Casos:
- `concluida` ou `abortada`: retorne mensagem informativa, NAO retome.
  ```
  Execucao em status terminal (<status>). Nada a retomar.
  Para nova execucao, use /agente-00c em outro projeto-alvo.
  ```
- `em_andamento`: retomada normal pos-schedule. Pule para passo 6.
- `aguardando_humano`: requer `--resposta-bloqueio`. Continue passo 5.

### 5. Aplicar resposta a bloqueio (se status = aguardando_humano)

#### 5.a. Sem `--resposta-bloqueio`

Liste bloqueios pendentes e termine:

```bash
bloqueios.sh list --state-dir <SD> --status aguardando
```

Output:
```
Status: aguardando_humano. Bloqueios pendentes:

  block-NNN  dec-MMM  <pergunta>
  ...

Re-execute com --resposta-bloqueio <block-id>:<sua-resposta>
```

#### 5.b. Com `--resposta-bloqueio <id>:<resp>`

Parse o argumento:
- `block_id = parte antes do primeiro ":"`
- `resposta = parte depois do primeiro ":"` (preserve `:` adicionais)

Sanitize a resposta:
```bash
resposta_safe=$(printf '%s' "$resposta" | sanitize.sh limit-length --max 2000)
```

Aplique:
```bash
bloqueios.sh respond --state-dir <SD> --block-id <block_id> --resposta "$resposta_safe"
```

Erros:
- `bloqueio nao encontrado`: emit lista de bloqueios validos + retorne.
- `nao esta em status aguardando`: bloqueio ja respondido — informe ao
  operador, mas continue (status pode ja ter voltado para `em_andamento`
  via outro respond).

Apos `respond`, se `bloqueios.sh count --pending-only` retornar 0,
`.execucao.status` ja esta de volta para `em_andamento` automaticamente.
Caso contrario, ainda ha pendentes — liste-os e instrua o operador a
chamar `/agente-00c-resume` novamente com mais respostas.

### 6. Spawnar agente-orquestrador (continuacao da pipeline)

Use a tool Agent:

```
Agent(
  description: "Continuar pipeline 00C apos retomada",
  subagent_type: "agente-00c-orchestrator",
  prompt: """
    Voce esta sendo invocado como CONTINUACAO de uma execucao 00C
    existente (NAO uma nova execucao).

    Context:
    - state-dir: <SD>
    - projeto-alvo-path: <PAP>
    - feature-dir: <PAP>/docs/specs/<feature> (deduzir de
      .etapa_corrente e estrutura existente)
    - whitelist: <PAP>/.claude/agente-00c-whitelist
    - retomada_motivo: "<resume_after_block|resume_after_schedule>"

    Comece pelo Loop principal — passo 2 (start nova onda) — pulando o
    item 1 (lock + validate + sha256-verify) que ja foi feito por este
    /agente-00c-resume.

    Use as primitivas operacionais documentadas no seu prompt
    (~/.claude/agents/agente-00c-orchestrator.md) sem desvios.
  """
)
```

Aguarde retorno do orquestrador (uma mensagem de sumario).

### 7. Liberar lock

```bash
state-lock.sh release --state-dir <SD>
```

### 8. Apresentar resultado ao operador

Imprima o sumario retornado pelo orquestrador, anotando que e retomada:

```
Agente-00C retomado.
Execucao: <id>
Tipo: <retomada apos bloqueio|retomada apos schedule>
[sumario do orquestrador aqui]
```

## Estado atual

**FASE 7.2 — operacional.** Depende das primitivas instaladas via
`cstk install`: `~/.claude/skills/agente-00c-runtime/scripts/`. Em caso
de skill ausente, falhe com mensagem orientando `cstk install`.
