# Tarefas — todas pendentes (reproduz bug historico)

Este fixture e o caso mais estrito do bug: ha checkboxes `[ ]` mas
ZERO de qualquer outro tipo (`[x]`, `[~]`, `[!]`). No script antigo,
`grep -cE '^\- \[x\] '` encontrava zero matches, imprimia "0" em
stdout e saia com codigo 1 — disparando o fallback `|| printf '0'`
que concatenava "0\\n0". A expressao aritmetica subsequente quebrava
com "syntax error in expression (error token is \"0\")".

Com o fix, cada contador e inicializado a 0 via `|| VAR=0`.

## FASE 1 - Planejamento inicial

### 1.1 Esboco do dominio `[C]`

- [ ] 1.1.1 identificar entidades principais
- [ ] 1.1.2 listar atores
- [ ] 1.1.3 mapear fluxos basicos

### 1.2 Infraestrutura `[A]`

- [ ] 1.2.1 escolher banco de dados
- [ ] 1.2.2 definir estrutura de deploy

---

Contagem esperada para metrics.sh:

- PENDING = 5
- DONE = 0
- IN_PROGRESS = 0
- BLOCKED = 0
- TOTAL = 5
- pct_done = 0
- TASKS = 2
- PHASES = 1
- CRITICAL = 1
- HIGH = 1
- MEDIUM = 0
