#!/usr/bin/env bash
# PostToolCall hook: ESLint Gate
# After Write/Edit to a .ts/.tsx file, runs ESLint to catch lint errors.
# Blocks if ESLint reports errors.

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

# Run eslint on the specific file
ESLINT_OUTPUT=$(pnpm eslint "$FILE_PATH" 2>&1) || {
  echo "ESLINT ERRORS in $FILE_PATH:" >&2
  echo "$ESLINT_OUTPUT" >&2
  echo "" >&2
  echo "Fix the lint errors before continuing." >&2
  exit 2
}

exit 0
