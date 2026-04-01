# Claude Code Toolkit

Conjunto de ferramentas para aumentar a produtividade no desenvolvimento do dia a dia com
o [Claude Code](https://claude.ai/code).

Este repositorio contém **skills** e **hooks** que estendem as capacidades do Claude Code para tarefas
comuns de documentação, desenvolvimento e qualidade de código.

## Estrutura

```
├── global/                     # Skills globais (independentes de linguagem)
│   └── skills/
│       ├── advisor/            # Conselheiro estratégico
│       ├── commit/             # Padronização de commits
│       ├── create-tasks/       # Criação de backlog de tarefas
│       ├── create-use-case/    # Documentação de casos de uso
│       ├── execute-task/       # Execução de tarefas com workflow de 9 etapas
│       ├── initialize-docs/    # Inicialização de estrutura de documentação
│       ├── review-task/        # Revisão de status de tarefas
│       └── validate-documentation/ # Validação de documentação
├── language-related/           # Skills e hooks específicos por linguagem
│   ├── go/                     # Go
│   │   ├── skills/             # Skills para projetos Go
│   │   ├── hooks/              # Hooks de validação para Go
│   │   └── settings.json       # Configuração de hooks
│   └── dotnet/                 # .NET
│       └── skills/             # Skills para projetos .NET
```

## Skills Globais

Skills disponíveis em `global/skills/`, independentes de linguagem ou framework:

| Skill | Trigger | Descrição |
|-------|---------|-----------|
| **advisor** | "me aconselhe", "analise estratégica" | Conselheiro brutalmente honesto que disseca raciocínio e gera planos de ação |
| **commit** | Ao commitar | Padronização de mensagens de commit |
| **create-tasks** | "criar tarefas", "criar backlog" | Cria backlog de tarefas técnicas estruturado por fases |
| **create-use-case** | "criar caso de uso", "gerar UC" | Gera documentação de caso de uso com template de 15 seções e diagramas Mermaid |
| **execute-task** | "executar tarefa", "execute task" | Executa tarefa seguindo workflow obrigatório de 9 etapas |
| **initialize-docs** | "inicializar docs", "setup documentação" | Cria hierarquia padrão de documentação com 9 níveis |
| **review-task** | "revisar tarefas", "status das tarefas" | Gera relatório de status com progresso e recomendações |
| **validate-documentation** | "validar documentação", "verificar UC" | Valida documentos contra padrões de qualidade |

### Workflow: execute-task

O skill `execute-task` impõe um workflow completo de 9 etapas:

1. **Análise** - Detectar contexto e ler documentação
2. **Localização** - Encontrar tarefa no arquivo de tarefas
3. **Planejamento** - Definir escopo e identificar padrões
4. **Implementação** - Executar a tarefa
5. **Testes** - Rodar testes se aplicável
6. **Validação** - Verificar qualidade e consistência
7. **Lint** - Checar formatação e padrões
8. **Conclusão** - Gerar relatório de execução
9. **Atualização** - Marcar tarefa como concluída

## Skills para Go

Skills em `language-related/go/skills/` para projetos Go:

| Skill | Descrição |
|-------|-----------|
| **go-add-entity** | Adiciona uma nova entidade ao serviço |
| **go-add-migration** | Cria nova migration SQL |
| **go-add-test** | Gera testes para código Go |
| **go-add-consumer** | Adiciona consumer de mensagens (RabbitMQ) |
| **go-review-service** | Revisa qualidade de um serviço Go |

### Hooks para Go

Hooks em `language-related/go/hooks/` para validações automáticas:

| Hook | Descrição |
|------|-----------|
| **go-build-gate.sh** | Valida build antes de operações |
| **check-uncommitted.sh** | Verifica alterações não commitadas |
| **check-schema-prefix.sh** | Valida prefixo de schema nas migrations |
| **check-route-order.sh** | Verifica ordenação de rotas no router |

## Skills para .NET

Skills em `language-related/dotnet/skills/` para projetos .NET:

| Skill | Descrição |
|-------|-----------|
| **dotnet-create-entity** | Cria entidade com mapeamento EF Core |
| **dotnet-create-feature** | Gera feature completa (handler, validator, etc.) |
| **dotnet-create-project** | Scaffolding de novo projeto .NET |
| **dotnet-create-test** | Gera testes unitários e de integração |
| **dotnet-hexagonal-architecture** | Aplica arquitetura hexagonal |
| **dotnet-infrastructure** | Configura infraestrutura (DB, cache, messaging) |
| **dotnet-review-code** | Revisa qualidade de código .NET |
| **dotnet-testing** | Estratégias e padrões de teste |

## Instalação

Copie os diretórios desejados para o seu projeto ou instalação global do Claude Code:

```bash
# Skills globais — copiar para o projeto
cp -r global/skills/ seu-projeto/.claude/skills/

# Skills globais — instalação global
cp -r global/skills/ ~/.claude/skills/

# Skills de Go — copiar para projeto Go
cp -r language-related/go/skills/ seu-projeto/.claude/skills/
cp -r language-related/go/hooks/ seu-projeto/.claude/hooks/
cp language-related/go/settings.json seu-projeto/.claude/settings.json

# Skills de .NET — copiar para projeto .NET
cp -r language-related/dotnet/skills/ seu-projeto/.claude/skills/
```

### Estrutura de Destino

```
~/.claude/                  # Instalação global
└── skills/

seu-projeto/
└── .claude/                # Instalação por projeto
    ├── skills/
    └── hooks/              # (opcional, para hooks de linguagem)
```

## Convenções de Nomenclatura

| Tipo | Padrão | Exemplo |
|------|--------|---------|
| Casos de Uso | `UC-{DOMÍNIO}-{NNN}` | UC-CAD-001 |
| Decisões de Arquitetura | `ADR-{NNN}-{título}` | ADR-001-database |
| Regras de Negócio | `RN{NN}` | RN01 |
| Casos de Teste | `CT{NN}` | CT01 |
| Exceções | `E{NNN}` | E001 |

### Códigos de Domínio

- `AUTH` - Autenticação
- `CAD` - Cadastros
- `PED` - Pedidos
- `FIN` - Financeiro
- `FAT` - Faturamento
- `LOG` - Logística
- `MON` - Monitoramento

## Hierarquia de Documentação

O skill `/initialize-docs` cria a seguinte estrutura:

```
docs/
├── 01-briefing-discovery/      # Requisitos iniciais, PDFs
├── 02-requisitos-casos-uso/    # Casos de uso (UC-*)
├── 03-modelagem-dados/         # DERs, schemas
├── 04-arquitetura-sistema/     # ADRs, diagramas
├── 05-definicao-apis/          # REST, gRPC, Webhooks, Messaging
├── 06-ui-ux-design/            # Wireframes, mockups
├── 07-plano-testes/            # Planos de teste
├── 08-operacoes/               # Runbooks
└── 09-entregaveis/             # Release notes
```

## Contribuindo

Contribuições são bem-vindas. Para adicionar novos skills ou hooks:

1. Siga a estrutura de diretórios existente
2. Crie um `SKILL.md` dentro do diretório do skill
3. Teste com o Claude Code antes de submeter

## Licença

MIT
