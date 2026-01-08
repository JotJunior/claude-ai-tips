# Inicializar Estrutura de Documentacao

Inicializa a estrutura padrao de documentacao do projeto, criando diretorios e arquivos de template.

## Argumentos

$ARGUMENTS

## Instrucoes

Execute os seguintes passos para inicializar a estrutura de documentacao:

### 1. Verificar Estrutura Atual

Primeiro, verifique o diretorio `docs/` atual:

```bash
# Listar estrutura existente
find ./docs -type d 2>/dev/null || echo "Diretorio docs nao existe"
find ./docs -type f -name "*.md" 2>/dev/null | head -50
```

### 2. Estrutura Padrao de Diretorios

Crie os seguintes diretorios (se nao existirem):

```
docs/
├── 01-briefing-discovery/      # Documentos de briefing, requisitos iniciais, PDFs de especificacao
├── 02-requisitos-casos-uso/    # Casos de uso (UC-XXX-*.md)
├── 03-modelagem-dados/         # DERs, schemas de banco, modelagem (DER-*.md)
├── 04-arquitetura-sistema/     # ADRs, diagramas de arquitetura (ADR-*.md)
├── 05-definicao-apis/          # Contratos de API
│   ├── REST/                   # APIs REST
│   ├── gRPC/                   # Definicoes gRPC/protobuf
│   ├── WEBHOOKS/               # Webhooks
│   └── MESSAGING/              # Mensageria (RabbitMQ, Kafka, etc)
├── 06-ui-ux-design/            # Wireframes, mockups, guias de estilo
├── 07-plano-testes/            # Planos de teste, casos de teste
├── 08-operacoes/               # Runbooks, procedimentos operacionais
└── 09-entregaveis/             # Documentos de entrega, releases notes
```

### 3. Criar Diretorios

```bash
mkdir -p docs/01-briefing-discovery
mkdir -p docs/02-requisitos-casos-uso
mkdir -p docs/03-modelagem-dados
mkdir -p docs/04-arquitetura-sistema
mkdir -p docs/05-definicao-apis/REST
mkdir -p docs/05-definicao-apis/gRPC
mkdir -p docs/05-definicao-apis/WEBHOOKS
mkdir -p docs/05-definicao-apis/MESSAGING
mkdir -p docs/06-ui-ux-design
mkdir -p docs/07-plano-testes
mkdir -p docs/08-operacoes
mkdir -p docs/09-entregaveis
```

### 4. Criar Arquivos de Template (README em cada diretorio)

Para cada diretorio, crie um README.md se nao existir:

#### docs/README.md (Principal)

```markdown
# Documentacao do Projeto

Este diretorio contem toda a documentacao do projeto organizada por fase/tipo.

## Estrutura

| Diretorio | Descricao |
|-----------|-----------|
| [01-briefing-discovery](./01-briefing-discovery/) | Documentos iniciais, briefings, requisitos de negocio |
| [02-requisitos-casos-uso](./02-requisitos-casos-uso/) | Casos de uso detalhados (UC-*) |
| [03-modelagem-dados](./03-modelagem-dados/) | Modelagem de dados, DERs, schemas |
| [04-arquitetura-sistema](./04-arquitetura-sistema/) | Decisoes de arquitetura (ADR-*), diagramas |
| [05-definicao-apis](./05-definicao-apis/) | Contratos de API (REST, gRPC, Webhooks) |
| [06-ui-ux-design](./06-ui-ux-design/) | Wireframes, mockups, guias de estilo |
| [07-plano-testes](./07-plano-testes/) | Planos e casos de teste |
| [08-operacoes](./08-operacoes/) | Runbooks, procedimentos operacionais |
| [09-entregaveis](./09-entregaveis/) | Release notes, documentos de entrega |

## Convencoes de Nomenclatura

- **UC-XXX**: Caso de Uso (ex: UC-001-autenticar-usuario.md)
- **ADR-XXX**: Architectural Decision Record (ex: ADR-001-escolha-banco.md)
- **DER-XXX**: Diagrama Entidade-Relacionamento (ex: DER-clientes.md)
- **TC-XXX**: Test Case (ex: TC-001-login.md)
- **RB-XXX**: Runbook (ex: RB-001-deploy.md)

## Como Contribuir

1. Siga as convencoes de nomenclatura
2. Use Markdown para todos os documentos
3. Inclua diagramas usando Mermaid quando possivel
4. Mantenha os documentos atualizados
```

