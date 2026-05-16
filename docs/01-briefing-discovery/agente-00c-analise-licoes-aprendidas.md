---
titulo: Análise de Acertos e Erros do agente-00c — Lições para Evoluir as Skills
autor: Jot
data: 2026-05-15
fonte: relatorio bruto de exec-2026-05-11T19-59-58Z-agente-00c-novos-projetos (material do projeto-alvo, NAO incluido neste repo)
volume_analisado: 60 ondas, 224 decisões, 10 bloqueios, 52 sugestões
audiencia: Claude Code (para aplicar mudanças nas skills)
---

# Análise de Acertos e Erros — agente-00c (primeira execução completa)

> **Como usar este documento**
> Cada recomendação tem um bloco `Ação para Claude Code` com o arquivo-alvo, o problema concreto e o patch sugerido. Esses blocos foram redigidos para que o Claude Code consiga aplicar a mudança diretamente, sem necessidade de tradução adicional.

---

## 1. Visão Geral da Execução

A execução foi materialmente bem-sucedida: 60 ondas, 868 testes verdes, a11y zero violações em 13 páginas, zero issues abertas no toolkit, encerramento ordenado (`dec-224`). O projeto resultou funcional com pouquíssimos ajustes manuais. Isso valida o desenho geral do agente-00c.

Ao mesmo tempo, o relatório expõe um conjunto de padrões repetidos de atrito — falsos positivos em três camadas (drift, score-de-decisão, secrets-filter), retrabalho por dessincronização de contratos, e bloqueios humanos que poderiam ter sido amortizados. Esses padrões são o foco da análise.

| Indicador | Valor | Leitura |
|---|---:|---|
| Ondas executadas | 60 | Execução longa, válida para regressão |
| Decisões auditadas | 224 | Trilha completa preservada |
| Bloqueios humanos | 10 | 5 dos 10 foram `npm install` (atrito mecânico) |
| Falsos positivos `drift.sh` | 3+ | sug-018, sug-024, sug-041, sug-051 |
| Falsos positivos `score=3` | 3 | sug-037 (TS Express 5, enum estados, regressão web) |
| Retrabalho documental | 2+ | sug-002 (session-port), sug-013/040 (tasks.md drift) |
| Falsos positivos `secrets-filter` | recorrente | sug-005, sug-049 |

---

## 2. O Que Funcionou Bem (e Por Quê)

Cada acerto abaixo está pareado com a razão estrutural que o tornou robusto — para que possamos preservá-los nas próximas evoluções.

### 2.1 Auditabilidade por Decisões (5 campos)

`state.json` + `state-decisions.sh` registraram 224 decisões com Contexto, Opções, Escolha, Justificativa e Score. Em `dec-126` o orquestrador conseguiu admitir que `dec-123` foi erro baseado em premissa falsa e corrigir — algo só possível porque a trilha estava cravada.

**Razão estrutural:** decisões com Score forçam o orquestrador a escolher entre 0..3 (trivial vs estratégica), o que cria pressão saudável para validar antes de afirmar.

### 2.2 FR-018 (proibição de `npm install` autônomo)

Os 5 bloqueios `npm install` (block-005 a block-009) são exatamente onde queríamos parar: instalação de dependência muda a superfície de ataque e exige consentimento humano. O retorno simétrico foi rápido — operador responde `opt_a` e o orquestrador continua.

**Razão estrutural:** restrição cirúrgica em ponto crítico, não restrição genérica. Auto-mode para o que é reversível; bloqueio para o que altera contratos com pacote externo.

### 2.3 Pipeline SDD em ordem rígida (briefing → constitution → specify → clarify → plan → checklist → create-tasks → execute-task)

`dec-004` a `dec-027` mostram a sequência produzindo artefatos que se alimentam: 9 princípios da constitution viraram 9 Resolved Ambiguities na spec, que viraram 22 FRs, que viraram 8 tabelas no data-model, que viraram 3 contratos REST, que viraram 10 cenários quickstart. **Cada artefato resolve ambiguidades do anterior.**

**Razão estrutural:** SDD não é sequência de documentos — é uma cadeia de gates onde cada passo destrava o seguinte. Constitution antes de specify previne princípios retrofittados; checklist antes de create-tasks previne tarefas malcalibradas.

### 2.4 Padrão repo-agregador para outbox transacional (sug-006)

