#!/usr/bin/env bash
# PostToolCall hook: TypeScript Type Check Gate
# After Write/Edit to a .ts/.tsx file, runs `tsc --noEmit` to catch type errors.
# Blocks if type checking fails.

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

# Find tsconfig.json
TSCONFIG=$(find . -maxdepth 3 -name 'tsconfig.json' -type f 2>/dev/null | head -1)
[ -z "$TSCONFIG" ] && exit 0

TSCONFIG_DIR=$(dirname "$TSCONFIG")

# Run tsc --noEmit
TSC_OUTPUT=$(cd "$TSCONFIG_DIR" && pnpm tsc --noEmit 2>&1) || {
  echo "TYPE CHECK FAILED in $FILE_PATH:" >&2
  echo "$TSC_OUTPUT" >&2
  echo "" >&2
  echo "Fix the type errors before continuing." >&2
  exit 2
}

exit 0
