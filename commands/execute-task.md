# Executar Tarefa

Execute uma tarefa específica do projeto seguindo o fluxo obrigatório de execução.

## Tarefa Solicitada

$ARGUMENTS

---

## FLUXO OBRIGATÓRIO DE EXECUÇÃO

**IMPORTANTE**: Siga TODAS as etapas na ordem. Não pule etapas.

```
┌─────────────────────────────────────────────────────────────────────────┐
│                         FLUXO DE EXECUÇÃO                               │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                         │
│  1. ANÁLISE          Detectar contexto e ler documentação               │
│       │                                                                 │
│       ▼                                                                 │
│  2. LOCALIZAÇÃO      Encontrar tarefa no arquivo de tarefas             │
│       │                                                                 │
│       ▼                                                                 │
│  3. PLANEJAMENTO     Definir o que fazer e quais arquivos afetar        │
│       │                                                                 │
│       ▼                                                                 │
│  4. IMPLEMENTAÇÃO    Executar a tarefa (criar/modificar arquivos)       │
│       │                                                                 │
│       ▼                                                                 │
│  5. TESTES           Executar testes (se aplicável)                     │
│       │                                                                 │
│       ▼                                                                 │
│  6. VALIDAÇÃO        Verificar qualidade e consistência                 │
│       │                                                                 │
│       ▼                                                                 │
│  7. LINT             Verificar formatação e padrões                     │
│       │                                                                 │
│       ▼                                                                 │
│  8. CONCLUSÃO        Resumir o que foi feito                            │
│       │                                                                 │
│       ▼                                                                 │
│  9. ATUALIZAÇÃO      Marcar tarefa como [x] no arquivo de tarefas       │
│                                                                         │
└─────────────────────────────────────────────────────────────────────────┘
```

---

## ETAPA 1: ANÁLISE

### 1.1 Detectar Contexto do Projeto

Identifique o tipo de projeto:

| Tipo | Indicadores | Foco |
|------|-------------|------|
| **Documentação** | `docs/` com `.md`, UC-*, ADRs, ausência de `src/` | Markdown, diagramas |
| **Código** | `src/`, `app/`, `package.json`, `composer.json` | Implementação, testes |
| **Misto** | Contém `docs/` e código-fonte | Ambos |

### 1.2 LEITURA OBRIGATÓRIA DE DOCUMENTAÇÃO

**CRÍTICO**: Antes de executar QUALQUER tarefa, leia a documentação relevante:

```
SEMPRE LER (se existirem):
├── README.md                    # Visão geral do projeto
├── CLAUDE.md                    # Instruções específicas para o Claude
├── docs/
│   ├── tasks.md                 # Arquivo de tarefas (ou TODO.md)
│   ├── 01-briefing-discovery/   # Contexto e requisitos
│   ├── 02-requisitos-casos-uso/ # Casos de uso (UC-*)
│   ├── 03-modelagem-dados/      # DER e dicionários
│   └── arquitetura/             # Decisões técnicas (ADRs)
```

**Por que ler a documentação?**
- Entender o contexto completo do projeto
- Conhecer padrões e convenções existentes
- Identificar dependências e relacionamentos
- Evitar decisões que conflitem com a arquitetura
- Manter consistência com o restante do projeto

### 1.3 Checklist da Análise

- [ ] Identifiquei o tipo de projeto
- [ ] Li o README.md
- [ ] Li o CLAUDE.md (se existir)
- [ ] Li a documentação relevante em `docs/`
- [ ] Entendi o contexto da tarefa

---

## ETAPA 2: LOCALIZAÇÃO

### 2.1 Encontrar Arquivo de Tarefas

Procure na seguinte ordem:
1. `docs/tasks.md`
2. `tasks.md`
3. `TODO.md`
4. `docs/TODO.md`
5. `.github/TODO.md`

### 2.2 Identificar a Tarefa

Encontre a tarefa específica: **$ARGUMENTS**

Extraia:
- **ID da tarefa** (ex: TASK-CAD-001)
- **Descrição completa**
- **Subtarefas** (se houver)
- **Prioridade** (P0, P1, P2, P3)
- **Dependências** (outras tarefas que precisam estar prontas)
- **Domínio** (CAD, PED, FIN, etc.)

### 2.3 Checklist da Localização

- [ ] Encontrei o arquivo de tarefas
- [ ] Localizei a tarefa solicitada
- [ ] Identifiquei todas as subtarefas
- [ ] Verifiquei dependências
- [ ] Confirmei que dependências estão concluídas

