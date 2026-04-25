# tarball.sh — download de tarball + verificacao SHA-256 + extract.
#
# Funcao exportada:
#   download_and_verify <tarball_url> <sha256_url> <dest_dir>
#
# Sequencia:
#   1. Baixa tarball_url para tempdir privado
#   2. Baixa sha256_url (arquivo ".sha256") para mesmo tempdir
#   3. Compara checksum esperado (do .sha256) com checksum calculado localmente
#   4. Se match, extrai tarball em dest_dir
#   5. Cleanup do tempdir
#
# Em caso de mismatch ou falha em qualquer passo: aborta com exit 1 e NAO
# toca dest_dir. Comportamento alinhado com FR-010a da spec cstk-cli
# ("Mismatch aborta a operacao sem realizar qualquer escrita no filesystem
# de destino").
#
# Deps: tar, mktemp, rm, mkdir, awk, head, printf; http.sh, compat.sh.
#
# POSIX sh puro.

if [ -n "${_CSTK_TARBALL_LOADED:-}" ]; then
  return 0 2>/dev/null
fi
_CSTK_TARBALL_LOADED=1

# shellcheck source=/dev/null
. "${CSTK_LIB:?CSTK_LIB must be set}/http.sh"
# shellcheck source=/dev/null
. "${CSTK_LIB}/compat.sh"

download_and_verify() {
  if [ "$#" -ne 3 ]; then
    printf 'tarball: download_and_verify espera 3 argumentos (tarball_url, sha256_url, dest_dir)\n' >&2
    return 2
  fi
  _turl=$1
  _surl=$2
  _dest=$3

  _tmp=$(mktemp -d 2>/dev/null) || {
    printf 'tarball: mktemp -d falhou\n' >&2
    return 1
  }
  _tar_file="$_tmp/archive.tar.gz"
  _sha_file="$_tmp/archive.tar.gz.sha256"

  if ! http_download "$_turl" "$_tar_file"; then
    rm -rf -- "$_tmp"
    return 1
  fi
  if ! http_download "$_surl" "$_sha_file"; then
    rm -rf -- "$_tmp"
    return 1
  fi

  # Formato esperado do .sha256: "<hex>  <filename>" (uma ou mais linhas).
  # Pega o primeiro hash encontrado.
  _expected=$(awk 'NF>=1 {print $1; exit}' "$_sha_file")
  if [ -z "$_expected" ]; then
    printf 'tarball: arquivo .sha256 vazio ou malformado: %s\n' "$_surl" >&2
    rm -rf -- "$_tmp"
    return 1
  fi

  _actual=$(sha256_file "$_tar_file") || {
    rm -rf -- "$_tmp"
    return 1
  }

  if [ "$_expected" != "$_actual" ]; then
    printf 'tarball: checksum MISMATCH para %s\n' "$_turl" >&2
    printf '  esperado: %s\n' "$_expected" >&2
    printf '  obtido:   %s\n' "$_actual" >&2
    rm -rf -- "$_tmp"
    return 1
  fi

  if ! mkdir -p -- "$_dest" 2>/dev/null; then
    printf 'tarball: nao foi possivel criar dest_dir: %s\n' "$_dest" >&2
    rm -rf -- "$_tmp"
    return 1
  fi

  if ! tar -xzf "$_tar_file" -C "$_dest" 2>/dev/null; then
    printf 'tarball: falha ao extrair em %s\n' "$_dest" >&2
    rm -rf -- "$_tmp"
    return 1
  fi

  rm -rf -- "$_tmp"
  return 0
}