`dec-014`/`dec-006` consolidou o trio (decisão + transição + enqueue) dentro de `TriagemRepo.aprovarSolicitacao()`, deixando o use case agnóstico de Kysely. Helper puro `buildCriarIssuePayload` foi reusado em FASE 6.4.

**Razão estrutural:** o agente reconheceu um padrão emergente e propôs ADR para consolidá-lo (sug-006). Esse "reconhecimento de padrão durante execução" deve ser explicitamente encorajado.

### 2.5 ADR-003 promovida a APROVADA-CONDICIONAL no handoff

Em vez de marcar LGPD como "feito" ou "pendente", a `dec-224` promoveu a ADR a `APROVADA-CONDICIONAL` com handoff explícito para DPO Fotus. Removeu ambiguidade entre "tecnicamente entregue" e "formalmente aceito".

**Razão estrutural:** estados intermediários explícitos (PROPOSTA → APROVADA-CONDICIONAL → APROVADA) protegem o operador contra ilusão de prontidão.

### 2.6 Retro a cada 50 ondas (sug-045)

A onda-050 detectou marco e gerou retro consolidada, que alimentou a FASE 11 (release notes) e expôs padrões (3 falsos positivos `score-3`, 11 ondas com `tasks.md` defasado).

**Razão estrutural:** auditoria contínua não substitui retro estruturada. Em execuções longas, marcos forçam aprendizado de meta-padrões.

### 2.7 Encerramento ordeiro sobre continuação forçada (dec-224)

Quando a fronteira é humano (npm install, droplet, parecer DPO), o agente encerrou em vez de simular progresso. Os "próximos passos" ficaram catalogados em 3 trilhas (Operador, Ops, DPO).

**Razão estrutural:** o agente entende a diferença entre "posso fazer" e "tenho permissão e contexto para fazer". Esse limite deve ser preservado em qualquer evolução do auto-mode.

---

## 3. Padrões de Erro Recorrentes

Cinco padrões dominaram o retrabalho. Cada um é classificado por raiz, frequência e custo.

### 3.1 Falsos Positivos no `drift.sh` (4 ocorrências)

| Ocorrência | Onda | Causa |
|---|:---:|---|
| sug-018 | 020 | Aspectos contam apenas UCs de produto, não backbone técnico |
| sug-024 | 022-026 | Orquestrador não atualiza `aspectos_chave_tocados` |
| sug-041 | 040 | Token matcher não faz match parcial (`mcp-jira` ≠ `integracao-bidirecional-mcp-jira`) |
| sug-051 | 060 | Detector não conhece fases operacionais (runbooks, CI/CD) |

**Raiz comum:** `drift.sh` mede com heurística mas o orquestrador trata o exit code como verdade absoluta. Quatro vezes o operador (ou o próprio orquestrador via dec auditada) precisou anular o sinal.

### 3.2 Falsos Positivos com Score 3 sem Validação Empírica (3 ocorrências — sug-037)

| Ocorrência | Onda | Afirmação errada |
|---|:---:|---|
| Express 5 tipos | 024 | "Express 5 embute tipos nativos" — falso, criou shims.d.ts (`dec-048`) |
| Enum estados | 028 | "Estados expirada/aprovada_pendente_jira não existem" (`dec-123`) — falso, eram 8 estados |
| Regressão web | 033 | Afirmou bug que não existia |

**Raiz comum:** `Score 3` (decide sem clarificar) foi atribuído sem rodar `tsc --noEmit`, `grep` ou `vitest --t`. A trilha audita a decisão mas não pede evidência.

### 3.3 `tasks.md` Defasado em Relação ao Código (sug-013, sug-040)

11 ondas (028-038) tiveram código entregue sem marcar `[x]` em `tasks.md`. FASE 8.8 inteira ficou em `[ ]` enquanto as páginas existiam, com testes, no repositório.

**Raiz comum:** `tasks.md` é fonte de verdade declarada mas a sincronização é manual e fácil de esquecer. Não há gate "código exists ⇒ task marcada".

### 3.4 Bugs Recorrentes no `secrets-filter.sh` (sug-005, sug-049)

Valores legítimos públicos por design (SAML_ISSUER, COOKIE_DOMAIN, OIDC_ISSUER) foram redatados, removendo referências necessárias a paths reais do relatório. Causou hesitação do orquestrador em escrever o report scrubbed.

