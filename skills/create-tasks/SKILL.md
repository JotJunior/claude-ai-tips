---
name: create-task-list
description: |
  Gera lista completa de tarefas de implementacao organizadas em milestones
  a partir da documentacao existente do projeto (UCs, ADRs, APIs, DDs, diagramas).
  Produz um arquivo indice (tasks-index.md) e um arquivo por milestone (tasks-{id}-{nome}.md).
  Triggers: "criar tarefas", "gerar tasks", "create tasks", "planejar implementacao",
  "criar lista de tarefas", "task breakdown", "gerar milestones".
allowed-tools:
  - Read
  - Write
  - Edit
  - Glob
  - Grep
  - Task
---

# Skill: Geracao de Lista de Tarefas

Esta skill gera uma lista completa e estruturada de tarefas de implementacao
a partir da documentacao existente do projeto. Produz arquivos Markdown com
milestones, tarefas, subtarefas, dependencias e vinculos com artefatos.

## Quando Usar

Claude deve invocar esta skill automaticamente quando:
- Usuario pedir para criar/gerar lista de tarefas de implementacao
- Usuario mencionar "tasks", "tarefas", "milestones", "task breakdown"
- Houver necessidade de transformar documentacao em plano de execucao
- Usuario pedir para planejar a implementacao do projeto
- Usuario pedir para decompor o projeto em tarefas

## Entrada Esperada

A skill espera que o projeto tenha documentacao existente. Tipos de artefatos reconhecidos:

| Tipo | Padrao de ID | Descricao |
|------|-------------|-----------|
| **Use Cases** | UC-{NNN} ou UC-{DOM}-{NNN} | Casos de uso com fluxos e regras |
| **ADRs** | ADR-{NNN} | Decisoes de arquitetura |
| **APIs** | API-{NNN} | Definicoes de endpoints e contratos |
| **Data Definitions** | DD-{nome} | Modelos de dados e dicionarios |
| **Diagramas** | DER, C4, sequencia, etc. | Diagramas tecnicos |
| **Briefing/Discovery** | Qualquer formato | Documentos de requisitos iniciais |

## Saida Produzida

### 1. Arquivo Indice: `tasks-index.md`

Contem:
- Resumo com total de tarefas e milestones
- Tabela de milestones com links, contagem e dependencias
- Grafo de dependencias (arvore ASCII)
- Cobertura de artefatos (quais UCs, ADRs, APIs, DDs cada milestone referencia)
- Ordem de execucao sugerida por fases

### 2. Arquivos por Milestone: `tasks-{id}-{nome}.md`

Cada arquivo contem:
- Header com objetivo, dependencias, entregavel e progresso
- Tarefas com subtarefas detalhadas
- Referencias a artefatos vinculados

## Estrutura das Tarefas

### Formato de Tarefa Principal

```markdown
- [ ] **{MILESTONE_ID}-{NNN}** — {Descricao da tarefa} `{REF-1}` `{REF-2}`
```

Onde:
- `MILESTONE_ID` = ID do milestone (ex: M0, M1, M2)
- `NNN` = Numero sequencial de 3 digitos (001, 002, 003)
- `Descricao` = Acao clara no infinitivo (Criar, Configurar, Implementar)
- `REF-N` = Referencia a artefato vinculado entre backticks

### Formato de Subtarefa

```markdown
  - [ ] {MILESTONE_ID}-{NNN}.{N} — {Descricao da subtarefa}
```

Onde:
- `N` = Numero sequencial da subtarefa (1, 2, 3)
- Indentacao de 2 espacos
- Sem referencias (herdadas da tarefa pai)

### Regras de Decomposicao

1. **Granularidade**: Cada subtarefa deve ser executavel em uma sessao de trabalho
2. **Atomicidade**: Cada subtarefa deve produzir um resultado verificavel
3. **Completude**: A soma das subtarefas deve cobrir toda a tarefa pai
4. **Independencia**: Subtarefas devem ser minimamente dependentes entre si
5. **Clareza**: Descricoes devem iniciar com verbo no infinitivo
6. **Limite**: Maximo de 7 subtarefas por tarefa (se precisar mais, divida a tarefa)

### Exemplos de Boa Decomposicao

```markdown
- [ ] **M1-002** — Criar migration da tabela users `DD-autenticacao` `UC-001`
  - [ ] M1-002.1 — Criar campos id (UUID PK), email (UNIQUE), senha_hash e nome
  - [ ] M1-002.2 — Criar campos tipo e status com ENUMs
  - [ ] M1-002.3 — Criar campos de timestamps (criado_em, atualizado_em)
  - [ ] M1-002.4 — Criar indexes necessarios

- [ ] **M3-005** — Implementar endpoint POST /stores `API-002` `UC-003`
  - [ ] M3-005.1 — Criar handler com validacao de payload
  - [ ] M3-005.2 — Implementar logica de negocio no service
  - [ ] M3-005.3 — Criar repository para persistencia
  - [ ] M3-005.4 — Adicionar testes unitarios
```

## Processo de Geracao

### Fase 1: Descoberta de Artefatos

