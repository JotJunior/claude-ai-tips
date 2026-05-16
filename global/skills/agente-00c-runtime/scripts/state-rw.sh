#!/bin/sh
# state-rw.sh — read/write helpers para state.json do agente-00C.
#
# Ref: docs/specs/agente-00c/contracts/state-schema.md
#      docs/specs/agente-00c/data-model.md
#      docs/specs/agente-00c/spec.md FR-008/FR-017/FR-024/FR-029
#
# Subcomandos:
#   state-rw.sh init  --state-dir DIR --execucao-id ID
#                     --projeto-alvo-path PATH --descricao TEXT
#                     [--stack-json TEXT] [--whitelist-urls JSON-ARRAY]
#                     — cria state.json + state.json.sha256 + state-history/
#   state-rw.sh read  --state-dir DIR
#                     — imprime conteudo atual de state.json em stdout
#   state-rw.sh write --state-dir DIR
#                     — le novo conteudo em stdin, faz backup do anterior em
#                       state-history/onda-<NNN>-<ts>.json, regrava
#                       state.json + state.json.sha256
#   state-rw.sh get   --state-dir DIR --field 'JQ-PATH'
#                     — extrai campo via jq (ex: '.execucao.status')
#   state-rw.sh set   --state-dir DIR --field 'JQ-PATH' --value JSON
#                     — atualiza campo in-place (com backup + sha256)
#   state-rw.sh sha256-update --state-dir DIR
#                     — recalcula state.json.sha256 do state atual
#   state-rw.sh sha256-verify --state-dir DIR
#                     — exit 0 se hash bate, 1 se diverge (FR-029)
#   state-rw.sh path-check --projeto-alvo-path PATH
#                     — valida path: existe (ou cria), e diretorio, gravavel.
#                       NAO valida zonas proibidas — isso e FR-024 (FASE 6.1).
#   state-rw.sh infer-aspectos --state-dir DIR [--projeto-alvo-path PATH]
#                     — infere aspectos tocados pela onda corrente a
#                       partir de git diff --name-only HEAD~1..HEAD,
#                       aplicando matcher fuzzy contra union das 3
#                       camadas de aspectos (iniciais/tecnicos/operacionais).
#                       Stdout: JSON array de aspectos detectados (pode
#                       ser vazio). Nao escreve state.json — caller
#                       decide se chama `set --field
#                       '.ondas[-1].aspectos_chave_tocados' --value ...`.
#                       Ref: docs/specs/agente-00c-evolucao/tasks.md §2.3.
#
# Exit codes:
#   0  sucesso
#   1  erro generico (jq ausente, FS error, validacao falhou)
#   2  uso incorreto (flag invalida, subcomando desconhecido)
#
# POSIX sh + jq + sha256sum/shasum + mkdir/mv/touch + git.

set -eu

_SR_NAME="state-rw"

_sr_die() {
  printf '%s: %s\n' "$_SR_NAME" "$1" >&2
  exit "${2:-1}"
}

_sr_log() {
  printf '%s: %s\n' "$_SR_NAME" "$1" >&2
}

# ---------- Helpers portaveis ----------

# _sr_sha256_file FILE -> hex hash em stdout
_sr_sha256_file() {
  if command -v sha256sum >/dev/null 2>&1; then
    sha256sum -- "$1" | awk '{print $1}'
  elif command -v shasum >/dev/null 2>&1; then
    shasum -a 256 -- "$1" | awk '{print $1}'
  else
    _sr_die "sha256sum/shasum ausente — instale coreutils ou perl-shasum" 1
  fi
}

# _sr_iso_now -> timestamp UTC ISO 8601 (Z, sem milis)
_sr_iso_now() {
  # `date -u +%FT%TZ` funciona em GNU e BSD.
  date -u +%FT%TZ
}

# _sr_ts_for_filename -> timestamp safe para nome de arquivo (sem ":")
_sr_ts_for_filename() {
  date -u +%Y%m%dT%H%M%SZ
}

# _sr_require_jq -> aborta se jq ausente
_sr_require_jq() {
  if ! command -v jq >/dev/null 2>&1; then
    _sr_die "jq nao encontrado no PATH. Instale com 'brew install jq' (macOS) ou 'apt install jq' (Debian/Ubuntu)." 1
  fi
}

