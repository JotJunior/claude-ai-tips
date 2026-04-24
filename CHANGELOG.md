# Changelog

Todas as mudanças relevantes deste projeto são documentadas aqui.

O formato segue [Keep a Changelog](https://keepachangelog.com/pt-BR/1.1.0/) e
este projeto adere a [Semantic Versioning](https://semver.org/lang/pt-BR/).

## [Unreleased]

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
