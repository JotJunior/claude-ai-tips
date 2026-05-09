#!/bin/sh
# drift.sh — drift detection / goal alignment (FR-027).
#
# Ref: docs/specs/agente-00c/spec.md FR-027
#      docs/specs/agente-00c/threat-model.md T1
#      docs/specs/agente-00c/tasks.md FASE 5.4
#
# Modelo: na primeira onda o orquestrador extrai 3-7 aspectos-chave
# do projeto-alvo via prompt de auto-reflexao (palavras curtas
# normalizadas — ex: para "POC de bot Slack que sumariza threads",
# resultado: ["slack","bot","sumarizacao","threads","poc"]). Esses
# aspectos sao gravados via `drift.sh init` e CONGELADOS no estado
# (.aspectos_chave_iniciais — nao mudam mais).
#
# A cada onda, `drift.sh check` compara o conteudo das decisoes
# (campos `contexto` e `escolha`) contra os aspectos. Conta ondas
# consecutivas sem tocar nenhum aspecto:
#   - 0..2 ondas: OK (exit 0)
#   - 3 ondas: aviso (exit 0 mas mensagem em stderr)
#   - >=5 ondas: aborto `desvio_de_finalidade` (exit 3)
#
# Subcomandos:
#   drift.sh init --state-dir DIR --aspectos JSON-ARRAY
#       — Grava aspectos no estado. Falha se ja foi inicializado
#         (idempotente para erro, NAO sobrescreve — congelado).
#       — JSON-ARRAY de strings, 3..7 itens.
#
#   drift.sh check --state-dir DIR
#       — Avalia ondas consecutivas sem aspecto tocado.
#       — Stdout: numero de ondas consecutivas sem aspecto + warn|abort se aplicavel.
#       — Exit 0 (ok ou warn), Exit 3 (abort).
#
#   drift.sh aspectos --state-dir DIR
#       — Lista aspectos em stdout (um por linha).
#
# Exit codes:
#   0 alinhado (ou warn)
#   1 erro generico (init duplicado, ja foi gravado)
#   2 uso incorreto
#   3 desvio_de_finalidade — aborto (5+ ondas consecutivas sem tocar nenhum aspecto)
#
# POSIX sh + jq.

set -eu

_DR_NAME="drift"
_DR_WARN_THRESHOLD=3
_DR_ABORT_THRESHOLD=5

_dr_die_usage() { printf '%s: %s\n' "$_DR_NAME" "$1" >&2; exit 2; }
_dr_die()       { printf '%s: %s\n' "$_DR_NAME" "$1" >&2; exit "${2:-1}"; }

_dr_require_jq() {
  command -v jq >/dev/null 2>&1 \
    || _dr_die "jq nao encontrado no PATH" 1
}

_dr_state_file() { printf '%s/state.json\n' "$1"; }

_dr_atomic_write() {
  _dst=$1; _src=$2
  _tmp=$(mktemp -- "${_dst}.XXXXXX") || _dr_die "mktemp falhou" 1
  cp -- "$_src" "$_tmp" || { rm -f -- "$_tmp"; _dr_die "I/O cp" 1; }
  mv -f -- "$_tmp" "$_dst" || { rm -f -- "$_tmp"; _dr_die "mv" 1; }
}

_dr_update_sha() {
  _sf=$(_dr_state_file "$1")
  _shf="$1/state.json.sha256"
  if command -v sha256sum >/dev/null 2>&1; then
    _h=$(sha256sum -- "$_sf" | awk '{print $1}')
  else
    _h=$(shasum -a 256 -- "$_sf" | awk '{print $1}')
  fi
  printf '%s\n' "$_h" > "$_shf"
}

_dr_cmd_init() {
  _sd=""
  _asp=""
  while [ "$#" -gt 0 ]; do
    case "$1" in
      --state-dir) _sd=$2;  shift 2 ;;
      --aspectos)  _asp=$2; shift 2 ;;
      *) _dr_die_usage "init: flag desconhecida: $1" ;;
    esac
  done
  [ -n "$_sd" ]  || _dr_die_usage "init: --state-dir obrigatorio"
  [ -n "$_asp" ] || _dr_die_usage "init: --aspectos obrigatorio (JSON array de strings)"
  _dr_require_jq

  _sf=$(_dr_state_file "$_sd")
  [ -f "$_sf" ] || _dr_die "init: state.json ausente em $_sd" 1

  # Validacao do array
  if ! printf '%s' "$_asp" | jq -e '
    type == "array" and length >= 3 and length <= 7
    and all(.[]; type == "string" and (. | length) > 0)
  ' >/dev/null 2>&1; then
    _dr_die "init: --aspectos precisa ser JSON array com 3..7 strings nao-vazias" 1
  fi

  # Verifica se ja foi inicializado (cravado, nao sobrescreve)
  _existing=$(jq -r '.aspectos_chave_iniciais // [] | length' "$_sf")
  if [ "$_existing" -gt 0 ]; then
    _dr_die "init: aspectos_chave_iniciais ja foi gravado ($_existing aspectos). Nao sobrescreve (congelado pos-primeira-onda)." 1
  fi

  _new_state=$(mktemp) || _dr_die "mktemp falhou" 1
  jq --argjson a "$_asp" '.aspectos_chave_iniciais = $a' "$_sf" > "$_new_state" \
    || { rm -f -- "$_new_state"; _dr_die "jq update falhou" 1; }
  _dr_atomic_write "$_sf" "$_new_state"
  rm -f -- "$_new_state" 2>/dev/null || :
  _dr_update_sha "$_sd"
}