# ---------- Layout do state-dir ----------

_sr_state_file() { printf '%s/state.json\n' "$1"; }
_sr_sha_file()   { printf '%s/state.json.sha256\n' "$1"; }
_sr_history_dir() { printf '%s/state-history\n' "$1"; }

# _sr_ensure_state_dir DIR -> mkdir -p; abre se imposivel
_sr_ensure_state_dir() {
  if ! mkdir -p -- "$1" 2>/dev/null; then
    _sr_die "nao foi possivel criar state-dir: $1" 1
  fi
  if ! mkdir -p -- "$(_sr_history_dir "$1")" 2>/dev/null; then
    _sr_die "nao foi possivel criar state-history/: $(_sr_history_dir "$1")" 1
  fi
  # Touch test: garante gravabilidade antes de qualquer Write real (2.4.3).
  _sr_touchprobe="$1/.write-probe"
  if ! ( : > "$_sr_touchprobe" ) 2>/dev/null; then
    _sr_die "permissao de escrita negada em $1" 1
  fi
  rm -f -- "$_sr_touchprobe" 2>/dev/null || :
}

# _sr_atomic_write DST CONTENT_FILE -> mv atomico de tmp para DST
_sr_atomic_write() {
  _sr_dst=$1
  _sr_src=$2
  _sr_tmp=$(mktemp -- "${_sr_dst}.XXXXXX") || _sr_die "mktemp falhou em $(dirname -- "$_sr_dst")" 1
  # Captura erros de cp (disco cheio aparece aqui — task 2.4.4).
  if ! cp -- "$_sr_src" "$_sr_tmp"; then
    rm -f -- "$_sr_tmp" 2>/dev/null || :
    _sr_die "I/O error gravando em $_sr_tmp (disco cheio? quota?)" 1
  fi
  if ! mv -f -- "$_sr_tmp" "$_sr_dst"; then
    rm -f -- "$_sr_tmp" 2>/dev/null || :
    _sr_die "mv atomico falhou: $_sr_tmp -> $_sr_dst" 1
  fi
}

# _sr_update_sha STATE_DIR -> regrava state.json.sha256
_sr_update_sha() {
  _sr_sf=$(_sr_state_file "$1")
  _sr_shf=$(_sr_sha_file "$1")
  _sr_h=$(_sr_sha256_file "$_sr_sf")
  printf '%s\n' "$_sr_h" > "$_sr_shf" 2>/dev/null \
    || _sr_die "I/O error gravando $_sr_shf" 1
}

