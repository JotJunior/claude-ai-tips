# common.sh — logging + deteccao de ambiente, compartilhado por todo o CLI.
#
# Funcoes exportadas:
#   log_info <msg>     — imprime "[info] msg" em stderr
#   log_warn <msg>     — imprime "[warn] msg" em stderr
#   log_error <msg>    — imprime "[error] msg" em stderr
#   is_tty             — retorna 0 se stdout e TTY, 1 caso contrario
#   color_enabled      — retorna 0 se output deve ter cor (respeita NO_COLOR)
#
# Sem side-effects no boot. Sourced por cli/cstk e pelas outras libs.
#
# POSIX sh puro. Sem bash-isms. Sem deps alem de: printf, test.

if [ -n "${_CSTK_COMMON_LOADED:-}" ]; then
  return 0 2>/dev/null
fi
_CSTK_COMMON_LOADED=1

log_info() {
  printf '[info] %s\n' "$*" >&2
}

log_warn() {
  printf '[warn] %s\n' "$*" >&2
}

log_error() {
  printf '[error] %s\n' "$*" >&2
}

is_tty() {
  [ -t 1 ]
}

# color_enabled: cor aceita se (a) stdout e TTY, (b) TERM nao e "dumb",
# (c) NO_COLOR nao esta setado. Honra https://no-color.org/.
color_enabled() {
  if [ -n "${NO_COLOR:-}" ]; then
    return 1
  fi
  if [ "${TERM:-dumb}" = "dumb" ]; then
    return 1
  fi
  is_tty
}
