# Tarefas — estrutura realista de fases e tarefas

Fixture aproximando um tasks.md real (tres fases, seis tarefas, subtarefas
parcialmente preenchidas). Serve para exercitar contagem de FASES/TAREFAS
em documentos com volume mais proximo do tipico.

## FASE 1 - Fundacao

### 1.1 Setup do projeto `[A]`

- [x] 1.1.1 criar repo
- [x] 1.1.2 configurar CI
- [x] 1.1.3 adicionar linter

### 1.2 Schema inicial `[C]`

- [x] 1.2.1 migration base
- [x] 1.2.2 seed de dados
- [ ] 1.2.3 adicionar indices

## FASE 2 - Dominio

### 2.1 Entidades principais `[A]`

- [x] 2.1.1 entidade User
- [~] 2.1.2 entidade Account
- [ ] 2.1.3 entidade Transaction

### 2.2 Regras de negocio `[C]`

- [~] 2.2.1 validacoes de criacao
- [ ] 2.2.2 regras de transicao de estado
- [ ] 2.2.3 auditoria

## FASE 3 - API

### 3.1 Endpoints CRUD `[A]`

- [ ] 3.1.1 GET /users
- [ ] 3.1.2 POST /users
- [!] 3.1.3 DELETE /users (bloqueada por regra legal)

### 3.2 Autenticacao `[M]`

- [ ] 3.2.1 middleware JWT
- [ ] 3.2.2 refresh token

---

Contagem esperada para metrics.sh (validada contra execucao real):

- PENDING = 8
- DONE = 6
- IN_PROGRESS = 2
- BLOCKED = 1
- TOTAL = 17
- pct_done = 35 (6 * 100 / 17 = 35 truncado)
- TASKS = 6
- PHASES = 3
- CRITICAL = 2 (1.2, 2.2)
- HIGH = 3 (1.1, 2.1, 3.1)
- MEDIUM = 1 (3.2)