# _sr_next_onda_id STATE_DIR -> proximo numero sequencial de onda (NNN)
_sr_next_onda_id() {
  _sr_require_jq
  _sr_sf=$(_sr_state_file "$1")
  if [ ! -f "$_sr_sf" ]; then
    printf '001\n'
    return 0
  fi
  # Extrai max(.ondas[].id) numerico. id tem formato "onda-NNN".
  _sr_max=$(jq -r '
    if (.ondas // []) | length == 0 then 0
    else ([.ondas[].id // ""] | map(sub("^onda-0*"; "") | tonumber? // 0) | max)
    end' -- "$_sr_sf" 2>/dev/null) || _sr_max=0
  _sr_next=$((_sr_max + 1))
  printf 'onda-%03d\n' "$_sr_next" | sed 's/onda-//'
}

# _sr_backup_current STATE_DIR -> move state.json -> state-history/
# Usa numero da onda corrente (default 001 se ainda nao houver) + ts.
_sr_backup_current() {
  _sr_sf=$(_sr_state_file "$1")
  [ -f "$_sr_sf" ] || return 0
  _sr_hd=$(_sr_history_dir "$1")
  mkdir -p -- "$_sr_hd" 2>/dev/null || _sr_die "nao consegui criar $_sr_hd" 1
  # Determina onda atual via .ondas[-1].id (se existir) — fallback "init".
  _sr_curr_onda="init"
  if command -v jq >/dev/null 2>&1; then
    _sr_curr_onda=$(jq -r '
      if (.ondas // []) | length > 0 then (.ondas[-1].id // "init") else "init" end
    ' -- "$_sr_sf" 2>/dev/null) || _sr_curr_onda="init"
  fi
  _sr_ts=$(_sr_ts_for_filename)
  _sr_bk="$_sr_hd/${_sr_curr_onda}-${_sr_ts}.json"
  if ! mv -- "$_sr_sf" "$_sr_bk"; then
    _sr_die "backup falhou: $_sr_sf -> $_sr_bk" 1
  fi
}

# ---------- Subcomandos ----------

_sr_cmd_init() {
  _sd=""
  _ei=""
  _pap=""
  _desc=""
  _stack="null"
  _whitelist="[]"
  while [ "$#" -gt 0 ]; do
    case "$1" in
      --state-dir)         _sd=$2;        shift 2 ;;
      --execucao-id)       _ei=$2;        shift 2 ;;
      --projeto-alvo-path) _pap=$2;       shift 2 ;;
      --descricao)         _desc=$2;      shift 2 ;;
      --stack-json)        _stack=$2;     shift 2 ;;
      --whitelist-urls)    _whitelist=$2; shift 2 ;;
      *) _sr_die "init: flag desconhecida: $1" 2 ;;
    esac
  done
  [ -n "$_sd" ]   || _sr_die "init: --state-dir obrigatorio" 2
  [ -n "$_ei" ]   || _sr_die "init: --execucao-id obrigatorio" 2
  [ -n "$_pap" ]  || _sr_die "init: --projeto-alvo-path obrigatorio" 2
  [ -n "$_desc" ] || _sr_die "init: --descricao obrigatorio" 2

  _sr_require_jq
  _sr_ensure_state_dir "$_sd"

  _sr_sf=$(_sr_state_file "$_sd")
  if [ -f "$_sr_sf" ]; then
    _sr_die "init: state.json ja existe em $_sd. Use /agente-00c-abort ou /agente-00c-resume." 1
  fi

  _now=$(_sr_iso_now)
  # Templating do esqueleto via jq (escape automatico de strings).
  _tmp=$(mktemp -- "${_sr_sf}.XXXXXX") || _sr_die "mktemp falhou" 1
  jq -n \
    --arg id "$_ei" \
    --arg pap "$_pap" \
    --arg desc "$_desc" \
    --arg now "$_now" \
    --argjson stack "$_stack" \
    --argjson wl "$_whitelist" \
    '{
      schema_version: "1.0.0",
      execucao: {
        id: $id,
        projeto_alvo_path: $pap,
        projeto_alvo_descricao: $desc,
        stack_sugerida: $stack,
        status: "em_andamento",
        motivo_termino: null,
        iniciada_em: $now,
        terminada_em: null
      },
      etapa_corrente: "briefing",
      proxima_instrucao: "Iniciar etapa briefing — invocar skill briefing do toolkit com a descricao curta do projeto-alvo.",
      ondas: [],
      decisoes: [],
      bloqueios_humanos: [],
      orcamentos: {
        recursividade_max: 3,
        profundidade_corrente_subagentes: 1,
        retro_execucoes_max_por_feature: 2,
        retro_execucoes_consumidas: 0,
        ciclos_max_por_etapa: 5,
        ciclos_consumidos_etapa_corrente: 0,
        tool_calls_threshold_onda: 80,
        wallclock_threshold_segundos: 5400,
        estado_size_threshold_bytes: 1048576,
        tool_calls_onda_corrente: 0,
        inicio_onda_corrente: null
      },
      metricas_acumuladas: {
        ondas_total: 0,
        tool_calls_total: 0,
        tempo_wallclock_total_segundos: 0,
        profundidade_max_atingida: 1,
        subagentes_spawned: 0,
        decisoes_total: 0,
        bloqueios_humanos_total: 0,
        sugestoes_skills_globais_total: 0,
        issues_toolkit_abertas: 0
      },
      whitelist_urls_externas: $wl,
      historico_movimento_circular: [],
      aspectos_chave_iniciais: []
    }' > "$_tmp" || { rm -f -- "$_tmp"; _sr_die "jq init falhou" 1; }
  _sr_atomic_write "$_sr_sf" "$_tmp"
  rm -f -- "$_tmp" 2>/dev/null || :
  _sr_update_sha "$_sd"
  _sr_log "init: estado criado em $_sr_sf"
}

