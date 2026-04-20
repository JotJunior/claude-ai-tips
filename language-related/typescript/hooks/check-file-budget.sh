#!/usr/bin/env bash
# PostToolCall hook: File Budget Enforcer
# Warns if file exceeds 250 lines, blocks if exceeds 400 lines.
# Large files are a code smell - consider splitting.

set -euo pipefail

INPUT="${CLAUDE_TOOL_INPUT:-}"
[ -z "$INPUT" ] && exit 0

FILE_PATH=$(echo "$INPUT" | jq -r '.file_path // empty' 2>/dev/null)
[ -z "$FILE_PATH" ] && exit 0

# Early return se nao e TS
case "$FILE_PATH" in
  *.ts|*.tsx) ;;
  *) exit 0 ;;
esac

cd "$CLAUDE_PROJECT_DIR" 2>/dev/null || exit 0

# Check if file exists
[ ! -f "$FILE_PATH" ] && exit 0

# Count lines
LINE_COUNT=$(wc -l < "$FILE_PATH" 2>/dev/null || echo 0)
LINE_COUNT=$(echo "$LINE_COUNT" | tr -d ' ')

# > 400 lines = block
if [ "$LINE_COUNT" -gt 400 ]; then
  cat >&2 <<MSG
BLOCKED: File budget exceeded (hard limit).

Arquivo: $FILE_PATH
Linhas: $LINE_COUNT
Limite: 400

Arquivos com mais de 400 linhas sao dificeis de manter.
Refatore em modulos menores:
  - Separe hooks customizados
  - Extraia utilitarios
  - Crie componentes menores
  - Use composicao

Sugestao: Angular CDK compliance - max 400 linhas por arquivo.

Veja: language-related/typescript/skills/file-budget/
MSG
  exit 2
fi

# > 250 lines = warning
if [ "$LINE_COUNT" -gt 250 ]; then
  cat >&2 <<MSG
WARNING: File approaching budget limit.

Arquivo: $FILE_PATH
Linhas: $LINE_COUNT
Limite: 250 (warning) / 400 (block)

Considere refatorar em modulos menores.
Este arquivo sera bloqueado ao atingir 400 linhas.

Veja: language-related/typescript/skills/file-budget/
MSG
  exit 0
fi

exit 0
