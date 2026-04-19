---
name: specify
description: |
  Use quando o usuario descrever uma nova feature em linguagem natural e pedir
  para transformar em spec SDD estruturada (user stories, requisitos
  funcionais, success criteria). Tambem quando mencionar "specify", "criar
  spec", "nova feature", "especificacao", "feature spec". NAO use para
  documentacao classica de UC (use create-use-case) ou para refinar spec
  existente (use clarify).
argument-hint: "[descricao da feature em linguagem natural]"
allowed-tools:
  - Read
  - Write
  - Edit
  - Glob
  - Grep
  - Bash
---

# Skill: Especificar Feature (SDD)

Transforme uma descricao em linguagem natural em uma feature spec completa seguindo
o formato Spec-Driven Development. Foco no QUE e POR QUE — nunca no COMO implementar.

## Argumentos

$ARGUMENTS

---

## FLUXO DE EXECUCAO

```
1. ANALISE         Parsear descricao e extrair conceitos
     |
2. ESTRUTURA       Criar diretorio e gerar short name
     |
3. ESPECIFICACAO   Preencher template com conteudo concreto
     |
4. VALIDACAO       Checar qualidade contra criterios internos
     |
5. CLARIFICACAO    Resolver ambiguidades criticas com o usuario
     |
6. SALVAMENTO      Salvar e reportar proximos passos
```

---

## ETAPA 1: ANALISE

### 1.1 Parsear Descricao

Extraia do input ($ARGUMENTS):
- **Atores**: Quem usa a feature (usuarios, admins, sistemas)
- **Acoes**: O que a feature permite fazer
- **Dados**: Que entidades/informacoes estao envolvidas
- **Restricoes**: Limites, regras, condicoes

### 1.2 Ler Contexto do Projeto

```
SEMPRE LER (se existirem):
-- README.md
-- CLAUDE.md
-- docs/constitution.md (para alinhar com principios)
-- docs/specs/ (para verificar IDs existentes e evitar duplicatas)
```

---

## ETAPA 2: ESTRUTURA

### 2.1 Gerar Short Name

Crie um nome curto (2-4 palavras, kebab-case) que capture a essencia da feature:
- Formato acao-substantivo quando possivel
- Preservar termos tecnicos e siglas
- Exemplos:
  - "Quero adicionar autenticacao de usuario" → `user-auth`
  - "Implementar integracao OAuth2 para a API" → `oauth2-api-integration`
  - "Criar dashboard de analytics" → `analytics-dashboard`

### 2.2 Criar Diretorio

Criar `docs/specs/{short-name}/` (ou caminho sugerido pelo usuario).

---

## ETAPA 3: ESPECIFICACAO

### 3.1 Template da Feature Spec

Ler o template em `templates/feature-spec.md` (mesmo diretorio desta skill) e
preencher com conteudo concreto derivado da descricao. Estrutura:

- **User Scenarios & Testing** — stories priorizadas (P1..Pn) + edge cases
- **Requirements** — functional requirements e key entities
- **Success Criteria** — measurable outcomes, technology-agnostic

Para ver exemplos de spec bem escrita vs mal escrita:
- `examples/spec-good.md` — ilustra stories independentes, success criteria mensuraveis, zero detalhes de implementacao
- `examples/spec-bad.md` — catalogo de anti-patterns (jargao tecnico em SC, stories acopladas, adjetivos vagos, excesso de [NEEDS CLARIFICATION])

### 3.2 Regras de Preenchimento

**User Stories:**
- Priorizadas como jornadas de usuario ordenadas por importancia
- Cada story deve ser INDEPENDENTEMENTE TESTAVEL
- Se implementar apenas UMA story, ainda deve haver um MVP viavel
- Adicionar quantas stories forem necessarias (P1, P2, P3, P4...)

**Functional Requirements:**
- Cada requisito deve ser testavel
- Foco no QUE o sistema faz, nao COMO implementar
- Usar defaults razoaveis para detalhes nao especificados:
  - Retencao de dados: praticas padrao da industria
  - Performance: expectativas padrao para web/mobile
  - Tratamento de erros: mensagens user-friendly com fallbacks
  - Autenticacao: session-based ou OAuth2 para web apps
- Para ambiguidades criticas, marcar com `[NEEDS CLARIFICATION: pergunta especifica]`
- **MAXIMO 3 marcadores [NEEDS CLARIFICATION]** no total
- Prioridade de clarificacao: escopo > seguranca > UX > detalhes tecnicos

**Success Criteria:**
- DEVEM ser mensuráveis (tempo, porcentagem, contagem, taxa)
- DEVEM ser technology-agnostic (sem frameworks, linguagens, databases)
- DEVEM ser user-focused (perspectiva do usuario/negocio)
- DEVEM ser verificaveis sem conhecer detalhes de implementacao

**Exemplos de Success Criteria BEM escritos:**
- "Usuarios completam checkout em menos de 3 minutos"
- "Sistema suporta 10.000 usuarios concorrentes"
- "95% das buscas retornam resultados em menos de 1 segundo"

**Exemplos de Success Criteria MAL escritos (implementation-focused):**
- "API response time under 200ms" (muito tecnico)
- "Database handles 1000 TPS" (detalhe de implementacao)
- "React components render efficiently" (framework-specific)

