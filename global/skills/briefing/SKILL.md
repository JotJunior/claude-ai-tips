---
name: briefing
description: |
  Use quando o usuario iniciar um novo projeto, pedir discovery/kickoff, ou
  quiser levantar contexto estruturado via entrevista (visao, usuarios,
  restricoes, prioridades, stack, qualidade, futuro). Tambem quando mencionar
  "briefing", "discovery", "iniciar projeto", "novo projeto", "entrevista do
  projeto", "project intake", "kickoff". NAO use se ja existe briefing
  completo e o usuario nao pediu atualizacao — o documento alimenta
  constitution, specs e demais artefatos SDD.
argument-hint: "[descricao inicial do projeto ou vazio para entrevista completa]"
allowed-tools:
  - Read
  - Write
  - Edit
  - Glob
  - Grep
  - Bash
---

# Skill: Briefing de Projeto

Conduza uma entrevista estruturada de discovery para capturar a essencia do projeto,
produzindo um documento de briefing que serve de fundacao para todos os artefatos SDD.

## Argumentos

$ARGUMENTS

---

## FLUXO DE EXECUCAO

```
1. CONTEXTO        Detectar projeto e artefatos existentes
     |
2. TRIAGEM         Determinar profundidade da entrevista
     |
3. ENTREVISTA      Perguntas estruturadas por dimensao (interativo)
     |
4. SINTESE         Consolidar respostas em documento de briefing
     |
5. VALIDACAO       Confirmar com usuario antes de salvar
     |
6. SALVAMENTO      Salvar e recomendar proximos passos
```

---

## ETAPA 1: CONTEXTO

### 1.1 Detectar Projeto

Leia os seguintes arquivos (se existirem) para entender o que ja se sabe:

```
SEMPRE LER (se existirem):
-- README.md
-- CLAUDE.md
-- docs/01-briefing-discovery/*.md (briefings anteriores)
-- docs/constitution.md
-- docs/specs/*/spec.md (specs existentes)
-- package.json, go.mod, pyproject.toml, Cargo.toml (stack tecnica)
```

### 1.2 Verificar Briefing Existente

Procurar briefings existentes:
1. `docs/01-briefing-discovery/briefing.md`
2. `docs/01-briefing-discovery/BRIEFING-*.md`
3. `docs/briefing.md`

Se encontrado:
- Carregar conteudo atual
- Identificar secoes incompletas ou marcadas com TODO
- Perguntar ao usuario: "Encontrei um briefing existente. Deseja **atualizar** ou **criar um novo**?"

Se nao encontrado:
- Seguir para entrevista completa (Etapa 2)

---

## ETAPA 2: TRIAGEM

### 2.1 Analisar Input

Analise $ARGUMENTS e o contexto coletado:

| Cenario | Acao |
|---------|------|
| Argumento vazio, projeto vazio | Entrevista COMPLETA (todas as dimensoes) |
| Argumento vazio, projeto existente | Entrevista FOCADA (apenas gaps detectados) |
| Argumento com descricao do projeto | Entrevista ADAPTADA (preencher o que falta da descricao) |
| Argumento com caminho para documento | Extrair contexto do documento + entrevista complementar |

### 2.2 Preencher o que ja se sabe

Para cada dimensao da entrevista, verificar se a informacao ja existe no contexto:
- Se inferivel de arquivos do projeto: preencher e marcar como `[inferido]`
- Se explicita no argumento: preencher e marcar como `[fornecido]`
- Se desconhecida: incluir na fila de perguntas

### 2.3 Calcular Fila de Perguntas

- **Entrevista completa**: ate 10 perguntas (todas as dimensoes)
- **Entrevista focada/adaptada**: apenas gaps, max 7 perguntas
- Nunca exceder 10 perguntas no total

---

## ETAPA 3: ENTREVISTA

### 3.1 Dimensoes de Discovery

A entrevista cobre 7 dimensoes. Cada dimensao tem 1-2 perguntas.
**Perguntas sao feitas UMA POR VEZ**, aguardando resposta antes de avancar.

---

#### DIMENSAO 1: Visao e Proposito

**O que captura**: A essencia do projeto — o que e, por que existe, qual problema resolve.

**Pergunta 1.1 — Elevator Pitch**:

```markdown
## Pergunta 1: Visao do Projeto

Descreva o projeto em 2-3 frases, como se estivesse explicando para alguem
que nunca ouviu falar dele.

**O que preciso saber**:
- O que o projeto FAZ
- Qual PROBLEMA resolve
- Para QUEM

**Exemplo**: "Um sistema de gestao de pedidos que permite lojistas acompanharem
vendas em tempo real e emitirem notas automaticamente. Resolve o problema de
visibilidade operacional para pequenos comercios."

Responda com sua descricao livre.
```

---

