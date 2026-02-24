---
name: create-use-case
description: |
  Cria documento de caso de uso completo (UC-*.md) com fluxos, atores, regras de negocio,
  dados tecnicos e casos de teste seguindo template padronizado.
  Triggers: "criar caso de uso", "gerar UC", "documentar funcionalidade",
  "use case", "criar documentacao de requisitos", "novo UC".
argument-hint: "[descricao da funcionalidade ou caminho para documento base]"
allowed-tools:
  - Read
  - Write
  - Glob
  - Grep
---

# Skill: Criar Caso de Uso

Crie um documento de caso de uso completo seguindo o template em `template-uc.md` (no mesmo diretorio desta skill).

## Argumentos

$ARGUMENTS

## Instrucoes

Analise o argumento fornecido. Ele pode ser:
1. **Item de tarefa**: Descricao de funcionalidade/requisito
2. **Documento de base**: Arquivo existente com especificacoes para detalhar

### Passos para criacao

1. **Identifique o dominio** do caso de uso com base no contexto:
   - AUTH: Autenticacao e autorizacao
   - CAD: Cadastros e dados mestres
   - PED: Pedidos e vendas
   - FIN: Financeiro e pagamentos
   - FAT: Faturamento e notas fiscais
   - LOG: Logistica e entregas
   - MON: Monitoramento e alertas
   - INAD: Inadimplencia
   - REC: Recebimentos/Pagamentos
   - PROP: Propostas
   - CONT: Contratos
   - DOM: Dominio/Dados mestres
   - Outro dominio conforme o contexto do projeto

2. **Determine o proximo ID** disponivel:
   - Padrao: `UC-{DOMINIO}-{NUMERO}` (ex: UC-CAD-001)
   - Verifique IDs existentes no projeto com Glob `UC-*.md`

3. **Leia o template** em `template-uc.md` (diretorio desta skill)

4. **Gere o documento** preenchendo todas as secoes do template

5. **Valide** contra o checklist de qualidade

6. **Salve** no diretorio de casos de uso do projeto

## Estrutura do Documento UC

O documento gerado deve conter as 14 secoes do template:

1. Informacoes Gerais (tabela com ID, Nome, Dominio, Prioridade, Versao, Status)
2. Descricao (minimo 2 paragrafos: O QUE faz e POR QUE)
3. Atores (tabela: Primario, Secundario, Sistema)
4. Pre-condicoes (lista numerada)
5. Pos-condicoes (sucesso e falha)
6. Fluxo Principal (diagrama Mermaid `sequenceDiagram` + tabela de passos)
7. Fluxos Alternativos (tabela: passo, condicao, acao)
8. Excecoes (tabela: codigo E001..E00N, excecao, tratamento)
9. Regras de Negocio (tabela: RN01..RN0N + detalhamento de regras complexas)
10. Requisitos Nao-Funcionais (tabela: RNF01..RNF0N)
11. Dados Tecnicos (mapeamento de campos, endpoints, request/response)
12. Casos de Teste (tabela: CT01..CT0N com cenario, entrada, resultado)
13. Metricas e Monitoramento (tabela: nome_metrica, descricao)
14. Dependencias (tabela: UC relacionado, relacao, descricao)
15. Referencias (links para documentos)

### Diagramas

Usar Mermaid:
- `sequenceDiagram` para fluxo principal
- `flowchart TD` para decisoes complexas
- `erDiagram` para relacionamentos de dados

### Exemplos de Qualidade

**Regra de Negocio bem escrita:**
```markdown
| ID   | Regra                                                    |
|------|----------------------------------------------------------|
| RN01 | CNPJ/CPF deve ser unico no sistema                       |
| RN02 | Razao Social e obrigatoria (minimo 3 caracteres)         |

### Detalhamento RN01 - Validacao de Documento

A validacao segue o algoritmo:
1. Remover formatacao
2. Validar digitos verificadores
3. Consultar API externa se disponivel
```

**Caso de Teste bem escrito:**
```markdown
| ID   | Cenario              | Entrada              | Resultado Esperado    |
|------|----------------------|----------------------|-----------------------|
| CT01 | Cliente PJ valido    | CNPJ 12345678000199  | CODPARC retornado     |
| CT02 | CNPJ invalido        | CNPJ 11111111111111  | Erro E001             |
```

## Checklist de Qualidade

Antes de finalizar, verificar:
- [ ] Todas as secoes obrigatorias preenchidas
- [ ] Diagrama Mermaid valido e legivel
- [ ] Regras de negocio com detalhamento quando complexas
- [ ] Casos de teste cobrindo sucesso, erro e edge cases (minimo 5)
- [ ] Mapeamento de campos completo (se integracao)
- [ ] Dependencias identificadas
- [ ] Data de criacao no rodape

## Saida Esperada

1. Gere o documento completo em Markdown
2. Pergunte ao usuario o diretorio onde salvar (ou sugira baseado no projeto)
3. Salve com Write no padrao `UC-{DOMINIO}-{NUMERO}-{nome-descritivo}.md`