# http.sh — wrappers curl com error mapping, usados para fetch de GitHub Releases.
#
# Funcoes exportadas:
#   http_download <url> <dest>   — baixa URL para arquivo local
#   http_check_url <url>         — HEAD para verificar disponibilidade (0/1)
#
# Convencoes de curl:
#   -f   fail em 4xx/5xx (sem gerar output "normal")
#   -s   silent (sem progress bar)
#   -S   mostra mensagem em caso de erro
#   -L   segue redirects (GitHub Releases redireciona para CDN)
#
# Timeouts conservadores:
#   --connect-timeout 10   nao esperar mais de 10s para conectar
#   --max-time 300         tarball de release nao deve demorar mais de 5min
#
# Error mapping (curl exit -> usuario):
#   6  nao consegui resolver host (DNS down / offline)
#   7  nao consegui conectar (firewall / host offline)
#   22 servidor retornou 4xx/5xx
#   28 timeout
#   resto: generic
#
# Retornos:
#   0  sucesso
#   1  erro de rede, HTTP, curl ausente ou arg problema
#   2  uso incorreto (argumentos faltando)
#
# POSIX sh puro. Deps: curl, printf, command.

if [ -n "${_CSTK_HTTP_LOADED:-}" ]; then
  return 0 2>/dev/null
fi
_CSTK_HTTP_LOADED=1

http_download() {
  # POSIX sh NAO tem local vars — usamos prefixo _http_ para evitar colisao
  # com variaveis do caller (ex: _dest em tarball.sh).
  if [ "$#" -ne 2 ]; then
    printf 'http: http_download espera 2 argumentos (url, dest)\n' >&2
    return 2
  fi
  _http_url=$1
  _http_dest=$2
  if ! command -v curl >/dev/null 2>&1; then
    printf 'http: curl nao encontrado no PATH\n' >&2
    return 1
  fi
  _http_ec=0
  curl -fsSL --connect-timeout 10 --max-time 300 -o "$_http_dest" -- "$_http_url" 2>/dev/null || _http_ec=$?
  if [ "$_http_ec" -eq 0 ]; then
    return 0
  fi
  case "$_http_ec" in
    6)  printf 'http: nao foi possivel resolver host de %s (offline?)\n' "$_http_url" >&2 ;;
    7)  printf 'http: falha ao conectar em %s\n' "$_http_url" >&2 ;;
    22) printf 'http: servidor retornou erro HTTP para %s\n' "$_http_url" >&2 ;;
    28) printf 'http: timeout ao baixar %s\n' "$_http_url" >&2 ;;
    *)  printf 'http: download falhou (curl exit %d): %s\n' "$_http_ec" "$_http_url" >&2 ;;
  esac
  [ -f "$_http_dest" ] && rm -f -- "$_http_dest"
  return 1
}

http_check_url() {
  if [ "$#" -ne 1 ]; then
    printf 'http: http_check_url espera 1 argumento (url)\n' >&2
    return 2
  fi
  if ! command -v curl >/dev/null 2>&1; then
    printf 'http: curl nao encontrado no PATH\n' >&2
    return 1
  fi
  curl -fsSLI --connect-timeout 10 --max-time 30 -o /dev/null -- "$1" 2>/dev/null
}