1. Escanear o diretorio `docs/` (ou equivalente) do projeto
2. Identificar e catalogar todos os artefatos:
   - Use Cases (UC-*)
   - ADRs (ADR-*)
   - APIs (API-*)
   - Data Definitions (DD-*)
   - Diagramas e outros documentos tecnicos
3. Ler cada artefato para extrair requisitos, decisoes e restricoes

### Fase 2: Definicao de Milestones

1. Agrupar funcionalidades em milestones logicos
2. Definir dependencias entre milestones
3. Para cada milestone, definir:
   - ID sequencial (M0, M1, M2...)
   - Nome descritivo (max 30 caracteres)
   - Objetivo (1 frase)
   - Entregavel concreto (o que esta "pronto" ao final)
   - Dependencias de outros milestones

**Diretrizes para milestones:**

| Diretriz | Descricao |
|----------|-----------|
| **M0 sempre existe** | Bootstrap/infraestrutura do projeto |
| **Ordenacao por dependencia** | Milestones dependentes vem depois |
| **Tamanho equilibrado** | 10-25 tarefas por milestone |
| **Entregavel concreto** | Cada milestone deve produzir algo funcional |
| **Coesao tematica** | Tarefas do mesmo dominio juntas |

### Fase 3: Decomposicao em Tarefas

Para cada milestone:

1. Analisar os artefatos referenciados
2. Extrair tarefas concretas de implementacao
3. Decompor cada tarefa em subtarefas
4. Vincular cada tarefa aos artefatos fonte (UCs, ADRs, APIs, DDs)
5. Numerar sequencialmente

**Categorias comuns de tarefas:**

| Categoria | Verbos | Exemplos |
|-----------|--------|----------|
| Infraestrutura | Configurar, Criar, Instalar | Docker, CI/CD, configs |
| Banco de Dados | Criar migration, Definir schema | Tabelas, indexes, triggers |
| Backend | Implementar, Criar handler/service | Endpoints, logica, workers |
| Frontend | Criar componente, Implementar tela | Pages, components, hooks |
| Integracao | Conectar, Integrar, Sincronizar | APIs externas, webhooks |
| Testes | Criar testes, Testar | Unitarios, integracao, e2e |
| Documentacao | Documentar, Criar README | Setup, APIs, contributing |

### Fase 4: Montagem do Indice

1. Calcular totais (tarefas por milestone e total geral)
2. Montar tabela de milestones
3. Gerar grafo de dependencias em ASCII
4. Mapear cobertura de artefatos (qual milestone cobre qual UC/ADR/API/DD)
5. Definir ordem de execucao por fases

### Fase 5: Geracao dos Arquivos

1. Gerar `tasks-index.md` usando o template
2. Gerar um `tasks-{id}-{nome}.md` por milestone usando o template
3. Validar consistencia:
   - Todos os artefatos referenciados existem
   - Todas as dependencias sao validas
   - Numeracao sequencial sem gaps
   - Totais batem com contagem real

## Convencoes de Nomenclatura

### Arquivos

```
tasks-index.md                    # Indice geral
tasks-m00-bootstrap.md            # Milestone M0
tasks-m01-banco-dados.md          # Milestone M1
tasks-m02-autenticacao.md         # Milestone M2
tasks-m{NN}-{slug-kebab-case}.md  # Padrao geral
```

### IDs

```
M{N}          # Milestone (M0, M1, M2...)
M{N}-{NNN}    # Tarefa (M0-001, M1-015)
M{N}-{NNN}.{N} # Subtarefa (M0-001.1, M1-015.3)
```

### Referencias a Artefatos

Sempre entre backticks simples no formato original do artefato:

```markdown
`ADR-001` `UC-003` `API-005` `DD-autenticacao`
```

## Interacao com o Usuario

### Antes de gerar, perguntar:

1. **Diretorio de saida**: Onde salvar os arquivos de tarefas (sugerir `docs/`)
2. **Escopo**: Gerar tarefas para todo o projeto ou apenas parte
3. **Nivel de detalhe**: Se incluir testes como tarefas separadas ou embutidas

### Durante a geracao:

1. Mostrar lista de artefatos encontrados
2. Apresentar proposta de milestones para validacao
3. Gerar os arquivos apos confirmacao

### Apos gerar:

1. Exibir resumo com total de milestones, tarefas e subtarefas
2. Indicar os arquivos criados
3. Sugerir proximos passos (`/execute-task M0-001`)

## Checklist de Qualidade

Antes de finalizar, verificar:

- [ ] Todos os artefatos do projeto estao referenciados em ao menos uma tarefa
- [ ] Nenhuma tarefa sem referencia a artefato (exceto tarefas genericas de infra)
- [ ] Dependencias entre milestones sao consistentes (sem ciclos)
- [ ] Numeracao sequencial sem gaps em cada milestone
- [ ] Totais no indice batem com contagem real nos arquivos
- [ ] Subtarefas cobrem completamente cada tarefa pai
- [ ] Descricoes claras e acionaveis (verbo no infinitivo)
- [ ] Grafo de dependencias reflete a realidade
- [ ] Ordem de execucao respeita o caminho critico
- [ ] Cada milestone tem entre 10 e 25 tarefas (ajustar se necessario)