#### docs/01-briefing-discovery/README.md

```markdown
# Briefing e Discovery

Documentos iniciais do projeto, incluindo:

- Documentos de briefing de negocio
- Requisitos iniciais
- PDFs de especificacao
- Documentos de stakeholders
- Analises de viabilidade

## Arquivos Esperados

- **BRIEFING-*.md**: Documentos de briefing
- **REQ-*.md**: Requisitos de alto nivel
- **ANALISE-*.md**: Analises de viabilidade
- ***.pdf**: Documentos externos de referencia
```

#### docs/02-requisitos-casos-uso/README.md

```markdown
# Requisitos e Casos de Uso

Casos de uso detalhados do sistema.

## Convencao de Nomenclatura

Os casos de uso seguem o padrao: `UC-{NUMERO}-{nome-descritivo}.md`

Exemplo: `UC-001-autenticar-usuario.md`

## Estrutura de um Caso de Uso

Cada caso de uso deve conter:

1. Informacoes Gerais (ID, Nome, Prioridade)
2. Descricao
3. Atores
4. Pre-condicoes
5. Pos-condicoes
6. Fluxo Principal (com diagrama Mermaid)
7. Fluxos Alternativos
8. Excecoes
9. Regras de Negocio
10. Requisitos Nao-Funcionais
11. Casos de Teste
12. Dependencias

## Template

Use o comando `/create-use-case` para criar um novo caso de uso.
```

#### docs/03-modelagem-dados/README.md

```markdown
# Modelagem de Dados

Diagramas e schemas de banco de dados.

## Convencao de Nomenclatura

- `DER-{sistema/entidade}.md`: Diagrama Entidade-Relacionamento
- `SCHEMA-{banco}.sql`: Scripts de criacao de banco
- `MIGRATION-{numero}-{descricao}.sql`: Scripts de migracao

## Conteudo Esperado

- Diagramas ER usando Mermaid
- Scripts DDL
- Dicionario de dados
- Regras de integridade
```

#### docs/04-arquitetura-sistema/README.md

```markdown
# Arquitetura do Sistema

Documentos de arquitetura e decisoes tecnicas.

## ADR - Architecture Decision Records

Cada decisao de arquitetura segue o padrao: `ADR-{NUMERO}-{titulo}.md`

### Estrutura de um ADR

1. **Titulo**: Decisao tomada
2. **Status**: Proposto | Aceito | Depreciado | Substituido
3. **Contexto**: Problema ou necessidade
4. **Decisao**: O que foi decidido
5. **Consequencias**: Impactos positivos e negativos
6. **Alternativas Consideradas**: Outras opcoes avaliadas

## Diagramas

- Diagramas C4 (Contexto, Container, Componente)
- Diagramas de sequencia
- Diagramas de implantacao
```

#### docs/05-definicao-apis/README.md

```markdown
# Definicao de APIs

Contratos e especificacoes de APIs do sistema.

## Subdiretorios

| Diretorio | Tipo | Descricao |
|-----------|------|-----------|
| [REST](./REST/) | REST APIs | Especificacoes OpenAPI/Swagger |
| [gRPC](./gRPC/) | gRPC | Definicoes Protobuf |
| [WEBHOOKS](./WEBHOOKS/) | Webhooks | Contratos de webhooks |
| [MESSAGING](./MESSAGING/) | Mensageria | Schemas de eventos |

## Convencoes

- REST: `{service}-api.md` ou `{service}-openapi.yaml`
- gRPC: `{service}.proto.md`
- Webhooks: `{provider}-webhooks.md`
- Messaging: `{queue}-schemas.md`
```

#### docs/07-plano-testes/README.md

