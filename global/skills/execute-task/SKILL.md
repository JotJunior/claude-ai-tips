---
name: execute-task
description: |
  Executa uma tarefa especifica do projeto seguindo fluxo obrigatorio de 9 etapas:
  analise, localizacao, planejamento, implementacao, testes, validacao, lint, conclusao e atualizacao.
  Triggers: "executar tarefa", "execute task", "fazer tarefa", "implementar tarefa",
  "rodar tarefa", "executar subtarefa".
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
1. `docs/tasks.md`
2. `tasks.md`
3. `TODO.md`
4. `docs/TODO.md`
5. `.github/TODO.md`

### 2.2 Identificar a Tarefa

Encontre a tarefa especifica: **$ARGUMENTS**

Extraia:
- **ID da tarefa** (ex: TASK-CAD-001)
- **Descricao completa**
- **Subtarefas** (se houver)
- **Prioridade** (P0, P1, P2, P3)
- **Dependencias** (outras tarefas que precisam estar prontas)
- **Dominio** (CAD, PED, FIN, etc.)

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
1. Leia codigo relacionado existente
2. Leia CLAUDE.md para convencoes do projeto
3. Siga padroes e arquitetura do projeto
4. Implemente com tratamento de erros
5. Mantenha arquivos em UTF-8
```

**Principios obrigatorios:**
- Verifique assinaturas de metodos antes de implementar
- Use interfaces ao inves de implementacoes concretas
- Dependency Injection para dependencias
- Tratamento de erros com mensagens claras

**Para projetos Go (microservicos):**
- Toda query SQL DEVE incluir schema prefix (`schema.table`)
- Enum values DEVEM coincidir com CHECK constraints do PostgreSQL
- DTO field names DEVEM coincidir entre frontend e backend
- Rotas estaticas ANTES de rotas com `/:id` (Fiber trie)
- Codigo em ingles, UI text em portugues com acentos corretos

**Para projetos Frontend (React/TypeScript):**
- Usar componentes shared existentes (PageHeader, ServerPagination, etc.)
- CRUD forms em paginas dedicadas, NAO modais
- Hooks obrigatorios: useConfirmDialog para acoes destrutivas
- Path alias: `@/*` para `./src/*`

**Para tarefas multi-servico:**
- Use Agent para paralelizar trabalho em servicos independentes
- Trace DTOs e enums em TODOS os servicos afetados antes de implementar
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

### 7.1 Para Codigo Go

```bash
# Build (obrigatorio — hooks validam isso automaticamente)
cd services/{service} && go build ./...

# Lint
cd services/{service} && golangci-lint run ./...

# Vet
cd services/{service} && go vet ./...
```

### 7.2 Para Codigo Frontend (TypeScript/React)

```bash
cd services/{frontend} && npx tsc --noEmit
cd services/{frontend} && npm run lint
```

### 7.3 Para Documentacao

```
# Verificar formatacao Markdown
# Verificar sintaxe de tabelas
# Verificar code blocks
# Verificar diagramas Mermaid (sintaxe)
```

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

### Documentacao
- `UC-AUTH-NNN`: Autenticacao
- `UC-CAD-NNN`: Cadastros
- `UC-PED-NNN`: Pedidos
- `UC-FAT-NNN`: Faturamento
- `UC-FIN-NNN`: Financeiro
- `UC-LOG-NNN`: Logistica
- `UC-MON-NNN`: Monitoramento

### Regras e Testes
- `RN-NNN`: Regra de Negocio
- `CT-NNN`: Caso de Teste
- `E-NNN`: Codigo de Excecao
- `RNF-NNN`: Requisito Nao-Funcional

---

**EXECUTE AGORA A TAREFA: $ARGUMENTS**

**LEMBRE-SE:**
1. LEIA A DOCUMENTACAO em `docs/` ANTES de comecar
2. SIGA TODAS AS ETAPAS na ordem
3. NAO PULE etapas
4. MARQUE A TAREFA como [x] ao final