#!/usr/bin/env bash
# PreToolCall hook: Block direct git commit on main/master
# Only allows commits on feature branches (feat/*, fix/*, chore/*, etc).
# Main/master commits must go through PR merge.

set -euo pipefail

INPUT="${CLAUDE_TOOL_INPUT:-}"
[ -z "$INPUT" ] && exit 0

COMMAND=$(echo "$INPUT" | jq -r '.command // empty' 2>/dev/null)
[ -z "$COMMAND" ] && exit 0

# Check if command is git commit
if echo "$COMMAND" | grep -qE 'git\s+commit' 2>/dev/null; then
  cd "$CLAUDE_PROJECT_DIR" 2>/dev/null || exit 0
  
  # Get current branch
  CURRENT_BRANCH=$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo "")
  
  # Block if on main or master
  if [ "$CURRENT_BRANCH" = "main" ] || [ "$CURRENT_BRANCH" = "master" ]; then
    cat >&2 <<MSG
BLOCKED: Direct commit on protected branch.

Branch atual: $CURRENT_BRANCH
Comando: $COMMAND

Commits diretos em main/master sao bloqueados.
Fluxo correto:
  1. Crie feature branch: git checkout -b feat/minha-feature
  2. Faca commit das alteracoes
  3. Push: git push -u origin feat/minha-feature
  4. Abra Pull Request
  5. Apos review, faca merge via PR

Branches permitidos: feat/*, fix/*, chore/*, refactor/*, docs/*, test/*, ci/*, build/*

Veja: docs/guides/releases/README.md
MSG
    exit 2
  fi
fi

exit 0