**Raiz comum:** filtro trata `.env` como conjunto homogêneo de secrets, sem distinção entre identificadores públicos e segredos reais.

### 3.5 Bloqueios Humanos por Atrito Mecânico (block-005 a block-009)

5 dos 10 bloqueios foram `npm install` em workspaces diferentes. Mesmo formato, mesmo desfecho (`opt_a` ou `deps_instaladas_prosseguir_com_escopo_original`). O operador resolveu cada um manualmente.

**Raiz comum:** o briefing/plan não emite pre-flight de bootstrap. Cada workspace novo gera um bloqueio cirúrgico previsível.

### 3.6 Falsos Positivos Adicionais (system-reminders TaskCreate)

Em onda-028, sug-029 reporta 8+ system-reminders ignorados sobre TaskCreate/TaskUpdate. O agente-00c tem seu próprio sistema canônico (state.json + decisoes); reminders paralelos geram ruído.

---

## 4. Recomendações por Skill SDD

> Os blocos abaixo são endereçados ao Claude Code. Cada um indica skill, arquivo-alvo e mudança concreta.

### 4.1 `briefing` — Pre-flight de Bootstrap

**Problema:** monorepos com múltiplos workspaces produzem N bloqueios humanos de `npm install`, todos com mesma resposta.

**Ação para Claude Code:**

- **Arquivo a editar:** `skills/briefing/SKILL.md`
- **Adicionar seção** "Pre-flight de Bootstrap" ao final do template do briefing, com instrução:
  1. Identificar todos os workspaces declarados em `plan.md` §Project Structure
  2. Gerar `scripts/bootstrap-deps.sh` com uma linha `npm install --workspace=<nome> <deps_canonicas>` por workspace, agrupadas
  3. Instruir o operador a executar `bash scripts/bootstrap-deps.sh` UMA VEZ antes de `/agente-00c`
  4. Documentar no briefing que stacks multi-workspace exigem este passo
- **Justificativa registrada:** sug-021 (padrão recorrente em block-007 e block-008)
- **Critério de aceitação:** após a mudança, projeto com 2+ workspaces gera zero bloqueios `npm install` na primeira passada.

### 4.2 `specify` — Resolver `ScheduleWakeup` e Encryption Key

**Problema:** sug-016 detectou que `ScheduleWakeup` não está disponível no harness; fallback `CronCreate` exige autorização. sug-003/sug-011/sug-015 mostram divisas técnicas que deveriam ter sido FRs explícitas no spec.

**Ação para Claude Code:**

- **Arquivo a editar:** `skills/specify/SKILL.md`
- **Adicionar checklist** "Decisões de Infraestrutura Auditáveis" na geração do spec.md:
  - Política de scheduling: `autoSchedule: 'cron' | 'wakeup' | 'manual' | 'auto'` (default `auto`)
  - Política de key rotation: explicitar se SESSION_ENCRYPTION_KEY suporta versionamento (`v1:<base64>`)
  - Política de refresh proativo vs on-demand: declarar gap window aceitável (ex: 5min)
  - Cada decisão vira um FR explícito (FR-NN-INFRA-X) — não fica como dívida descoberta na onda-007
- **Justificativa registrada:** sug-003, sug-011, sug-015, sug-016
- **Critério de aceitação:** `dec-XXX` sobre key rotation ou scheduling não pode acontecer durante `execute-task` — deve estar resolvida no spec.

### 4.3 `clarify` — Spawnar Subagente Real

**Problema:** `dec-006` documenta que `clarify` rodou com orquestrador atuando in-process como answerer porque a tool Agent não estava disponível. Isso preservou o rigor mas removeu o segundo par-de-olhos que o padrão dois-atores garantia.

**Ação para Claude Code:**

- **Arquivo a editar:** `skills/clarify/SKILL.md`
- **Garantir que** o template chama explicitamente `Agent({ subagent_type: "agente-00c-clarify-answerer", ... })` e falha graciosamente para in-process apenas com warning auditado.
- **Adicionar verificação** no início da skill: testar disponibilidade da tool Agent via dry-run; se ausente, emitir `Decisao` declarando o downgrade.
- **Justificativa registrada:** `dec-006`
- **Critério de aceitação:** quando Agent tool disponível, clarify SEMPRE spawna subagente (auditável via lista de agentes em state.json).

### 4.4 `plan` — Cross-check de Convenções de Case e Schemas

