# Indice de Tarefas de Implementacao - {NOME_PROJETO}

> **Total de tarefas:** {TOTAL_TAREFAS}
> **Milestones:** {TOTAL_MILESTONES} ({RANGE_MILESTONES})
> **Status:** {RESUMO_COBERTURA}

## Milestones

| #   | Milestone                | Arquivo                                                  | Tarefas | Progresso | Dependencias           |
|-----|--------------------------|----------------------------------------------------------|---------|-----------|------------------------|
| {ID} | {Nome}                  | [{arquivo}]({arquivo})                                   | {N}     | 0/{N}     | {deps ou "Nenhuma"}    |

## Grafo de Dependencias

```
{MILESTONE_RAIZ} ({Nome})
├── {MILESTONE_FILHO_1} ({Nome})
│   ├── {MILESTONE_NETO_1} ({Nome})
│   │   └── ...
│   └── ...
└── {MILESTONE_FINAL} ({Nome}) <- depende de todos
```

## Cobertura de Artefatos

### Use Cases ({RANGE_UCS})

| UC | Descricao | Milestones |
|----|-----------|------------|
| {UC-ID} | {Descricao} | {M1, M2, M3} |

### Data Definitions (DDs)

| DD | Milestones |
|----|------------|
| {DD-ID} | {M1, M2} |

### APIs ({RANGE_APIS})

| API | Descricao | Milestones |
|-----|-----------|------------|
| {API-ID} | {Descricao} | {M1, M2} |

### ADRs ({RANGE_ADRS})

| ADR | Descricao | Milestones |
|-----|-----------|------------|
| {ADR-ID} | {Descricao} | {M1, M2} |

## Ordem de Execucao Sugerida

A execucao segue o caminho critico do grafo de dependencias:

1. **Fase 1 - {Nome}:** {M0} -> {M1}
2. **Fase 2 - {Nome}:** {M2} -> {M3}
3. **Fase N - {Nome}:** {MX} -> {MY}