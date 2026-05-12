# Changelog

Todas as mudanças relevantes deste projeto são documentadas aqui.

O formato segue [Keep a Changelog](https://keepachangelog.com/pt-BR/1.1.0/) e
este projeto adere a [Semantic Versioning](https://semver.org/lang/pt-BR/).

## [Unreleased]

## [3.5.1] - 2026-05-12

### Fixed

- **`/agente-00c` falhava em install default por falta da skill
  `agente-00c-runtime`**: a runtime (infra interna que provê
  `state-rw.sh`, `path-guard.sh`, `whitelist-validate.sh` etc. ao
  orchestrator) so constava no profile `all` — `cstk install` default
  (profile `sdd`) instalava comandos e agentes do 00C mas deixava a
  runtime de fora. Resultado: `/agente-00c` falhava na primeira chamada
  Bash do orchestrator com referencia a script ausente.

  Tres camadas de fix:

  - `scripts/profiles.txt.in`: `agente-00c-runtime` agora pertence a
    `sdd` E `complementary` (alem do `all` ja existente). Qualquer
    install default carrega a runtime junto.
  - `cli/lib/00c-bootstrap.sh::_00c_check_deps`: pre-flight do
    `cstk 00c` estende para command + runtime executavel +
    orchestrator. Antes so checava o `.md` do command — instalacao
    parcial passava silenciosa e quebrava so dentro de uma onda.
  - `global/agents/agente-00c-orchestrator.md`: nova secao "Pre-flight
    da execucao" antes do loop de onda, com Bash check programatico de
    `state-rw.sh`/`state-lock.sh`/`path-guard.sh` (+x). Substitui a
    interpretacao em natural-language que estava produzindo
    diagnosticos hallucinados.

  Regression test em `tests/cstk/test_build-release.sh` garante que o
  profile `sdd` inclui `agente-00c-runtime` permanentemente.

- **Orchestrator (sub-agent) nao pode invocar `ScheduleWakeup` de forma
  sobrevivente**: o thread do sub-agent termina ao retornar o sumario
  para o slash command pai. Qualquer wakeup agendado pelo orchestrator
  firmaria — se firmasse — para contexto ja extinto. O resultado era o
  erro recorrente `Proxima onda agendada: nenhuma (ScheduleWakeup
  indisponivel — operador retoma via agente-00c-resume)`.

  Refactor para o padrao decide-aqui-executa-la:

  - `global/agents/agente-00c-orchestrator.md`: `ScheduleWakeup`
    removido de `allowed-tools`. Step 11 reescrito — orchestrator agora
    DECIDE `delaySeconds` + `reason` e grava o ISO planejado em
    `.ondas[-1].proxima_onda_agendada_para`. Step 13 (sumario)
    formaliza linha `Schedule intent: delaySeconds=N; reason="..."; prompt="..."`
    (ou `Schedule intent: none; motivo=<X>`) que o pai parseia.
  - `global/commands/agente-00c.md` e `global/commands/agente-00c-resume.md`:
    `ScheduleWakeup` adicionado ao `allowed-tools`. Novo step "Schedule
    da proxima onda" parseia a linha do sumario do orchestrator e
    invoca `ScheduleWakeup` no thread do pai. Em caso de falha, limpa
    `.ondas[-1].proxima_onda_agendada_para` via `state-rw.sh set`.

  Comportamento externo: `/agente-00c` e `/agente-00c-resume` agora
  realmente agendam a proxima onda quando o status e `em_andamento` sem
  bloqueios. O sumario ao operador mostra ISO real do wakeup, nao
  intencao do sub-agent.

## [3.5.0] - 2026-05-09

### Added

- **Subcomando `cstk 00c <path>` — bootstrap interativo do agente-00C
  (FASE 12 do `cstk-cli`)**: atalho recomendado para iniciar uma sessao
  do agente-00C. Cria diretorio do projeto-alvo, valida path, coleta
  parametros via prompts (descricao, stack JSON, whitelist de URLs) e
  invoca `claude` ja com `/agente-00c '<args>'` auto-submetido como
  primeiro turno. Elimina friccao de `mkdir`/`cd` + memorizar a sintaxe
  da slash command.

  - **Validacao defensiva** (FR-016b): rejeita path traversal `..`,
    rejeita 14 zonas de sistema (`/`, `/etc`, `/usr`, `/var`, `/bin`,
    `/sbin`, `/boot`, `/proc`, `/sys`, `~/.ssh`, `~/.gnupg`, `~/.aws`,
    `~/.config/claude` + canonicas e resolvidas no macOS); resolve
    symlinks via `realpath -m` (fallback POSIX `cd -P` para BSD).
    `<path>` exato em `$HOME` rejeitado, mas paths INSIDE `$HOME` sao
    permitidos.
  - **TTY-only** (FR-016a): subcomando recusa execucao em pipe/CI;
    `[ -t 0 ] && [ -t 1 ]`. Stderr pode ser redirecionado.
  - **Dir nao-vazio = recusa direta sem prompt** (FR-016b): finalidade
    e atalho para projeto NOVO; mensagem aponta `/agente-00c-resume`
    para retomada.
  - **Lock per-path** (FR-016h, novo): `mkdir <path>/.cstk-00c.lock/`
    atomico antes de qualquer prompt; release via `trap EXIT INT TERM`
    + release explicito antes do `exec claude`. Previne race entre
    duas instancias simultaneas no mesmo `<path>`.
  - **Dep checks** (FR-016d): claude CLI no PATH; `jq` no PATH (teste
    funcional via `jq --version`); `~/.claude/commands/agente-00c.md`
    instalado — ausencia dispara prompt `[Y/n]` para auto-install via
    `cstk install` em foreground (respeita lockfile global de FR-015).
    Falha do nested install propaga exit code + razao.
  - **Sanitizacao** (FR-016g): descricao escapada para shell single-quotes
    (`'` -> `'\''`); stack JSON compactada via `jq -c`; whitelist
    persistida em `<path>/.agente-00c-whitelist.txt` (chmod 600) e
    referenciada via path absoluto em `--whitelist` (evita argv overflow).
  - **Validacao de URL na whitelist**: espelha
    `agente-00c-runtime/scripts/whitelist-validate.sh` rejeitando
    patterns overly-broad (`**` puro, `*://*`, `https://*` sem dominio,
    host vazio, sem scheme http(s), wildcard fora do prefixo
    `*.dominio.tld`).
  - **Dry-run preview obrigatorio** (FR-016e): mostra path final,
    descricao, stack, whitelist count + path, e linha exata da
    `/agente-00c` que sera invocada. Confirmacao final `[Y/n]` (default
    Y); flag `--yes` pula apenas o prompt final + auto-install.
  - **Spawn auto-submit** (FR-016f): `exec claude "$slash_command"`
    passa a slash command como argv[1]; claude processa como primeiro
    turno automatico (sem exigir Enter adicional do operador).

  Implementacao em `cli/lib/00c-bootstrap.sh` (~480 linhas POSIX puro)
  com 16 helpers privados `_00c_*` + entry point publico
  `bootstrap_00c_main`. **Special-case no dispatcher** porque POSIX
  nao permite funcao com nome iniciando em digito (`00c_main` invalido).

  Cobertura de testes: 18 cenarios em `tests/cstk/test_00c-bootstrap.sh`
  com mocks de `claude` (registra argv) e `cstk install` (controlavel).
  Cenarios cobrem path validation, TTY, deps ausentes, prompts (descricao
  9/501 chars, com `$`, com unicode, JSON malformado, URL overly-broad),
  lock pre-existente, dry-run + cancel, happy path com argv correto,
  apostrofo escapado, JSON com aspas duplas internas. Suite total:
  **505 PASS / 0 FAIL**.

### Changed

- **Carve-out 1.1.0 atualizada**: `jq` agora obrigatorio em
  `cli/lib/00c-bootstrap.sh` (era opcional em outros comandos do cstk).
  Justificativa: validacao de stack JSON (FR-016c) + dep transitiva do
  `agente-00c-runtime` que o `cstk 00c` invoca via `/agente-00c` —
  falha cedo em FR-016d e melhor UX que erro tardio dentro da sessao
  do `claude`.

- **`cstk` dispatcher e `cstk --help` atualizados** com nova entrada
  `00c <path>` listando o subcomando entre os comandos validos.

- **README.md secao Agente-00C** documenta `cstk 00c <path>` como o
  caminho preferido para iniciar sessoes do agente-00C, com nota
  apontando `/agente-00c-resume` para retomada de execucoes existentes.

## [3.4.0] - 2026-05-09

### Changed

- **`/agente-00c` faz warm-up de permissoes em batch ANTES de spawnar
  o orquestrador (post-FASE 9 feedback)**: nova passo 0 invoca todas
  as 10 skills da pipeline + 3 agentes custom + ScheduleWakeup + Bash
  helpers + Read/Write em sequencia. Cada invocacao dispara o prompt
  nativo de permissao do Claude Code uma vez, com o operador presente.
  Apos confirmacao, o orquestrador roda autonomamente sem interrupcoes
  (resolve o problema de fluxo travado quando permissoes "lazy" pediam
  aprovacao em ondas posteriores onde o operador nao estava disponivel).
  `/agente-00c-resume` e `/agente-00c-abort` NAO refazem warm-up
  (resume = continuacao, abort = operacao curta com operador
  presente). Orquestrador ganhou secao "Warm-up de permissoes
  (pre-condicao)" documentando o contrato e instruindo deteccao de
  permissao pendente no meio de uma onda como BloqueioHumano.

### Added

- **Validacao end-to-end (parcial) e licoes da implementacao do agente-00C (FASE 9)**:

  - **`scripts/quickstart-shell-sim.sh`**: simula via Bash os 10 cenarios
    do quickstart compondo as primitivas dos 14 scripts do
    `agente-00c-runtime`. NAO invoca o agente Claude — exercita apenas
    composicao shell-level. Resultado: **10/10 PASS** em ~5s. Detecta
    regressao quando um script deixa de compor com outros (gate
    complementar a `tests/run.sh` que testa cada script isoladamente).

  - **`docs/specs/agente-00c/validation-runs/`** (novo diretorio): registro
    de execucoes do agente-00C. README com template + tipos
    (shell-simulation vs end-to-end-real). Primeiro registro:
    `2026-05-06-end-to-end-shell-simulation.md` (10/10 PASS, SCs
    validaveis em shell-level: SC-001, SC-002, SC-007, SC-008).

  - **`docs/specs/agente-00c/lessons-from-implementation.md`**: 5 licoes
    concretas da implementacao das 8 fases — bug jq em pipe (drift.sh),
    dupla resolucao de symlinks no macOS (path-guard.sh), "skills
    internas" como padrao (`agente-00c-runtime`), cobertura forçada
    como ROI alto (3 bugs descobertos), estratificacao 3-camadas
    (commands/agents/scripts). Cada licao com proposta concreta de FR
    para skill especifica + avaliacao contra constitution do toolkit
    (nenhuma requer amendment).

  Subtarefas da FASE 9 atendidas autonomamente: 9.1.1-9.1.11 (10
  cenarios shell-simulated + relatorio), 9.2.1-9.2.3 (bump MINOR
  determinado, CHANGELOG/README atualizados), 9.4.1-9.4.3 (licoes da
  implementacao + propostas FR + avaliacao constitution).

  Subtarefas pendentes (exigem operador): 9.2.4 (cstk doctor pos-release
  v3.4.0), 9.3.* (primeira execucao real do agente em projeto-alvo —
  exige 1-3h wallclock + curadoria de relatorio), 9.4.4 (abertura real
  de issues no toolkit — exige autorizacao + execucao com `gh`), 9.4.5
  (atualizar threat-model com threats observados em runtime real).

- **Relatorio e integracao com toolkit do agente-00C (FASE 8)**: 28
  subtarefas implementadas em 3 novos scripts cobrindo geracao de
  relatorio com 6 secoes auditaveis, registro de Sugestoes para skills
  globais e abertura automatica de Issue no toolkit GitHub.

  - `report.sh` (FR-011 + SC-001 + FR-012): subcomandos `generate` e
    `validate`. `generate` renderiza 6 secoes obrigatorias (Resumo
    Executivo com tabela de 15 campos + paragrafo, Linha do Tempo
    com tabela de ondas, Decisoes agrupadas por agente + lista
    detalhada, Bloqueios Humanos divididos em pendentes/respondidos/
    sem, Sugestoes em 3 niveis de severidade, Licoes Aprendidas
    cravado como placeholder em parcial e preenchivel via
    `--licoes-aprendidas` + `--final`) + Apendice A com 5 paths.
    `validate` checa as 6 secoes via `grep -qF` e reporta faltantes.
    Caller deve aplicar `secrets-filter.sh scrub` em pipe (FR-030).

  - `suggestions.sh` (FR-020): subcomandos `register`, `list`,
    `count`, `next-id`, `mark-issue`, `render-md`. Sugestoes vivem
    em DOIS lugares — `state.json .sugestoes[]` (ground truth JSON)
    + agente-00c-suggestions.md (export human-readable regerado a
    cada register/mark-issue). 3 severidades validadas:
    informativa, aviso, impeditiva. Diagnostico exige >=50 chars
    para forçar detalhamento acionavel. `mark-issue` atualiza
    `.issue_aberta` + incrementa `metricas_acumuladas.issues_toolkit_abertas`.

  - `issue.sh` (FR-021): subcomandos `create`, `check-duplicate`,
    `hash`. Excecao escopada ao Principio V — apenas `gh issue
    create --repo JotJunior/claude-ai-tips`. Hash de 8 chars do
    diagnostico normalizado (lowercase + collapse whitespace + sha256
    + cut) para dedup via `gh issue list --search`. Template do
    `contracts/issue-template.md` aplicado via heredoc (Skill afetada,
    Diagnostico, Reproducao com decisoes recentes, Por que e
    impeditivo, Proposta de correcao, Anexos). Defense in depth:
    `secrets-filter.sh scrub` aplicado 2x (no build do body + antes
    do `gh create`). Labels `agente-00c,bug,skill-global` criadas
    automaticamente se ausentes (`gh label create --force`). Falha
    de `gh create` (sem internet, rate limit) propaga exit 1; corpo
    truncado em ~4000 chars com pointer ao relatorio local. `--dry-run`
    imprime template completo sem chamar `gh`.

  Agente orquestrador atualizado (passo 12 do Loop principal) com
  template operacional completo: pipe de `report.sh generate |
  secrets-filter.sh scrub > <report.md>` + `report.sh validate`,
  fluxo de Sugestao (impeditiva => `issue.sh create`), retentativa
  + bloqueio humano em falha persistente.

  27 cenarios de teste novos em
  `tests/test_{report,suggestions,issue}.sh`. `test_issue.sh` cobre
  apenas dry-run + hash (chamadas reais a `gh` evitadas para nao
  gerar issues em produçao — validacao end-to-end na FASE 9.1.6).

- **Continuacao cross-sessao do agente-00C (FASE 7)**: 20 subtarefas
  cobrindo `ScheduleWakeup` para ondas curtas, `/agente-00c-resume`,
  fallback `/schedule` Routines para pausas longas, e
  `/agente-00c-abort`. Sem novos scripts — todas as primitivas
  necessarias ja existem nas FASES 2-6 (state-rw, state-validate,
  state-lock, bloqueios, sanitize, secrets-filter, state-ondas).

  - **`global/agents/agente-00c-orchestrator.md`** — passo 11 expandido:
    `ScheduleWakeup` invocado APENAS para ondas nao-terminais sem
    bloqueios pendentes; tabela de calibracao de `delaySeconds`
    respeitando cache Anthropic (5min TTL): 60-270s para continuacao
    normal, 1200-1800s apos threshold proxy. Sentinela
    `<<autonomous-loop-dynamic>>` documentada. Reason no formato
    `agente-00c onda <NNN+1> apos <motivo>`. Passo 13 cravou formato do
    sumario retornado ao operador.

  - **`global/agents/agente-00c-orchestrator.md`** — nova secao "Pausas
    longas e fallback `/schedule` Routines": template completo de
    routine `/schedule criar "..." cron="..." prompt="/agente-00c-resume
    --projeto-alvo-path <PAP>"`; orientacao para incluir no relatorio
    parcial quando `aguardando_humano` + sinais de inatividade;
    explicito "NAO criar routine automaticamente" (operador escolhe
    cron especifico).

  - **`global/commands/agente-00c-resume.md`** — substituido o esqueleto
    da FASE 1 por fluxo operacional de 8 passos: parse de args, lock
    acquire, validate + sha256-verify, branch por status (terminal /
    em_andamento / aguardando_humano), apply de `--resposta-bloqueio`
    com sanitizacao via `sanitize.sh limit-length --max 2000`, spawn
    do orquestrador com prompt indicando "CONTINUACAO de execucao
    existente" + `retomada_motivo`, lock release + sumario.

  - **`global/commands/agente-00c-abort.md`** — substituido o esqueleto
    por fluxo operacional de 8 passos: parse, validacao com fail-soft
    para schema invalido (abort PROCEDE — pode ser o motivo do abort),
    idempotencia explicita (status terminal = no-op), atualizacao via
    `state-rw.sh set` (backup automatico), stub minimal de relatorio
    com `secrets-filter.sh scrub` aplicado, commit local via
    `state-ondas.sh git-commit` (fail-soft se nao e repo git, NUNCA
    push), sumario com hash do commit.

  - **`README.md`** — limitacao "Schedule mínimo de 5 min via /loop"
    atualizada para refletir clamp [60, 3600s] do `ScheduleWakeup` +
    fallback `/schedule` Routines.

- **Seguranca do agente-00C (FASE 6 — todas as 9 sub-features sao [C])**:
  56 subtarefas implementadas em 5 scripts focados no
  `agente-00c-runtime`, cobrindo 8 FRs criticos (FR-017, FR-018, FR-024,
  FR-025, FR-026, FR-027, FR-028, FR-029, FR-030, FR-031) e 5 threats
  (T1, T2, T3, T4, T5).

  - `path-guard.sh` (FR-024 + FR-017): subcomandos `validate-target`,
    `check-write`, `resolve`. Resolve symlinks via `realpath`/`readlink -f`
    com fallback portavel para paths inexistentes. Lista de zonas
    proibidas cobre 20+ paths incluindo formas canonica (`/etc`) e
    resolvida no macOS (`/private/etc`); explicitamente NAO bloqueia
    `/var/folders` (mktemp). Resolve TAMBEM cada zona antes de comparar
    (defesa T2 contra symlinks adversariais que apontam para zona
    proibida via `~`).

  - `bash-guard.sh` (FR-018 + FR-028 + SC-008): subcomandos
    `check-blocklist`, `check-whitelist`, `check`. Blocklist: sudo,
    package managers (npm/pnpm/yarn/pip/gem/brew/go install/cargo
    install) sem prefixo `docker exec/run`, `git push` (qualquer
    remote), kubectl mutativo, terraform apply/destroy, aws cli
    mutativo, gcloud deploy, docker push, docker-compose push, helm
    install/upgrade/uninstall. Whitelist: detecta network calls
    (curl/wget/gh api,issue,pr,repo,browse/git fetch,pull,clone),
    extrai URL (incluindo via `--repo OWNER/NAME` para gh) e checa
    contra whitelist; converte glob simples (`**` -> `.*`, `*` ->
    `[^/]*`) em regex. Excecao escopada: `gh issue create --repo
    JotJunior/claude-ai-tips` bypass (FR-021).

  - `secrets-filter.sh` (FR-030): subcomandos `scrub`, `check`. Filtros
    em ordem (especificos primeiro para preservar tipo): AWS keys
    (`AKIA[A-Z0-9]{16,}`), Bearer tokens, basic auth em URLs, tokens
    com palavra-chave proxima (token/key/secret/password/pwd/auth/
    api_key/access_key precedendo valor 20+ chars), valores de chaves
    do `.env` (carregado via `--env-file`, valores < 8 chars
    ignorados). `[REDACTED]`, `[REDACTED-AWS-KEY]` e `[REDACTED-ENV]`
    distinguem tipo. Hashes git e UUIDs sem palavra-chave proxima NAO
    sao filtrados (anti-falso-positivo).

  - `sanitize.sh` (FR-025): subcomandos `limit-length`, `check-length`,
    `escape-commit-msg`, `escape-issue-body`, `escape-path`. Defaults
    cobrem `descricao_curta` (max 500 chars). `escape-commit-msg`
    remove newlines/tabs/dollars/backticks/quotes + limita 100 chars.
    `escape-issue-body` preserva newlines (markdown), remove `$(...)`
    e backticks. `escape-path` remove path traversal `..` + chars
    nao-`[A-Za-z0-9._-]` + limita 64 chars.

  - `whitelist-validate.sh` (FR-031): subcomandos `check`, `list`.
    Rejeita patterns "overly broad": `**` puro sem dominio, `*://*`
    (scheme com glob), `https://*` sem dominio, host vazio, sem
    scheme, wildcard fora do padrao prefixo `*.dominio.tld`.
    Diagnostico inclui numero da linha + motivo + conteudo.

  Agente orquestrador (`global/agents/agente-00c-orchestrator.md`)
  atualizado com tabela de primitivas estendida (5 novos scripts) +
  secao "Defesa em profundidade" reescrita listando os 7 mecanismos
  (bash-guard, path-guard, sanitize, secrets-filter, whitelist-validate,
  sha256-verify, goal alignment) com instrucoes operacionais explicitas
  para o LLM (quando invocar, qual subcomando, semantica de exit code).

  62 cenarios de teste novos em
  `tests/test_{path-guard,bash-guard,secrets-filter,sanitize,whitelist-validate}.sh`.
  Inclui casos adversariais: symlink que aponta para `~/.ssh`, comando
  Bash com `sudo`/`git push`/`docker push`/`kubectl apply`, payload com
  AWS key/Bearer/basic auth/.env values, whitelist com `**`/`*://*`/etc.

- **Autonomia controlada do agente-00C (FASE 5)**: 5 novos scripts em
  `global/skills/agente-00c-runtime/scripts/` cobrem os 5 mecanismos de
  aborto graceful que mantem o orquestrador dentro do orcamento e do
  escopo declarado (Principio IV — Autonomia Limitada com Aborto).

  - `budget.sh`: proxies de orcamento de sessao (FR-009, sem signal
    nativo de tokens). 3 dimensoes: tool_calls da onda (default 80),
    wallclock (default 5400s = 90min) e tamanho de state.json (default
    1MB). `check` exit 1 quando QUALQUER threshold dispara, com TSV
    `TIPO\tCURRENT\tTHRESHOLD` em stdout. Wallclock usa fallback portavel
    BSD/GNU para `date -d` vs `date -j -f`. State size via `stat -f %z`
    (BSD) / `stat -c %s` (GNU) / `wc -c` (fallback).

  - `cycles.sh`: limite de ciclos por etapa (FR-014.a — `loop_em_etapa`).
    `tick` incrementa contador; `--progress-made` zera (orquestrador
    decide quando 1 dos 4 indicadores de FR-014 aconteceu). `reset`
    explicito ao avancar de etapa (separacao de responsabilidades — nao
    infere mudanca via `.etapa_corrente`). Exit 3 em > 5 ciclos.

  - `circular.sh`: deteccao de movimento circular (FR-014.b). `push`
    armazena `{problema_hash, solucao_hash, timestamp}` em buffer FIFO
    de capacidade 6. Normalizacao: lowercase + nao-alfanumerico->space +
    20 primeiras palavras. `detect` exit 3 quando mesmo problema_hash
    aparece >=3 vezes (cobre o padrao "P=A,S=X / P=B,S=Y / P=A,S=Z /
    P=B,S=Y / P=A,S=X" do exemplo da spec).

  - `drift.sh`: drift detection / goal alignment (FR-027, threat T1).
    `init` grava 3..7 aspectos-chave (cravado pos-primeira-onda — recusa
    sobrescrever). `check` itera ondas do final para o inicio, conta
    consecutivas sem decisao mencionando aspecto (case-insensitive
    substring nos campos contexto/escolha/justificativa de cada
    decisao). Warn em 3 ondas (stderr, exit 0); abort em 5 (exit 3,
    motivo `desvio_de_finalidade`).

  - `retro.sh`: limite de retro-execucoes (FR-006). `check` valida
    `consumed < max` (default 2). `consume` exit 3 SEM mutar estado se
    incremento excederia max (defesa em profundidade — testado com
    snapshot before/after). Orquestrador converte 3a tentativa em
    BloqueioHumano via `bloqueios.sh register`.

  37 cenarios de teste em `tests/test_{budget,cycles,circular,drift,retro}.sh`.

  Agente orquestrador (`global/agents/agente-00c-orchestrator.md`)
  atualizado: tabela de primitivas inclui os 5 novos scripts; passos 7
  e 8 do Loop principal de uma onda referenciam cada gatilho de aborto
  com semantica explicita (motivo, exit code, acao do orquestrador).

- **Padrao clarify de dois atores (agente-00C FASE 4)**: implementacao
  do mecanismo de "Pause-or-Decide" (Principio II da feature), com
  mediacao orquestrada entre clarify-asker (gera 1-5 perguntas via skill
  clarify) e clarify-answerer (decide via heuristica de score 0..3).

  - `global/agents/agente-00c-clarify-asker.md`: prompt operacional
    completo. Inputs (`spec_path`, `briefing_path`, `etapa_corrente`,
    `decisoes_anteriores`, `quantidade_max_perguntas`); fluxo (Read +
    Skill clarify + filtro de redundantes); formato JSON cravado com
    `Q1..QN` + `default_sugerido` opcional; saida vazia `{ "perguntas":
    [] }` quando nao ha clarificacao pendente. Tools restritas a Skill+Read
    (sem Agent — bisneto nao recursiona).

  - `global/agents/agente-00c-clarify-answerer.md`: heuristica de score
    documentada (3 fontes: briefing, constitutions toolkit+feature,
    stack-sugerida). Tabela de decisao (>=2 decide, ==1 decide so se
    outras violarem constitution, ==0 pause-humano). Tie-breaker em 4
    niveis. Formato JSON com `pause_humano: bool` e
    `contexto_para_humano` quando aplicavel. Tools restritas a Read+Bash
    (Bash apenas para `date`).

  - `global/agents/agente-00c-orchestrator.md`: passo 5 do Loop
    principal expandido com fluxo de mediacao em 7 sub-passos (a-g):
    pre-flight via spawn-tracker, spawn asker, spawn answerer (irmaos),
    aplicar respostas validas como Decisao via state-decisions.sh,
    converter score 0 em BloqueioHumano via bloqueios.sh, fim de onda
    gracioso quando ha pendentes.

  - **Novo script** `global/skills/agente-00c-runtime/scripts/bloqueios.sh`:
    ciclo de vida de BloqueioHumano (FR-015, FR-016). 6 subcomandos:
    `register` (gera `block-NNN` sequencial; valida FK para Decisao
    existente; valida `pergunta >= 20 chars`; atualiza
    `.execucao.status = "aguardando_humano"` e
    `.metricas_acumuladas.bloqueios_humanos_total`); `respond` (marca
    `respondido` + grava `resposta_humana` + `respondido_em`; volta
    `.execucao.status = "em_andamento"` SO quando todos os bloqueios
    pendentes foram respondidos); `list` (TSV com filtro opcional por
    status); `count` (com `--pending-only`); `next-id`; `get`
    (JSON do bloqueio).

  14 cenarios de teste em `tests/test_bloqueios.sh` cobrem o lifecycle
  completo (register -> respond), FK violation, validacao de pergunta
  curta, status transitions com bloqueios multiplos, idempotencia.

- **Orquestrador raiz do agente-00C (FASE 3)**: 4 novos scripts em
  `global/skills/agente-00c-runtime/scripts/` cobrem state machine,
  decisoes auditaveis, tracking de subagentes e ciclo de vida de ondas.

  - `pipeline.sh`: 5 subcomandos. `stages` imprime as 10 etapas
    canonicas (briefing → constitution → specify → clarify → plan →
    checklist → create-tasks → execute-task → review-task →
    review-features). `next-stage`/`prev-stage` para avanco linear ou
    retro-execucao. `detect-completion` mapeia 7 etapas para artefatos
    esperados em `docs/specs/<feature>/`. `skill-conflict` detecta
    skill em local (`<projeto>/.claude/skills/`) + global
    (`~/.claude/skills/`) com 4 status (conflict/only-local/only-global/
    not-found); regra: local vence.
  - `state-decisions.sh`: registro auditavel (Principio I —
    Auditabilidade Total). `register` valida 5 campos obrigatorios
    (contexto>=20, opcoes_consideradas>=1, escolha, justificativa>=20,
    agente); falha = exit 1 com `violacao Principio I`. Ids `dec-NNN`
    sequenciais; linka a `onda_id` corrente; `--score` 0..3 para
    decisoes do clarify-answerer (FR-015). Atualiza
    `metricas_acumuladas.decisoes_total`. Subcomandos `count`, `list`,
    `next-id` para introspeccao.
  - `spawn-tracker.sh`: enforce FR-013 (max 3 niveis). `enter` valida
    `(current+1) <= 3` ANTES de qualquer escrita; falha = exit 3 SEM
    modificar estado. Atualiza `profundidade_max_atingida` e
    `subagentes_spawned`. `leave` decrementa (idempotente em min 1).
    `check` exposto para validacao read-only. Defesa em profundidade:
    agentes `agente-00c-clarify-asker` e `clarify-answerer` NAO
    declaram tool Agent.
  - `state-ondas.sh`: ciclo de vida de Ondas. `start` cria nova `onda-NNN`
    + reseta tool_calls/inicio_onda_corrente. `end` valida 1 dos 5
    motivos validos (etapa_concluida_avancando, threshold_proxy_atingido,
    bloqueio_humano, aborto, concluido), calcula wallclock (fallback
    portavel GNU `date -d` -> BSD `date -j -f`) e atualiza
    metricas_acumuladas. `tool-call-tick` para incrementar contador
    (backup so a cada 10 ticks p/ nao explodir state-history/).
    `git-commit --motivo MOTIVO` faz commit local no projeto-alvo
    (`chore(agente-00c): <onda-id> - <motivo>`); NUNCA `git push`
    (Principio V — Blast Radius Confinado).

  46 cenarios de teste em `tests/test_{pipeline,state-decisions,spawn-tracker,state-ondas}.sh`.

  Agente orquestrador (`global/agents/agente-00c-orchestrator.md`)
  atualizado com instrucoes operacionais detalhadas (13 passos do loop
  principal de uma onda) referenciando estas primitivas.

- **Skill interna `agente-00c-runtime` (agente-00C FASE 2)**: biblioteca
  POSIX consumida pelos agentes custom do agente-00C. NAO e
  user-invocavel — empacota helpers de estado, validacao e lock para a
  pipeline. Distribuida via `cstk install` (catalog/skills/) e instalada
  em `~/.claude/skills/agente-00c-runtime/`. Conteudo:

  - `scripts/state-rw.sh`: subcomandos `init`, `read`, `write`, `get`,
    `set`, `sha256-update`, `sha256-verify`, `path-check`. Implementa
    schema state.json v1.0.0, backups automaticos por onda em
    `state-history/`, integridade SHA-256 (FR-029), atomic write
    via mktemp+mv, write-probe para detectar permissao negada, captura
    de I/O errors (disco cheio).
  - `scripts/state-validate.sh`: validador FR-008 read-only com 10
    checagens (schema_version, 14 campos obrigatorios, 4 invariantes
    numericas, status x terminada_em, 5 campos de Decisao, integridade
    de FK BloqueioHumano -> Decisao, whitelist nao-vazia). Sem
    auto-correcao (Principio III).
  - `scripts/state-lock.sh`: subcomandos `acquire`, `release`, `check`,
    `check-execution-busy`. Lock via `mkdir` atomico em
    `<state-dir>/.lock/`; locks independentes por projeto-alvo
    (permite execucoes simultaneas em projetos distintos). TOCTOU
    residual (CHK072) documentado.

  Dependencia: `jq` (carve-out 1.1.0 da constitution para JSON
  estruturado). 36 cenarios de teste em `tests/test_state-{rw,validate,lock}.sh`.

- **`cstk install` distribui `commands/` e `agents/` (agente-00C FASE 1.2)**:
  o tarball de release agora inclui `catalog/commands/` e `catalog/agents/`
  (espelhos de `global/commands/` e `global/agents/`), e o `cstk install`
  copia esses `.md` soltos para `~/.claude/commands/` e `~/.claude/agents/`
  (respectivamente `./.claude/commands/` e `./.claude/agents/` em
  `--scope project`). Cada kind tem seu proprio manifest dedicado
  (`<dest>/.cstk-manifest`) com schema identico ao de skills.

  Comportamento: instalacao sempre processa TODOS os `.md` (sem filtro de
  profile — sao infraestrutura, nao skills); re-install vira "updated";
  arquivo pre-existente sem entry no manifest e PRESERVADO como third-party
  (FR-007). Tarballs historicos sem `catalog/commands/` ou
  `catalog/agents/` continuam validos — ambos os campos sao opcionais.

- **`cstk doctor` varre os 3 kinds (skills, commands, agents)**: drift em
  commands/agents (EDITED, MISSING, ORPHAN) e reportado com prefixo de
  kind (ex: `[EDITED]   commands/agente-00c`); skills continuam exibidas
  sem prefixo (compatibilidade backward). `--fix` remove entries MISSING
  do manifest correto por kind.

- **Esqueleto do agente-00C** em `global/commands/` (3 slash commands:
  `/agente-00c`, `/agente-00c-abort`, `/agente-00c-resume`) e
  `global/agents/` (3 agentes custom: orchestrator, clarify-asker,
  clarify-answerer). Esqueleto apenas — implementacao operacional ocorre
  ao longo das Fases 2-9 do backlog em
  `docs/specs/agente-00c/tasks.md`.

### Changed

- `manifest_default_path` aceita argumento opcional `kind` (default
  `skills` — backward compatible). Uso: `manifest_default_path global commands`.
- `hash.sh` exporta `hash_file <arquivo>` (wrapper sobre `sha256_file`)
  para cobrir artefatos single-file (commands/agents). `hash_dir`
  inalterado.

## [3.3.0] - 2026-05-05

### Added

- **Skill `review-features`**: relatorio comparativo de TODAS as features
  do projeto (cross-feature), complementar a `review-task` (que olha UMA
  feature). Saida: tabela com nome, descricao, % concluida, criticidade
  pendente e sugestao de acao por feature (`ARQUIVAR` / `ABANDONAR` /
  `PRIORIZAR` / `CONTINUAR` / `INDEFINIDO`).

  Heuristica deterministica:
  - `ARQUIVAR`: feature 100% concluida
  - `ABANDONAR`: 0% concluida e sem modificacao ha mais de 90 dias
  - `PRIORIZAR`: tem subtasks `[C]` pendentes e menos de 50% concluida
  - `CONTINUAR`: caso geral em andamento
  - `INDEFINIDO`: tasks.md vazio

  Acompanha script POSIX `scripts/aggregate.sh` (saida markdown ou
  JSON-lines via `--json`) com 16 cenarios de teste em
  `tests/test_aggregate.sh`. A skill e read-only — sugestao e recomendacao,
  nunca executa arquivar/deletar sem confirmacao do usuario.

## [3.2.3] - 2026-04-27

### Changed

- **`cstk install --help` agora lista os profiles disponiveis** (`sdd`,
  `complementary`, `all`) com o conteudo de cada um e marca `sdd` como
  default. Antes, o usuario via apenas "Default: sdd" e nao tinha como
  descobrir que existiam outros profiles nem o que cada um continha — a
  unica fonte era `scripts/profiles.txt.in` no repo, fora do alcance de
  quem instalou via tarball.

  Reportado por usuario: apos `cstk install` (default `sdd`), faltavam
  skills complementares (advisor, bugfix, owasp-security, etc.) e nao
  havia pista no help de como instala-las. Solucao: profile
  `complementary` instala as 9 skills de uso pontual; profile `all`
  instala tudo. Exemplos no help cobrem os 3 profiles + cherry-pick.

  Test atualizado: `scenario_install_help_exit_zero` verifica que os
  tres nomes de profile aparecem na saida.

## [3.2.2] - 2026-04-27

### Fixed

- **`cstk install` e `cstk update` sem `--from` agora consultam a API
  GitHub** para descobrir a ultima release, em vez de abortar com
  "vem na FASE 3.2 (bootstrap)" — mensagem misleading que sobreviveu
  a entrega da FASE 3.2 (que entregou apenas o bootstrap standalone,
  nao a resolucao no comando `cstk install`).

  Comportamento novo:
  - `--from URL` (explicit)             → usa a URL fornecida
  - `$CSTK_RELEASE_URL` (env)           → usa a URL do env
  - **(novo)** sem nada acima           → GitHub API /releases/latest

  Honra `$CSTK_REPO` para forks (default `JotJunior/claude-ai-tips`).
  Mesmo padrao ja em uso por `cstk self-update` desde FASE 5.

  Reportado por usuario: `cstk install` apos bootstrap retornava
  "[error] install: --from URL ausente e \$CSTK_RELEASE_URL nao setado"
  — quebrava o fluxo "instalar via one-liner depois `cstk install`"
  documentado no README.

  Test atualizado: `scenario_install_sem_from_e_sem_env_consulta_api`
  usa `CSTK_REPO=invalid/nonexistent` para forcar 404 da API e validar
  que o erro reportado e "falha ao consultar" (em vez de mensagem
  antiga sobre CSTK_RELEASE_URL nao setado).

## [3.2.1] - 2026-04-27

### Fixed

- **Bootstrap one-liner (`cli/install.sh`) e `cstk self-update` baixavam
  URL com 404.** A construcao da URL do tarball usava o tag completo
  (`cstk-v3.2.0.tar.gz`), mas `scripts/build-release.sh` strip o prefixo
  `v` ao gerar o asset (`cstk-3.2.0.tar.gz`). Match falhava com 404.

  Fix: ambos `cli/install.sh` e `cli/lib/self-update.sh` agora computam
  `TAG_BARE=${TAG#v}` e usam essa variante ao construir o filename do
  asset, mantendo o tag original (com `v`) no path do release. Comporta-
  mento alinhado com `build-release.sh`.

  **Impacto**: `releases/latest/download/install.sh` em v3.2.0 esta
  quebrado — usuarios precisam usar v3.2.1 (que fixa o asset URL ao
  baixar). v3.2.0 nao foi removida; tag continua presente para
  rastreabilidade do incidente.

  Descoberto por usuario reportando `curl: (22) ... 404` ao executar o
  one-liner publicado no README.

## [3.2.0] - 2026-04-26

### Added

- **`cstk` CLI (POSIX shell)** — toolkit de instalação, atualização e
  auditoria de skills. Substitui o `cp -r` manual documentado em
  `CLAUDE.md` por um fluxo rastreável: manifest por escopo (versão +
  `source_sha256` + ISO timestamp), lock concorrente via `mkdir`,
  verificação SHA-256 obrigatória em todo download (FR-010a),
  preservação de skills de terceiros (FR-007), políticas explícitas de
  conflito em update (`--force` / `--keep`, exit 4 quando edit local
  detectado sem flag — FR-008).

  **Comandos**: `install`, `update`, `self-update`, `list`, `doctor`.

  **Profiles**: `sdd` (default — pipeline SDD com 10 skills),
  `complementary` (9 skills independentes), `all` (todos os 35 skills),
  `language-go`, `language-dotnet`. Cherry-pick por nome também
  suportado; modo interativo via `--interactive` (seletor numerado em
  TTY).

  **Escopos**: `--scope global` (`~/.claude/skills/`, default) e
  `--scope project` (`./.claude/skills/`). Hooks de `language-*` são
  instalados APENAS em escopo de projeto (FR-009c) com merge automático
  de `settings.json` quando `jq` disponível, ou paste-block instrucional
  quando ausente (FR-009d).

  **Self-update atômico** (FR-006): par `bin + lib` tratado como unidade
  indivisível via stage-and-rename coordenado + boot-check de versão
  embutida vs versão da lib. Nunca toca o manifest de skills (FR-006a;
  verificável: mtime do `.cstk-manifest` preservado).

  **Pipeline de release** em `.github/workflows/release.yml` —
  triggered por `push tag v*`, valida testes (`tests/run.sh` + cstk
  suite), gera tarball determinístico via `scripts/build-release.sh`
  e publica via `gh release create` com `cstk-X.Y.Z.tar.gz`,
  `.sha256` e `install.sh` (asset standalone para o one-liner
  `curl <url> | sh`).

  **Observabilidade**: `cstk list` (TSV/pretty) + `cstk doctor`
  (4 estados de drift: OK, EDITED, MISSING, ORPHAN — SC-007).

  **Determinismo do tarball** (`scripts/build-release.sh`): mtime
  normalizado, `gzip -n`, ordenação `LC_ALL=C sort`, detecção
  GNU-vs-BSD tar para paths portáveis. Verificado: 2 builds
  consecutivos produzem o mesmo SHA-256.

  **Cobertura de testes**: 242 cenários (`tests/run.sh` global), zero
  falhas. Gap real único (Scenario 13 SC-003 byte-a-byte) coberto por
  `tests/cstk/test_quickstart-e2e.sh`.

  Spec completa em [`docs/specs/cstk-cli/`](./docs/specs/cstk-cli/);
  documentação user-facing em [`README.md`](./README.md) §Instalação.

### Governance

- **Constitution 1.0.0 → 1.1.0 (MINOR amendment)**: nova subseção "Optional
  dependencies with graceful fallback" sob Princípio II disciplinando deps
  não-POSIX em três condições cumulativas (uso opcional com fallback
  verificável, confinamento em único arquivo, declaração explícita na feature).
  Nota complementar no Decision Framework item 4 reconhece subseções de
  carve-out como mecanismo válido quando precedidas por amendment MINOR.
  Não afrouxa Princípio II — Bash-isms seguem proibidos, `ripgrep`/`fd`/`bats`
  permanecem banidos mesmo como opcionais, deps obrigatórias continuam vetadas.
  Primeiro caso concreto sob a nova regra: `jq` opcional em `cli/lib/hooks.sh`
  da feature `cstk-cli`. Ver `docs/specs/constitution-amend-optional-deps/`
  para histórico completo de raciocínio.

## [3.1.1] - 2026-04-20

Versão PATCH — correção de bug latente em `validate.sh` análogo ao
histórico de `metrics.sh` (commit `ead1b68`).

### Fixed

- **`validate.sh` deixa de poluir stderr com `integer expression expected`.**
  As linhas 244–245 continham o mesmo padrão defeituoso `grep -c ... || printf '0'`
  que quebrou `metrics.sh`: em no-match, `grep -c` imprime `"0"` e sai com
  exit 1, disparando o fallback que concatena outro `"0"` — resultado
  `"0\n0"` quebra as comparações aritméticas subsequentes. Fix aplica o
  padrão seguro `VAR=$(grep -c ...) || VAR=0`.
- **Bug latente adicional revelado**: a aritmética corrompida fazia com
  que os três `if` do bloco "Próximos Passos" (`Corrigir N ERRO(s)`,
  `N AVISO(s)`, `Nenhuma ação necessária`) falhassem silenciosamente em
  docs válidos. Com o fix, a mensagem de sucesso `- Nenhuma acao
  necessaria. Documentacao renderiza corretamente.` volta a aparecer
  quando aplicável.
- Tabela Resumo do stdout deixa de renderizar `| X | 0\n0 |` em duas
  linhas quando algum contador é zero — agora sempre em linha única
  `| X | 0 |`.

### Added

- **`tests/test_validate.sh :: scenario_stderr_limpo_em_docs_validos`**:
  regressão dedicada que captura stderr ao rodar `validate.sh` contra
  `fixtures/docs-site/valid/` e falha se contiver `"integer expression
  expected"` ou `"[: "`. Protege contra o retorno do bug histórico.
- **Assertion adicional em `scenario_docs_validos`**: trava como
  invariant a linha "Nenhuma acao necessaria" que agora aparece em docs
  válidos.
- Feature SDD completa em `docs/specs/fix-validate-stderr-noise/`:
  spec + plan + research + quickstart + tasks + checklists/requirements
  (29 subtarefas, 100% concluídas).

### Contract preserved

- Exit codes de `validate.sh` inalterados (0 em sucesso, 1 em ERROs).
- Estrutura do stdout (seções, colunas, severidades) inalterada.
- Apenas valores numéricos corrigidos onde estavam corrompidos, e
  stderr limpo. Nenhum teste existente em `test_validate.sh` quebrou.

## [3.1.0] - 2026-04-20

Versão MINOR — adição de suíte automatizada de testes para os scripts
POSIX distribuídos em `global/skills/**/scripts/`.

### Added

- **Suite automatizada de testes em `tests/`** cobrindo os 5 scripts
  shell do toolkit (`metrics.sh`, `next-task-id.sh`, `next-uc-id.sh`,
  `scaffold.sh`, `validate.sh`). Entry point único `tests/run.sh` executa
  44 scenarios em 3–4 segundos e reporta status trichotômico
  PASS / FAIL / ERROR no formato TAP.

- **Harness POSIX puro** em `tests/lib/harness.sh` com gestão isolada
  por `mktemp -d` + `trap EXIT/INT/TERM`, e os helpers `assert_exit`,
  `assert_stdout_contains`, `assert_stderr_contains`, `assert_stdout_match`,
  `assert_no_side_effect`, `fixture` e `run_all_scenarios`. Zero
  Bash-isms; zero dependências além das ferramentas POSIX canônicas.

- **Regressão dedicada do bug histórico de `metrics.sh`**
  (`scenario_regressao_bug_grep_c_sem_matches`) protegendo contra o
  retorno do padrão defeituoso `grep -c ... || printf '0'` que
  concatenava `"0\n0"` e quebrava expressões aritméticas. Validado
  revertendo o fix temporariamente durante a entrega: a suíte detectou
  3 FAILs incluindo o dedicado.

- **Modos do runner**: `--list` (lista scenarios sem executar),
  `--check-coverage` (detecta scripts sem teste e testes sem script;
  exit 1 em órfão), filtragem por `PATTERN` posicional, `--help`.

- **Governança de cobertura (FR-009 da spec)**: no modo normal, órfãos
  aparecem como warning (`ORPHANS: N` + bloco `# WARN:`) sem bloquear;
  no modo `--check-coverage`, órfãos fazem exit 1. Convenção estrita
  `tests/test_<nome>.sh` para cada `global/skills/<skill>/scripts/<nome>.sh`.

- **`tests/README.md`** com quickstart, arquitetura, formato TAP, exit
  codes, contrato do harness (tabelas de helpers) e guia para adicionar
  teste ao script novo.

- **Spec completa em `docs/specs/shell-scripts-tests/`**: `spec.md` +
  `plan.md` + `research.md` + `data-model.md` + `contracts/runner-cli.md`
  + `quickstart.md` + `checklists/requirements.md` + `tasks.md`. Feature
  entregue em 5 fases, 113 subtarefas, 100% concluídas.

### Known issue (fora do escopo desta release)

- `validate.sh` (linhas 273–284) contém o mesmo padrão
  `grep -c || printf '0'` do bug histórico de `metrics.sh`. Afeta
  apenas stderr (não exit code nem stdout). Registrado em
  `docs/specs/shell-scripts-tests/tasks.md` §FASE 2. Candidato para
  nova feature em ciclo SDD separado.

## [3.0.0] - 2026-04-20

Versão MAJOR devido a remoção de asset distribuído (contrato de instalação
muda — usuários que faziam `cp -r global/insights/` precisam migrar).

### Removed (BREAKING)

- **Diretório `global/insights/` removido do repositório.** O arquivo
  `usage-insights.md` que vivia ali era uma curadoria específica de sessões
  de um usuário (Go + TypeScript + PostgreSQL multi-serviço), não um playbook
  genérico. Distribuí-lo como parte do toolkit confundia quem clonava: o
  conteúdo era tratado como autoritativo quando era apenas o snapshot de um
  contexto.

  **Como fica agora**:

  - A skill `apply-insights` continua funcionando — ela sempre leu de
    `~/.claude/insights/usage-insights.md` (espaço do usuário), nunca de
    `global/insights/` diretamente.
  - Se o arquivo `~/.claude/insights/usage-insights.md` existir, a skill o
    usa. Caso contrário, cai em best-practices genéricas (comportamento
    já documentado no SKILL.md).
  - O modelo recomendado agora: gerar o arquivo via a slash command nativa
    `/insights` do Claude Code (que analisa suas sessões reais) ou curá-lo
    manualmente. Cada usuário mantém o seu próprio.

  **Impacto para consumidores**:

  - O comando `cp -r global/insights/ ~/.claude/insights/` (documentado no
    README) não existe mais — o diretório-fonte foi removido.
  - Quem já tinha copiado o arquivo para `~/.claude/insights/` mantém a
    cópia local intocada.
  - README atualizado: seção "Insights de Uso" reescrita para refletir o
    modelo por-usuário; diagrama de estrutura e bloco de instalação
    limpos.
  - CLAUDE.md atualizado: seção "Renomeando uma skill" não referencia mais
    `global/insights/`.

### Migration

1. Se você dependia do arquivo distribuído:

   ```bash
   # O arquivo pode continuar no seu ~/.claude/insights/ se você já o copiou
   ls ~/.claude/insights/usage-insights.md

   # Caso contrário, gere o seu via o /insights nativo do Claude Code,
   # ou mantenha um playbook curado manualmente neste caminho
   ```

2. Se você referenciava `global/insights/` em scripts ou docs próprios,
   remover a referência — o caminho não resolve mais.

## [2.0.0] - 2026-04-19

Versão MAJOR devido a rename de skill user-visível (identificador de invocação
é contrato público).

### Changed (BREAKING)

- **Skill `insights` renomeada para `apply-insights`** — o Claude Code tem uma
  slash command nativa `/insights` (analisa suas sessões de uso) que colidia
  no namespace de autocomplete com a nossa skill homônima. As duas
  coexistiam sem uma sobrescrever a outra, mas a ambiguidade gerava atrito:
  - usuários precisavam selecionar a correta a cada invocação
  - documentação que referenciasse `/insights` ficava ambígua
  - hooks que tentassem invocar por string tinham comportamento indefinido

  Rename para `apply-insights` deixa claro que a função é **prescritiva**
  (aplicar um playbook ao projeto) — distinta da nativa, que é
  **introspectiva** (analisar sessões). A description da skill agora explicita
  essa diferença para o modelo.

  **Impacto para consumidores**:
  - Invocações via `/insights` agora rodam a skill nativa do Claude Code
  - Para a função antiga, usar `/apply-insights`
  - Arquivos CLAUDE.md / documentação que referenciavam `/insights` precisam
    ser atualizados

### Migration

1. Se o seu projeto tem instalação local: `.claude/skills/insights/` →
   `.claude/skills/apply-insights/`
2. Atualizar triggers em CLAUDE.md, memórias, hooks, scripts
3. Nova invocação: `/apply-insights` (ou qualquer dos triggers em português
   como "aplicar insights", "aplicar playbook", "melhorar claude.md")

## [1.1.0] - 2026-04-19

Refatoração ampla das 18 skills globais aplicando os princípios do artigo
["Skills no Claude Code: O Guia Definitivo"](./docs/artigo.md) e adicionando
1 nova skill. Todas as mudanças são backward-compatible na invocação pelo
nome — skills continuam respondendo aos mesmos triggers e argumentos.

### Added

- **Nova skill `validate-docs-rendered`** (categoria "Verificação de Produto"
  do artigo) — valida que a documentação Markdown realmente renderiza
  corretamente: diagramas Mermaid parseáveis, links internos sem 404,
  frontmatter YAML consistente, tabelas bem formadas, code blocks com
  linguagem declarada. Script POSIX `scripts/validate.sh` roda 5 checagens
  com exit code para uso em CI/hooks.

- **Seções `Gotchas` em todas as 18 skills preexistentes** — documentando
  armadilhas recorrentes e erros típicos. Segue a recomendação do artigo de
  que "o conteúdo mais valioso de uma skill é a seção de gotchas".

- **Scripts POSIX reutilizáveis em 4 skills**:
  - `initialize-docs/scripts/scaffold.sh` — cria estrutura 01-09 com READMEs
    template, idempotente, suporta `--dry-run`, `--force`, `--dir=PATH`
  - `create-use-case/scripts/next-uc-id.sh` — calcula próximo `UC-{DOMINIO}-NNN`
    disponível; suporta `--list` para auditar domínios existentes
  - `create-tasks/scripts/next-task-id.sh` — calcula próximo ID hierárquico
    (`1.3`, `1.2.4`) com regex ancorado para evitar falsos positivos
  - `review-task/scripts/metrics.sh` — extrai métricas de progresso do
    tasks.md em formato tabular + JSON

- **Arquitetura de skill-como-pasta** com subdiretórios para *progressive
  disclosure* em 8 skills (specify, plan, create-tasks, create-use-case,
  briefing, checklist, constitution, analyze):
  - `templates/` — templates preenchíveis (feature-spec, plan, tasks,
    briefing, constitution, data-model, contracts, quickstart, research,
    use-case)
  - `examples/` — exemplos concretos (specify tem `spec-good.md` e
    `spec-bad.md` com anti-patterns comentados)
  - `references/` — documentação de apoio (catálogos de items por domínio
    para checklist; consistency-checks para analyze; discovery-guide
    detalhado para briefing)

- **Composição explícita do pipeline SDD** — cada skill do pipeline agora
  documenta em seções `## Pré-requisitos` e `## Próximos passos` quais
  artefatos consome e qual skill é o passo lógico seguinte. Torna a sequência
  briefing → constitution → specify → clarify → plan → checklist →
  create-tasks → analyze → execute-task → review-task navegável sem
  tooling formal de dependências.

- **`config.json` em 3 skills** para configuração por projeto:
  - `create-use-case/config.json` — mapa de domínios customizados, output_dir,
    formato de ID, mínimos de qualidade
  - `create-tasks/config.json` — níveis de criticidade, paths de output
    (spec_derived vs standalone), prefixo de fase, granularidade
  - `initialize-docs/config.json` — estrutura de diretórios customizável,
    `keep_in_root`, `file_routing` por padrão

  Quando `config.json` está ausente, as skills usam defaults documentados.
  Quando presente, o projeto adapta as convenções sem bifurcar a skill.

### Changed

- **Reescrita do campo `description` de todas as 18 skills** no formato de
  *trigger conditions* ("Use quando o usuário X, Y ou Z. Também quando
  mencionar A, B, C. NÃO use quando W.") em vez de resumo. Isso melhora
  descoberta — o modelo precisa decidir *quando* invocar a skill, não apenas
  o que ela faz. Particularmente relevante com Opus 4.7, que interpreta
  descrições de forma mais literal.

- **Agnosticização completa das skills** — removidas referências específicas
  a projetos, stacks e convenções de qualquer cliente/codebase. Skills agora
  tratam stack (Go/Python/React/etc.), domínios de negócio (AUTH/CAD/PED) e
  paths internos (`services/{service}/...`) como exemplos ilustrativos
  marcados, não como assunções. Cada skill funciona em qualquer projeto.

- **`bugfix` reescrita para ser stack-agnostic** — os 8 passos do protocolo
  (Step 0..7) agora usam terminologia genérica de camadas ("server /
  backend", "client / frontend", "cross-boundary") em vez de listas
  específicas de Go/React. Comandos de build/test/lint apresentados em
  tabela por stack.

- **`execute-task` reescrita para ser stack-agnostic** — Etapa 7 (Lint) é
  agora uma tabela com comandos típicos por stack (Go, Node, Rust, Python,
  Java, .NET) em vez de assumir `go build ./...`.

- **`create-use-case`: domínios deixam de ser enum fixo** — a lista antiga
  (AUTH, CAD, PED, FIN, FAT, LOG, MON, INAD, REC, PROP, CONT, DOM) virou
  exemplo; a skill consulta `config.json` ou UCs existentes antes de
  perguntar ao usuário.

- **Templates extraídos do SKILL.md para arquivos separados** — reduzem o
  custo de contexto no momento da invocação: o modelo carrega o template
  só quando preenche, não toda vez que decide se invoca a skill.

### Moved

- `global/skills/create-use-case/template-uc.md` →
  `global/skills/create-use-case/templates/use-case.md`
  (alinhamento com a convenção `templates/` das demais skills)

### Documentation

- README.md atualizado com:
  - Seção "Anatomia de uma skill" documentando a arquitetura (SKILL.md +
    templates/examples/references/scripts/config.json)
  - Esclarecimento de que domínios (AUTH/CAD/PED/etc.) são configuráveis
    por projeto, não uma lista universal
  - Seção "Contribuindo" revisada com guidelines para novas skills
    (trigger-condition descriptions, gotchas, progressive disclosure)
  - Link para este CHANGELOG

### Estatísticas desta versão

- 18 skills preexistentes atualizadas
- 1 skill nova (`validate-docs-rendered`)
- 19 arquivos novos de templates/references/examples
- 5 scripts POSIX (4 nas skills existentes + 1 na skill nova)
- 3 arquivos `config.json`
- 5 commits incrementais (uma fase por commit)

---

## [1.0.0] - 2026-04-18

Primeira versão publicada do toolkit.

### Added

- 18 skills globais cobrindo pipeline SDD completo (briefing, constitution,
  specify, clarify, plan, checklist, create-tasks, analyze, execute-task,
  review-task) e skills complementares (advisor, bugfix, create-use-case,
  image-generation, initialize-docs, insights, owasp-security,
  validate-documentation)
- Skills específicas para Go (commit, create-report, go-add-entity,
  go-add-migration, go-add-test, go-add-consumer, go-review-pr,
  go-review-service) e hooks de validação
- Skills específicas para .NET (create-entity, create-feature,
  create-project, create-test, hexagonal-architecture, infrastructure,
  review-code, testing)
- Arquivo `global/insights/usage-insights.md` com padrões extraídos de 134
  sessões reais de uso
- README documentando estrutura, pipeline SDD sugerido e convenções de
  nomenclatura

[2.0.0]: https://github.com/JotJunior/claude-ai-tips/releases/tag/v2.0.0
[1.1.0]: https://github.com/JotJunior/claude-ai-tips/releases/tag/v1.1.0
[1.0.0]: https://github.com/JotJunior/claude-ai-tips/releases/tag/v1.0.0
