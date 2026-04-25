# manifest.sh — leitura/escrita do manifest TSV de skills instaladas.
#
# Formato (data-model.md §Manifest, schema v1):
#   linha 1:  # cstk manifest v1
#   linha 2:  # schema: <skill-name>\t<toolkit-version>\t<source-sha256>\t<installed-at-iso>
#   linha 3+: <skill>\t<version>\t<sha256>\t<iso-ts>   (uma por skill instalada)
#
# Localizacao por escopo:
#   global  = ~/.claude/skills/.cstk-manifest
#   project = ./.claude/skills/.cstk-manifest  (relativo ao CWD)
#
# Funcoes exportadas:
#   manifest_default_path <scope>      — caminho default para "global" ou "project"
#   detect_schema_version <path>       — imprime "v1" ou aborta com erro
#   read_manifest <path>               — emite linhas data (sem comentarios)
#   write_manifest <path>              — le TSV em stdin, escreve atomicamente
#   upsert_entry <path> <skill> <version> <sha> <ts>
#                                       — adiciona ou substitui entrada (idempotente)
#   remove_entry <path> <skill>        — remove entrada se existir (idempotente)
#   lookup_entry <path> <skill>        — imprime linha da skill ou nada (exit 0
#                                         se encontrada, exit 1 se nao)
#
# Garantias:
#   - write_manifest e atomico: escreve em mktemp adjacente, depois mv -f.
#     Leitor concorrente ve manifest antigo OU novo, nunca parcial.
#   - upsert e remove preservam ordem das demais linhas.
#   - read_manifest pula manifest inexistente (saida vazia, exit 0) — caller
#     pode tratar como "nada instalado".
#
# POSIX sh puro. Deps: awk, mktemp, mv, rm, dirname, printf.

if [ -n "${_CSTK_MANIFEST_LOADED:-}" ]; then
  return 0 2>/dev/null
fi
_CSTK_MANIFEST_LOADED=1

_CSTK_MANIFEST_HEADER_V1='# cstk manifest v1'
_CSTK_MANIFEST_SCHEMA_V1='# schema: <skill-name>\t<toolkit-version>\t<source-sha256>\t<installed-at-iso>'

manifest_default_path() {
  if [ "$#" -ne 1 ]; then
    printf 'manifest: manifest_default_path espera 1 argumento (scope)\n' >&2
    return 2
  fi
  case "$1" in
    global)  printf '%s/.claude/skills/.cstk-manifest\n' "${HOME:?HOME nao setado}" ;;
    project) printf '%s\n' "./.claude/skills/.cstk-manifest" ;;
    *)
      printf 'manifest: scope invalido: %s (esperado global|project)\n' "$1" >&2
      return 2
      ;;
  esac
}

# detect_schema_version: aborta com exit 1 se header malformado.
# Manifest inexistente = "v1" (default — sera criado com header v1 ao escrever).
detect_schema_version() {
  if [ "$#" -ne 1 ]; then
    printf 'manifest: detect_schema_version espera 1 argumento (path)\n' >&2
    return 2
  fi
  _manifest_path=$1
  if [ ! -f "$_manifest_path" ]; then
    printf 'v1\n'
    return 0
  fi
  # Le linha 1; se for header v1, OK. Caso contrario, abort.
  _manifest_first=$(head -n 1 -- "$_manifest_path" 2>/dev/null) || _manifest_first=""
  case "$_manifest_first" in
    "$_CSTK_MANIFEST_HEADER_V1")
      printf 'v1\n'
      return 0
      ;;
    "")
      printf 'manifest: arquivo vazio em %s\n' "$_manifest_path" >&2
      return 1
      ;;
    *)
      printf 'manifest: header desconhecido em %s\n' "$_manifest_path" >&2
      printf '  esperado: %s\n' "$_CSTK_MANIFEST_HEADER_V1" >&2
      printf '  obtido:   %s\n' "$_manifest_first" >&2
      printf 'cstk talvez precise de self-update para schema mais novo\n' >&2
      return 1
      ;;
  esac
}

# read_manifest: imprime linhas de dados (skill\tversion\tsha\tts), uma por linha.
# Manifest inexistente -> saida vazia, exit 0.
read_manifest() {
  if [ "$#" -ne 1 ]; then
    printf 'manifest: read_manifest espera 1 argumento (path)\n' >&2
    return 2
  fi
  _manifest_path=$1
  if [ ! -f "$_manifest_path" ]; then
    return 0
  fi
  # Valida schema antes de ler
  detect_schema_version "$_manifest_path" >/dev/null || return 1
  # Ignora linhas vazias e comentarios (#); imprime so dados
  awk '/^[[:space:]]*$/ {next} /^#/ {next} {print}' "$_manifest_path"
}

