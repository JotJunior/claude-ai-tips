---
name: execute-task
description: |
  Use quando o usuario pedir para executar, fazer ou implementar uma tarefa
  especifica do backlog, seguindo fluxo obrigatorio de 9 etapas (analise,
  localizacao, planejamento, implementacao, testes, validacao, lint, conclusao
  e atualizacao). Tambem quando mencionar "executar tarefa", "execute task",
  "fazer tarefa", "implementar tarefa", "rodar tarefa", "executar subtarefa".
  NAO use para criar tarefas (use create-tasks), gerar plano tecnico
  (use plan) ou corrigir bug (use bugfix).
argument-hint: "[ID ou descricao da tarefa a executar]"
allowed-tools:
  - Read
  - Write
  - Edit
  - Glob
  - Grep
  - Bash
  - Agent
  - TaskCreate
  - TaskUpdate
---

# Skill: Executar Tarefa

Execute uma tarefa especifica do projeto seguindo o fluxo obrigatorio de execucao.

## Pre-requisitos

**Obrigatorio**: arquivo de tasks existente contendo a tarefa a executar.
Localizacoes suportadas: `docs/specs/*/tasks.md` (SDD), `docs/tasks.md`,
`docs/tasks-*.md`, `tasks.md`, `TODO.md`.

**Recomendado**: `spec.md`, `plan.md` e documentacao relacionada ja existentes
(a Etapa 1 da skill le esses antes de comecar).

## Proximos passos

1. `/execute-task {proxima-id}` — continuar com a proxima tarefa pendente
2. `/review-task` — revisar progresso e identificar dependencias desbloqueadas
3. `/analyze` — se suspeita de drift entre implementacao e spec

## Tarefa Solicitada

$ARGUMENTS

---

## FLUXO OBRIGATORIO DE EXECUCAO

**IMPORTANTE**: Siga TODAS as etapas na ordem. Nao pule etapas. Ao final de cada etapa, faca um mini-resumo do que foi feito e revise o fluxo de execucao.

```
1. ANALISE          Detectar contexto e ler documentacao
     |
2. LOCALIZACAO      Encontrar tarefa no arquivo de tarefas
     |
3. PLANEJAMENTO     Definir o que fazer e quais arquivos afetar
     |
4. IMPLEMENTACAO    Executar a tarefa (criar/modificar arquivos)
     |
5. TESTES           Executar testes (se aplicavel)
     |
6. VALIDACAO        Verificar qualidade e consistencia
     |
7. LINT             Verificar formatacao e padroes
     |
8. CONCLUSAO        Resumir o que foi feito
     |
9. ATUALIZACAO      Marcar tarefa como [x] no arquivo de tarefas
```

---

## ETAPA 1: ANALISE

### 1.1 Detectar Contexto do Projeto

Identifique o tipo de projeto:

| Tipo | Indicadores | Foco |
|------|-------------|------|
| **Documentacao** | `docs/` com `.md`, UC-*, ADRs, ausencia de `src/` | Markdown, diagramas |
| **Codigo** | `src/`, `app/`, `package.json`, `composer.json` | Implementacao, testes |
| **Misto** | Contem `docs/` e codigo-fonte | Ambos |

### 1.2 LEITURA OBRIGATORIA DE DOCUMENTACAO

**CRITICO**: Antes de executar QUALQUER tarefa, leia a documentacao relevante:

```
SEMPRE LER (se existirem):
-- README.md
-- CLAUDE.md
-- docs/
   -- tasks.md, tasks-{service}.md ou TODO.md
   -- 01-briefing-discovery/
   -- 02-requisitos-casos-uso/
   -- 03-modelagem-dados/
   -- arquitetura/
```

Para projetos com multiplos servicos, tambem verificar:
- `docs/tasks-{service-name}.md` (arquivo de tarefas especifico do servico)
- Padroes existentes em servicos similares (ler codigo de referencia)

### 1.3 Checklist da Analise

