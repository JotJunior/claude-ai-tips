#!/bin/sh
# install-hooks.sh — configures git to use .githooks/ and ensures +x permissions.
# Run via npm postinstall or manually.

set -eu

HOOKS_DIR=".githooks"

if [ ! -d "$HOOKS_DIR" ]; then
    echo "AVISO: $HOOKS_DIR/ nao encontrado — hooks nao configurados."
    exit 0
fi

if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    echo "AVISO: nao eh um repositorio git — hooks nao configurados."
    exit 0
fi

CURRENT=$(git config core.hooksPath 2>/dev/null || echo "")

if [ "$CURRENT" != "$HOOKS_DIR" ]; then
    git config core.hooksPath "$HOOKS_DIR"
    echo "configurado: core.hooksPath = $HOOKS_DIR"
else
    echo "ok: core.hooksPath ja configurado ($HOOKS_DIR)"
fi

for hook in "$HOOKS_DIR"/*; do
    if [ -f "$hook" ] && [ ! -x "$hook" ]; then
        chmod +x "$hook"
        echo "chmod +x: $hook"
    fi
done

exit 0
