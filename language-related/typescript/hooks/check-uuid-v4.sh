#!/usr/bin/env bash
# PostToolCall hook: Block UUID v4 usage when project uses ULID/CUID2
# Detects uuidv4(), randomUUID() and suggests ulid() or createId().

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

# Check for uuid v4 patterns
if grep -qE '(uuidv4|randomUUID|UUID\.v4)' "$FILE_PATH" 2>/dev/null; then
  # Check package.json for ULID or CUID2
  cd "$CLAUDE_PROJECT_DIR" 2>/dev/null || exit 0
  
  if grep -qE '"(ulid|cuid2|@ulid/|@paralleldrive/cuid2)' 'package.json' 2>/dev/null; then
    cat >&2 <<MSG
BLOCKED: UUID v4 usage detected in project that uses ULID/CUID2.

Arquivo: $FILE_PATH
Encontrado: uuidv4() ou randomUUID()

Este projeto usa ULID ou CUID2 para IDs. Use:
  - ULID: import { ulid } from 'ulid' => ulid()
  - CUID2: import { createId } from 'cuid2' => createId()

Beneficios sobre UUID v4:
  - ULID: lexicographically sortable, mais compacto (26 vs 36 chars)
  - CUID2: collision-resistant, k-ordered

Veja: language-related/typescript/skills/id-generation/
MSG
    exit 2
  fi
fi

exit 0
