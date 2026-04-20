#!/usr/bin/env bash
# PostToolCall hook: Block hard delete in entities with soft delete column
# Detects db.delete() usage and suggests db.update({ deletedAt: new Date() }).

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

# Check for hard delete patterns
if grep -qE 'db\.delete\(|await db\.delete\(' "$FILE_PATH" 2>/dev/null; then
  # Check if there's a deletedAt column in schema files
  HAS_SOFT_DELETE=false
  for schema_file in $(find . -name '*.schema.ts' -o -name '*.schema.tsx' 2>/dev/null); do
    if grep -q 'deletedAt' "$schema_file" 2>/dev/null; then
      HAS_SOFT_DELETE=true
      break
    fi
  done
  
  if $HAS_SOFT_DELETE; then
    cat >&2 <<MSG
BLOCKED: Hard delete (db.delete()) detected in project with soft delete.

Arquivo: $FILE_PATH
Encontrado: db.delete()

Este projeto usa soft delete (coluna deletedAt). Use:
  db.update({ deletedAt: new Date() })
  // ou
  db.updateWhere({ /* conditions */ }, { deletedAt: new Date() })

Hard delete viola a auditoria e a conformidade LGPD.

Veja: language-related/typescript/skills/soft-delete/
MSG
    exit 2
  fi
fi

exit 0