---

## ETAPA 3: PLANEJAMENTO

### 3.1 Classificar Tipo de Tarefa

| Tipo | Exemplos | Ações Principais |
|------|----------|------------------|
| 📚 Documentação | Criar UC, atualizar ADR, modelagem | Criar/editar `.md` |
| 💻 Código | Implementar feature, corrigir bug | Criar/editar código |
| 🧪 Testes | Criar testes, aumentar cobertura | Criar/editar testes |
| 🔧 Infraestrutura | CI/CD, configs, scripts | Criar/editar configs |

### 3.2 Definir Escopo

Liste exatamente:
1. **Arquivos a CRIAR** (novos)
2. **Arquivos a MODIFICAR** (existentes)
3. **Arquivos a CONSULTAR** (referência)
4. **Validações necessárias**

### 3.3 Identificar Padrões do Projeto

Antes de implementar, verifique:
- Convenções de nomenclatura existentes
- Estrutura de arquivos similar
- Padrões de código/documentação usados
- Templates existentes

### 3.4 Checklist do Planejamento

- [ ] Classifiquei o tipo de tarefa
- [ ] Listei arquivos a criar
- [ ] Listei arquivos a modificar
- [ ] Identifiquei padrões a seguir
- [ ] Tenho clareza do que fazer

---

## ETAPA 4: IMPLEMENTAÇÃO

### 4.1 Para Tarefas de DOCUMENTAÇÃO

```
1. Leia documentos relacionados existentes
2. Use templates/padrões do projeto
3. Crie/atualize documentos em Markdown
4. Inclua diagramas Mermaid quando apropriado
5. Mantenha links internos funcionais
6. Siga nomenclatura: UC-XXX-NNN, RN-NNN, CT-NNN
```