- [ ] Identifiquei o tipo de projeto
- [ ] Li o README.md
- [ ] Li o CLAUDE.md (se existir)
- [ ] Li a documentacao relevante em `docs/`
- [ ] Entendi o contexto da tarefa

---

## ETAPA 2: LOCALIZACAO

### 2.1 Encontrar Arquivo de Tarefas

Procure na seguinte ordem:
1. `docs/specs/*/tasks.md` — backlog ligado a uma spec SDD (prioritario se a tarefa vem de uma spec)
2. `docs/tasks.md`
3. `docs/tasks-*.md` — backlog por modulo/servico
4. `tasks.md`
5. `TODO.md`, `docs/TODO.md`, `.github/TODO.md`

**IMPORTANTE**: se a tarefa se origina de uma spec em `docs/specs/{name}/`, o
`tasks.md` a atualizar ao final esta em `docs/specs/{name}/tasks.md` — NAO em
`docs/tasks-*.md`. Criar ou atualizar arquivo errado quebra a composicao SDD.

### 2.2 Identificar a Tarefa

Encontre a tarefa especifica: **$ARGUMENTS**

Extraia:
- **ID da tarefa** (ex: 1.2.3 ou TASK-XYZ-001, no formato usado pelo projeto)
- **Descricao completa**
- **Subtarefas** (se houver)
- **Criticidade/prioridade** ([C]/[A]/[M] ou P0/P1/P2)
- **Dependencias** (outras tarefas que precisam estar prontas)
- **Dominio/contexto** (conforme convencao do projeto)

### 2.3 Checklist da Localizacao

- [ ] Encontrei o arquivo de tarefas
- [ ] Localizei a tarefa solicitada
- [ ] Identifiquei todas as subtarefas
- [ ] Verifiquei dependencias
- [ ] Confirmei que dependencias estao concluidas

---

## ETAPA 3: PLANEJAMENTO

### 3.1 Classificar Tipo de Tarefa

| Tipo | Exemplos | Acoes Principais |
|------|----------|------------------|
| Documentacao | Criar UC, atualizar ADR, modelagem | Criar/editar `.md` |
| Codigo | Implementar feature, corrigir bug | Criar/editar codigo |
| Testes | Criar testes, aumentar cobertura | Criar/editar testes |
| Infraestrutura | CI/CD, configs, scripts | Criar/editar configs |

### 3.2 Definir Escopo

Liste exatamente:
1. **Arquivos a CRIAR** (novos)
2. **Arquivos a MODIFICAR** (existentes)
3. **Arquivos a CONSULTAR** (referencia)
4. **Validacoes necessarias**

### 3.3 Identificar Padroes do Projeto

Antes de implementar, verifique:
- Convencoes de nomenclatura existentes
- Estrutura de arquivos similar
- Padroes de codigo/documentacao usados
- Templates existentes

### 3.4 Checklist do Planejamento

- [ ] Classifiquei o tipo de tarefa
- [ ] Listei arquivos a criar
- [ ] Listei arquivos a modificar
- [ ] Identifiquei padroes a seguir
- [ ] Tenho clareza do que fazer

---

## ETAPA 4: IMPLEMENTACAO

### 4.1 Para Tarefas de DOCUMENTACAO

```
1. Leia documentos relacionados existentes
2. Use templates/padroes do projeto
3. Crie/atualize documentos em Markdown
4. Inclua diagramas Mermaid quando apropriado
5. Mantenha links internos funcionais
6. Siga nomenclatura: UC-XXX-NNN, RN-NNN, CT-NNN
```