#### DIMENSAO 2: Usuarios e Stakeholders

**O que captura**: Quem usa o sistema e quem toma decisoes.

**Pergunta 2.1 — Atores Principais**:

```markdown
## Pergunta 2: Usuarios e Atores

Quem sao os USUARIOS do sistema? Liste os tipos de usuario (personas/papeis)
e o que cada um faz.

**Exemplos de papeis**: admin, operador, cliente final, parceiro, sistema externo

**Formato sugerido**:
- [Papel]: [O que faz no sistema]
- [Papel]: [O que faz no sistema]

Responda listando os papeis, ou descreva livremente.
```

---

#### DIMENSAO 3: Escopo e Prioridades

**O que captura**: O que esta dentro e fora do escopo, e o que e mais importante.

**Pergunta 3.1 — Features Core vs Nice-to-Have**:

```markdown
## Pergunta 3: Escopo e Prioridades

Quais sao as funcionalidades ESSENCIAIS (sem elas o projeto nao faz sentido)
vs funcionalidades DESEJAVEIS (agregam valor mas podem esperar)?

**Formato sugerido**:

**Essenciais (MVP)**:
1. [Feature]
2. [Feature]

**Desejaveis (pos-MVP)**:
1. [Feature]
2. [Feature]

Responda listando ou descrevendo livremente.
```

**Pergunta 3.2 — Trade-offs** (se projeto nao-trivial):

```markdown
## Pergunta 4: Trade-offs

Quando precisar escolher, qual sua prioridade?

| Opcao | Descricao |
|-------|-----------|
| A | **Velocidade de entrega** — Lancar rapido, iterar depois |
| B | **Qualidade e robustez** — Fazer bem feito, mesmo que demore |
| C | **Escopo completo** — Entregar tudo planejado, ajustando prazo |
| D | **Experiencia do usuario** — UX impecavel, mesmo sacrificando features |

Responda com a letra (ou ordene por prioridade, ex: "B > D > A > C").
```

---

#### DIMENSAO 4: Restricoes

**O que captura**: Limites reais do projeto — tempo, equipe, orcamento, tech.

**Pergunta 4.1 — Restricoes do Projeto**:

```markdown
## Pergunta 5: Restricoes

Quais restricoes o projeto tem? Responda o que souber:

- **Prazo**: Ha deadline? (ex: "lancar em 3 meses", "sem prazo fixo")
- **Equipe**: Quantas pessoas? Qual experiencia? (ex: "1 dev fullstack senior")
- **Budget**: Ha limitacao de custo? (ex: "usar apenas servicos free-tier")
- **Tecnica**: Alguma tecnologia obrigatoria ou proibida? (ex: "tem que ser em Go", "sem vendor lock-in")

Responda o que for relevante — pode pular itens que nao se aplicam.
```

---

#### DIMENSAO 5: Contexto Tecnico

**O que captura**: Stack, infraestrutura, integracoes.

**Pergunta 5.1 — Stack e Infraestrutura**:

Pular se ja inferido de arquivos do projeto (go.mod, package.json, etc.).

```markdown
## Pergunta 6: Stack Tecnica

Qual a stack tecnica do projeto? Se ainda nao decidiu, descreva preferencias.

**Categorias**:
- **Backend**: (ex: Go, Node.js, Python, Java)
- **Frontend**: (ex: React, Vue, mobile nativo, nenhum)
- **Banco de dados**: (ex: PostgreSQL, MongoDB, SQLite)
- **Infraestrutura**: (ex: Docker, Kubernetes, serverless, VPS)
- **Integracoes externas**: (ex: Stripe, SendGrid, APIs de terceiros)

Responda o que souber. Se preferir que eu sugira, diga "sugira baseado no projeto".
```

---

#### DIMENSAO 6: Qualidade e Padroes

**O que captura**: Expectativas de qualidade, compliance, observabilidade.

**Pergunta 6.1 — Padroes de Qualidade**:

```markdown
## Pergunta 7: Qualidade e Padroes

Quais padroes de qualidade sao importantes para o projeto?

| Opcao | Descricao |
|-------|-----------|
| A | **Testes rigorosos** — TDD, cobertura alta, CI/CD |
| B | **Seguranca primeiro** — OWASP, auditoria, compliance (LGPD/GDPR) |
| C | **Observabilidade** — Logging, metricas, alertas, tracing |
| D | **Performance** — Baixa latencia, alta concorrencia |
| E | **Acessibilidade** — WCAG, i18n, suporte a multiplos dispositivos |
| F | **Documentacao** — Codigo documentado, ADRs, specs completos |

Selecione todas que se aplicam (ex: "A, B, F") ou descreva suas expectativas.
```

---

#### DIMENSAO 7: Visao de Futuro

**O que captura**: Direcao de longo prazo, escalabilidade, evolucao.

