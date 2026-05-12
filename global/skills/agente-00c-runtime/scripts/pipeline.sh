#!/bin/sh
# pipeline.sh — state machine canonica da pipeline SDD do agente-00C.
#
# Ref: docs/specs/agente-00c/spec.md FR-004
#      docs/specs/agente-00c/plan.md §Summary
#      docs/specs/agente-00c/tasks.md FASE 3.1
#
# Subcomandos:
#   pipeline.sh stages
#       — imprime as 10 etapas canonicas (uma por linha)
#   pipeline.sh next-stage --current STAGE
#       — imprime proxima etapa em ordem linear (vazio se ja na ultima)
#   pipeline.sh prev-stage --current STAGE
#       — imprime etapa anterior (para retro-execucao)
#   pipeline.sh detect-completion --feature-dir DIR --stage STAGE
#                                  [--projeto-alvo-path PAP]
#       — exit 0 se artefato esperado da etapa existe; exit 1 se nao
#       — Mapeamento etapa -> artefato esperado (no feature-dir):
#           briefing       -> briefing.md
#           constitution   -> constitution.md
#           specify        -> spec.md
#           clarify        -> spec.md (assume editado pela skill clarify)
#           plan           -> plan.md
#           checklist      -> checklists/ (qualquer .md dentro)
#           create-tasks   -> tasks.md
#           execute-task   -> presenca de pelo menos 1 [x] em tasks.md
#           review-task    -> sempre passa (review e cross-task — sem artefato)
#           review-features -> sempre passa
#       — `briefing` e `constitution` sao artefatos PROJECT-LEVEL (uma vez por
#         projeto, nao por feature). As skills `briefing` e `constitution`
#         salvam em paths do `/initialize-docs` (hierarquia numerada):
#           briefing      -> docs/01-briefing-discovery/briefing.md
#           constitution  -> docs/constitution.md
#         Quando `--projeto-alvo-path PAP` e passado, esses paths sao
#         aceitos como fallback alem do feature-dir convencional. Isso
#         resolve o conflito com `/initialize-docs` (issue #3) sem quebrar
#         o layout SDD canonico.
#   pipeline.sh skill-conflict --skill NAME --projeto-alvo-path PATH
#       — emite info se a skill existe em ambos local e global
#       — exit 0 (info); exit 1 (so global); exit 2 (so local); exit 3 (nenhum)
#       — Sempre, skill local vence (quando ambas existem) — output indica isso
#
# POSIX sh + jq nao requerido (apenas leitura de FS + listas hardcoded).

set -eu

_PL_NAME="pipeline"

# Lista canonica em ordem (FR-004; tasks.md 3.1.1).
_PL_STAGES_LIST="briefing constitution specify clarify plan checklist create-tasks execute-task review-task review-features"

_pl_die_usage() {
  printf '%s: %s\n' "$_PL_NAME" "$1" >&2
  exit 2
}

_pl_die() {
  printf '%s: %s\n' "$_PL_NAME" "$1" >&2
  exit "${2:-1}"
}

_pl_print_help() {
  cat >&2 <<'HELP'
pipeline.sh — state machine canonica da pipeline SDD do agente-00C.

USO:
  pipeline.sh stages
  pipeline.sh next-stage --current STAGE
  pipeline.sh prev-stage --current STAGE
  pipeline.sh detect-completion --feature-dir DIR --stage STAGE
                                [--projeto-alvo-path PAP]
  pipeline.sh skill-conflict --skill NAME --projeto-alvo-path PATH

EXIT:
  0 sucesso (ou skill conflict info)
  1 nao-completion / so global / outro
  2 uso incorreto / so local
  3 nenhuma skill encontrada
HELP
}

_pl_is_valid_stage() {
  for _s in $_PL_STAGES_LIST; do
    [ "$_s" = "$1" ] && return 0
  done
  return 1
}

_pl_cmd_stages() {
  for _s in $_PL_STAGES_LIST; do
    printf '%s\n' "$_s"
  done
}

_pl_cmd_next_stage() {
  _curr=""
  while [ "$#" -gt 0 ]; do
    case "$1" in
      --current) _curr=$2; shift 2 ;;
      *) _pl_die_usage "next-stage: flag desconhecida: $1" ;;
    esac
  done
  [ -n "$_curr" ] || _pl_die_usage "next-stage: --current obrigatorio"
  _pl_is_valid_stage "$_curr" || _pl_die "etapa desconhecida: $_curr (use 'stages')" 1
  _take_next=0
  for _s in $_PL_STAGES_LIST; do
    if [ "$_take_next" = 1 ]; then
      printf '%s\n' "$_s"
      return 0
    fi
    [ "$_s" = "$_curr" ] && _take_next=1
  done
  # Caiu fora do loop -> ja na ultima etapa: sem proxima.
  return 0
}

_pl_cmd_prev_stage() {
  _curr=""
  while [ "$#" -gt 0 ]; do
    case "$1" in
      --current) _curr=$2; shift 2 ;;
      *) _pl_die_usage "prev-stage: flag desconhecida: $1" ;;
    esac
  done
  [ -n "$_curr" ] || _pl_die_usage "prev-stage: --current obrigatorio"
  _pl_is_valid_stage "$_curr" || _pl_die "etapa desconhecida: $_curr" 1
  _prev=""
  for _s in $_PL_STAGES_LIST; do
    if [ "$_s" = "$_curr" ]; then
      [ -n "$_prev" ] && printf '%s\n' "$_prev"
      return 0
    fi
    _prev=$_s
  done
  return 0
}