**Problema:** `dec-172` e `dec-173` resolveram em FASE 8 (onda-040) uma divergência snake_case vs camelCase que existia desde o contrato (`dec-064`). Custo: testes que parseavam mocks (não payload real) mascararam o drift por 40 ondas.

**Ação para Claude Code:**

- **Arquivo a editar:** `skills/plan/SKILL.md`
- **Adicionar seção obrigatória** "Convenções de Borda" em `plan.md`, com:
  - Case style por camada (DTO backend, DTO frontend, DB columns)
  - Mapper layer: existe? onde? quem é fonte da verdade?
  - Validação Zod em qual borda (request, response, ambos)
- **Adicionar a `quickstart.md`** um cenário E2E que faz roundtrip real (não mock) cobrindo o contrato emitido pelo backend.
- **Justificativa registrada:** sug-002, sug-042, `dec-172`
- **Critério de aceitação:** zero divergência de case style descoberta após FASE 5.

### 4.5 `create-tasks` — Sincronização Bidirecional com Código

**Problema:** sug-040 mostra 11 ondas (028-038) com FASE 8.8 marcada `[ ]` enquanto o código existia. sug-013 mostra FASEs 6.4-6.7 nascendo via decisões sem voltar a `tasks.md`.

**Ação para Claude Code:**

- **Arquivo a editar:** `skills/create-tasks/SKILL.md`
- **Adicionar seção** "Sincronização com Código":
  1. Antes de executar uma tarefa, `grep` pelos arquivos canônicos da tarefa
  2. Se existem, marcar `[x]` com comentário `validado empiricamente onda-NNN`
  3. Se a decisão criou novas tarefas (sub-FASE), inseri-las no `tasks.md` no mesmo commit da decisão
- **Adicionar hook pos-onda** em `agente-00c-orchestrator`: comparar diff de arquivos da onda contra checkbox de `tasks.md`; alertar se descompassado.
- **Justificativa registrada:** sug-013, sug-040
- **Critério de aceitação:** drift entre código e `tasks.md` ≤ 1 onda.

Adicional para sub-tarefas de tipos compartilhados:
- **Subtarefa obrigatória:** quando FASE replica tipos em outro pacote (ex: Zod 4 local), incluir step "verificar paridade exata com `packages/shared-types/src/*.ts`" e teste smoke comparando `z.enum().options` (sug-028).

### 4.6 `execute-task` — Validação Empírica Antes de `Score 3`

**Problema:** três falsos positivos `score=3` (sug-037) custaram ondas adicionais. Em todos, o orquestrador afirmou problema técnico sem rodar `tsc/test/grep`.

**Ação para Claude Code:**

- **Arquivo a editar:** `skills/execute-task/SKILL.md`
- **Inserir Etapa 0** no fluxo de 9 etapas: "Validação Empírica de Premissas":
  - Antes de afirmar problema técnico com `score >= 2`, executar pelo menos uma:
    - `npx tsc --noEmit` para tipos
    - `npx vitest run -t '<descricao>'` para comportamento
    - `grep -r '<sintaxe>'` para presença de símbolo
    - Inspecionar `node_modules/<pkg>/package.json` para campos `types`/`exports`
  - **Citar output literal** no Contexto da decisão
  - Sem evidência empírica, score máximo permitido é `2`
- **Justificativa registrada:** sug-037 (3 ocorrências), `dec-048`, `dec-123`/`dec-126`
- **Critério de aceitação:** zero decisão `score=3` sem campo `Evidencia` referenciando comando executado.

Adicional sobre dynamic imports e fallback:
- **Subtarefa proibida:** dynamic import de `tests/fakes/*` em `src/` (sug-039). Mover Fakes para `src/infra/<dominio>/fake/`.

### 4.7 `validate-documentation` — Modo `--runbook`

**Problema:** sug-048 mostra que os 3 runbooks (SETUP-VPS, RESTORE-DRILL, ENV-VARS) seguiram padrão estrutural mas a verificação foi manual.

**Ação para Claude Code:**

- **Arquivo a editar:** `skills/validate-documentation/SKILL.md`
- **Adicionar perfil `--runbook`** que valida:
  - Frontmatter YAML: `title` começa com `RB-\d{3}:`, `versao`, `severidade`, `tempo-estimado`, `pre-requisitos`
  - Seções obrigatórias: Descrição, Pré-requisitos, Procedimento, Verificação/Validação, Rollback (obrigatório se severidade=crítica), Contatos
  - Ausência de `TODO|XXX|FIXME|placeholder`
  - Cross-refs: paths relativos devem existir
