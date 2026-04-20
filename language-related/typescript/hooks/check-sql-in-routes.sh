#!/usr/bin/env bash
# PostToolCall hook: Block SQL template tags in routes/handlers
# Detects sql\`...\` usage in src/routes/ or src/handlers/ directories.
# SQL should live in src/repositories/ layer.

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

# Check if file is in routes or handlers directory
case "$FILE_PATH" in
  src/routes/*|src/handlers/*|*/routes/*|*/handlers/*)
    cd "$CLAUDE_PROJECT_DIR" 2>/dev/null || exit 0
    
    # Get content to check for SQL template tag
    CONTENT=$(echo "$INPUT" | jq -r '.content // empty' 2>/dev/null)
    [ -z "$CONTENT" ] && CONTENT=$(echo "$INPUT" | jq -r '.new_string // empty' 2>/dev/null)
    [ -z "$CONTENT" ] && exit 0
    
    # Check for sql template tag
    if echo "$CONTENT" | grep -qE 'sql\s*`' 2>/dev/null; then
      cat >&2 <<MSG
BLOCKED: SQL template tag detected in routes/handlers layer.

Arquivo: $FILE_PATH
Encontrado: sql\`...\`

SQL deve ficar na camada de Repository, nao em Routes/Handlers.
Isso viola o padrao de arquitetura em camadas.

Mova o SQL para:
  src/repositories/ ou
  src/data/ ou
  src/dal/

e chame via funcao no handler:
  const result = await userRepository.findById(id);

Veja: language-related/typescript/skills/architecture/
MSG
      exit 2
    fi
    ;;
esac

exit 0
