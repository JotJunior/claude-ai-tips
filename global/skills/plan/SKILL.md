---
name: plan
description: |
  Gera plano de implementacao tecnico a partir de uma feature spec, incluindo
  pesquisa de tecnologias, modelo de dados, contratos de API e cenarios de teste.
  Triggers: "criar plano", "plan", "planejar implementacao", "plano tecnico",
  "implementation plan".
argument-hint: "[caminho para spec ou descricao da feature]"
allowed-tools:
  - Read
  - Write
  - Edit
  - Glob
  - Grep
  - Bash
  - Agent
---

# Skill: Plano de Implementacao Tecnico

Gere um plano de implementacao completo a partir de uma feature spec, cobrindo
arquitetura, decisoes tecnicas, modelo de dados e contratos.

## Argumentos

$ARGUMENTS

---

## FLUXO DE EXECUCAO

```
1. CONTEXTO           Carregar spec, constitution e projeto
     |
2. CONSTITUTION CHECK Gate obrigatorio antes de prosseguir
     |
3. TECHNICAL CONTEXT  Preencher stack, deps, constraints
     |
4. PHASE 0 — RESEARCH Resolver unknowns, pesquisar libs
     |
5. PHASE 1 — DESIGN   Modelo de dados, contratos, quickstart
     |
6. PLAN DOCUMENT       Consolidar plano final
     |
7. RE-CHECK            Revalidar constitution pos-design
     |
8. SALVAMENTO          Salvar artefatos e reportar
```

---

## ETAPA 1: CONTEXTO

### 1.1 Localizar Spec

Use $ARGUMENTS para encontrar a spec:
1. **Caminho direto**: usar como fornecido
2. **Nome da feature**: buscar `docs/specs/{name}/spec.md`
3. **Glob**: listar `docs/specs/*/spec.md` e pedir ao usuario para escolher

Se spec nao encontrada: instruir usuario a rodar `/specify` primeiro.

### 1.2 Carregar Documentos

```
OBRIGATORIO:
-- Feature spec (spec.md)

OPCIONAL (se existirem):
-- docs/constitution.md (principios de governanca)
-- CLAUDE.md (convencoes do projeto)
-- README.md (contexto geral)
-- docs/specs/{feature}/research.md (pesquisa previa, se rerrun)
```

### 1.3 Extrair da Spec

- User stories com prioridades
- Functional requirements
- Key entities
- Success criteria
- Edge cases
- [NEEDS CLARIFICATION] pendentes (devem ser resolvidos antes ou durante Phase 0)

---

## ETAPA 2: CONSTITUTION CHECK

### 2.1 Gate Obrigatorio

Se `docs/constitution.md` existe:

1. Carregar todos os principios MUST/SHOULD
2. Para cada principio, verificar se a feature spec esta em conformidade
3. Documentar resultado:

```markdown
## Constitution Check

*GATE: Deve passar antes do Phase 0. Re-checar apos Phase 1.*

| Principio | Status | Notas |
|-----------|--------|-------|
| [Nome] | PASS / FAIL / N/A | [Detalhes] |
```

4. Se FAIL em principio MUST: **ERROR** — nao prosseguir ate resolver

Se constitution nao existe: pular esta etapa e documentar "No constitution found".

---

## ETAPA 3: TECHNICAL CONTEXT

### 3.1 Preencher Contexto

Detectar do projeto e da spec (marcar unknowns como NEEDS CLARIFICATION):

```markdown
## Technical Context

**Language/Version**: [ex: Go 1.24, Python 3.11, TypeScript 5.x ou NEEDS CLARIFICATION]
**Primary Dependencies**: [ex: Chi v5, FastAPI, React 18 ou NEEDS CLARIFICATION]
**Storage**: [ex: PostgreSQL, Redis, files ou N/A]
**Testing**: [ex: go test, pytest, vitest ou NEEDS CLARIFICATION]
**Target Platform**: [ex: Kubernetes, Vercel, mobile ou NEEDS CLARIFICATION]
**Project Type**: [ex: library, cli, web-service, mobile-app ou NEEDS CLARIFICATION]
**Performance Goals**: [ex: 1000 req/s, 60 fps ou NEEDS CLARIFICATION]
**Constraints**: [ex: <200ms p95, <100MB memory ou NEEDS CLARIFICATION]
**Scale/Scope**: [ex: 10k users, 1M LOC ou NEEDS CLARIFICATION]
```

### 3.2 Inferencia

Antes de marcar NEEDS CLARIFICATION, tentar inferir de:
- `go.mod`, `package.json`, `pyproject.toml`, `Cargo.toml` — linguagem e deps
- `Dockerfile`, `docker-compose.yml`, K8s manifests — platform
- `CLAUDE.md` — convencoes e stack
- Patterns existentes no projeto — testing, storage

---

## ETAPA 4: PHASE 0 — RESEARCH

### 4.1 Resolver Unknowns

Para cada NEEDS CLARIFICATION no Technical Context:
- Pesquisar no projeto por evidencias
- Se nao resolvivel: criar task de pesquisa

Para cada dependencia/tecnologia:
- Verificar best practices para o contexto

### 4.2 Dispatch de Research (para unknowns complexos)

Para projetos complexos, usar Agent para pesquisa paralela:

```
Agent 1: "Research {unknown} for {feature context}"
Agent 2: "Find best practices for {tech} in {domain}"
```

### 4.3 Consolidar em research.md

```markdown
# Research: [FEATURE]

## Decision 1: [Topico]

**Decision**: [O que foi escolhido]
**Rationale**: [Por que escolhido]
**Alternatives considered**: [O que mais foi avaliado]

## Decision 2: [Topico]

**Decision**: [...]
**Rationale**: [...]
**Alternatives considered**: [...]
```

