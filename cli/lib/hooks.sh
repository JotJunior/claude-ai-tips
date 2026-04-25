# hooks.sh — deteccao de jq + merge de settings.json + fallback de paste manual.
#
# Ref: docs/specs/cstk-cli/spec.md §FR-009d
#      docs/constitution.md §Principio II (carve-out 1.1.0)
#      docs/specs/cstk-cli/quickstart.md Scenarios 4, 5
#
# **CONFINAMENTO DE jq (Constitution 1.1.0 §Optional dependencies)**:
# Este e o UNICO arquivo do toolkit autorizado a referenciar `jq`. A
# condicao (b) do carve-out exige confinamento em um unico arquivo; o
# resto do CLI MUST permanecer POSIX puro. Adicionar `jq` em qualquer
# outro `.sh` viola o carve-out e exige nova amendment de constituicao.
#
# Funcoes exportadas:
#   detect_jq                          — exit 0 se jq disponivel, 1 se nao
#   merge_settings <target> <source>   — merge JSON via jq (jq obrigatorio).
#                                         Source novas chaves entram, target
#                                         vence em conflitos. NUNCA executa
#                                         sem jq; NUNCA sobrescreve com `>`.
#   print_paste_block <target> <source>
#                                       — fallback sem jq: imprime bloco
#                                         JSON em stderr com instrucoes
#                                         para o usuario mesclar manualmente.
#
# Garantias defensivas:
#   - merge_settings aborta com exit 1 se jq nao detectado
#   - merge_settings preserva a copia original em <target>.bak antes de mv
#   - Escrita atomica via mktemp + mv
#   - test -f guards antes de qualquer leitura
#
# Deps: jq (opcional via carve-out), mktemp, mv, cp, cat, command, printf.

if [ -n "${_CSTK_HOOKS_LOADED:-}" ]; then
  return 0 2>/dev/null
fi
_CSTK_HOOKS_LOADED=1

# shellcheck source=/dev/null
. "${CSTK_LIB:?CSTK_LIB must be set}/common.sh"

# detect_jq: imprime nada; retorna 0 se jq esta no PATH, 1 se nao.
detect_jq() {
  command -v jq >/dev/null 2>&1
}

# merge_settings: faz merge recursivo de <source> dentro de <target>.
# Politica: target vence em conflitos (preserva chaves pre-existentes
# nao-conflitantes do usuario). Source contribui chaves novas.
#
# Comportamento:
#   - jq ausente: aborta com exit 1 (use print_paste_block como alternativa)
#   - target nao existe: copia source -> target (sem merge necessario)
#   - target existe: jq -s '.[0] * .[1]' <source> <target> > tmp; mv tmp target
#     (atomic; cria backup .bak antes de sobrescrever)
#   - Validacao JSON: jq aborta com erro nao-zero se source ou target invalido
merge_settings() {
  if [ "$#" -ne 2 ]; then
    log_error "hooks: merge_settings espera 2 argumentos (target, source)"
    return 2
  fi
  _hooks_target=$1
  _hooks_source=$2

  if ! detect_jq; then
    log_error "hooks: merge_settings exige jq (carve-out 1.1.0); use print_paste_block como fallback"
    return 1
  fi
  if [ ! -f "$_hooks_source" ]; then
    log_error "hooks: source JSON nao encontrado: $_hooks_source"
    return 1
  fi

  _hooks_target_dir=$(dirname -- "$_hooks_target")
  if [ ! -d "$_hooks_target_dir" ]; then
    if ! mkdir -p -- "$_hooks_target_dir"; then
      log_error "hooks: nao consegui criar dir pai de $_hooks_target"
      return 1
    fi
  fi

  # Caso 1: target nao existe -> apenas copia source
  if [ ! -f "$_hooks_target" ]; then
    if ! cp -- "$_hooks_source" "$_hooks_target"; then
      log_error "hooks: cp inicial falhou para $_hooks_target"
      return 1
    fi
    log_info "hooks: $_hooks_target criado a partir de $_hooks_source"
    return 0
  fi

  # Caso 2: target existe -> jq merge (target vence)
  # Backup defensivo. test -f guard ja garantiu existencia.
  if ! cp -- "$_hooks_target" "${_hooks_target}.bak"; then
    log_error "hooks: backup de $_hooks_target falhou — abortando sem merge"
    return 1
  fi

  _hooks_tmp=$(mktemp -- "${_hooks_target_dir}/.cstk-merge.XXXXXX") || {
    log_error "hooks: mktemp em $_hooks_target_dir falhou"
    return 1
  }

  # jq -s slurp: le ambos como array; .[0] * .[1] = merge recursivo, segundo vence.
  # Source primeiro, target segundo => target vence em conflitos.
  if ! jq -s '.[0] * .[1]' -- "$_hooks_source" "$_hooks_target" > "$_hooks_tmp" 2>/dev/null; then
    log_error "hooks: jq merge falhou (JSON invalido em source ou target?)"
    rm -f -- "$_hooks_tmp"
    return 1
  fi

  if ! mv -f -- "$_hooks_tmp" "$_hooks_target"; then
    log_error "hooks: mv atomico falhou para $_hooks_target"
    rm -f -- "$_hooks_tmp"
    return 1
  fi

  log_info "hooks: $_hooks_target mesclado (backup em ${_hooks_target}.bak)"
  return 0
}

# print_paste_block: fallback quando jq ausente. Imprime em stderr o JSON
# do source com instrucao clara de onde colar. NUNCA modifica o filesystem.
print_paste_block() {
  if [ "$#" -ne 2 ]; then
    log_error "hooks: print_paste_block espera 2 argumentos (target, source)"
    return 2
  fi
  _pb_target=$1
  _pb_source=$2
  if [ ! -f "$_pb_source" ]; then
    log_error "hooks: source JSON nao encontrado: $_pb_source"
    return 1
  fi
  {
    printf '\n'
    printf '# Hooks to merge manually into %s:\n' "$_pb_target"
    printf '#   1. Abra (ou crie) %s\n' "$_pb_target"
    printf '#   2. Cole o bloco abaixo dentro do objeto raiz, mesclando\n'
    printf '#      chaves existentes manualmente em caso de conflito.\n'
    printf '#   3. Instale jq para automatizar este passo no proximo install.\n'
    printf '# ----- BEGIN PAYLOAD -----\n'
    cat -- "$_pb_source"
    printf '\n# ----- END PAYLOAD -----\n'
  } >&2
  return 0
}