# detect-completion: artefato esperado por etapa.
#
# Fallback PAP (issue #3): briefing e constitution sao project-level. Quando
# `--projeto-alvo-path PAP` e passado, alem do feature-dir convencional, os
# paths do /initialize-docs sao aceitos:
#   briefing      -> $PAP/docs/01-briefing-discovery/briefing.md
#   constitution  -> $PAP/docs/constitution.md
_pl_cmd_detect_completion() {
  _fd=""
  _st=""
  _pap=""
  while [ "$#" -gt 0 ]; do
    case "$1" in
      --feature-dir)        _fd=$2;  shift 2 ;;
      --stage)              _st=$2;  shift 2 ;;
      --projeto-alvo-path)  _pap=$2; shift 2 ;;
      *) _pl_die_usage "detect-completion: flag desconhecida: $1" ;;
    esac
  done
  [ -n "$_fd" ] || _pl_die_usage "detect-completion: --feature-dir obrigatorio"
  [ -n "$_st" ] || _pl_die_usage "detect-completion: --stage obrigatorio"
  _pl_is_valid_stage "$_st" || _pl_die "detect-completion: etapa desconhecida: $_st" 2
  [ -d "$_fd" ] || _pl_die "detect-completion: feature-dir nao existe: $_fd" 1

  case "$_st" in
    briefing)
      # feature-dir OR (com PAP) hierarquia numerada do /initialize-docs.
      if [ -f "$_fd/briefing.md" ]; then
        return 0
      elif [ -n "$_pap" ] && [ -f "$_pap/docs/01-briefing-discovery/briefing.md" ]; then
        return 0
      else
        return 1
      fi
      ;;
    constitution)
      # feature-dir OR (com PAP) docs/constitution.md (root convencional).
      if [ -f "$_fd/constitution.md" ]; then
        return 0
      elif [ -n "$_pap" ] && [ -f "$_pap/docs/constitution.md" ]; then
        return 0
      else
        return 1
      fi
      ;;
    specify|clarify) [ -f "$_fd/spec.md" ]             || return 1 ;;
    plan)            [ -f "$_fd/plan.md" ]             || return 1 ;;
    checklist)
      # Qualquer .md dentro de checklists/ conta
      if [ ! -d "$_fd/checklists" ]; then
        return 1
      fi
      _found=$(find "$_fd/checklists" -maxdepth 1 -type f -name '*.md' 2>/dev/null | head -1)
      [ -n "$_found" ] || return 1
      ;;
    create-tasks)    [ -f "$_fd/tasks.md" ]            || return 1 ;;
    execute-task)
      # Pelo menos 1 marcacao [x] em tasks.md
      [ -f "$_fd/tasks.md" ] || return 1
      grep -q '^[[:space:]]*-[[:space:]]*\[x\]' "$_fd/tasks.md" 2>/dev/null || return 1
      ;;
    review-task|review-features)
      # Etapas de review nao deixam artefato persistente — sempre completas
      # (cabe ao orquestrador decidir invocar ou pular; aqui retornamos 0).
      return 0
      ;;
  esac
  return 0
}

# skill-conflict: detecta skill com mesmo nome em local + global.
# Local em <projeto-alvo>/.claude/skills/ ; global em ~/.claude/skills/.
_pl_cmd_skill_conflict() {
  _skill=""
  _pap=""
  while [ "$#" -gt 0 ]; do
    case "$1" in
      --skill)             _skill=$2; shift 2 ;;
      --projeto-alvo-path) _pap=$2;   shift 2 ;;
      *) _pl_die_usage "skill-conflict: flag desconhecida: $1" ;;
    esac
  done
  [ -n "$_skill" ] || _pl_die_usage "skill-conflict: --skill obrigatorio"
  [ -n "$_pap" ]   || _pl_die_usage "skill-conflict: --projeto-alvo-path obrigatorio"

  _local="$_pap/.claude/skills/$_skill"
  _global="${HOME:?HOME nao setado}/.claude/skills/$_skill"
  _has_local=0
  _has_global=0
  [ -d "$_local" ]  && _has_local=1
  [ -d "$_global" ] && _has_global=1

  if [ "$_has_local" = 1 ] && [ "$_has_global" = 1 ]; then
    # Conflito: ambas. Local vence.
    cat <<INFO
status: conflict
resolution: local-wins
local: $_local
global: $_global
recommendation: registrar Decisao informativa com refs aos dois paths
INFO
    return 0
  fi
  if [ "$_has_local" = 1 ] && [ "$_has_global" = 0 ]; then
    printf 'status: only-local\nlocal: %s\n' "$_local"
    return 2
  fi
  if [ "$_has_local" = 0 ] && [ "$_has_global" = 1 ]; then
    printf 'status: only-global\nglobal: %s\n' "$_global"
    return 1
  fi
  printf 'status: not-found\nskill: %s\n' "$_skill"
  return 3
}

# ---------- Dispatch ----------

if [ "$#" -lt 1 ]; then
  _pl_print_help
  exit 2
fi

_PL_SUBCMD=$1
shift

case "$_PL_SUBCMD" in
  stages)             _pl_cmd_stages "$@" ;;
  next-stage)         _pl_cmd_next_stage "$@" ;;
  prev-stage)         _pl_cmd_prev_stage "$@" ;;
  detect-completion)  _pl_cmd_detect_completion "$@" ;;
  skill-conflict)     _pl_cmd_skill_conflict "$@" ;;
  -h|--help|help)     _pl_print_help; exit 0 ;;
  *) _pl_die_usage "subcomando desconhecido: $_PL_SUBCMD (use --help)" ;;
esac
