#!/usr/bin/env bash
set -euo pipefail

INPUT="${CLAUDE_TOOL_INPUT:-}"
[ -z "$INPUT" ] && exit 0

FILE_PATH=$(echo "$INPUT" | jq -r '.file_path // empty')
[ -z "$FILE_PATH" ] && exit 0

case "$FILE_PATH" in
  *.py) ;;
  *) exit 0 ;;
esac

# Encontrar pyproject.toml ancestor
PROJECT_DIR=$(dirname "$FILE_PATH")
while [ "$PROJECT_DIR" != "/" ] && [ ! -f "$PROJECT_DIR/pyproject.toml" ]; do
  PROJECT_DIR=$(dirname "$PROJECT_DIR")
done

[ -f "$PROJECT_DIR/pyproject.toml" ] || exit 0

cd "$PROJECT_DIR"

if command -v uv >/dev/null 2>&1; then
  RUNNER="uv run"
else
  RUNNER=""
fi

OUTPUT=$($RUNNER ruff check "$FILE_PATH" 2>&1) || {
  cat >&2 <<MSG
Linting failed in $FILE_PATH

$OUTPUT

Hint: Run manually with:
  uv run ruff check --fix $FILE_PATH

Documentation: language-related/python/skills/py-review-pr/
MSG
  exit 2
}

exit 0
