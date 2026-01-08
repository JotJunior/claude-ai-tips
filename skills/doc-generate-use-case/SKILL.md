---
name: generate-use-case-documentation
description: |
  Gera documentação completa de casos de uso (UC-*.md) seguindo padrões estabelecidos.
  Use quando precisar criar documentos UC com fluxos, atores, pré/pós-condições,
  regras de negócio, dados técnicos e casos de teste.
  Triggers: "criar caso de uso", "gerar UC", "documentar funcionalidade",
  "use case", "criar documentação de requisitos".
allowed-tools:
  - Read
  - Write
  - Glob
  - Grep
---

# Skill: Geração de Casos de Uso

Esta skill gera documentação estruturada de casos de uso seguindo o padrão UC (Use Case).

## Quando Usar

Claude deve invocar esta skill automaticamente quando:
- Usuário pedir para criar/gerar um caso de uso
- Usuário mencionar "UC", "use case" ou "caso de uso"
- Houver necessidade de documentar uma funcionalidade de sistema
- Usuário pedir documentação de requisitos funcionais

## Estrutura do Documento UC

O documento gerado deve conter:

### Seções Obrigatórias

1. **Informações Gerais** - Tabela com ID, Nome, Domínio, Prioridade, Versão, Status
2. **Descrição** - Objetivo e contexto do caso de uso
3. **Atores** - Tabela com atores primários e secundários
4. **Pré-condições** - Lista numerada de condições necessárias
5. **Pós-condições** - Resultados de sucesso e falha
6. **Fluxo Principal** - Diagrama Mermaid sequenceDiagram + tabela de passos
7. **Fluxos Alternativos** - Variações do fluxo principal
8. **Exceções** - Tratamento de erros com códigos E001, E002...
9. **Regras de Negócio** - Tabela com RN01, RN02... e detalhamentos
10. **Requisitos Não-Funcionais** - Performance, disponibilidade, etc.
11. **Dados Técnicos** - Mapeamento de campos, endpoints, payloads
12. **Casos de Teste** - Cenários CT01, CT02... com entrada e resultado
13. **Dependências** - Relacionamentos com outros UCs
14. **Referências** - Links para documentos relacionados

### Padrão de ID

```
UC-{DOMÍNIO}-{NÚMERO}
```

Domínios:
- AUTH: Autenticação
- CAD: Cadastros
- PED: Pedidos
- FIN: Financeiro
- FAT: Faturamento
- LOG: Logística
- MON: Monitoramento

### Diagramas

Usar Mermaid para:
- `sequenceDiagram` - Fluxo principal
- `flowchart TD` - Decisões complexas
- `erDiagram` - Relacionamentos de dados

### Exemplos de Qualidade

**Bom exemplo de Regra de Negócio:**
```markdown
| ID   | Regra                                                    |
|------|----------------------------------------------------------|
| RN01 | CNPJ/CPF deve ser único no sistema                       |
| RN02 | Razão Social é obrigatória (mínimo 3 caracteres)         |

### Detalhamento RN01 - Validação de Documento

A validação segue o algoritmo:
1. Remover formatação
2. Validar dígitos verificadores
3. Consultar API externa se disponível
```

**Bom exemplo de Caso de Teste:**
```markdown
| ID   | Cenário              | Entrada              | Resultado Esperado    |
|------|----------------------|----------------------|-----------------------|
| CT01 | Cliente PJ válido    | CNPJ 12345678000199  | CODPARC retornado     |
| CT02 | CNPJ inválido        | CNPJ 11111111111111  | Erro E001             |
```

## Processo de Geração

1. Analisar o requisito ou tarefa fornecida
2. Identificar o domínio correto
3. Verificar UCs existentes para definir próximo número
4. Gerar documento completo seguindo template
5. Validar completude das seções
6. Perguntar onde salvar o arquivo

## Checklist de Qualidade

Antes de finalizar, verificar:
- [ ] Todas as seções obrigatórias preenchidas
- [ ] Diagrama Mermaid válido e legível
- [ ] Regras de negócio com detalhamento quando complexas
- [ ] Casos de teste cobrindo sucesso, erro e edge cases
- [ ] Mapeamento de campos completo (se integração)
- [ ] Dependências identificadas
- [ ] Data de criação no rodapé