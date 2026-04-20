# Documento com link interno quebrado

Este fixture deve FALHAR na checagem de links do `validate.sh`: o link
abaixo aponta para um arquivo que nao existe no diretorio, e o script
deve reportar ERRO "Arquivo nao encontrado: ./nao-existe.md".

Consulte [documento inexistente](./nao-existe.md) para mais detalhes.

O link e o unico problema — nao ha mermaid, frontmatter mal formado, ou
outras violacoes.