_sr_cmd_read() {
  _sd=""
  while [ "$#" -gt 0 ]; do
    case "$1" in
      --state-dir) _sd=$2; shift 2 ;;
      *) _sr_die "read: flag desconhecida: $1" 2 ;;
    esac
  done
  [ -n "$_sd" ] || _sr_die "read: --state-dir obrigatorio" 2
  _sr_sf=$(_sr_state_file "$_sd")
  [ -f "$_sr_sf" ] || _sr_die "read: state.json nao existe em $_sd" 1
  cat -- "$_sr_sf"
}

_sr_cmd_write() {
  _sd=""
  while [ "$#" -gt 0 ]; do
    case "$1" in
      --state-dir) _sd=$2; shift 2 ;;
      *) _sr_die "write: flag desconhecida: $1" 2 ;;
    esac
  done
  [ -n "$_sd" ] || _sr_die "write: --state-dir obrigatorio" 2
  _sr_require_jq
  _sr_ensure_state_dir "$_sd"

  _sr_sf=$(_sr_state_file "$_sd")
  # Le stdin para tmp e valida JSON antes de tocar o estado.
  _new=$(mktemp -- "${_sr_sf}.new.XXXXXX") || _sr_die "mktemp falhou" 1
  if ! cat > "$_new"; then
    rm -f -- "$_new"; _sr_die "I/O lendo stdin" 1
  fi
  if ! jq -e . "$_new" >/dev/null 2>&1; then
    rm -f -- "$_new"; _sr_die "write: stdin nao e JSON valido (jq falhou)" 1
  fi
  # Backup do anterior (se existir) ANTES de sobrescrever (2.3.1).
  _sr_backup_current "$_sd"
  _sr_atomic_write "$_sr_sf" "$_new"
  rm -f -- "$_new" 2>/dev/null || :
  _sr_update_sha "$_sd"
  _sr_log "write: state.json atualizado em $_sr_sf (backup em state-history/)"
}

_sr_cmd_get() {
  _sd=""
  _f=""
  while [ "$#" -gt 0 ]; do
    case "$1" in
      --state-dir) _sd=$2; shift 2 ;;
      --field)     _f=$2;  shift 2 ;;
      *) _sr_die "get: flag desconhecida: $1" 2 ;;
    esac
  done
  [ -n "$_sd" ] || _sr_die "get: --state-dir obrigatorio" 2
  [ -n "$_f" ]  || _sr_die "get: --field obrigatorio (ex: '.execucao.status')" 2
  _sr_require_jq
  _sr_sf=$(_sr_state_file "$_sd")
  [ -f "$_sr_sf" ] || _sr_die "get: state.json ausente em $_sd" 1
  jq -r "$_f" -- "$_sr_sf"
}

_sr_cmd_set() {
  _sd=""
  _f=""
  _v=""
  _v_set=0
  while [ "$#" -gt 0 ]; do
    case "$1" in
      --state-dir) _sd=$2; shift 2 ;;
      --field)     _f=$2;  shift 2 ;;
      --value)     _v=$2;  _v_set=1; shift 2 ;;
      *) _sr_die "set: flag desconhecida: $1" 2 ;;
    esac
  done
  [ -n "$_sd" ]   || _sr_die "set: --state-dir obrigatorio" 2
  [ -n "$_f" ]    || _sr_die "set: --field obrigatorio" 2
  [ "$_v_set" = 1 ] || _sr_die "set: --value obrigatorio (JSON valido — strings com aspas)" 2
  _sr_require_jq
  _sr_ensure_state_dir "$_sd"
  _sr_sf=$(_sr_state_file "$_sd")
  [ -f "$_sr_sf" ] || _sr_die "set: state.json ausente em $_sd" 1
  # Valida que --value e JSON parseavel (string raw nao serve — pedimos aspas).
  if ! printf '%s' "$_v" | jq -e . >/dev/null 2>&1; then
    _sr_die "set: --value nao e JSON valido. Strings precisam de aspas: '\"foo\"'." 1
  fi
  _new=$(mktemp -- "${_sr_sf}.new.XXXXXX") || _sr_die "mktemp falhou" 1
  if ! jq --argjson v "$_v" "$_f = \$v" -- "$_sr_sf" > "$_new"; then
    rm -f -- "$_new"; _sr_die "set: jq update falhou" 1
  fi
  _sr_backup_current "$_sd"
  _sr_atomic_write "$_sr_sf" "$_new"
  rm -f -- "$_new" 2>/dev/null || :
  _sr_update_sha "$_sd"
  _sr_log "set: $_f atualizado"
}

