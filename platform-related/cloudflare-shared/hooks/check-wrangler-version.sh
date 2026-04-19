#!/bin/sh
# check-wrangler-version.sh — PreToolCall hook para comandos wrangler.
#
# Detecta se o comando Bash contem `wrangler` e compara versao instalada
# com latest no npm. Emite aviso no stderr quando desatualizado — nunca
# bloqueia (exit 0 sempre).
#
# Cache: 24h em /tmp/.claude-wrangler-version-check para evitar hit
# repetido no npm registry.
#
# Escopo:
#   - devDep local (package.json): sugere `bun add -d wrangler@latest` (ou npm/pnpm)
#   - global (npm i -g): sugere `npm i -g wrangler@latest`
#   - npx/bunx (cache): nao sugere (npx pega latest por default)
#
# Variaveis esperadas:
#   CLAUDE_TOOL_INPUT — JSON com parametros do tool call (Bash)

set -eu

CLAUDE_TOOL_INPUT="${CLAUDE_TOOL_INPUT:-}"
[ -z "$CLAUDE_TOOL_INPUT" ] && exit 0

if ! command -v jq >/dev/null 2>&1; then
  exit 0
fi

CMD=$(printf '%s' "$CLAUDE_TOOL_INPUT" | jq -r '.command // empty' 2>/dev/null)
[ -z "$CMD" ] && exit 0

# Detecta wrangler no comando. Padrao: palavra "wrangler" precedida por
# espaco/inicio e seguida por espaco/argumento.
case "$CMD" in
  *wrangler*) ;;
  *) exit 0 ;;
esac

# Filtra falsos positivos — mencao do nome sem invocacao
echo "$CMD" | grep -qE '(^|[^a-zA-Z0-9_-])(wrangler|npx +wrangler|bunx +wrangler|pnpm +(run +|dlx +)?wrangler|bun +(run +|x +)?wrangler)' || exit 0

CACHE="/tmp/.claude-wrangler-version-check"
CACHE_TTL=86400

# Cache hit (< 24h)
if [ -f "$CACHE" ]; then
  AGE=$(( $(date +%s) - $(stat -f %m "$CACHE" 2>/dev/null || stat -c %Y "$CACHE" 2>/dev/null || echo 0) ))
  if [ "$AGE" -lt "$CACHE_TTL" ]; then
    CACHED=$(cat "$CACHE" 2>/dev/null || echo "")
    case "$CACHED" in
      OK*) exit 0 ;;
      OUTDATED*)
        printf '[wrangler-version] %s\n' "$CACHED" >&2
        exit 0
        ;;
    esac
  fi
fi

LATEST=$(curl -s --max-time 3 'https://registry.npmjs.org/wrangler/latest' 2>/dev/null \
  | jq -r '.version // empty' 2>/dev/null || echo "")

[ -z "$LATEST" ] && exit 0

INSTALLED=""
PROJECT_DIR="${CLAUDE_PROJECT_DIR:-$(pwd)}"

# 1. Tenta devDep local no projeto
if [ -f "$PROJECT_DIR/package.json" ]; then
  INSTALLED=$(jq -r '.devDependencies.wrangler // .dependencies.wrangler // empty' "$PROJECT_DIR/package.json" 2>/dev/null | sed 's/^[\^~>=<]*//')
fi

# 2. Fallback: wrangler --version global
if [ -z "$INSTALLED" ]; then
  INSTALLED=$(wrangler --version 2>/dev/null | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -1 || echo "")
fi

if [ -z "$INSTALLED" ]; then
  echo "OK (wrangler nao instalado localmente — npx usa latest)" > "$CACHE"
  exit 0
fi

if [ "$INSTALLED" = "$LATEST" ]; then
  echo "OK (wrangler $INSTALLED — atualizado)" > "$CACHE"
  exit 0
fi

# Detecta package manager
PM="npm"
if [ -f "$PROJECT_DIR/bun.lock" ] || [ -f "$PROJECT_DIR/bun.lockb" ]; then
  PM="bun"
elif [ -f "$PROJECT_DIR/pnpm-lock.yaml" ]; then
  PM="pnpm"
elif [ -f "$PROJECT_DIR/yarn.lock" ]; then
  PM="yarn"
fi

case "$PM" in
  bun)  UPDATE_CMD="bun add -d wrangler@latest" ;;
  pnpm) UPDATE_CMD="pnpm add -D wrangler@latest" ;;
  yarn) UPDATE_CMD="yarn add -D wrangler@latest" ;;
  *)    UPDATE_CMD="npm install -D wrangler@latest" ;;
esac

MSG="wrangler desatualizado: local=$INSTALLED latest=$LATEST — para atualizar: $UPDATE_CMD"
echo "OUTDATED $MSG" > "$CACHE"
printf '[wrangler-version] %s\n' "$MSG" >&2

exit 0