**Pergunta 7.1 — Evolucao**:

```markdown
## Pergunta 8: Visao de Futuro

Como voce ve o projeto daqui a 6-12 meses?

- Vai crescer em **usuarios**? (escala)
- Vai crescer em **features**? (escopo)
- Vai precisar de **mais desenvolvedores**? (equipe)
- Ha planos de **monetizacao** ou **mudanca de modelo**?

Descreva livremente o que imagina para o futuro do projeto.
```

---

### 3.2 Regras da Entrevista

1. **Uma pergunta por vez** — aguardar resposta antes de avancar
2. **Adaptar ao contexto** — pular perguntas cujas respostas ja sao conhecidas
3. **Aceitar respostas livres** — nao forcar formato; extrair informacao do texto
4. **Aceitar "nao sei"** — marcar como `[a definir]` e seguir em frente
5. **Aceitar atalhos** — se usuario responder varias dimensoes de uma vez, registrar todas
6. **Maximo 10 perguntas** — se usuario disser "chega", "pronto" ou "prossiga", encerrar
7. **Nao julgar respostas** — registrar fielmente; criticas sao trabalho do `/advisor`
8. **Confirmar inferencias** — quando preencher algo inferido, confirmar brevemente:
   "Detectei que o projeto usa [linguagem + banco identificados do package.json/go.mod/etc]. Correto?"

### 3.3 Transicao entre Perguntas

Apos cada resposta:
- Agradecer brevemente (1 linha max, sem ser efusivo)
- Se a resposta levantar aspecto nao coberto: adicionar pergunta de follow-up (dentro do limite)
- Apresentar proxima pergunta

---

## ETAPA 4: SINTESE

### 4.1 Template do Briefing

Apos encerrar a entrevista, consolidar todas as respostas no template:

```markdown
# Project Briefing: [PROJECT_NAME]

**Data**: [DATE]
**Status**: Draft
**Versao**: 1.0

---

## 1. Visao e Proposito

**O que e**: [Descricao concisa do projeto]

**Problema que resolve**: [Problema central]

**Proposta de valor**: [Por que alguem usaria isso]

## 2. Usuarios e Stakeholders

| Ator | Papel | Acoes Principais |
|------|-------|-----------------|
| [Nome] | [Tipo] | [O que faz] |

**Stakeholders de decisao**: [Quem decide prioridades, aprova entregas]

## 3. Escopo

### MVP (Essencial)

1. [Feature essencial]
2. [Feature essencial]
3. [Feature essencial]

### Pos-MVP (Desejavel)

1. [Feature desejavel]
2. [Feature desejavel]

### Fora de Escopo

- [O que explicitamente NAO faz parte do projeto]

## 4. Prioridades e Trade-offs

**Ordem de prioridade**: [ex: Qualidade > UX > Velocidade > Escopo]

**Decisoes explicitas**:
- [Trade-off aceito, ex: "Aceitar escopo menor para manter qualidade"]

## 5. Restricoes

| Restricao | Valor | Notas |
|-----------|-------|-------|
| Prazo | [valor ou "flexivel"] | [contexto] |
| Equipe | [tamanho e perfil] | [contexto] |
| Budget | [valor ou "nao definido"] | [contexto] |
| Tecnica | [restricoes obrigatorias] | [contexto] |

## 6. Stack Tecnica

| Camada | Tecnologia | Justificativa |
|--------|-----------|---------------|
| Backend | [tech] | [por que] |
| Frontend | [tech] | [por que] |
| Banco de dados | [tech] | [por que] |
| Infraestrutura | [tech] | [por que] |
| Integracoes | [tech] | [por que] |

## 7. Qualidade e Padroes

**Padroes adotados**:
- [Padrao 1 e o que significa para o projeto]
- [Padrao 2 e o que significa para o projeto]

**Compliance**: [LGPD, GDPR, PCI-DSS, ou "nenhum especifico"]

## 8. Visao de Futuro

**6 meses**: [Onde o projeto deve estar]

**12 meses**: [Evolucao esperada]

**Riscos conhecidos**:
- [Risco 1]
- [Risco 2]

---

## Itens a Definir

| Item | Dimensao | Impacto |
|------|----------|---------|
| [O que falta decidir] | [Qual dimensao] | [Alto/Medio/Baixo] |

---

**Proximo passo recomendado**: `/constitution` para definir principios de governanca
```

### 4.2 Regras de Sintese

- **Usar as palavras do usuario** — nao reescrever em jargao tecnico
- **Marcar inferencias** — se algo foi inferido (nao dito explicitamente), indicar com `[inferido]`
- **Marcar pendencias** — itens sem resposta vao para "Itens a Definir"
- **Remover secoes vazias** — se dimensao inteira nao se aplica, remover (nao deixar "N/A")
- **Nao inventar** — se o usuario nao mencionou, nao adicionar