**Output**: `docs/specs/{feature}/research.md` com todos os NEEDS CLARIFICATION resolvidos.

---

## ETAPA 5: PHASE 1 — DESIGN

**Prerequisito**: research.md completo (todos os NEEDS CLARIFICATION resolvidos)

### 5.1 Modelo de Dados

Extrair entidades da spec → `data-model.md`:

```markdown
# Data Model: [FEATURE]

## Entity: [Name]

| Field | Type | Constraints | Notes |
|-------|------|-------------|-------|
| id | UUID | PK | Auto-generated |
| name | string | NOT NULL, min 3 chars | |
| status | enum | CHECK (active, inactive) | Default: active |
| created_at | timestamp | NOT NULL | Auto-set |

### Relationships

- [Entity A] 1:N [Entity B] via `entity_a_id`
- [Entity C] N:M [Entity D] via `entity_c_entity_d` join table

### State Transitions (if applicable)

draft → active → suspended → archived
```

**Output**: `docs/specs/{feature}/data-model.md`

### 5.2 Contratos de Interface

Se o projeto expoe interfaces externas (APIs, CLI, eventos):

```markdown
# Contracts: [FEATURE]

## [Endpoint/Command/Event]

**Method**: POST /api/v1/resource
**Auth**: Required (JWT)

### Request

| Field | Type | Required | Validation |
|-------|------|----------|------------|
| name | string | yes | min 3, max 100 |

### Response (200)

| Field | Type | Description |
|-------|------|-------------|
| id | uuid | Created resource ID |

### Error Responses

| Status | Code | Description |
|--------|------|-------------|
| 400 | VALIDATION_ERROR | Invalid input |
| 409 | CONFLICT | Resource already exists |
```

**Output**: `docs/specs/{feature}/contracts/` (um arquivo por grupo de endpoints)

Pular se projeto e puramente interno (build scripts, one-off tools).

### 5.3 Quickstart / Cenarios de Teste

```markdown
# Quickstart: [FEATURE]

## Scenario 1: [Happy Path]

1. [Passo]
2. [Passo]
3. **Expected**: [Resultado]

## Scenario 2: [Error Case]

1. [Passo]
2. **Expected**: [Erro esperado]
```

**Output**: `docs/specs/{feature}/quickstart.md`

---

## ETAPA 6: PLAN DOCUMENT

### 6.1 Template do Plano

Consolidar tudo no plano final:

```markdown
# Implementation Plan: [FEATURE]

**Feature**: `[short-name]` | **Date**: [DATE] | **Spec**: [link relativo]

## Summary

[Requisito primario + abordagem tecnica da pesquisa]

## Technical Context

[Conteudo da Etapa 3, com NEEDS CLARIFICATION ja resolvidos]

## Constitution Check

[Conteudo da Etapa 2]

## Project Structure

### Documentation (this feature)

docs/specs/[feature]/
├── spec.md
├── plan.md          # This file
├── research.md      # Phase 0 output
├── data-model.md    # Phase 1 output
├── quickstart.md    # Phase 1 output
└── contracts/       # Phase 1 output

### Source Code (repository root)

[Arvore de diretorios real do projeto, com paths concretos]

**Structure Decision**: [Decisao documentada sobre estrutura escolhida]

## Complexity Tracking

> Preencher APENAS se Constitution Check tem violacoes que precisam justificativa

| Violacao | Por Que Necessario | Alternativa Simples Rejeitada Porque |
|----------|-------------------|--------------------------------------|
| [ex: 4o servico] | [necessidade] | [por que 3 sao insuficientes] |
```

**Output**: `docs/specs/{feature}/plan.md`

---

## ETAPA 7: RE-CHECK

### 7.1 Revalidar Constitution

Se constitution existe, re-checar principios apos design:
- Design introduziu complexidade nao justificada?
- Principios MUST continuam respeitados?
- Atualizar tabela de Constitution Check se necessario

---

## ETAPA 8: SALVAMENTO

### 8.1 Artefatos Gerados

Listar todos os arquivos criados:

```markdown
## Artefatos

| Arquivo | Status |
|---------|--------|
| docs/specs/{feature}/plan.md | Criado |
| docs/specs/{feature}/research.md | Criado |
| docs/specs/{feature}/data-model.md | Criado |
| docs/specs/{feature}/contracts/*.md | Criado (se aplicavel) |
| docs/specs/{feature}/quickstart.md | Criado |
```

### 8.2 Reportar

```markdown
## Plano Criado

**Feature**: [short-name]
**Diretorio**: docs/specs/{feature}/
**Artefatos**: [N] arquivos gerados
**Constitution**: PASS / N/A
**NEEDS CLARIFICATION restantes**: 0

### Proximos Passos

1. `/checklist` — Gerar quality gate antes de implementar
2. `/create-tasks` — Decompor plano em tarefas executaveis
3. `/analyze` — Validar consistencia entre spec, plan e tasks (apos tasks)
```

---

## REGRAS IMPORTANTES

- **NEVER gerar codigo nesta fase** — apenas documentacao tecnica
- **NEEDS CLARIFICATION devem ser resolvidos** no Phase 0 (nao deixar para implementacao)
- **Constitution violations sao bloqueantes** — nao prosseguir sem resolver
- **Usar Agent para pesquisa paralela** em projetos complexos com multiplas unknowns
- **Paths devem ser reais** — verificar existencia de diretorios antes de referenciar
- **Phase 0 vem antes de Phase 1** — nao projetar modelo de dados com unknowns pendentes
