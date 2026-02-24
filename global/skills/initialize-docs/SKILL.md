---
name: initialize-docs
description: |
  Inicializa estrutura padrao de documentacao do projeto com diretorios numerados,
  READMEs template e organizacao por tipo (briefing, UCs, DER, ADRs, APIs, testes, operacoes).
  Triggers: "inicializar docs", "criar estrutura docs", "setup documentacao",
  "organizar documentacao", "estrutura de pastas docs".
argument-hint: "[--dry-run | --force | --no-move]"
allowed-tools:
  - Read
  - Write
  - Glob
  - Grep
  - Bash
  - Edit
---

# Skill: Inicializar Estrutura de Documentacao

Inicializa a estrutura padrao de documentacao do projeto, criando diretorios e arquivos de template.

## Argumentos

$ARGUMENTS

## Instrucoes

Execute os seguintes passos para inicializar a estrutura de documentacao:

### 1. Verificar Estrutura Atual

Primeiro, verifique o diretorio `docs/` atual usando Glob e Bash.

### 2. Estrutura Padrao de Diretorios

Crie os seguintes diretorios (se nao existirem):

```
docs/
-- 01-briefing-discovery/      # Documentos de briefing, requisitos iniciais
-- 02-requisitos-casos-uso/    # Casos de uso (UC-XXX-*.md)
-- 03-modelagem-dados/         # DERs, schemas de banco (DER-*.md)
-- 04-arquitetura-sistema/     # ADRs, diagramas de arquitetura (ADR-*.md)
-- 05-definicao-apis/          # Contratos de API
|   -- REST/                   # APIs REST
|   -- gRPC/                   # Definicoes gRPC/protobuf
|   -- WEBHOOKS/               # Webhooks
|   -- MESSAGING/              # Mensageria (RabbitMQ, Kafka, etc)
-- 06-ui-ux-design/            # Wireframes, mockups, guias de estilo
-- 07-plano-testes/            # Planos de teste, casos de teste
-- 08-operacoes/               # Runbooks, procedimentos operacionais
-- 09-entregaveis/             # Documentos de entrega, releases notes
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

### 4. Criar READMEs Template

Para cada diretorio, crie um README.md se nao existir, com:
- Descricao do proposito do diretorio
- Convencoes de nomenclatura
- Tipos de arquivo esperados
- Links para templates relevantes

#### docs/README.md (Principal)

```markdown
# Documentacao do Projeto

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

- **UC-XXX-NNN**: Caso de Uso
- **ADR-NNN**: Architectural Decision Record
- **DER-XXX**: Diagrama Entidade-Relacionamento
- **TC-NNN**: Test Case
- **RB-NNN**: Runbook
```

### 5. Mover Arquivos Existentes

Se existirem arquivos na raiz de `docs/`, mova-os para os diretorios apropriados:

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

## Opcoes de Argumento

- `--dry-run`: Apenas mostra o que seria feito, sem executar
- `--force`: Sobrescreve READMEs existentes
- `--no-move`: Apenas cria diretorios e templates, nao move arquivos

## Notas

- Este comando e idempotente - pode ser executado multiplas vezes
- Arquivos ja existentes nao sao sobrescritos (exceto com `--force`)
- Arquivos de projeto como `tasks-*.md` e `cronograma.md` sao mantidos na raiz