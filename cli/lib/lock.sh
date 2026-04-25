# lock.sh — lockfile via mkdir atomico, com trap de cleanup.
#
# Funcoes exportadas:
#   acquire_lock <path-lockdir>   — cria dir lock; se ja existe, exit 3
#   release_lock                  — remove dir lock (idempotente)
#
# Semantica:
#   - `mkdir` e atomico em POSIX: se o diretorio ja existe, falha com exit != 0.
#     Nao precisa de flock (nao-POSIX) nem de PID files (inseguros).
#   - Apos acquire_lock bem-sucedido, um trap em EXIT/INT/TERM chama
#     release_lock — garante limpeza em crash normal.
#   - Kill -9 deixa o lock stale; acquire_lock subsequente instruira o
#     usuario a remover manualmente.
#
# Global:
#   _CSTK_LOCK_DIR   — path do lock atualmente detido (vazio se nenhum)
#
# POSIX sh puro. Deps: mkdir, rmdir, trap, printf.

if [ -n "${_CSTK_LOCK_LOADED:-}" ]; then
  return 0 2>/dev/null
fi
_CSTK_LOCK_LOADED=1

_CSTK_LOCK_DIR=""

acquire_lock() {
  # POSIX sh NAO tem local vars — prefixo _lock_ para evitar colisao.
  if [ "$#" -ne 1 ]; then
    printf 'lock: acquire_lock espera 1 argumento (lockdir)\n' >&2
    return 2
  fi
  _lock_target=$1
  _lock_parent=$(dirname -- "$_lock_target")
  if [ ! -d "$_lock_parent" ]; then
    printf 'lock: diretorio pai nao existe: %s\n' "$_lock_parent" >&2
    return 1
  fi
  if mkdir -- "$_lock_target" 2>/dev/null; then
    _CSTK_LOCK_DIR=$_lock_target
    # shellcheck disable=SC2064  # trap com expansao imediata intencional
    trap "release_lock" EXIT INT TERM
    return 0
  fi
  printf 'cstk: lock ja detido por outro processo: %s\n' "$_lock_target" >&2
  printf 'Se tem certeza de que nao ha outro cstk rodando, remova: rmdir %s\n' "$_lock_target" >&2
  return 3
}

release_lock() {
  if [ -n "$_CSTK_LOCK_DIR" ] && [ -d "$_CSTK_LOCK_DIR" ]; then
    rmdir -- "$_CSTK_LOCK_DIR" 2>/dev/null || :
  fi
  _CSTK_LOCK_DIR=""
}
