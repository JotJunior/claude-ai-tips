#!/usr/bin/env bash
# PostToolCall hook: Block unsafe Date.toISOString() usage
# Detects new Date().toISOString() without timezone-aware wrapper.
# Suggests using date-fns-tz or an internal helper.

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

# Check for unsafe toISOString patterns
if grep -qE 'new Date\(\)\.toISOString\(\)' "$FILE_PATH" 2>/dev/null; then
  cat >&2 <<'MSG'
BLOCKED: Unsafe Date.toISOString() usage detected.

Arquivo: FILE_PATH
Encontrado: new Date().toISOString()

Problema: toISOString() retorna UTC, ignora timezone do usuario/contexto.
Pode causar bugs sutis em aplicacoes com usuarios em fusos diferentes.

Sugestao: Use date-fns-tz ou helper interno:
  - date-fns-tz: formatInTimeZone(date, 'America/Sao_Paulo', "yyyy-MM-dd'T'HH:mm:ss.SSSxxx")
  - Helper interno: formatDateTZ(date, 'America/Sao_Paulo')

Veja: language-related/typescript/skills/date-handling/
MSG
  # Replace placeholder with actual file path
  sed -i '' "s|FILE_PATH|$FILE_PATH|g" >&2 <<<""
  exit 2
fi

exit 0