**Padrões obrigatórios:**
- Headers hierárquicos (# ## ### ####)
- Tabelas com alinhamento consistente
- Code blocks com linguagem especificada
- Links relativos para arquivos internos

### 4.2 Para Tarefas de CÓDIGO

```
1. Leia código relacionado existente
2. Siga padrões e arquitetura do projeto
3. Aplique princípios SOLID
4. Implemente com tratamento de erros
5. Adicione comentários onde necessário
6. Mantenha arquivos em UTF-8
```

**Princípios obrigatórios:**
- Verifique assinaturas de métodos antes de implementar
- Use interfaces ao invés de implementações concretas
- Dependency Injection para dependências
- Tratamento de erros com mensagens claras

### 4.3 Checklist da Implementação

- [ ] Segui padrões existentes do projeto
- [ ] Criei todos os arquivos necessários
- [ ] Modifiquei arquivos conforme planejado
- [ ] Código/documentação está completo
- [ ] Não deixei TODOs pendentes

---

## ETAPA 5: TESTES

### 5.1 Para Projetos de Código

```bash
# Executar testes existentes
npm test / composer test / pytest / go test

# Verificar se novos testes são necessários
# Criar testes para código novo
```

**Critérios:**
- [ ] Testes existentes passam
- [ ] Novos testes foram criados (se necessário)
- [ ] Cobertura adequada para código novo

### 5.2 Para Projetos de Documentação

```
# Validar diagramas Mermaid (sintaxe)
# Verificar links internos
# Confirmar formatação Markdown
```

**Critérios:**
- [ ] Diagramas Mermaid renderizam corretamente
- [ ] Links internos funcionam
- [ ] Markdown bem formatado

### 5.3 Checklist de Testes

- [ ] Executei testes (se aplicável)
- [ ] Todos os testes passam
- [ ] Criei novos testes (se necessário)

---

## ETAPA 6: VALIDAÇÃO

### 6.1 Validação de Qualidade

**Para Documentação:**
- [ ] Todas as seções obrigatórias preenchidas
- [ ] Conteúdo claro e completo
- [ ] Sem erros de português/gramática
- [ ] Diagramas legíveis e corretos
- [ ] Referências cruzadas corretas

**Para Código:**
- [ ] Código compila/executa sem erros
- [ ] Funcionalidade implementada corretamente
- [ ] Tratamento de erros adequado
- [ ] Performance aceitável
- [ ] Sem vulnerabilidades óbvias

### 6.2 Validação de Consistência

- [ ] Consistente com documentação existente
- [ ] Consistente com código existente
- [ ] Nomenclatura segue padrões
- [ ] Arquitetura respeitada

### 6.3 Checklist de Validação

- [ ] Qualidade verificada
- [ ] Consistência verificada
- [ ] Pronto para próxima etapa

---

## ETAPA 7: LINT

### 7.1 Para Código

```bash
# Executar linters do projeto
npm run lint / composer lint / black / gofmt

# Corrigir problemas encontrados
npm run lint:fix (se disponível)
```

### 7.2 Para Documentação

```
# Verificar formatação Markdown
# Verificar sintaxe de tabelas
# Verificar code blocks
```

### 7.3 Checklist de Lint

- [ ] Linter executado (se aplicável)
- [ ] Problemas de lint corrigidos
- [ ] Formatação consistente

---

## ETAPA 8: CONCLUSÃO

### 8.1 Gerar Relatório de Execução

```markdown
## ✅ Tarefa Executada

**Tarefa:** [ID e nome]
**Tipo:** [Documentação/Código/Testes/Infraestrutura]
**Status:** Concluída

### Arquivos Criados
- `path/to/new-file.md`
- `path/to/new-file.ts`

### Arquivos Modificados
- `path/to/existing.md` - [descrição da mudança]
- `path/to/existing.ts` - [descrição da mudança]

### Testes
- [x] Testes executados: X passaram
- [x] Novos testes criados: Y

### Validações
- [x] Qualidade verificada
- [x] Consistência verificada
- [x] Lint executado

### Observações
- [Qualquer nota relevante]
```

### 8.2 Checklist de Conclusão

- [ ] Relatório gerado
- [ ] Todos os itens documentados

---

## ETAPA 9: ATUALIZAÇÃO

### 9.1 Marcar Tarefa como Concluída

**OBRIGATÓRIO**: Atualize o arquivo de tarefas!

```markdown
# Antes
- [ ] TASK-CAD-001: Criar UC de sincronização de clientes

# Depois
- [x] TASK-CAD-001: Criar UC de sincronização de clientes
```

### 9.2 Atualizar Subtarefas

Se houver subtarefas, marque TODAS como concluídas:

```markdown
# Antes
- [ ] TASK-CAD-001: Criar UC de sincronização
  - [ ] Definir fluxo principal
  - [ ] Documentar regras de negócio
  - [ ] Criar casos de teste

# Depois
- [x] TASK-CAD-001: Criar UC de sincronização
  - [x] Definir fluxo principal
  - [x] Documentar regras de negócio
  - [x] Criar casos de teste
```

### 9.3 Checklist Final

- [ ] Tarefa marcada como [x] no arquivo de tarefas
- [ ] Todas as subtarefas marcadas como [x]
- [ ] Arquivo de tarefas salvo

---

## RESUMO DO FLUXO

| Etapa | Nome | Ação Principal | Obrigatório |
|-------|------|----------------|-------------|
| 1 | Análise | Ler documentação | ✅ SIM |
| 2 | Localização | Encontrar tarefa | ✅ SIM |
| 3 | Planejamento | Definir escopo | ✅ SIM |
| 4 | Implementação | Executar tarefa | ✅ SIM |
| 5 | Testes | Rodar testes | Se aplicável |
| 6 | Validação | Verificar qualidade | ✅ SIM |
| 7 | Lint | Verificar formatação | Se aplicável |
| 8 | Conclusão | Gerar relatório | ✅ SIM |
| 9 | Atualização | Marcar [x] | ✅ SIM |

---

## NOMENCLATURAS COMUNS

### Documentação
- `UC-AUTH-NNN`: Autenticação
- `UC-CAD-NNN`: Cadastros
- `UC-PED-NNN`: Pedidos
- `UC-FAT-NNN`: Faturamento
- `UC-FIN-NNN`: Financeiro
- `UC-LOG-NNN`: Logística
- `UC-MON-NNN`: Monitoramento

### Regras e Testes
- `RN-NNN`: Regra de Negócio
- `CT-NNN`: Caso de Teste
- `E-NNN`: Código de Exceção
- `RNF-NNN`: Requisito Não-Funcional

---

**EXECUTE AGORA A TAREFA: $ARGUMENTS**

**LEMBRE-SE:**
1. ⚠️ LEIA A DOCUMENTAÇÃO em `docs/` ANTES de começar
2. ⚠️ SIGA TODAS AS ETAPAS na ordem
3. ⚠️ NÃO PULE etapas
4. ⚠️ MARQUE A TAREFA como [x] ao final