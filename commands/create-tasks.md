# Criar Lista de Tarefas

Gere uma lista completa de tarefas de implementacao a partir da documentacao existente do projeto.

## Argumentos

$ARGUMENTS

## Instrucoes

Analise a documentacao do projeto e gere uma lista estruturada de tarefas de implementacao
organizada em milestones. Cada tarefa deve ser decomposta em subtarefas atomicas e vinculada
aos artefatos de documentacao que a originaram.

### Passo 1: Descoberta de Artefatos

Escaneie o diretorio de documentacao do projeto e identifique todos os artefatos existentes:

```
PROCURAR (na ordem):
├── docs/                    # Diretorio principal de docs
├── documentation/           # Alternativa
├── .github/                 # Docs no GitHub
└── Raiz do projeto          # README, ARCHITECTURE, etc.

TIPOS DE ARTEFATOS:
├── Use Cases      (UC-*)           # Casos de uso
├── ADRs           (ADR-*)          # Decisoes de arquitetura
├── APIs           (API-*)          # Definicoes de API
├── Data Defs      (DD-*)           # Modelos de dados
├── Diagramas      (DER, C4, etc.)  # Diagramas tecnicos
└── Outros         (briefing, etc.) # Documentos de contexto
```

Leia cada artefato encontrado para entender:
- Requisitos funcionais e nao-funcionais
- Decisoes tecnicas e restricoes
- Modelos de dados e contratos de API
- Dependencias entre componentes

### Passo 2: Definir Milestones

Agrupe as funcionalidades em milestones coesos:

**Regras:**
- M0 e sempre o bootstrap/infraestrutura do projeto
- Ultimo milestone e sempre operacoes/deploy/producao
- Milestones intermediarios agrupam por dominio funcional
- Cada milestone deve ter entre 10 e 25 tarefas
- Milestones devem ter entregaveis concretos e verificaveis

**Para cada milestone, defina:**
- ID: M{N} (sequencial comecando em M0)
- Nome: Descritivo, max 30 caracteres
- Objetivo: 1 frase clara
- Dependencias: Quais milestones devem estar prontos antes
- Entregavel: O que esta "pronto" ao final

### Passo 3: Decompor em Tarefas

Para cada milestone, extraia tarefas concretas:

**Formato da tarefa:**
```markdown
- [ ] **M{N}-{NNN}** — {Verbo no infinitivo} {descricao} `{REF-1}` `{REF-2}`
```

**Formato da subtarefa:**
```markdown
  - [ ] M{N}-{NNN}.{N} — {Verbo no infinitivo} {descricao}
```

**Regras de decomposicao:**
1. Cada subtarefa = 1 sessao de trabalho
2. Cada subtarefa = 1 resultado verificavel
3. Max 7 subtarefas por tarefa
4. Descricoes iniciam com verbo no infinitivo
5. Toda tarefa deve ter ao menos 1 referencia a artefato (exceto infra generica)

### Passo 4: Montar Indice

Gere o arquivo `tasks-index.md` contendo:

1. **Tabela de milestones** com links, contagem e dependencias
2. **Grafo de dependencias** em ASCII (arvore)
3. **Cobertura de artefatos** por tipo:
   - Tabela de UCs com milestones onde aparecem
   - Tabela de DDs com milestones onde aparecem
   - Tabela de APIs com milestones onde aparecem
   - Tabela de ADRs com milestones onde aparecem
4. **Ordem de execucao** sugerida por fases

### Passo 5: Gerar Arquivos

Para cada milestone, gere um arquivo separado:

**Nomenclatura:**
```
tasks-index.md
tasks-m00-{slug}.md
tasks-m01-{slug}.md
...
tasks-m{NN}-{slug}.md
```

Onde `{slug}` e o nome do milestone em kebab-case sem acentos.

### Passo 6: Validar

Antes de finalizar, execute as validacoes:

- [ ] Todos os UCs referenciados em ao menos 1 tarefa
- [ ] Todos os ADRs referenciados em ao menos 1 tarefa
- [ ] Todos os APIs referenciados em ao menos 1 tarefa
- [ ] Todos os DDs referenciados em ao menos 1 tarefa
- [ ] Dependencias entre milestones sem ciclos
- [ ] Numeracao sequencial sem gaps
- [ ] Totais no indice == contagem real nos arquivos
- [ ] Cada milestone tem 10-25 tarefas

## Interacao

### Antes de gerar, pergunte ao usuario:

1. **Diretorio de saida** - Onde salvar os arquivos (sugerir `docs/`)
2. **Escopo** - Todo o projeto ou parte especifica
3. **Se ja existem tarefas** - Para evitar duplicacao ou para atualizar

### Apos gerar, apresente:

```markdown
## Resumo da Geracao

| Metrica | Valor |
|---------|-------|
| Milestones | {N} |
| Tarefas | {N} |
| Subtarefas | {N} |
| Artefatos cobertos | {N}/{TOTAL} |

### Arquivos Criados
- `docs/tasks-index.md`
- `docs/tasks-m00-{nome}.md`
- ...

### Proximos Passos
1. Revise os milestones e dependencias
2. Ajuste prioridades se necessario
3. Inicie com `/execute-task M0-001`
```

## Diretrizes de Qualidade

1. **Completude** - Toda a documentacao deve ser refletida nas tarefas
2. **Rastreabilidade** - Toda tarefa vinculada a artefato(s) fonte
3. **Praticidade** - Subtarefas executaveis, nao abstratas
4. **Consistencia** - Nomenclatura e formato uniformes
5. **Realismo** - Tarefas de teste e documentacao incluidas, nao apenas codigo

## Saida Esperada

Gere todos os arquivos Markdown prontos para serem salvos no diretorio de documentacao.
Pergunte ao usuario antes de salvar para confirmar o diretorio.