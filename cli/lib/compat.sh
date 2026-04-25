# compat.sh — wrappers portaveis para ferramentas que variam entre mac e linux.
#
# Funcoes exportadas:
#   sha256_file <path>    — imprime SHA-256 do arquivo (40 chars hex + newline)
#   sha256_stdin          — imprime SHA-256 de stdin
#   iso_now_utc           — imprime timestamp atual em ISO8601 UTC
#
# Deteccao: sha256sum (Linux / coreutils) > shasum -a 256 (macOS default).
# Retorna 1 com mensagem clara se nenhum dos dois estiver disponivel.
#
# POSIX sh puro. Deps: printf, awk, date, command.

if [ -n "${_CSTK_COMPAT_LOADED:-}" ]; then
  return 0 2>/dev/null
fi
_CSTK_COMPAT_LOADED=1

sha256_file() {
  # POSIX sh NAO tem local vars — usamos prefixo _compat_ para evitar
  # colisao com variaveis do caller.
  if [ "$#" -ne 1 ]; then
    printf 'compat: sha256_file espera 1 argumento (path)\n' >&2
    return 2
  fi
  _compat_file=$1
  if [ ! -f "$_compat_file" ]; then
    printf 'compat: arquivo nao existe: %s\n' "$_compat_file" >&2
    return 1
  fi
  if command -v sha256sum >/dev/null 2>&1; then
    sha256sum -- "$_compat_file" | awk '{print $1}'
  elif command -v shasum >/dev/null 2>&1; then
    shasum -a 256 -- "$_compat_file" | awk '{print $1}'
  else
    printf 'compat: nem sha256sum nem shasum encontrados no PATH\n' >&2
    return 1
  fi
}

sha256_stdin() {
  if command -v sha256sum >/dev/null 2>&1; then
    sha256sum | awk '{print $1}'
  elif command -v shasum >/dev/null 2>&1; then
    shasum -a 256 | awk '{print $1}'
  else
    printf 'compat: nem sha256sum nem shasum encontrados no PATH\n' >&2
    return 1
  fi
}

iso_now_utc() {
  date -u +%Y-%m-%dT%H:%M:%SZ
}
