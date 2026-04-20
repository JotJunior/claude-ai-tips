#!/usr/bin/env bash
# PreToolCall hook: Block direct wrangler deploy on main branch
# Detects 'wrangler deploy' command and blocks if run on main/master.
# Deploys should go through CI/release-please.

set -euo pipefail

INPUT="${CLAUDE_TOOL_INPUT:-}"
[ -z "$INPUT" ] && exit 0

COMMAND=$(echo "$INPUT" | jq -r '.command // empty' 2>/dev/null)
[ -z "$COMMAND" ] && exit 0

# Check if command contains wrangler deploy
if echo "$COMMAND" | grep -qE 'wrangler\s+(pages\s+)?deploy' 2>/dev/null; then
  cd "$CLAUDE_PROJECT_DIR" 2>/dev/null || exit 0
  
  # Get current branch
  CURRENT_BRANCH=$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo "")
  
  # Check if on main or master
  if [ "$CURRENT_BRANCH" = "main" ] || [ "$CURRENT_BRANCH" = "master" ]; then
    cat >&2 <<MSG
BLOCKED: Direct wrangler deploy on protected branch.

Branch atual: $CURRENT_BRANCH
Comando: $COMMAND

Deploys diretos em main/master sao bloqueados.
Use CI/CD pipeline ou release-please para deploys.

Fluxo correto:
  1. Crie feature branch: git checkout -b feat/minha-feature
  2. Faca suas alteracoes
  3. Abra PR e faca merge na main
  4. CI/CD faca o deploy automaticamente

Ou use release-please para management de versoes.

Veja: docs/guides/releases/README.md
MSG
    exit 2
  fi
fi

exit 0
