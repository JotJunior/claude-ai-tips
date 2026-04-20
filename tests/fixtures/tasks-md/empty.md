# Tarefas — arquivo vazio de propriedade

Este arquivo nao contem nenhum checkbox, fase ou tarefa. Existe para
exercitar o caminho em que `metrics.sh` encontra TOTAL=0 de subtarefas.

Esperado quando metrics.sh recebe este arquivo:

- Exit code 0
- stdout contem "Nenhuma subtarefa"
- stderr vazio
- zero erros aritmeticos

Este fixture foi a origem do bug historico: `grep -c` sem matches
imprime "0" em stdout E sai com codigo 1, o que, combinado com o
padrao antigo `|| printf '0'`, concatenava "0\\n0" e quebrava a
expressao aritmetica `$((PENDING + DONE + IN_PROGRESS + BLOCKED))`.