- **Justificativa registrada:** sug-048
- **Critério de aceitação:** novo RB-NNN é rejeitado por `validate-documentation --runbook` se faltar qualquer seção mínima.

---

## 5. Recomendações para o Orquestrador (`agente-00c-orchestrator`)

### 5.1 Mapeamento Etapa → Aspecto-Chave Automatizado

**Problema:** sug-024 mostra que o orquestrador não atualiza `.ondas[i].aspectos_chave_tocados`, resultando em `drift.sh` falsos positivos a cada poucas ondas.

**Ação para Claude Code:**

- **Arquivo a editar:** `skills/agente-00c-orchestrator/AGENT.md`
- **Adicionar passo no Loop principal** após `detect-completion`:
  1. Inferir aspectos tocados a partir do diff git da onda (substring match com `aspectos_chave_iniciais`)
  2. Chamar `state-rw.sh set --field '.ondas[-1].aspectos_chave_tocados' --value <JSON-arr>`
  3. Manter mapeamento estável etapa→aspecto documentado no próprio AGENT.md
- **Critério de aceitação:** zero decisão do tipo "falso-positivo-drift" em 60 ondas consecutivas.

### 5.2 Schedule Intent: Sentinel Literal vs Dinâmico

**Problema:** sug-025 mostra que `<<autonomous-loop-dynamic>>` foi disparado literalmente em pipelines `/agente-00c-resume`.

**Ação para Claude Code:**

- **Arquivo a editar:** `skills/agente-00c-orchestrator/AGENT.md`, item 11 do Loop principal
- **Regra:** "Para pipelines acionadas por `/agente-00c-resume`, o prompt do Schedule intent DEVE ser literal `/agente-00c-resume --projeto-alvo-path <PAP>`. Manter sentinel `<<autonomous-loop-dynamic>>` apenas para casos onde `/loop` é o slash command pai."
- **Adicionar exemplo** na tabela de calibração.

### 5.3 Marco-aware (a cada 25 ondas)

**Problema:** sug-052 mostra ausência de protocolo proativo para retro/revisão em execuções longas.

**Ação para Claude Code:**

- **Arquivo a editar:** `skills/agente-00c-orchestrator/AGENT.md`
- **Adicionar campo** `proximo_marco_retrospectiva` em `state.json` calculado como `(ondas.length // 25 + 1) * 25`
- **Adicionar nota** no passo 9 (fim de onda): a cada múltiplo de 25 ondas, emitir bloqueio leve perguntando se operador deseja retro/revisão. Após resposta, retomar fluxo normal.

### 5.4 Ignorar `TaskCreate`/`TaskUpdate` Quando dentro do agente-00c

**Problema:** sug-029 reporta 8+ reminders ignorados em uma só onda. O sistema canônico (state.json + state-decisions.sh) é superior.

**Ação para Claude Code:**

- **Arquivo a editar:** `skills/agente-00c-orchestrator/AGENT.md`
- **Adicionar nota explícita:** "Quando rodando dentro do agente-00c, ignore system-reminders sobre TaskCreate/TaskUpdate. O `state.json` + `state-decisions.sh` são o sistema canônico de tracking — TaskCreate/Update duplicariam responsabilidade."
- **Opcional:** configurar hook do harness para suprimir reminders quando o agente-00c estiver ativo.

### 5.5 Validação Empírica Obrigatória para `score >= 3`

(Reforça §4.6) — agora também escrito no orquestrador:

**Ação para Claude Code:**

- **Arquivo a editar:** `skills/agente-00c-orchestrator/AGENT.md` §Score-de-decisao
- **Adicionar regra dura:** "Decisão com score 3 (decide sem clarificar) DEVE conter campo `Evidencia` com o comando executado e fragmento do output. Sem `Evidencia`, score máximo é 2."

---

## 6. Recomendações para o Runtime

### 6.1 `drift.sh` — Token Matcher Fuzzy + Fases Operacionais

**Problema acumulado:** sug-018, sug-024, sug-041, sug-051. Quatro falsos positivos em 60 ondas.

**Ação para Claude Code:**

