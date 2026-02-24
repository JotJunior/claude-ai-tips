---
name: validate-documentation
description: |
  Valida documentação existente contra padrões de qualidade estabelecidos.
  Use para verificar completude, consistência e qualidade de documentos UC,
  diagramas, mapeamentos de dados e casos de teste.
  Triggers: "validar documentação", "verificar UC", "checar qualidade docs",
  "review documentation", "audit docs".
allowed-tools:
  - Read
  - Glob
  - Grep
---

# Skill: Validação de Documentação

Esta skill analisa e valida documentação existente contra padrões de qualidade.

## Quando Usar

Claude deve invocar esta skill automaticamente quando:
- Usuário pedir para validar/verificar documentação
- Usuário mencionar "review", "audit" ou "checar" documentos
- Antes de finalizar criação de documentação (auto-validação)
- Usuário pedir status de qualidade da documentação

## Critérios de Validação

### 1. Validação Estrutural (Documentos UC)

**Seções Obrigatórias:**
```
- [ ] Informações Gerais (tabela com ID, Nome, Domínio)
- [ ] Descrição (mínimo 2 parágrafos)
- [ ] Atores (tabela com tipo e descrição)
- [ ] Pré-condições (lista numerada)
- [ ] Pós-condições (sucesso e falha)
- [ ] Fluxo Principal (diagrama + tabela)
- [ ] Fluxos Alternativos (ao menos 1)
- [ ] Exceções (tabela com códigos)
- [ ] Regras de Negócio (tabela com IDs)
- [ ] Casos de Teste (tabela com cenários)
- [ ] Dependências (relacionamentos)
```

**Padrões de ID:**
```regex
UC-[A-Z]{2,4}-\d{3}     # UC-CAD-001, UC-AUTH-001
RN\d{2}                  # RN01, RN02
CT\d{2}                  # CT01, CT02
E\d{3}                   # E001, E002
FA\d                     # FA1, FA2
RNF\d{2}                 # RNF01, RNF02
```

### 2. Validação de Conteúdo

**Descrição:**
- Mínimo 100 caracteres
- Deve explicar O QUE e POR QUE

**Atores:**
- Pelo menos 1 ator primário
- Tipo deve ser: Primário, Secundário ou Sistema
- Descrição deve ser clara

**Fluxo Principal:**
- Diagrama Mermaid deve ser válido
- Passos devem ser numerados sequencialmente
- Cada passo deve ter descrição clara

**Regras de Negócio:**
- Cada regra deve ser acionável
- Regras complexas devem ter detalhamento

**Casos de Teste:**
- Mínimo 5 casos por UC
- Deve cobrir: sucesso, erro, edge cases
- Cada caso deve ter entrada e saída esperada

### 3. Validação de Consistência

**Cross-references:**
- Dependências devem referenciar UCs existentes
- Links internos devem ser válidos
- IDs não devem ser duplicados

**Nomenclatura:**
- Campos devem seguir padrão (camelCase ou UPPER_CASE)
- Nomes de atores consistentes entre documentos
- Terminologia uniforme

### 4. Validação de Diagramas Mermaid

**sequenceDiagram:**
```
- Participantes definidos
- Mensagens com setas corretas (->>, -->>)
- Alt/else para fluxos condicionais
- Loop para repetições
```

**flowchart:**
```
- Nós com IDs únicos
- Conexões válidas
- Decisões com múltiplas saídas
```

## Relatório de Validação

Formato do relatório gerado:

```markdown
# Relatório de Validação de Documentação

**Data:** YYYY-MM-DD
**Arquivos analisados:** N

## Resumo

| Status | Quantidade |
|--------|------------|
| OK     | X          |
| Aviso  | Y          |
| Erro   | Z          |

## Detalhes por Arquivo

### UC-XXX-NNN.md

**Status:** OK | Aviso | Erro

**Validações:**
- [x] Estrutura completa
- [x] Conteúdo adequado
- [ ] Consistência - Falta detalhar RN03
- [x] Diagramas válidos

**Ações recomendadas:**
1. Adicionar detalhamento para RN03
2. Incluir mais casos de teste de erro

---
```

## Níveis de Severidade

| Nível | Descrição | Ação |
|-------|-----------|------|
| **Erro** | Seção obrigatória ausente | Bloqueia aprovação |
| **Aviso** | Conteúdo insuficiente | Recomenda correção |
| **Info** | Sugestão de melhoria | Opcional |

## Processo de Validação

1. Identificar arquivos a validar (glob `UC-*.md`)
2. Para cada arquivo:
   - Verificar estrutura
   - Validar conteúdo
   - Checar consistência
   - Testar diagramas
3. Gerar relatório consolidado
4. Sugerir correções específicas

## Comandos de Validação

**Validar um arquivo:**
```
Valide o documento UC-CAD-001.md
```

**Validar todos os UCs:**
```
Valide toda a documentação de casos de uso
```

**Validar com auto-correção:**
```
Valide e corrija os problemas encontrados em UC-CAD-001.md
```