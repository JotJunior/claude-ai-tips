---
name: constitution
description: |
  Cria ou atualiza a constituicao do projeto — principios imutaveis de governanca
  que guiam todas as decisoes de arquitetura, qualidade e processo.
  Triggers: "criar constituicao", "constitution", "principios do projeto",
  "governance", "atualizar constituicao".
argument-hint: "[descricao do projeto ou principios desejados]"
allowed-tools:
  - Read
  - Write
  - Edit
  - Glob
  - Grep
---

# Skill: Constituicao do Projeto

Crie ou atualize a constituicao do projeto — o documento de principios imutaveis que governa
decisoes de arquitetura, qualidade e processo.

## Argumentos

$ARGUMENTS

---

## FLUXO DE EXECUCAO

```
1. CONTEXTO        Detectar projeto e constituicao existente
     |
2. COLETA          Coletar/derivar principios
     |
3. GERACAO         Preencher template com valores concretos
     |
4. PROPAGACAO      Verificar alinhamento com outros artefatos
     |
5. SALVAMENTO      Salvar e reportar
```

---

## ETAPA 1: CONTEXTO

### 1.1 Detectar Projeto

Leia os seguintes arquivos (se existirem) para entender o contexto:

```
SEMPRE LER (se existirem):
-- README.md
-- CLAUDE.md
-- docs/constitution.md (constituicao existente)
-- docs/specs/*/spec.md (specs existentes)
-- package.json, go.mod, pyproject.toml (stack tecnica)
```

### 1.2 Verificar Constituicao Existente

Procure constituicao existente nesta ordem:
1. `docs/constitution.md`
2. `constitution.md`

Se encontrada:
- Carregar conteudo atual
- Identificar placeholders `[ALL_CAPS_IDENTIFIER]` nao preenchidos
- Propor atualizacoes baseadas no input do usuario

Se nao encontrada:
- Seguir para coleta de principios (Etapa 2)

---

## ETAPA 2: COLETA DE PRINCIPIOS

### 2.1 Fontes de Principios

Analise o argumento fornecido ($ARGUMENTS). Ele pode ser:

1. **Descricao do projeto**: Inferir principios a partir do contexto
2. **Lista de principios**: Usar diretamente
3. **Numero de principios**: Respeitar a quantidade solicitada
4. **Vazio**: Inferir do contexto do projeto e perguntar ao usuario

### 2.2 Derivar Valores

Para cada placeholder no template:
- Se o usuario forneceu valor: usar diretamente
- Se inferivel do contexto (README, docs, stack): derivar e documentar a inferencia
- Se desconhecido: marcar como `TODO(<CAMPO>): explicacao` e incluir no relatorio

### 2.3 Datas e Versionamento

- `RATIFICATION_DATE`: data original de adocao (se desconhecida, perguntar ou marcar TODO)
- `LAST_AMENDED_DATE`: data de hoje se mudancas foram feitas
- `CONSTITUTION_VERSION`: incrementar seguindo versionamento semantico:
  - **MAJOR**: Remocao ou redefinicao incompativel de principios
  - **MINOR**: Novo principio ou expansao material de secao
  - **PATCH**: Clarificacoes, correcoes de texto, refinamentos nao-semanticos
- Se tipo de bump ambiguo: propor raciocinio ao usuario antes de finalizar

---

## ETAPA 3: GERACAO

### 3.1 Template da Constituicao

Preencha o template abaixo substituindo TODOS os placeholders por texto concreto:

```markdown
# [PROJECT_NAME] Constitution

## Core Principles

### [PRINCIPLE_1_NAME]

[PRINCIPLE_1_DESCRIPTION]

### [PRINCIPLE_2_NAME]

[PRINCIPLE_2_DESCRIPTION]

### [PRINCIPLE_3_NAME]

[PRINCIPLE_3_DESCRIPTION]

### [PRINCIPLE_4_NAME]

[PRINCIPLE_4_DESCRIPTION]

### [PRINCIPLE_5_NAME]

[PRINCIPLE_5_DESCRIPTION]

## [SECTION_2_NAME]

[SECTION_2_CONTENT]

## [SECTION_3_NAME]

[SECTION_3_CONTENT]

## Governance

[GOVERNANCE_RULES]

**Version**: [CONSTITUTION_VERSION] | **Ratified**: [RATIFICATION_DATE] | **Last Amended**: [LAST_AMENDED_DATE]
```

### 3.2 Regras de Preenchimento

- O usuario pode pedir mais ou menos principios que o template — ajustar conforme necessario
- Cada principio deve ser: **declarativo, testavel e livre de linguagem vaga**
  - Trocar "should" por MUST/SHOULD com rationale quando apropriado
- Remover comentarios HTML do template ao preencher
- Manter hierarquia de headings exatamente como no template
- Nao deixar nenhum placeholder `[...]` sem justificativa explicita

---

## ETAPA 4: PROPAGACAO

### 4.1 Checklist de Consistencia

Apos gerar a constituicao, verificar alinhamento com outros artefatos:

- [ ] `CLAUDE.md`: Principios refletidos nas instrucoes do projeto?
- [ ] `docs/specs/*/plan.md`: Plans existentes referenciam principios?
- [ ] `docs/specs/*/tasks.md`: Tasks refletem quality gates da constituicao?

### 4.2 Sync Impact Report

Gerar relatorio de impacto (como comentario HTML no topo do arquivo):

```markdown
<!--
Sync Impact Report
- Version: old → new
- Principios modificados: [lista]
- Secoes adicionadas: [lista]
- Secoes removidas: [lista]
- Artefatos que precisam atualizacao: [lista com status]
- TODOs pendentes: [lista]
-->
```

---

## ETAPA 5: SALVAMENTO

### 5.1 Validacao Final

Antes de salvar:
- [ ] Nenhum placeholder `[...]` sem justificativa
- [ ] Versao consistente com relatorio de impacto
- [ ] Datas em formato ISO YYYY-MM-DD
- [ ] Principios sao declarativos e testaveis
- [ ] Sem trailing whitespace

### 5.2 Salvar

Salvar em `docs/constitution.md` (ou caminho especificado pelo usuario).

### 5.3 Relatorio

Apresentar ao usuario:
- Nova versao e rationale do bump
- Principios criados/modificados
- Artefatos que precisam atualizacao manual
- Sugestao de commit message (ex: `docs: create project constitution v1.0.0`)

---

## EXEMPLOS DE PRINCIPIOS

**Para projetos Go microservicos:**
- Library-First: Features comecam como bibliotecas standalone
- Test-First (NON-NEGOTIABLE): TDD obrigatorio, Red-Green-Refactor
- Integration Testing: Testes contra banco real, nao mocks
- Observability: Logging estruturado obrigatorio

**Para projetos Frontend:**
- Component-First: UI construida de componentes reutilizaveis
- Accessibility: WCAG 2.1 AA como minimo
- Type Safety: TypeScript strict mode, sem `any`

**Para projetos genericos:**
- Simplicity: YAGNI — nao abstrair prematuramente
- Security: OWASP Top 10 como baseline
- Documentation: Codigo auto-documentado, comentarios para o "por que"