# _dr_count_drift_waves STATE_FILE
# Stdout: numero de ondas consecutivas (do fim para o inicio) onde NENHUMA
# decisao da onda menciona qualquer aspecto-chave (case-insensitive).
_dr_count_drift_waves() {
  _sf=$1
  jq -r '
    def matches_aspecto($txt; $aspectos):
      ($txt // "" | ascii_downcase) as $t
      | any($aspectos[]; . as $a | $t | contains($a | ascii_downcase));

    (.aspectos_chave_iniciais // []) as $aspectos
    | (.ondas // []) as $ondas
    | (.decisoes // []) as $decs
    | if ($aspectos | length) == 0 then 0
      else
        ($ondas | map(.id)) as $oids
        | reduce ($oids | reverse | .[]) as $oid (
            {count: 0, broken: false};
            if .broken then .
            else
              ($decs | map(select(.onda_id == $oid))) as $wave_decs
              | (any($wave_decs[]?;
                    matches_aspecto(.contexto; $aspectos)
                    or matches_aspecto(.escolha; $aspectos)
                    or matches_aspecto(.justificativa; $aspectos))) as $touched
              | if $touched then . + {broken: true}
                else . + {count: (.count + 1)}
                end
            end
          )
        | .count
      end
  ' "$_sf"
}

_dr_cmd_check() {
  _sd=""
  while [ "$#" -gt 0 ]; do
    case "$1" in
      --state-dir) _sd=$2; shift 2 ;;
      *) _dr_die_usage "check: flag desconhecida: $1" ;;
    esac
  done
  [ -n "$_sd" ] || _dr_die_usage "check: --state-dir obrigatorio"
  _dr_require_jq
  _sf=$(_dr_state_file "$_sd")
  [ -f "$_sf" ] || _dr_die "check: state.json ausente" 1

  _aspectos_count=$(jq -r '.aspectos_chave_iniciais // [] | length' "$_sf")
  if [ "$_aspectos_count" = 0 ]; then
    printf '0\n'
    printf '%s: aspectos_chave_iniciais nao inicializado — drift check desabilitado.\n' "$_DR_NAME" >&2
    return 0
  fi

  _drift_count=$(_dr_count_drift_waves "$_sf")
  printf '%s\n' "$_drift_count"

  if [ "$_drift_count" -ge "$_DR_ABORT_THRESHOLD" ]; then
    printf '%s: desvio_de_finalidade — %s ondas consecutivas sem tocar aspectos-chave (>= %s)\n' \
      "$_DR_NAME" "$_drift_count" "$_DR_ABORT_THRESHOLD" >&2
    exit 3
  fi
  if [ "$_drift_count" -ge "$_DR_WARN_THRESHOLD" ]; then
    printf '%s: AVISO — %s ondas consecutivas sem tocar aspectos-chave (warn >= %s, abort >= %s)\n' \
      "$_DR_NAME" "$_drift_count" "$_DR_WARN_THRESHOLD" "$_DR_ABORT_THRESHOLD" >&2
  fi
  exit 0
}

_dr_cmd_aspectos() {
  _sd=""
  while [ "$#" -gt 0 ]; do
    case "$1" in
      --state-dir) _sd=$2; shift 2 ;;
      *) _dr_die_usage "aspectos: flag desconhecida: $1" ;;
    esac
  done
  [ -n "$_sd" ] || _dr_die_usage "aspectos: --state-dir obrigatorio"
  _dr_require_jq
  _sf=$(_dr_state_file "$_sd")
  [ -f "$_sf" ] || _dr_die "aspectos: state.json ausente" 1
  jq -r '.aspectos_chave_iniciais // [] | .[]' "$_sf"
}

# ---------- Dispatch ----------

if [ "$#" -lt 1 ]; then
  cat >&2 <<'HELP'
drift.sh — drift detection / goal alignment (FR-027).

USO:
  drift.sh init     --state-dir DIR --aspectos JSON-ARRAY
  drift.sh check    --state-dir DIR
  drift.sh aspectos --state-dir DIR

Aspectos: 3..7 strings, congelados apos init. Check conta ondas
consecutivas (do fim para o inicio) sem decisao mencionando aspecto.

EXIT (check):
  0 alinhado (ou warn em stderr para drift_count >= 3)
  3 desvio_de_finalidade (drift_count >= 5)
HELP
  exit 2
fi

_DR_SUBCMD=$1
shift

case "$_DR_SUBCMD" in
  init)            _dr_cmd_init "$@" ;;
  check)           _dr_cmd_check "$@" ;;
  aspectos)        _dr_cmd_aspectos "$@" ;;
  -h|--help|help)  exit 0 ;;
  *) _dr_die_usage "subcomando desconhecido: $_DR_SUBCMD" ;;
esac