**Padroes obrigatorios:**
- Headers hierarquicos (# ## ### ####)
- Tabelas com alinhamento consistente
- Code blocks com linguagem especificada
- Links relativos para arquivos internos

### 4.2 Para Tarefas de CODIGO

```
1. Leia codigo relacionado existente (grep por simbolos similares)
2. Leia CLAUDE.md para convencoes do projeto
3. Siga padroes e arquitetura do projeto
4. Implemente com tratamento de erros adequado
5. Mantenha arquivos em UTF-8
```

**Principios obrigatorios (independente de stack):**
- Verifique assinaturas/interfaces existentes antes de implementar
- Prefira interfaces/abstracoes a implementacoes concretas quando convencao do projeto permitir
- Tratamento de erros com mensagens claras e acionaveis
- Siga convencoes de nomenclatura, layout de arquivos e estilo ja presentes no repositorio

**Ponto de atencao por camada (adaptar ao stack):**
- **Persistencia**: queries devem usar schema/namespace correto; valores enum devem bater com constraints do banco; scan/bind fields devem cobrir todas as colunas lidas
- **API/transporte**: nomes de campo devem bater entre cliente e servidor; ordem de rotas estaticas antes de dinamicas na maioria dos routers; versao do contrato preservada
- **Domain/Types**: tipos compartilhados (enums, DTOs) devem estar sincronizados em todas as camadas que os referenciam

**Para tarefas multi-modulo/servico:**
- Use Agent para paralelizar trabalho em modulos independentes
- Trace tipos, enums e contratos em TODOS os modulos afetados antes de implementar
- Grep por referencias residuais apos qualquer rename/refactor

### 4.3 Checklist da Implementacao

- [ ] Segui padroes existentes do projeto
- [ ] Criei todos os arquivos necessarios
- [ ] Modifiquei arquivos conforme planejado
- [ ] Codigo/documentacao esta completo
- [ ] Nao deixei TODOs pendentes

---

## ETAPA 5: TESTES

### 5.1 Para Projetos de Codigo

```bash
# Executar testes existentes
npm test / composer test / pytest / dotnet test

# Verificar se novos testes sao necessarios
# Criar testes para codigo novo
```

**Criterios:**
- [ ] Testes existentes passam
- [ ] Novos testes foram criados (se necessario)
- [ ] Cobertura adequada para codigo novo

### 5.2 Para Projetos de Documentacao

```
# Validar diagramas Mermaid (sintaxe)
# Verificar links internos
# Confirmar formatacao Markdown
```

**Criterios:**
- [ ] Diagramas Mermaid renderizam corretamente
- [ ] Links internos funcionam
- [ ] Markdown bem formatado

---

## ETAPA 6: VALIDACAO

### 6.1 Validacao de Qualidade

**Para Documentacao:**
- [ ] Todas as secoes obrigatorias preenchidas
- [ ] Conteudo claro e completo
- [ ] Sem erros de portugues/gramatica
- [ ] Diagramas legiveis e corretos
- [ ] Referencias cruzadas corretas

**Para Codigo:**
- [ ] Codigo compila/executa sem erros
- [ ] Funcionalidade implementada corretamente
- [ ] Tratamento de erros adequado
- [ ] Performance aceitavel
- [ ] Sem vulnerabilidades obvias

### 6.2 Validacao de Consistencia

- [ ] Consistente com documentacao existente
- [ ] Consistente com codigo existente
- [ ] Nomenclatura segue padroes
- [ ] Arquitetura respeitada

---

## ETAPA 7: LINT

Use o(s) comando(s) de lint/build padrao do stack em uso. Exemplos comuns:

| Stack | Comandos tipicos |
|-------|------------------|
| Go | `go build ./...`, `golangci-lint run ./...`, `go vet ./...` |
| Node / TypeScript | `npm run build`, `npx tsc --noEmit`, `npm run lint` |
| Rust | `cargo build`, `cargo clippy -- -D warnings`, `cargo fmt --check` |
| Python | `ruff check .`, `mypy .`, `python -m compileall .` |
| Java/Kotlin | `mvn compile`, `mvn verify`, `./gradlew build` |
| .NET | `dotnet build`, `dotnet format --verify-no-changes` |
| Documentacao | validar Markdown, tabelas, code blocks e diagramas Mermaid |

Se o projeto tem Makefile, README ou CI pipeline com comandos definidos, usar
esses — nao inventar comandos fora da convencao do projeto.

---

## ETAPA 8: CONCLUSAO

### 8.1 Gerar Relatorio de Execucao

```markdown
## Tarefa Executada

**Tarefa:** [ID e nome]
**Tipo:** [Documentacao/Codigo/Testes/Infraestrutura]
**Status:** Concluida

### Arquivos Criados
- `path/to/new-file`

### Arquivos Modificados
- `path/to/existing` - [descricao da mudanca]

### Testes
- [x] Testes executados: X passaram
- [x] Novos testes criados: Y

### Validacoes
- [x] Qualidade verificada
- [x] Consistencia verificada
- [x] Lint executado
```

---

## ETAPA 9: ATUALIZACAO

### 9.1 Marcar Tarefa como Concluida

**OBRIGATORIO**: Atualize o arquivo de tarefas!

```markdown
# Antes
- [ ] 1.1.1 Descricao da subtarefa

# Depois
- [x] 1.1.1 Descricao da subtarefa
```

### 9.2 Atualizar Subtarefas

Se houver subtarefas, marque TODAS como concluidas.

---

## NOMENCLATURAS COMUNS

Estas sao convencoes ilustrativas — a lista exata de dominios e prefixos e
definida pelo projeto. Se o projeto ja tem UCs/ADRs, derivar os codigos usados
via Glob em vez de assumir esta lista.

### Documentacao
- `UC-{DOMINIO}-NNN`: Caso de Uso (ex: UC-AUTH-001, UC-CAD-012)
- `ADR-NNN`: Architectural Decision Record
- `DER-{system}`: Diagrama Entidade-Relacionamento

### Regras e Testes
- `RN-NNN`: Regra de Negocio
- `CT-NNN`: Caso de Teste
- `E-NNN`: Codigo de Excecao
- `RNF-NNN`: Requisito Nao-Funcional
- `FA{N}`: Fluxo Alternativo

---

**EXECUTE AGORA A TAREFA: $ARGUMENTS**

**LEMBRE-SE:**
1. LEIA A DOCUMENTACAO em `docs/` ANTES de comecar
2. SIGA TODAS AS ETAPAS na ordem
3. NAO PULE etapas
4. MARQUE A TAREFA como [x] ao final

---

## Gotchas

### Ler documentacao ANTES de executar e OBRIGATORIO

Pular a etapa de analise leva a implementacao fora dos padroes do projeto. README, CLAUDE.md e docs/ contem as convencoes que o codigo nao revela sozinho. Rodar sem ler equivale a chutar estilo.

### Atualizar tasks.md no final e OBRIGATORIO

Tarefa concluida mas nao marcada `[x]` e tecnicamente nao-feita — o `/review-task` vai re-processar. Esta e a causa #1 de retrabalho. Marque como ultima acao da Etapa 9, sempre.

### Se a tarefa veio de uma spec, o tasks.md a atualizar esta na spec

Tarefa originada em `docs/specs/{name}/` atualiza `docs/specs/{name}/tasks.md`, NAO `docs/tasks-*.md` na raiz. Atualizar arquivo errado quebra a composicao SDD.

### Nao pular etapa de testes/lint por "tarefa pequena"

A etapa de lint/test e o gate que impede regressao. "Tarefa pequena" e o disfarce favorito do bug que vai aparecer em producao duas semanas depois. Se o projeto tem Makefile/CI com comandos definidos, use-os — nao invente shortcuts.

### STOP-AND-REMAP durante implementacao

Se durante a implementacao surge um issue em outra camada, pare, revise o plano (Etapa 3) e so entao continue. Perseguir issues emergentes sem remapear e a causa #1 de ciclos fix-reveal-fix.

### Detectar tipo de projeto antes de escolher comando

Rodar `go build` num projeto Python, ou `npm run lint` num projeto Rust, e ruido. A Etapa 1 (Analise) existe para identificar o stack — use-a antes de escolher comandos de lint.

### Cada etapa tem mini-resumo

O fluxo obrigatorio pede revisao ao final de cada etapa. Skip desse review fragiliza a cadeia — um erro na Etapa 2 so aparece na Etapa 6 e obriga refazer tudo. Mini-resumos sao barreiras contra isso.