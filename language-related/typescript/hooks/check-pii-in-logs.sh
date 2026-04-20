#!/usr/bin/env bash
# PostToolCall hook: Block PII in log statements
# Detects console.log/logger.info with variables named email, cpf, password, etc.
# Suggests using redact() helper.

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

# Get content
CONTENT=$(echo "$INPUT" | jq -r '.content // empty' 2>/dev/null)
[ -z "$CONTENT" ] && CONTENT=$(echo "$INPUT" | jq -r '.new_string // empty' 2>/dev/null)
[ -z "$CONTENT" ] && exit 0

# PII field patterns (case insensitive)
PII_PATTERNS='(email|cpf|phone|ssn|token|password|secret|creditCard|nickname)'

# Check for log statements with PII variables
# Pattern: console.log or logger.* containing a variable with PII name
VIOLATIONS=$(echo "$CONTENT" | grep -nE '(console\.log|logger\.(info|debug|warn|error))' 2>/dev/null | grep -E "$PII_PATTERNS" || true)

if [ -n "$VIOLATIONS" ]; then
  cat >&2 <<MSG
BLOCKED: Possible PII in log statements detected.

Arquivo: $FILE_PATH
Encontrado linhas com log contendo campos sensiveis.

Campos bloqueados: email, cpf, phone, ssn, token, password, secret, creditCard, nickname

Sugestao: Use funcao redact() do projeto:
  import { redact } from '@/utils/redact'
  
  logger.info({ userId: id, email: redact(user.email) })

Dados sensiveis NAO devem aparecer nos logs (LGPD).

Veja: language-related/typescript/skills/logging/
MSG
  exit 2
fi

exit 0
