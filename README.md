# Claude Code Toolkit

Conjunto de ferramentas para aumentar a produtividade no desenvolvimento do dia a dia com o [Claude Code](https://claude.ai/code).

Este repositório contém **commands**, **skills** e **agents** que estendem as capacidades do Claude Code para tarefas comuns de documentação e desenvolvimento.

## Estrutura

```
├── commands/     # Workflows de alto nível (slash commands)
├── skills/       # Capacidades especializadas invocadas por contexto
└── agents/       # Agentes autônomos para tarefas complexas
```

## Commands

Workflows invocados via slash commands para tarefas estruturadas:

| Comando | Descrição |
|---------|-----------|
| `/initialize-docs` | Cria hierarquia padrão de documentação com 9 níveis |
| `/execute-task <id>` | Executa tarefa seguindo workflow obrigatório de 9 etapas |
| `/review-task` | Gera relatório de status com métricas e recomendações |
| `/create-use-case` | Cria documentação de caso de uso usando template de 15 seções |

### Exemplo de Uso

```
/execute-task TASK-CAD-001
```

O comando guia o Claude através de: Análise → Localização → Planejamento → Implementação → Testes → Validação → Lint → Conclusão → Atualização.

## Skills

Capacidades auto-invocadas baseadas no contexto da conversa:

| Skill | Trigger | Descrição |
|-------|---------|-----------|
| **advisor** | Análises estratégicas | Conselheiro brutalmente honesto que disseca raciocínio e gera planos de ação |
| **doc-generate-use-case** | "criar caso de uso", "gerar UC" | Gera documentação estruturada com diagramas Mermaid |
| **doc-validate** | "validar documentação", "verificar UC" | Valida documentos contra padrões de qualidade |

### Skill: Advisor

A skill `advisor` é ativada automaticamente quando você apresenta ideias, planos ou estratégias para análise. Ela força respostas em duas partes:

1. **Crítica** - Análise forense do raciocínio
2. **Plano de Ação** - Prescrição tática com ações imediatas

## Agents

Agentes especializados para tarefas complexas que requerem autonomia:

### Documentation Agent

Especialista em documentação técnica que coordena:

- Criação de casos de uso (UC-*.md)
- Documentação de integrações
- Modelagem de dados e diagramas ER
- Documentação de APIs

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

## Instalação

### Instalação rápida (recomendado)

No diretório do seu projeto, execute:

```bash
curl -fsSL https://raw.githubusercontent.com/JotJunior/claude-ai-tips/main/install.sh | bash
```

Ou com `wget`:

```bash
wget -qO- https://raw.githubusercontent.com/JotJunior/claude-ai-tips/main/install.sh | bash
```

Isso instala os commands, skills e agents em `.claude/` no diretório atual.

### Instalação global

Para disponibilizar em todos os projetos:

```bash
curl -fsSL https://raw.githubusercontent.com/JotJunior/claude-ai-tips/main/install.sh | bash -s -- --global
```

### Estrutura de Diretórios Claude Code

```
~/.claude/                  # Instalação global (--global)
├── commands/
├── skills/
└── agents/

seu-projeto/
├── .claude/                # Instalação por projeto (padrão)
│   ├── commands/
│   ├── skills/
│   └── agents/
└── ...
```

## Hierarquia de Documentação

O comando `/initialize-docs` cria a seguinte estrutura:

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

Contribuições são bem-vindas. Para adicionar novos commands, skills ou agents:

1. Siga a estrutura de arquivos existente
2. Documente o uso no arquivo markdown correspondente
3. Teste com o Claude Code antes de submeter

## Licença

MIT