---

## ETAPA 4: VALIDACAO

### 4.1 Checklist de Qualidade Interna

Valide a spec contra estes criterios:

- [ ] Nenhum detalhe de implementacao (linguagens, frameworks, APIs)
- [ ] Focado no valor para o usuario e necessidades do negocio
- [ ] Escrito para stakeholders nao-tecnicos
- [ ] Todas as secoes obrigatorias preenchidas
- [ ] Requisitos sao testaveis e nao-ambiguos
- [ ] Success criteria sao mensuráveis
- [ ] Success criteria sao technology-agnostic
- [ ] Acceptance scenarios definidos para todas as stories
- [ ] Edge cases identificados
- [ ] Escopo claramente delimitado

### 4.2 Auto-Correcao

Se itens falham na validacao:
1. Listar itens que falharam e problemas especificos
2. Atualizar a spec para corrigir cada problema
3. Re-validar (max 3 iteracoes)
4. Se ainda falhando apos 3 iteracoes: documentar problemas restantes e avisar usuario

---

## ETAPA 5: CLARIFICACAO

### 5.1 Resolver [NEEDS CLARIFICATION]

Se existem marcadores `[NEEDS CLARIFICATION]` na spec:

1. Extrair todos os marcadores
2. Se mais de 3: manter apenas os 3 mais criticos e fazer guesses informados para o resto
3. Para cada marcador, apresentar ao usuario:

```markdown
## Questao [N]: [Topico]

**Contexto**: [Citar secao relevante da spec]

**O que precisamos saber**: [Pergunta especifica]

**Respostas Sugeridas**:

| Opcao | Resposta | Implicacoes |
|-------|----------|-------------|
| A     | [Primeira opcao] | [O que significa para a feature] |
| B     | [Segunda opcao] | [O que significa para a feature] |
| C     | [Terceira opcao] | [O que significa para a feature] |

**Sua escolha**: _[Aguardar resposta]_
```

4. Apos respostas: atualizar spec substituindo marcadores pelas respostas

---

## ETAPA 6: SALVAMENTO

### 6.1 Salvar Spec

Salvar em `docs/specs/{short-name}/spec.md`.

### 6.2 Reportar

```markdown
## Spec Criada

**Feature**: {short-name}
**Arquivo**: docs/specs/{short-name}/spec.md
**Status**: Draft
**User Stories**: {N} stories (P1-P{N})
**Requisitos**: {N} functional requirements
**Clarificacoes pendentes**: {N}

### Proximos Passos

1. `/clarify` — Refinar ambiguidades na spec (se houver NEEDS CLARIFICATION)
2. `/plan` — Gerar plano tecnico de implementacao
```

---

## DIRETRIZES RAPIDAS

- Foco no **QUE** usuarios precisam e **POR QUE**
- Evitar COMO implementar (sem tech stack, APIs, estrutura de codigo)
- Escrito para stakeholders de negocio, nao desenvolvedores
- Quando secao nao se aplica: remover inteiramente (nao deixar como "N/A")
- Pensar como tester: todo requisito vago deve falhar no checklist de qualidade

### Diferenca do create-use-case

- `create-use-case`: Formato UC classico (fluxos, atores, RNs, CTs) para documentacao formal
- `specify`: Feature spec SDD (user stories, acceptance criteria, success criteria) para workflow de desenvolvimento
- Ambos coexistem — UC para documentacao, specify para SDD

---

## Gotchas

### ZERO detalhes de implementacao na spec

Sem linguagens, frameworks, APIs, estrutura de codigo, nomes de bibliotecas, classes. A spec responde QUE e POR QUE — o COMO vai para `/plan`. Se aparece "em React" ou "com PostgreSQL" na spec, esta errado.

### Success Criteria devem ser technology-agnostic E mensuraveis

Correto: "Usuario completa checkout em <3 minutos", "95% das buscas retornam <1s", "Sistema suporta 10k usuarios concorrentes".
Errado: "API responde <200ms" (tecnico), "Database aguenta 1000 TPS" (implementacao), "Componentes React renderizam rapido" (framework).

### Maximo 3 `[NEEDS CLARIFICATION]` — priorizar escopo > seguranca > UX > tech

Mais de 3 marcadores indica que a spec deveria voltar ao usuario antes de escrever. Priorize o que impacta corretude e use defaults informados para o resto.

### Cada user story deve ser INDEPENDENTEMENTE TESTAVEL

Se implementar apenas P1 nao ha MVP viavel, as stories estao acopladas demais. Cada story precisa ter valor isolado para o usuario.

### Nao deixar secoes vazias com "N/A"

Se a feature nao envolve entidades de dados, remover a secao "Key Entities" inteira — nao deixar header com "N/A" abaixo. Secoes vazias sao ruido para o `/plan` e `/create-tasks` downstream.

### Defaults razoaveis ao inves de [NEEDS CLARIFICATION] para tudo

Retencao de dados, tratamento de erros padrao, autenticacao web-padrao — se nao critico, use o default da industria e documente a suposicao. Marcar tudo como pendente trava o fluxo.
