# Tarefas — mistura controlada de status

Fixture com proporcoes exatas. Cada tipo de checkbox aparece ao menos
uma vez para exercitar a contagem de todos os contadores do metrics.sh.

## FASE 1 - Fundacao

### 1.1 Estrutura base `[C]`

- [x] 1.1.1 primeiro passo
- [x] 1.1.2 segundo passo
- [~] 1.1.3 em andamento 1
- [ ] 1.1.4 pendente 1

### 1.2 Suporte `[A]`

- [x] 1.2.1 terceiro passo
- [~] 1.2.2 em andamento 2
- [!] 1.2.3 bloqueada 1
- [ ] 1.2.4 pendente 2

## FASE 2 - Extensoes

### 2.1 Feature extra `[M]`

- [ ] 2.1.1 pendente 3
- [ ] 2.1.2 pendente 4

---

Contagem esperada para metrics.sh (validada manualmente por inspecao):

- PENDING = 4 (1.1.4, 1.2.4, 2.1.1, 2.1.2)
- DONE = 3 (1.1.1, 1.1.2, 1.2.1)
- IN_PROGRESS = 2 (1.1.3, 1.2.2)
- BLOCKED = 1 (1.2.3)
- TOTAL = 10
- pct_done = 30
- TASKS = 3 (1.1, 1.2, 2.1)
- PHASES = 2
- CRITICAL = 1 (1.1)
- HIGH = 1 (1.2)
- MEDIUM = 1 (2.1)
