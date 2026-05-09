#!/bin/sh
# state-validate.sh — validacao de schema + invariantes do state.json (FR-008).
#
# Ref: docs/specs/agente-00c/contracts/state-schema.md §Regras de validacao
#      docs/specs/agente-00c/spec.md FR-008
#      docs/specs/agente-00c/constitution.md §III (Idempotencia de Retomada)
#
# Sintaxe:
#   state-validate.sh --state-dir DIR
#
# Comportamento:
#   1. Le state.json. Se nao parseavel = exit 1 com diagnostico.
#   2. Verifica presenca + tipo de cada campo obrigatorio.
#   3. Aplica invariantes (profundidade <= 3, ciclos <= 5, retros <= 2).
#   4. Verifica consistencia de status x terminada_em.
#   5. Verifica que cada Decisao tem 5 campos preenchidos (Principio I).
#   6. Verifica que cada BloqueioHumano referencia uma Decisao existente.
#   7. Verifica que whitelist_urls_externas e array de strings nao vazias.
#
# IMPORTANTE: NAO faz auto-correcao. Falha = bloqueio puro (Principio III).
#
# Exit codes:
#   0 valido
#   1 invalido (lista de violacoes em stderr)
#   2 uso incorreto
#
# POSIX sh + jq.

set -eu

_SV_NAME="state-validate"

_sv_die_usage() {
  printf '%s: %s\n' "$_SV_NAME" "$1" >&2
  exit 2
}

_sv_emit_error() {
  printf '%s: VIOLACAO: %s\n' "$_SV_NAME" "$1" >&2
}

_sv_require_jq() {
  if ! command -v jq >/dev/null 2>&1; then
    printf '%s: jq nao encontrado no PATH. Instale com brew/apt.\n' "$_SV_NAME" >&2
    exit 1
  fi
}

# ---------- Parse de args ----------

_SV_STATE_DIR=""
while [ "$#" -gt 0 ]; do
  case "$1" in
    --state-dir) _SV_STATE_DIR=$2; shift 2 ;;
    -h|--help)
      cat >&2 <<'HELP'
state-validate.sh — valida state.json segundo FR-008.

USO:
  state-validate.sh --state-dir DIR

EXIT:
  0 valido
  1 invalido (violacoes em stderr)
  2 uso incorreto

Lista de checagens:
  1. Arquivo existe e e JSON parseavel.
  2. schema_version = "1.0.0".
  3. Campos obrigatorios presentes (execucao.*, etapa_corrente, proxima_instrucao,
     ondas, decisoes, bloqueios_humanos, orcamentos.*, whitelist_urls_externas).
  4. status x terminada_em consistentes (terminal => terminada_em != null).
  5. profundidade_corrente_subagentes <= 3.
  6. ciclos_consumidos_etapa_corrente <= 5.
  7. retro_execucoes_consumidas <= 2.
  8. Cada Decisao tem 5 campos: contexto, opcoes_consideradas (>=1),
     escolha, justificativa, agente.
  9. Cada BloqueioHumano referencia uma Decisao existente (decisao_id).
 10. whitelist_urls_externas e array de strings nao-vazias.
HELP
      exit 0
      ;;
    *) _sv_die_usage "flag desconhecida: $1" ;;
  esac
done

[ -n "$_SV_STATE_DIR" ] || _sv_die_usage "--state-dir obrigatorio"

_SV_FILE="$_SV_STATE_DIR/state.json"
_sv_require_jq

# 1. Existe e parseavel
if [ ! -f "$_SV_FILE" ]; then
  _sv_emit_error "state.json nao existe em $_SV_STATE_DIR"
  exit 1
fi
if ! jq -e . "$_SV_FILE" >/dev/null 2>&1; then
  _sv_emit_error "state.json nao e JSON parseavel"
  exit 1
fi

# Coleta violacoes em $_SV_VIOL (multilinha). Imprime tudo no fim.
_SV_VIOL=""
_sv_add() { _SV_VIOL="$_SV_VIOL
$1"; }

# 2. schema_version
_v=$(jq -r '.schema_version // ""' "$_SV_FILE")
if [ "$_v" != "1.0.0" ]; then
  _sv_add "schema_version desconhecido: \"$_v\" (esperado \"1.0.0\")"
fi

# 3. Campos obrigatorios estruturais
_check_field() {
  _path=$1
  _kind=$2  # string|object|array|number
  _t=$(jq -r "($_path) | type" "$_SV_FILE" 2>/dev/null) || _t="null"
  case "$_kind:$_t" in
    string:string) ;;
    object:object) ;;
    array:array) ;;
    number:number) ;;
    *)
      _sv_add "campo obrigatorio ausente ou tipo errado: $_path (esperado $_kind, obtido $_t)"
      ;;
  esac
}

_check_field '.execucao'                          object
_check_field '.execucao.id'                       string
_check_field '.execucao.projeto_alvo_path'        string
_check_field '.execucao.projeto_alvo_descricao'   string
_check_field '.execucao.status'                   string
_check_field '.execucao.iniciada_em'              string
_check_field '.etapa_corrente'                    string
_check_field '.proxima_instrucao'                 string
_check_field '.ondas'                             array
_check_field '.decisoes'                          array
_check_field '.bloqueios_humanos'                 array
_check_field '.orcamentos'                        object
_check_field '.orcamentos.profundidade_corrente_subagentes' number
_check_field '.orcamentos.ciclos_consumidos_etapa_corrente' number
_check_field '.orcamentos.retro_execucoes_consumidas'       number
_check_field '.whitelist_urls_externas'           array

