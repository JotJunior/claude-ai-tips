# Changelog

Todas as mudanças relevantes deste projeto são documentadas aqui.

O formato segue [Keep a Changelog](https://keepachangelog.com/pt-BR/1.1.0/) e
este projeto adere a [Semantic Versioning](https://semver.org/lang/pt-BR/).

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