_sr_cmd_sha256_update() {
  _sd=""
  while [ "$#" -gt 0 ]; do
    case "$1" in
      --state-dir) _sd=$2; shift 2 ;;
      *) _sr_die "sha256-update: flag desconhecida: $1" 2 ;;
    esac
  done
  [ -n "$_sd" ] || _sr_die "sha256-update: --state-dir obrigatorio" 2
  _sr_sf=$(_sr_state_file "$_sd")
  [ -f "$_sr_sf" ] || _sr_die "sha256-update: state.json ausente em $_sd" 1
  _sr_update_sha "$_sd"
}

_sr_cmd_sha256_verify() {
  _sd=""
  while [ "$#" -gt 0 ]; do
    case "$1" in
      --state-dir) _sd=$2; shift 2 ;;
      *) _sr_die "sha256-verify: flag desconhecida: $1" 2 ;;
    esac
  done
  [ -n "$_sd" ] || _sr_die "sha256-verify: --state-dir obrigatorio" 2
  _sr_sf=$(_sr_state_file "$_sd")
  _sr_shf=$(_sr_sha_file "$_sd")
  [ -f "$_sr_sf" ]  || _sr_die "sha256-verify: state.json ausente em $_sd" 1
  [ -f "$_sr_shf" ] || _sr_die "sha256-verify: state.json.sha256 ausente em $_sd" 1
  _stored=$(head -n 1 -- "$_sr_shf" | tr -d '[:space:]')
  _actual=$(_sr_sha256_file "$_sr_sf")
  if [ "$_stored" = "$_actual" ]; then
    return 0
  fi
  printf '%s: hash divergente\n  stored: %s\n  actual: %s\n' "$_SR_NAME" "$_stored" "$_actual" >&2
  exit 1
}

# path-check: validacao de --projeto-alvo-path no nivel filesystem.
# NAO inclui validacao de zonas proibidas (FR-024) — isso e FASE 6.1.
_sr_cmd_path_check() {
  _pap=""
  _create=0
  while [ "$#" -gt 0 ]; do
    case "$1" in
      --projeto-alvo-path) _pap=$2; shift 2 ;;
      --create) _create=1; shift ;;
      *) _sr_die "path-check: flag desconhecida: $1" 2 ;;
    esac
  done
  [ -n "$_pap" ] || _sr_die "path-check: --projeto-alvo-path obrigatorio" 2
  if [ -e "$_pap" ] && [ ! -d "$_pap" ]; then
    _sr_die "path-check: caminho aponta para arquivo, nao diretorio: $_pap" 1
  fi
  if [ ! -d "$_pap" ]; then
    if [ "$_create" = 1 ]; then
      mkdir -p -- "$_pap" 2>/dev/null \
        || _sr_die "path-check: nao consegui criar $_pap (permissao? FS read-only?)" 1
    else
      _sr_die "path-check: diretorio nao existe: $_pap (use --create para criar)" 1
    fi
  fi
  # Touch test: gravabilidade antes de qualquer escrita real (2.4.3).
  _probe="$_pap/.agente-00c-write-probe"
  if ! ( : > "$_probe" ) 2>/dev/null; then
    _sr_die "path-check: permissao de escrita negada em $_pap" 1
  fi
  rm -f -- "$_probe" 2>/dev/null || :
}