---

## ETAPA 5: VALIDACAO

### 5.1 Apresentar Resumo

Antes de salvar, apresentar ao usuario um resumo executivo:

```markdown
## Resumo do Briefing

**Projeto**: [Nome]
**Resumo**: [1-2 frases]
**Atores**: [N] identificados
**Features MVP**: [N] features
**Stack**: [resumo da stack]
**Restricoes criticas**: [lista curta]
**Itens a definir**: [N] pendencias

Deseja que eu salve este briefing? Ou ha algo a corrigir/complementar?
```

### 5.2 Iterar se Necessario

- Se usuario pedir correcoes: aplicar e re-apresentar resumo
- Se usuario pedir mais perguntas: retomar entrevista (respeitando limite de 10)
- Se usuario aprovar: prosseguir para salvamento

---

## ETAPA 6: SALVAMENTO

### 6.1 Criar Diretorio

Se `docs/01-briefing-discovery/` nao existir, criar.

### 6.2 Salvar Briefing

Salvar em `docs/01-briefing-discovery/briefing.md`.

Se ja existe um briefing:
- Salvar como `docs/01-briefing-discovery/briefing-[DATE].md`
- Ou sobrescrever se usuario pediu atualizacao

### 6.3 Reportar

```markdown
## Briefing Salvo

**Arquivo**: docs/01-briefing-discovery/briefing.md
**Dimensoes cobertas**: [N]/7
**Itens a definir**: [N]

### Proximos Passos (fluxo SDD recomendado)

1. `/constitution` — Definir principios de governanca baseados no briefing
2. `/specify [feature]` — Especificar features do MVP identificadas
3. `/clarify` — Resolver ambiguidades nas specs geradas
4. `/plan` — Gerar planos tecnicos de implementacao
5. `/create-tasks` — Decompor planos em tarefas executaveis
```

---

## DIRETRIZES RAPIDAS

- **Entrevista, nao interrogatorio** — tom conversacional, sem pressao
- **Capturar, nao julgar** — o briefing registra; o `/advisor` critica
- **Adaptar, nao seguir cegamente** — se o projeto e simples, pular dimensoes irrelevantes
- **Priorizar MVP** — focar no que importa AGORA, nao no que pode importar depois
- **Respeitar o usuario** — se ele ja sabe o que quer, nao forcar reflexao desnecessaria
- **Alimentar o pipeline** — o briefing deve ser util para `/constitution` e `/specify`

### Relacao com Outras Skills

| Skill | Relacao com Briefing |
|-------|---------------------|
| `constitution` | Consome briefing para derivar principios de governanca |
| `specify` | Consome briefing para contextualizar features |
| `clarify` | Pode refinar ambiguidades do briefing se necessario |
| `advisor` | Pode criticar decisoes registradas no briefing |
| `plan` | Usa briefing como contexto tecnico de alto nivel |
| `initialize-docs` | Cria o diretorio onde o briefing e salvo |

---

## Gotchas

### Uma pergunta por vez — aguardar resposta antes de avancar

Despejar 7 perguntas de uma vez quebra a entrevista. O valor esta no ciclo pergunta-resposta-reflexao-proxima. Enviar bloco significa que o usuario responde em batch, sem reflexao.

### Maximo 10 perguntas TOTAL

Nao exceda por "mais uma coisa importante". Se 10 nao resolveram, registre o que tem e marque o resto como "A Definir" — o briefing e draft, pode ser atualizado depois.

### Inferencias devem ser marcadas `[inferido]` e confirmadas

Quando preencher algo derivado do codigo (ex: stack detectada de `go.mod`), marque `[inferido]` e confirme com uma linha: "Detectei X, correto?". Assumir sem confirmar e arriscar registrar premissa errada como fato.

### Se o usuario responder varias dimensoes de uma vez, registre TODAS

Usuario pragmatico frequentemente responde em texto corrido cobrindo 3 dimensoes. Capture tudo e pule as perguntas equivalentes — nao repita o que ja foi dito so para seguir o roteiro.

### NAO julgar respostas — briefing registra, advisor critica

Se o usuario diz "vou lancar sem testes para ganhar velocidade", registre fielmente. Criticar aqui quebra a confianca da entrevista. A critica e papel do `/advisor`, se o usuario pedir.

### Remover secoes inteiras quando a dimensao nao se aplica

Se o projeto e uma biblioteca interna sem usuarios finais, remover a secao "Usuarios e Stakeholders" em vez de deixar "N/A". Secoes vazias sao ruido para `/constitution` e `/specify` downstream.

### Nunca reescrever em jargao tecnico

Usar as palavras do usuario. Se ele disse "app de caixa", nao trocar por "sistema de ponto-de-venda transacional". O briefing preserva linguagem; o `/plan` traduz em tecnico.
