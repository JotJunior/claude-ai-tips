# hash.sh — hash determinista de diretorio via manifest canonico ordenado.
#
# Funcao exportada:
#   hash_dir <dir>   — imprime SHA-256 de um manifest ordenado do conteudo
#
# Estrategia (portavel mac + linux):
#   1. Lista TODOS os arquivos regulares sob <dir> via find -type f
#   2. Ordena os paths relativos via sort -- garante ordem deterministica
#   3. Para cada arquivo, imprime linha "<sha256>  <relpath>"
#   4. Hash SHA-256 dessa saida textual
#
# Rejeicao de alternativas:
#   - `tar --sort=name --owner=0 ...` e GNU-only; BSD tar do macOS nao suporta.
#     Esta abordagem manifest-canonico e equivalente semanticamente e funciona
#     em qualquer sistema com find + sort + sha256*.
#   - `mtime`/`inode` nao fazem parte do hash — mudanca de permissoes ou
#     timestamps nao afeta; so conteudo + path relativo importam. E o desejado
#     para detectar edicoes de CONTEUDO.
#
# Deps: find, sort, printf; compat.sh (sha256_file, sha256_stdin).
#
# POSIX sh puro.

if [ -n "${_CSTK_HASH_LOADED:-}" ]; then
  return 0 2>/dev/null
fi
_CSTK_HASH_LOADED=1

# shellcheck source=/dev/null
. "${CSTK_LIB:?CSTK_LIB must be set}/compat.sh"

hash_dir() {
  # POSIX sh NAO tem local vars — prefixo _hash_ para evitar colisao.
  if [ "$#" -ne 1 ]; then
    printf 'hash: hash_dir espera 1 argumento (diretorio)\n' >&2
    return 2
  fi
  if [ ! -d "$1" ]; then
    printf 'hash: diretorio nao existe: %s\n' "$1" >&2
    return 1
  fi
  _hash_target=$1
  # Gera manifest canonico e hasheia. Variaveis dentro do subshell (cd + find)
  # sao isoladas — nao precisam de prefixo.
  (
    cd -- "$_hash_target" || return 1
    find . -type f -print | sort | while IFS= read -r _f; do
      _h=$(sha256_file "$_f") || exit 1
      printf '%s  %s\n' "$_h" "$_f"
    done
  ) | sha256_stdin
}