# 4. status x terminada_em
_st=$(jq -r '.execucao.status // ""' "$_SV_FILE")
_te=$(jq -r '.execucao.terminada_em // null' "$_SV_FILE")
case "$_st" in
  abortada|concluida)
    if [ "$_te" = "null" ]; then
      _sv_add "status terminal (\"$_st\") mas execucao.terminada_em e null"
    fi
    ;;
  em_andamento|aguardando_humano)
    if [ "$_te" != "null" ]; then
      _sv_add "status nao-terminal (\"$_st\") mas execucao.terminada_em preenchido (\"$_te\")"
    fi
    ;;
  "")
    : # ja reportado pelo _check_field acima
    ;;
  *)
    _sv_add "execucao.status invalido: \"$_st\" (esperado em_andamento|aguardando_humano|abortada|concluida)"
    ;;
esac

# 5/6/7. Invariantes numericas
_check_max() {
  _path=$1
  _max=$2
  _label=$3
  _val=$(jq -r "($_path) // 0" "$_SV_FILE" 2>/dev/null) || _val=0
  # Garante numerico
  case "$_val" in
    ''|*[!0-9-]*) return 0 ;;  # ja reportado por _check_field
  esac
  if [ "$_val" -gt "$_max" ]; then
    _sv_add "$_label violado: $_path = $_val > $_max"
  fi
}

_check_max '.orcamentos.profundidade_corrente_subagentes' 3 "Invariante FR-013 (max 3 niveis de subagentes)"
_check_max '.orcamentos.ciclos_consumidos_etapa_corrente' 5 "Invariante FR-014.a (max 5 ciclos sem progresso)"
_check_max '.orcamentos.retro_execucoes_consumidas'       2 "Invariante FR-006 (max 2 retro-execucoes)"

# 8. Decisoes: 5 campos preenchidos
_dec_total=$(jq '.decisoes | length' "$_SV_FILE" 2>/dev/null) || _dec_total=0
if [ "$_dec_total" -gt 0 ]; then
  _missing=$(jq -r '
    .decisoes[]? | select(
      (.contexto | type) != "string" or (.contexto | length) == 0 or
      (.opcoes_consideradas | type) != "array" or (.opcoes_consideradas | length) == 0 or
      (.escolha | type) != "string" or (.escolha | length) == 0 or
      (.justificativa | type) != "string" or (.justificativa | length) == 0 or
      (.agente | type) != "string" or (.agente | length) == 0
    ) | .id // "<sem-id>"
  ' "$_SV_FILE" 2>/dev/null) || _missing=""
  if [ -n "$_missing" ]; then
    # Lista decisoes incompletas (uma por linha)
    _OLD_IFS=$IFS
    IFS='
'
    for _id in $_missing; do
      IFS=$_OLD_IFS
      _sv_add "Decisao $_id viola Principio I (algum dos 5 campos vazio: contexto, opcoes_consideradas, escolha, justificativa, agente)"
      IFS='
'
    done
    IFS=$_OLD_IFS
  fi
fi

# 9. BloqueioHumano: cada um referencia Decisao existente
_block_total=$(jq '.bloqueios_humanos | length' "$_SV_FILE" 2>/dev/null) || _block_total=0
if [ "$_block_total" -gt 0 ]; then
  _orphan=$(jq -r '
    (.decisoes // []) as $D
    | (.decisoes // [] | map(.id) ) as $ids
    | .bloqueios_humanos[]?
      | select((.decisao_id | type) != "string" or ((.decisao_id) as $d | $ids | index($d) == null))
      | .id // "<sem-id>"
  ' "$_SV_FILE" 2>/dev/null) || _orphan=""
  if [ -n "$_orphan" ]; then
    _OLD_IFS=$IFS
    IFS='
'
    for _bid in $_orphan; do
      IFS=$_OLD_IFS
      _sv_add "BloqueioHumano $_bid referencia decisao_id inexistente"
      IFS='
'
    done
    IFS=$_OLD_IFS
  fi
fi

# 10. whitelist_urls_externas: array de strings nao-vazias
_wl_bad=$(jq -r '
  .whitelist_urls_externas // [] | to_entries[]?
  | select((.value | type) != "string" or (.value | length) == 0)
  | .key
' "$_SV_FILE" 2>/dev/null) || _wl_bad=""
if [ -n "$_wl_bad" ]; then
  _sv_add "whitelist_urls_externas contem entrada(s) invalida(s) (nao-string ou string vazia) em indice(s): $(printf '%s' "$_wl_bad" | tr '\n' ' ')"
fi

# ---------- Veredicto ----------

if [ -z "$_SV_VIOL" ]; then
  exit 0
fi

# Imprime cada violacao (omitindo a linha em branco do head)
printf '%s\n' "$_SV_VIOL" | sed '/^$/d' | while IFS= read -r _line; do
  _sv_emit_error "$_line"
done
exit 1