# write_manifest: le TSV em stdin (skill\tversion\tsha\tts), escreve em path
# atomicamente. Sobrescreve se existir.
write_manifest() {
  if [ "$#" -ne 1 ]; then
    printf 'manifest: write_manifest espera 1 argumento (path)\n' >&2
    return 2
  fi
  _manifest_path=$1
  _manifest_dir=$(dirname -- "$_manifest_path")
  if [ ! -d "$_manifest_dir" ]; then
    printf 'manifest: diretorio pai nao existe: %s\n' "$_manifest_dir" >&2
    return 1
  fi
  _manifest_tmp=$(mktemp -- "$_manifest_dir/.cstk-manifest.XXXXXX") || {
    printf 'manifest: mktemp em %s falhou\n' "$_manifest_dir" >&2
    return 1
  }
  # Header + schema + dados de stdin
  {
    printf '%s\n' "$_CSTK_MANIFEST_HEADER_V1"
    printf '%s\n' "$_CSTK_MANIFEST_SCHEMA_V1"
    cat
  } > "$_manifest_tmp" || {
    rm -f -- "$_manifest_tmp"
    return 1
  }
  if ! mv -f -- "$_manifest_tmp" "$_manifest_path"; then
    rm -f -- "$_manifest_tmp"
    printf 'manifest: mv atomico falhou para %s\n' "$_manifest_path" >&2
    return 1
  fi
  return 0
}

# upsert_entry: adiciona ou substitui entrada. Idempotente.
upsert_entry() {
  if [ "$#" -ne 5 ]; then
    printf 'manifest: upsert_entry espera 5 argumentos (path, skill, version, sha, ts)\n' >&2
    return 2
  fi
  _manifest_path=$1
  _manifest_skill=$2
  _manifest_version=$3
  _manifest_sha=$4
  _manifest_ts=$5
  if [ -z "$_manifest_skill" ]; then
    printf 'manifest: nome de skill vazio\n' >&2
    return 2
  fi
  # Le entradas atuais excluindo a skill alvo, depois acrescenta nova.
  _manifest_existing=$(read_manifest "$_manifest_path") || return 1
  {
    if [ -n "$_manifest_existing" ]; then
      printf '%s\n' "$_manifest_existing" | awk -F'\t' -v skill="$_manifest_skill" '$1 != skill'
    fi
    printf '%s\t%s\t%s\t%s\n' "$_manifest_skill" "$_manifest_version" "$_manifest_sha" "$_manifest_ts"
  } | write_manifest "$_manifest_path"
}

# remove_entry: remove skill se existir. Idempotente (skill ausente = no-op).
remove_entry() {
  if [ "$#" -ne 2 ]; then
    printf 'manifest: remove_entry espera 2 argumentos (path, skill)\n' >&2
    return 2
  fi
  _manifest_path=$1
  _manifest_skill=$2
  if [ -z "$_manifest_skill" ]; then
    printf 'manifest: nome de skill vazio\n' >&2
    return 2
  fi
  if [ ! -f "$_manifest_path" ]; then
    return 0
  fi
  _manifest_existing=$(read_manifest "$_manifest_path") || return 1
  if [ -z "$_manifest_existing" ]; then
    return 0
  fi
  printf '%s\n' "$_manifest_existing" \
    | awk -F'\t' -v skill="$_manifest_skill" '$1 != skill' \
    | write_manifest "$_manifest_path"
}

# lookup_entry: imprime linha da skill (TSV completa). Exit 0 se encontrada,
# exit 1 se nao (sem mensagem em stderr — uso programatico).
lookup_entry() {
  if [ "$#" -ne 2 ]; then
    printf 'manifest: lookup_entry espera 2 argumentos (path, skill)\n' >&2
    return 2
  fi
  _manifest_path=$1
  _manifest_skill=$2
  if [ -z "$_manifest_skill" ]; then
    return 1
  fi
  _manifest_existing=$(read_manifest "$_manifest_path") || return 1
  if [ -z "$_manifest_existing" ]; then
    return 1
  fi
  _manifest_match=$(printf '%s\n' "$_manifest_existing" \
    | awk -F'\t' -v skill="$_manifest_skill" '$1 == skill {print; exit}')
  if [ -z "$_manifest_match" ]; then
    return 1
  fi
  printf '%s\n' "$_manifest_match"
  return 0
}