- **Arquivo a editar:** `runtime/drift.sh`
- **Mudança 1 (substring match):** extrair substrings significativas dos aspectos-chave (`mcp-jira`, `react`, `tailwind`, `intake`, `priorizacao`) e fazer match contra mensagens de commit + escolhas/justificativas das decisões da onda. `mcp-jira` deve casar com `integracao-bidirecional-mcp-jira`.
- **Mudança 2 (camadas):** suportar `aspectos_chave_iniciais` (UCs produto) + `aspectos_chave_tecnicos` (auth, sessão, db, infra) + `aspectos_chave_operacionais` (runbooks, CI/CD). Onda toca aspectos se hits em qualquer camada.
- **Mudança 3 (janela móvel):** trocar "5 ondas consecutivas sem hits = abort" por "5 sem hits em janela de 12 = warn; 8 sem hits em janela de 12 = abort". Backbone técnico legítimo (FASE 4.x, 7.x) não deve disparar abort.
- **Mudança 4 (primitivo mark-touched):** adicionar comando `drift.sh mark-touched --aspecto <X>` para que o orquestrador registre toque explicitamente quando inferência automática falhar.
- **Mudança 5 (debug list):** log do drift deve enumerar candidates por onda — ajuda diagnóstico.

### 6.2 `secrets-filter.sh` — Allow-list de Identificadores Públicos

**Problema:** sug-005, sug-049. SAML_ISSUER, COOKIE_DOMAIN, OIDC_ISSUER são públicos por design mas viram `[REDACTED-ENV]`.

**Ação para Claude Code:**

- **Arquivo a editar:** `runtime/secrets-filter.sh`
- **Adicionar arquivo** `.secrets-filter-ignore` com 1 chave por linha:
  ```
  SAML_ISSUER
  OIDC_ISSUER
  COOKIE_DOMAIN
  MICROSOFT_TENANT_ID
  PROJECT_NAME
  APP_NAME
  PUBLIC_*
  NEXT_PUBLIC_*
  ```
- **Modificar passo 5** do filtro: pular chaves listadas no ignore.
- **Fallback heurístico:** valores com < 30 chars sem caracteres especiais E que matchem padrão de slug não são tratados como secret.
- **Critério de aceitação:** report scrubbed da execução [REDACTED-ENV] preserva `docs/specs/[nome-feature]/` legível.

### 6.3 `state-rw.sh` — Helper de Inferência de Aspectos

**Problema:** complementa §5.1. Hoje só existe `set` raw.

**Ação para Claude Code:**

- **Arquivo a editar:** `runtime/state-rw.sh`
- **Adicionar comando** `state-rw.sh infer-aspectos --from-git-diff` que:
  1. Executa `git diff --name-only` desde início da onda
  2. Aplica matcher fuzzy contra `aspectos_chave_iniciais`
  3. Retorna JSON array para `set --field '.ondas[-1].aspectos_chave_tocados'`
- **Integração:** orquestrador chama no passo de finalização da onda (vide §5.1).

### 6.4 `agente-00c-runtime` — Inicialização de Aspectos no `briefing`

**Problema:** sug-004. A primeira onda nunca chama `drift.sh init`, deixando `aspectos_chave_iniciais=null`. Resultado: o detector funciona em modo `warn` mas nunca consegue `abort` legitimamente.

**Ação para Claude Code:**

- **Arquivo a editar:** `skills/agente-00c/AGENT.md` ou template do `/agente-00c`
- **Mudança:** na PRIMEIRA onda do orquestrador, após gerar `BRIEFING.md`, extrair 3-7 aspectos-chave e chamar `drift.sh init` ANTES de finalizar a onda.
- **Fallback:** criar `/agente-00c-resume --init-aspectos <JSON-ARRAY>` para projetos que já passaram da onda-001 com `aspectos_chave_iniciais=null` (relaxar idempotência atual).

### 6.5 `agente-00c-runtime/refresh` — Mutex Cross-Pod

**Problema:** sug-019. Race condition entre `auth-middleware` on-demand refresh e job `refresh-perfil-5min`.

**Ação para Claude Code:**

- **Recomendação para projetos com auth:** documentar no template `agente-00c-runtime` que em multi-pod a sincronização deve usar `pg_try_advisory_xact_lock(hashtext(sid))` ou `SELECT FOR UPDATE` na transação. Para single-node POC, `RefreshMutex` em memória basta. Mover a chamada ao IdP para DENTRO da transação serializa via lock de linha.

