# Claude Code Toolkit

Conjunto de ferramentas para aumentar a produtividade no desenvolvimento do dia a dia com
o [Claude Code](https://claude.ai/code).

Este repositorio contém **skills**, **hooks** e **insights** que estendem as capacidades do Claude Code
para tarefas de documentação, desenvolvimento, segurança e qualidade de código.

## Estrutura

```
├── global/                     # Skills e insights globais (independentes de linguagem)
│   ├── insights/               # Insights de uso extraídos de sessões reais
│   │   └── usage-insights.md   # Padrões de fricção e estratégias comprovadas
│   └── skills/                 # 19 skills globais (cada skill é uma pasta)
│       ├── advisor/
│       ├── analyze/
│       ├── apply-insights/
│       ├── briefing/
│       ├── bugfix/
│       ├── checklist/
│       ├── clarify/
│       ├── constitution/
│       ├── create-tasks/
│       ├── create-use-case/
│       ├── execute-task/
│       ├── image-generation/
│       ├── initialize-docs/
│       ├── owasp-security/
│       ├── plan/
│       ├── review-task/
│       ├── specify/
│       ├── validate-docs-rendered/
│       └── validate-documentation/
├── language-related/           # Skills e hooks específicos por linguagem
│   ├── go/                     # Go
│   │   ├── skills/             # Skills para projetos Go
│   │   ├── hooks/              # Hooks de validação para Go
│   │   └── settings.json       # Configuração de hooks
│   └── dotnet/                 # .NET
│       └── skills/             # Skills para projetos .NET
```

### Anatomia de uma skill

Cada skill é uma pasta contendo um `SKILL.md` (ponto de entrada) e, conforme
o caso, subpastas que o Claude consulta sob demanda. Isso aplica o princípio
de *progressive disclosure* — o modelo paga só o contexto necessário no
momento de invocação, e carrega detalhes sob demanda:

```
skills/<nome>/
├── SKILL.md             # Ponto de entrada: quando invocar, regras de alto
│                        # nível, gotchas, ponteiros para subpastas
├── templates/           # Templates preenchíveis (feature-spec, plan, tasks...)
├── examples/            # Casos concretos (good.md vs bad.md)
├── references/          # Documentação de apoio (guias, catálogos, tabelas)
├── scripts/             # Scripts POSIX executáveis (next-id, scaffold, metrics...)
└── config.json          # Configuração por projeto (opcional)
```

Nem toda skill usa todas as subpastas — skills simples são só um `SKILL.md`.

## Skills Globais

Skills disponíveis em `global/skills/`, independentes de linguagem ou framework:

### Pipeline SDD (Spec-Driven Development)

Skills que formam o pipeline completo de desenvolvimento orientado por especificação:

| Skill | Trigger | Descrição |
|-------|---------|-----------|
| **briefing** | "briefing", "discovery", "novo projeto" | Entrevista estruturada de discovery coletando visão, usuários, restrições e contexto técnico |
| **constitution** | "constitution", "princípios do projeto" | Cria princípios imutáveis de governança que guiam decisões de arquitetura e qualidade |
| **specify** | "specify", "criar spec", "nova feature" | Transforma descrição natural em feature spec SDD com user stories, requisitos e critérios de aceite |
| **clarify** | "clarify", "resolver ambiguidades" | Identifica áreas sub-especificadas e resolve ambiguidades via perguntas estruturadas (max 5) |
| **plan** | "plan", "plano técnico" | Gera plano de implementação com pesquisa de tecnologias, modelo de dados e contratos de API |
| **checklist** | "checklist", "quality gate" | Gera checklists de validação de qualidade de requisitos — "Unit Tests for English" |
| **create-tasks** | "criar tarefas", "criar backlog" | Cria backlog de tarefas técnicas estruturado por fases com dependências |
| **analyze** | "analyze", "analisar consistência" | Análise read-only de consistência cross-artifact entre spec, plan, tasks e constitution |
| **execute-task** | "executar tarefa", "execute task" | Executa tarefa seguindo workflow obrigatório de 9 etapas |
| **review-task** | "revisar tarefas", "status das tarefas" | Gera relatório de status com progresso e recomendações |

### Skills Complementares

Skills independentes que podem ser usados em qualquer momento:

| Skill | Trigger | Descrição |
|-------|---------|-----------|
| **advisor** | "me aconselhe", "analise estratégica" | Conselheiro brutalmente honesto que disseca raciocínio e gera planos de ação |
| **bugfix** | "bugfix", "fix bug", "debug" | Protocolo estruturado de correção de bugs multi-camada |
| **create-use-case** | "criar caso de uso", "gerar UC" | Gera documentação de caso de uso com template de 15 seções e diagramas Mermaid |
| **image-generation** | Ao gerar imagens | Aprimora prompts de geração de imagens usando estrutura Subject-Context-Style |
| **initialize-docs** | "inicializar docs", "setup documentação" | Cria hierarquia padrão de documentação com 9 níveis |
| **apply-insights** | "aplicar insights", "aplicar playbook", "melhorar claude.md" | Analisa o projeto e aplica insights de uso comprovados ao CLAUDE.md, hooks e workflows. Renomeada de `insights` na 2.0.0 para evitar colisão com o `/insights` nativo do Claude Code (que tem função diferente — analisa suas sessões) |
| **owasp-security** | Ao revisar segurança | Revisão de segurança cobrindo OWASP Top 10:2025, ASVS 5.0 e segurança de IA Agêntica (2026) |
| **validate-documentation** | "validar documentação", "verificar UC" | Valida documentos individuais contra padrões de qualidade estrutural |
| **validate-docs-rendered** | "validar renderização", "verificar diagramas" | Valida que a documentação Markdown renderiza corretamente (Mermaid, links internos, frontmatter, tabelas) |

---

### Pipeline SDD — Sequência de Uso

O pipeline SDD é a sequência recomendada para levar uma ideia desde o discovery até a implementação.
Cada skill consome os artefatos do anterior e alimenta o próximo.

```
 ┌──────────────┐
 │  DISCOVERY   │
 └──────┬───────┘
        │
   ① briefing          Entrevista de discovery → docs/01-briefing-discovery/briefing.md
        │                Coleta visão, usuários, escopo, restrições e stack.
        │                Pergunta UMA pergunta por vez (max 10).
        ▼
   ② constitution      Briefing → docs/constitution.md
        │                Define princípios MUST/SHOULD que governam todas as decisões.
        │                Validado contra artefatos existentes (propagação).
        ▼
 ┌──────────────┐
 │ ESPECIFICAÇÃO│
 └──────┬───────┘
        │
   ③ specify            Descrição natural → docs/specs/{feature}/spec.md
        │                Gera user stories priorizadas, requisitos funcionais,
        │                critérios de aceite e success criteria mensuráveis.
        │                Foco no QUE e POR QUÊ — nunca no COMO.
        ▼
   ④ clarify            Spec → Spec refinada (in-place)
        │                Escaneia ambiguidades por taxonomia (10 categorias).
        │                Faz max 5 perguntas com opções e recomendação.
        │                Integra respostas diretamente na spec.
        ▼
 ┌──────────────┐
 │ PLANEJAMENTO │
 └──────┬───────┘
        │
   ⑤ plan              Spec → docs/specs/{feature}/plan.md + research.md + data-model.md
        │                Pesquisa tecnologias, define modelo de dados,
        │                contratos de API e cenários de teste.
        │                Valida contra constitution (gate obrigatório).
        ▼
   ⑥ checklist          Plan + Spec → docs/specs/{feature}/checklists/{domain}.md
        │                "Unit Tests for English" — valida QUALIDADE dos requisitos,
        │                não da implementação. Domínios: ux, api, security, performance.
        ▼
 ┌──────────────┐
 │ IMPLEMENTAÇÃO│
 └──────┬───────┘
        │
   ⑦ create-tasks      Plan → Backlog de tarefas estruturado por fases
        │                Tarefas com IDs, criticidade e matriz de dependências.
        ▼
   ⑧ analyze           Spec + Plan + Tasks + Constitution → Relatório de consistência
        │                Detecta duplicações, ambiguidades, gaps de cobertura
        │                e violações de princípios. Estritamente READ-ONLY.
        ▼
   ⑨ execute-task      Task → Código implementado (workflow de 9 etapas)
        │                Análise → Localização → Planejamento → Implementação →
        │                Testes → Validação → Lint → Conclusão → Atualização.
        ▼
   ⑩ review-task       Tasks → Relatório de status com métricas e próximas ações
```

#### Quando usar cada skill

| Momento | Skill | Entrada | Saída |
|---------|-------|---------|-------|
| Projeto novo ou feature grande | `briefing` | Conversa interativa | `briefing.md` |
| Após briefing | `constitution` | Briefing + contexto | `constitution.md` |
| Nova feature | `specify` | Descrição em linguagem natural | `spec.md` |
| Spec com dúvidas | `clarify` | `spec.md` existente | `spec.md` atualizada |
| Spec pronta | `plan` | `spec.md` | `plan.md`, `data-model.md`, `contracts/` |
| Antes de implementar | `checklist` | Spec + Plan | `checklists/{domain}.md` |
| Plan pronto | `create-tasks` | `plan.md` | Backlog estruturado |
| Tasks criadas | `analyze` | Todos os artefatos | Relatório de consistência |
| Task específica | `execute-task` | ID da tarefa | Código + relatório |
| Acompanhamento | `review-task` | Arquivo de tasks | Relatório de progresso |

#### Atalhos — Nem sempre é preciso percorrer todo o pipeline

- **Feature simples**: `specify` → `plan` → `create-tasks` → `execute-task`
- **Bug fix**: `bugfix` (skill independente, não requer pipeline)
- **Projeto existente sem docs**: `initialize-docs` → `briefing` → `constitution`
- **Só precisa de tasks**: `create-tasks` direto (se já tem contexto suficiente)

---

### Workflow: execute-task

O skill `execute-task` impõe um workflow completo de 9 etapas:

1. **Análise** - Detectar contexto e ler documentação
2. **Localização** - Encontrar tarefa no arquivo de tarefas
3. **Planejamento** - Definir escopo e identificar padrões
4. **Implementação** - Executar a tarefa
5. **Testes** - Rodar testes se aplicável
6. **Validação** - Verificar qualidade e consistência
7. **Lint** - Checar formatação e padrões
8. **Conclusão** - Gerar relatório de execução
9. **Atualização** - Marcar tarefa como concluída

### Protocolo: bugfix

O skill `bugfix` implementa um protocolo de 8 etapas derivado da análise de 71 correções de bugs
em 134 sessões. Projetado para eliminar ciclos de "corrige-revela-corrige" em arquiteturas multi-serviço:

- Classifica complexidade (simples vs. multi-camada)
- Rastreia o fluxo de dados completo antes de qualquer alteração
- Mapeia DTOs, enums e nomes de campo em todas as fronteiras
- Implementa correções em todas as camadas afetadas de uma vez

## Insights de Uso

O diretório `global/insights/` contém padrões extraídos de sessões reais de uso (1.490 mensagens,
134 sessões). Esses insights alimentam skills como `bugfix` e `apply-insights`, e documentam:

- **Padrões de fricção recorrentes** - Bugs em cascata multi-serviço, abordagens iniciais erradas, artefatos obsoletos
- **Estratégias comprovadas** - Protocolo de bug fix, segurança em migrations, convenções de código
- **Recomendações para CLAUDE.md** - Regras e hooks que melhoram a efetividade do Claude Code

Use o skill `apply-insights` para analisar seu projeto e aplicar automaticamente as recomendações relevantes.

> **Nota:** o Claude Code também tem uma slash command nativa `/insights` que analisa suas
> sessões (função introspectiva). A skill `apply-insights` é prescritiva — aplica um playbook
> curado ao projeto. Por isso o rename na versão 2.0.0: evitar colisão de nome.

## Skills para Go

Skills em `language-related/go/skills/` para projetos Go:

| Skill | Trigger | Descrição |
|-------|---------|-----------|
| **commit** | "commit", "commitar" | Commits com conventional commits, suporte a submodules e mudanças multi-serviço |
| **create-report** | "criar relatório", "novo relatório" | Implementa novo tipo de relatório end-to-end em 4 serviços |
| **go-add-entity** | — | Adiciona uma nova entidade ao serviço |
| **go-add-migration** | — | Cria nova migration SQL |
| **go-add-test** | — | Gera testes para código Go |
| **go-add-consumer** | — | Adiciona consumer de mensagens (RabbitMQ) |
| **go-review-pr** | "review pr", "quality gate" | Quality gate pré-PR, diff-aware, com revisão em 8 etapas |
| **go-review-service** | — | Revisa qualidade de um serviço Go |

### Hooks para Go

Hooks em `language-related/go/hooks/` para validações automáticas:

| Hook | Descrição |
|------|-----------|
| **go-build-gate.sh** | Valida build antes de operações |
| **check-uncommitted.sh** | Verifica alterações não commitadas |
| **check-schema-prefix.sh** | Valida prefixo de schema nas migrations |
| **check-route-order.sh** | Verifica ordenação de rotas no router |

## Skills para .NET

Skills em `language-related/dotnet/skills/` para projetos .NET:

| Skill | Descrição |
|-------|-----------|
| **dotnet-create-entity** | Cria entidade com mapeamento EF Core |
| **dotnet-create-feature** | Gera feature completa (handler, validator, etc.) |
| **dotnet-create-project** | Scaffolding de novo projeto .NET |
| **dotnet-create-test** | Gera testes unitários e de integração |
| **dotnet-hexagonal-architecture** | Aplica arquitetura hexagonal |
| **dotnet-infrastructure** | Configura infraestrutura (DB, cache, messaging) |
| **dotnet-review-code** | Revisa qualidade de código .NET |
| **dotnet-testing** | Estratégias e padrões de teste |

## Instalação

Copie os diretórios desejados para o seu projeto ou instalação global do Claude Code:

```bash
# Skills globais — copiar para o projeto
cp -r global/skills/ seu-projeto/.claude/skills/

# Skills globais — instalação global
cp -r global/skills/ ~/.claude/skills/

# Insights — copiar para o projeto (usado pelo skill apply-insights)
cp -r global/insights/ seu-projeto/.claude/insights/

# Skills de Go — copiar para projeto Go
cp -r language-related/go/skills/ seu-projeto/.claude/skills/
cp -r language-related/go/hooks/ seu-projeto/.claude/hooks/
cp language-related/go/settings.json seu-projeto/.claude/settings.json

# Skills de .NET — copiar para projeto .NET
cp -r language-related/dotnet/skills/ seu-projeto/.claude/skills/
```

### Estrutura de Destino

```
~/.claude/                  # Instalação global
├── skills/
└── insights/               # (opcional, para insights de uso)

seu-projeto/
└── .claude/                # Instalação por projeto
    ├── skills/
    ├── hooks/              # (opcional, para hooks de linguagem)
    └── insights/           # (opcional, para insights de uso)
```

## Convenções de Nomenclatura

| Tipo | Padrão | Exemplo |
|------|--------|---------|
| Casos de Uso | `UC-{DOMÍNIO}-{NNN}` | UC-CAD-001 |
| Decisões de Arquitetura | `ADR-{NNN}-{título}` | ADR-001-database |
| Regras de Negócio | `RN{NN}` | RN01 |
| Casos de Teste | `CT{NN}` | CT01 |
| Exceções | `E{NNN}` | E001 |

### Códigos de Domínio

Os códigos de domínio são **definidos por projeto**, não universais. A partir
de 1.1.0, as skills consultam os domínios reais via:

1. Campo `domains` em `config.json` (quando o projeto define explicitamente)
2. Glob de UCs existentes (quando o projeto já tem documentação)
3. Pergunta ao usuário via AskUserQuestion (quando ambos ausentes)

Exemplos comuns em projetos de negócio: `AUTH` (autenticação), `CAD`
(cadastros), `PED` (pedidos), `FIN` (financeiro). Use o que faz sentido no
seu domínio — a skill `create-use-case` não assume mais uma lista fixa.

## Hierarquia de Documentação

O skill `/initialize-docs` cria a seguinte estrutura:

```
docs/
├── 01-briefing-discovery/      # Requisitos iniciais, PDFs
├── 02-requisitos-casos-uso/    # Casos de uso (UC-*)
├── 03-modelagem-dados/         # DERs, schemas
├── 04-arquitetura-sistema/     # ADRs, diagramas
├── 05-definicao-apis/          # REST, gRPC, Webhooks, Messaging
├── 06-ui-ux-design/            # Wireframes, mockups
├── 07-plano-testes/            # Planos de teste
├── 08-operacoes/               # Runbooks
└── 09-entregaveis/             # Release notes
```

## Contribuindo

Contribuições são bem-vindas. Para adicionar novos skills ou hooks:

1. Siga a estrutura de pasta de uma skill existente (ver [Anatomia de uma skill](#anatomia-de-uma-skill))
2. Crie um `SKILL.md` como ponto de entrada — mantenha enxuto e use subpastas para conteúdo pesado
3. **description**: escreva como trigger condition, não resumo — "Use quando X, Y ou Z. Também quando mencionar A, B, C. NÃO use quando W."
4. **Gotchas**: documente armadilhas conhecidas — o conteúdo mais valioso de uma skill
5. **Templates/examples/references**: extraia conteúdo que o modelo consulta sob demanda
6. **Scripts**: prefira POSIX sh para operações determinísticas (next-id, validação, scaffold)
7. **config.json**: use para parâmetros que variam entre projetos
8. Teste com o Claude Code antes de submeter

## Categorias de Skills

A partir da versão 2.1.0, o toolkit é organizado em **3 namespaces por propósito**. Cada namespace tem README próprio com critérios de inclusão.

| Namespace | Propósito | Critério de inclusão | README |
|-----------|-----------|----------------------|--------|
| [`language-related/`](./language-related/) | **Como o código é escrito** | Específico de linguagem/ecossistema (Go, .NET, TS, Python) | [ver](./language-related/README.md) |
| [`platform-related/`](./platform-related/) | **Onde o código é executado / como recursos são provisionados** | Específico de runtime, CLI proprietária, API de provisionamento | [ver](./platform-related/README.md) |
| [`data-related/`](./data-related/) | **Como dados são consumidos** | Queries, DSL, mapping de serviços externos (DB, search, cache) | [ver](./data-related/README.md) |

### Princípio de partição

A regra para decidir onde uma skill entra:

- Se responde **"como escrevo código em X?"** → `language-related/`
- Se responde **"como provisiono/deployo/opero o recurso?"** → `platform-related/`
- Se responde **"como meu código fala com o recurso já provisionado?"** → `data-related/`

**Exemplo concreto com D1 (Cloudflare)**: criar banco via `wrangler d1 create` e aplicar migration via `wrangler d1 migrations apply` vai para `platform-related/cloudflare-workers/`. Escrever queries SQL otimizadas, padrões de `prepare().bind().batch()`, setup de FTS5, modelagem de schema vai para `data-related/d1/`. Mesmo serviço, facetas separadas.

### Matriz atual

| Namespace | Subpastas | Status |
|-----------|-----------|--------|
| `language-related/` | `go/` ✓ estável, `dotnet/` ✓ estável, `typescript/` planejada, `python/` planejada | parcial |
| `platform-related/` | `cloudflare-shared/`, `cloudflare-workers/`, `cloudflare-dns/`, `neon/` planejadas | scaffold |
| `data-related/` | `postgres/`, `d1/`, `elasticsearch/` planejadas | scaffold |

### Skills globais agnósticas

Skills que não são específicas de linguagem, plataforma ou serviço continuam em [`global/skills/`](./global/skills/) — inclui o pipeline SDD (`briefing`, `constitution`, `specify`, `clarify`, `plan`, `checklist`, `create-tasks`, `analyze`, `execute-task`, `review-task`) e skills complementares (`advisor`, `bugfix`, `create-use-case`, `image-generation`, `initialize-docs`, `owasp-security`, `apply-insights`, `validate-documentation`, `validate-docs-rendered`).

Nova skill agnóstica a partir de 2.1.0:

- [`cred-store`](./global/skills/cred-store/) — leitura de credenciais via cascata (env → 1Password → Keychain → arquivo)
- [`cred-store-setup`](./global/skills/cred-store-setup/) — registro interativo de credenciais

Usada por consumidores em `platform-related/` e `data-related/` para evitar duplicação de lógica de secrets por integração.

## Versionamento

Este projeto segue [Semantic Versioning](https://semver.org/) e mantém um
[CHANGELOG.md](./CHANGELOG.md) com o histórico de mudanças.

## Licença

MIT