```markdown
# Plano de Testes

Documentacao de testes do sistema.

## Estrutura

- **TC-{NUMERO}-{descricao}.md**: Casos de teste
- **TP-{NUMERO}-{descricao}.md**: Planos de teste
- **TR-{NUMERO}-{descricao}.md**: Relatorios de teste

## Tipos de Teste

1. Testes Unitarios
2. Testes de Integracao
3. Testes E2E
4. Testes de Performance
5. Testes de Seguranca
```

#### docs/08-operacoes/README.md

```markdown
# Operacoes

Documentos operacionais e runbooks.

## Convencoes

- **RB-{NUMERO}-{procedimento}.md**: Runbooks
- **ALERT-{sistema}.md**: Guia de alertas
- **INCIDENT-{data}-{titulo}.md**: Post-mortems

## Conteudo de um Runbook

1. Objetivo
2. Pre-requisitos
3. Passos detalhados
4. Troubleshooting
5. Rollback
6. Contatos
```

#### docs/09-entregaveis/README.md

```markdown
# Entregaveis

Documentos de entrega e releases.

## Estrutura

- **RELEASE-{versao}.md**: Release notes
- **CHANGELOG.md**: Historico de mudancas
- **DEPLOY-{ambiente}.md**: Guias de deploy
```

### 5. Mover Arquivos Existentes

Se existirem arquivos na raiz de `docs/`, mova-os para os diretorios apropriados baseado no padrao:

| Padrao do Arquivo | Destino |
|-------------------|---------|
| `UC-*.md` | `02-requisitos-casos-uso/` |
| `DER-*.md`, `SCHEMA-*.md` | `03-modelagem-dados/` |
| `ADR-*.md` | `04-arquitetura-sistema/` |
| `*-api.md`, `*.proto.md` | `05-definicao-apis/{tipo}/` |
| `TC-*.md`, `TP-*.md` | `07-plano-testes/` |
| `RB-*.md`, `RUNBOOK-*.md` | `08-operacoes/` |
| `RELEASE-*.md`, `CHANGELOG*.md` | `09-entregaveis/` |
| `*.pdf`, `BRIEFING-*.md` | `01-briefing-discovery/` |
| `tasks-*.md`, `cronograma*.md` | manter na raiz de `docs/` |

### 6. Relatorio de Execucao

Ao final, exiba um relatorio com:
- Diretorios criados
- Arquivos movidos
- Templates criados
- Avisos (arquivos que nao puderam ser movidos automaticamente)

## Exemplo de Saida

```
=== Inicializacao de Documentacao ===

[OK] Diretorios criados:
  - docs/07-plano-testes/
  - docs/08-operacoes/
  - docs/09-entregaveis/

[OK] Templates criados:
  - docs/README.md
  - docs/07-plano-testes/README.md
  - docs/08-operacoes/README.md
  - docs/09-entregaveis/README.md

[INFO] Arquivos movidos: 0

[WARN] Arquivos na raiz que precisam de revisao manual:
  - docs/tasks-new.md (manter na raiz)
  - docs/cronograma.md (manter na raiz)

=== Estrutura Final ===
docs/
├── 01-briefing-discovery/ (4 arquivos)
├── 02-requisitos-casos-uso/ (12 arquivos)
├── 03-modelagem-dados/ (6 arquivos)
├── 04-arquitetura-sistema/ (8 arquivos)
├── 05-definicao-apis/ (10 arquivos)
├── 06-ui-ux-design/ (0 arquivos)
├── 07-plano-testes/ (0 arquivos)
├── 08-operacoes/ (0 arquivos)
└── 09-entregaveis/ (0 arquivos)
```

## Opcoes de Argumento

- `--dry-run`: Apenas mostra o que seria feito, sem executar
- `--force`: Sobrescreve READMEs existentes
- `--no-move`: Apenas cria diretorios e templates, nao move arquivos

## Notas

- Este comando e idempotente - pode ser executado multiplas vezes
- Arquivos ja existentes nao sao sobrescritos (exceto com `--force`)
- Arquivos de projeto como `tasks-*.md` e `cronograma.md` sao mantidos na raiz