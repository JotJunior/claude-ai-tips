---
title: Documento com frontmatter aberto sem fechar
version: 1.0

# Corpo do documento

Este fixture deve FALHAR na checagem de frontmatter do `validate.sh`:
abre com `---` na primeira linha, mas nunca emite um `---` de fechamento.
O script deve reportar ERRO "Abre com `---` mas nao fecha".

O conteudo abaixo da linha 3 nao ajuda — sem o delimitador `---`, todo o
resto e tecnicamente parte do bloco de frontmatter nao fechado.