---

## 7. Plano de Ação Priorizado

| Prioridade | Mudança | Skill / Runtime | Onde |
|:---:|---|---|---|
| P0 | Validação empírica obrigatória para `score >= 3` | `execute-task`, `agente-00c-orchestrator` | §4.6, §5.5 |
| P0 | Token matcher fuzzy + fases no `drift.sh` | runtime | §6.1 |
| P0 | Allow-list no `secrets-filter.sh` | runtime | §6.2 |
| P1 | Pre-flight de bootstrap no `briefing` | `briefing` | §4.1 |
| P1 | Sincronização bidirecional `tasks.md` ↔ código | `create-tasks` + orquestrador | §4.5 |
| P1 | Mapeamento etapa → aspecto automatizado | `agente-00c-orchestrator` + `state-rw.sh` | §5.1, §6.3 |
| P2 | Cross-check de convenções de case no `plan` | `plan` | §4.4 |
| P2 | Decisões de infra como FRs explícitas | `specify` | §4.2 |
| P2 | Init de aspectos no briefing | runtime | §6.4 |
| P3 | Marco-aware a cada 25 ondas | `agente-00c-orchestrator` | §5.3 |
| P3 | Schedule intent literal | `agente-00c-orchestrator` | §5.2 |
| P3 | Modo `--runbook` no `validate-documentation` | `validate-documentation` | §4.7 |
| P3 | Spawnar subagente real em `clarify` | `clarify` | §4.3 |
| P3 | Suprimir reminders TaskCreate sob agente-00c | harness/orquestrador | §5.4 |

---

## 8. Métricas para Validar Evolução das Skills

Quando aplicar as mudanças, medir na próxima execução:

| Métrica | Baseline (esta execução) | Meta após mudanças |
|---|:---:|:---:|
| Bloqueios `npm install` | 5 | 0 (via pre-flight) |
| Falsos positivos `drift.sh` | 4 | ≤ 1 |
| Decisões `score=3` sem evidência | 3 | 0 |
| Ondas com `tasks.md` defasado | 11 | ≤ 2 |
| Falsos positivos `secrets-filter` | recorrente | 0 em paths públicos |
| Retrabalho de DTO/case style | 1 (40 ondas atrasado) | 0 (detectado em FASE 5) |

---

## 9. Lições de Meta-Processo

Três lições que transcendem skills individuais e devem informar futuras evoluções do toolkit:

**1. Heurísticas precisam de hatch de auditoria.** `drift.sh` é heurístico — perfeito não é meta. Mas o exit code foi tratado como verdade absoluta. A solução não é tornar a heurística perfeita; é dar ao orquestrador o vocabulário para reconhecer e registrar falsos positivos auditavelmente (vide `dec-171`).

**2. Score sem evidência é só convicção.** Score 3 deveria significar "decido sem clarificar porque tenho evidência empírica". Três casos mostraram que score 3 estava significando "decido sem clarificar porque tenho convicção". A diferença é grande e custou ondas.

**3. Atrito mecânico merece amortização, não automação.** Os 5 bloqueios `npm install` são exatamente onde queremos parar — mas em batch, não em 5 round-trips. Pre-flight resolve sem afrouxar FR-018.

---

## Apêndice A — Referências Cruzadas

Sugestões originais do relatório-fonte que sustentam cada recomendação:

| Recomendação | Sugestões originais |
|---|---|
| Validação empírica `score=3` | sug-037 |
| Token matcher `drift.sh` | sug-018, sug-024, sug-041, sug-051 |
| Allow-list `secrets-filter.sh` | sug-005, sug-049 |
| Pre-flight bootstrap | sug-021 |
| Sincronização `tasks.md` | sug-013, sug-040 |
| Mapeamento aspectos | sug-024 |
| Convenções de case | sug-002, sug-042 |
| FRs de infra | sug-003, sug-011, sug-015, sug-016 |
| Init aspectos no briefing | sug-004 |
| Marco-aware | sug-045, sug-052 |
| Schedule intent literal | sug-025 |
| Modo runbook | sug-048 |
| Subagente real em clarify | dec-006 |
| Suprimir reminders TaskCreate | sug-029 |
| Paridade Zod shared-types/web | sug-028 |
| Dynamic import de fakes | sug-039 |