# _sr_cmd_infer_aspectos: infere aspectos tocados pela onda corrente
# a partir de `git diff --name-only` aplicando matcher fuzzy contra
# union das 3 camadas de aspectos. Stdout: JSON array.
_sr_cmd_infer_aspectos() {
  _sd=""
  _pap=""
  while [ "$#" -gt 0 ]; do
    case "$1" in
      --state-dir)          _sd=$2;  shift 2 ;;
      --projeto-alvo-path)  _pap=$2; shift 2 ;;
      *) _sr_die "infer-aspectos: flag desconhecida: $1" 2 ;;
    esac
  done
  [ -n "$_sd" ] || _sr_die "infer-aspectos: --state-dir obrigatorio" 2
  command -v jq >/dev/null 2>&1 || _sr_die "infer-aspectos: jq ausente" 1
  command -v git >/dev/null 2>&1 || _sr_die "infer-aspectos: git ausente" 1

  _sf="$_sd/state.json"
  [ -f "$_sf" ] || _sr_die "infer-aspectos: state.json ausente em $_sd" 1

  # Resolver projeto-alvo: flag explicita > .execucao.projeto_alvo_path
  if [ -z "$_pap" ]; then
    _pap=$(jq -r '.execucao.projeto_alvo_path // ""' "$_sf")
  fi
  [ -n "$_pap" ] || _sr_die "infer-aspectos: nao consegui resolver projeto-alvo-path" 1
  [ -d "$_pap" ] || _sr_die "infer-aspectos: projeto-alvo nao e diretorio: $_pap" 1

  # Coletar arquivos modificados nesta onda. Estrategia:
  #   1. Se HEAD~1 existe, usa `git diff --name-only HEAD~1..HEAD`
  #   2. Caso contrario (primeira onda, repo sem historico), usa
  #      `git diff --name-only --cached` + `git ls-files --others --exclude-standard`
  _diff=$(
    cd "$_pap" 2>/dev/null || exit 1
    if git rev-parse --verify HEAD~1 >/dev/null 2>&1; then
      git diff --name-only HEAD~1..HEAD 2>/dev/null
    else
      git diff --name-only --cached 2>/dev/null
      git ls-files --others --exclude-standard 2>/dev/null
    fi
  ) || _diff=""

  # Aplicar matcher fuzzy: aspecto detectado se token-overlap com paths.
  # Reusa logica do drift.sh (matcher bidirecional + tokens >=3 chars).
  printf '%s\n' "$_diff" | jq -R -s --slurpfile state "$_sf" '
    def tokenize($s):
      ($s // "")
      | ascii_downcase
      | gsub("[^a-z0-9]+"; " ")
      | split(" ")
      | map(select(length >= 3));

    def matches_aspecto($txt; $aspecto):
      ($txt // "" | ascii_downcase) as $t
      | ($aspecto | ascii_downcase) as $a
      | ($t | contains($a))
        or (
          (tokenize($t)) as $tt
          | (tokenize($aspecto)) as $ta
          | any($tt[]; . as $x | any($ta[]; . == $x))
        );

    ($state[0]) as $st
    | (($st.aspectos_chave_iniciais     // []) +
       ($st.aspectos_chave_tecnicos     // []) +
       ($st.aspectos_chave_operacionais // []) | unique) as $aspectos
    | . as $diff
    | $aspectos
      | map(. as $a | select(matches_aspecto($diff; $a)))
      | unique
  '
}

# ---------- Dispatch ----------

_sr_print_help() {
  cat >&2 <<'HELP'
state-rw.sh — read/write helpers para state.json do agente-00C.

USO:
  state-rw.sh <subcomando> [flags]

SUBCOMANDOS:
  init           Cria state.json + state.json.sha256 + state-history/
  read           Imprime state.json em stdout
  write          Le novo state em stdin, faz backup + grava + sha256
  get            Extrai campo via jq path
  set            Atualiza campo in-place (com backup)
  sha256-update  Recalcula state.json.sha256
  sha256-verify  Compara hash atual com state.json.sha256 (FR-029)
  path-check     Valida --projeto-alvo-path (existe/cria/gravavel)
  infer-aspectos Infere aspectos tocados via git diff + matcher fuzzy

Flags variam por subcomando — consulte cabecalho do script para detalhes.

Dependencias: jq + git (brew install jq | apt install jq).
HELP
}

if [ "$#" -lt 1 ]; then
  _sr_print_help
  exit 2
fi

_sr_subcmd=$1
shift

case "$_sr_subcmd" in
  init)            _sr_cmd_init "$@" ;;
  read)            _sr_cmd_read "$@" ;;
  write)           _sr_cmd_write "$@" ;;
  get)             _sr_cmd_get "$@" ;;
  set)             _sr_cmd_set "$@" ;;
  sha256-update)   _sr_cmd_sha256_update "$@" ;;
  sha256-verify)   _sr_cmd_sha256_verify "$@" ;;
  path-check)      _sr_cmd_path_check "$@" ;;
  infer-aspectos)  _sr_cmd_infer_aspectos "$@" ;;
  -h|--help|help)  _sr_print_help; exit 0 ;;
  *) _sr_die "subcomando desconhecido: $_sr_subcmd (use --help)" 2 ;;
esac
