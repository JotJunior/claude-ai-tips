#!/bin/sh
# report.sh — gera relatorio do agente-00C com 6 secoes (FR-011, SC-001).
#
# Ref: docs/specs/agente-00c/contracts/report-format.md
#      docs/specs/agente-00c/spec.md FR-011, SC-001
#      docs/specs/agente-00c/tasks.md FASE 8.1 + 8.2
#
# Subcomandos:
#   report.sh generate --state-dir DIR [--final] [--paragrafo-resumo TEXT]
#                      [--licoes-aprendidas TEXT]
#       — Renderiza relatorio em stdout. 6 secoes obrigatorias (cabecalho +
#         secoes 1..6 + apendice A). Secao 6 (Licoes Aprendidas) so e
#         preenchida se --final + --licoes-aprendidas; senao placeholder.
#         Secao 1 paragrafo so se --paragrafo-resumo passado; senao
#         placeholder neutro.
#       — IMPORTANTE: NAO aplica secrets-filter — caller deve fazer
#         externamente: `report.sh generate ... | secrets-filter.sh scrub
#         --env-file <PAP>/.env > <PAP>/.claude/agente-00c-report.md`
#
#   report.sh validate --report-file FILE
#       — Verifica presenca das 6 secoes obrigatorias via regex de headings.
#       — Exit 0 se completo, 1 se faltando alguma secao + nome em stderr.
#
# Exit codes:
#   0 sucesso
#   1 erro generico OU validacao falhou
#   2 uso incorreto
#
# POSIX sh + jq.

set -eu

_RP_NAME="report"

_rp_die_usage() { printf '%s: %s\n' "$_RP_NAME" "$1" >&2; exit 2; }
_rp_die()       { printf '%s: %s\n' "$_RP_NAME" "$1" >&2; exit "${2:-1}"; }

_rp_require_jq() {
  command -v jq >/dev/null 2>&1 \
    || _rp_die "jq nao encontrado no PATH" 1
}

_rp_iso_now() { date -u +%FT%TZ; }
_rp_state_file() { printf '%s/state.json\n' "$1"; }

# _rp_render_header STATE_FILE GERADO_EM
_rp_render_header() {
  jq -r --arg now "$2" '
    "# Relatorio do Agente-00C — \(.execucao.id)",
    "",
    "**Gerado em**: \($now)",
    "**Status no momento**: \(.execucao.status)",
    "**Versao do schema**: \(.schema_version)",
    "",
    "---",
    ""
  ' "$1"
}

# _rp_render_secao_1 STATE_FILE PARAGRAFO
_rp_render_secao_1() {
  _para=$2
  [ -n "$_para" ] || _para="(Paragrafo de resumo nao fornecido — orquestrador deve gerar via --paragrafo-resumo na invocacao final.)"
  jq -r --arg para "$_para" '
    "## 1. Resumo Executivo",
    "",
    "| Campo | Valor |",
    "|-------|-------|",
    "| ID Execucao | \(.execucao.id) |",
    "| Projeto-Alvo | \(.execucao.projeto_alvo_path) |",
    "| Descricao | \(.execucao.projeto_alvo_descricao) |",
    "| Stack final | \(.execucao.stack_sugerida // "nao aplicavel — execucao abortada antes de definir") |",
    "| Status | \(.execucao.status) |",
    "| Motivo termino | \(.execucao.motivo_termino // "(em andamento)") |",
    "| Iniciada em | \(.execucao.iniciada_em) |",
    "| Terminada em | \(.execucao.terminada_em // "ainda em andamento") |",
    "| Ondas executadas | \(.metricas_acumuladas.ondas_total // 0) |",
    "| Tool calls totais | \(.metricas_acumuladas.tool_calls_total // 0) |",
    "| Decisoes registradas | \(.metricas_acumuladas.decisoes_total // ((.decisoes // []) | length)) |",
    "| Bloqueios humanos | \(.metricas_acumuladas.bloqueios_humanos_total // ((.bloqueios_humanos // []) | length)) |",
    "| Sugestoes para skills globais | \(.metricas_acumuladas.sugestoes_skills_globais_total // ((.sugestoes // []) | length)) |",
    "| Issues abertas no toolkit | \(.metricas_acumuladas.issues_toolkit_abertas // 0) |",
    "| Profundidade max de subagentes | \(.metricas_acumuladas.profundidade_max_atingida // 1) |",
    "",
    $para,
    ""
  ' "$1"
}

# _rp_render_secao_2 STATE_FILE
_rp_render_secao_2() {
  jq -r '
    "## 2. Linha do Tempo",
    "",
    "| Onda | Inicio | Fim | Etapas | Tool calls | Wallclock | Termino |",
    "|------|--------|-----|--------|------------|-----------|---------|",
    (
      if (.ondas // []) | length == 0 then
        "| - | - | - | (nenhuma onda completa ainda) | - | - | - |"
      else
        (.ondas[] |
          "| \(.id) | \(.inicio) | \(.fim // "-") | \((.etapas_executadas // []) | join(", ")) | \(.tool_calls // 0) | \(.wallclock_seconds // 0)s | \(.motivo_termino // "(em andamento)") |"
        )
      end
    ),
    ""
  ' "$1"
}

# _rp_render_secao_3 STATE_FILE
_rp_render_secao_3() {
  jq -r '
    (.decisoes // []) as $decs
    | "## 3. Decisoes",
      "",
      "Total: \($decs | length) decisoes registradas.",
      "",
      "### 3.1 Por agente",
      "",
      "| Agente | Quantidade |",
      "|--------|------------|"
      ,
      (
        if ($decs | length) == 0 then
          "| (nenhuma) | 0 |"
        else
          ($decs | group_by(.agente) | map({agente: .[0].agente, n: length}) |
            .[] | "| \(.agente) | \(.n) |")
        end
      ),
      "",
      "### 3.2 Lista detalhada",
      "",
      (
        if ($decs | length) == 0 then
          "(Nenhuma decisao registrada nesta execucao.)"
        else
          ($decs[] |
            "#### \(.id) — \(.etapa) — \(.agente) — \(.timestamp)",
            "",
            "**Contexto**: \(.contexto)",
            "",
            "**Opcoes consideradas**: \((.opcoes_consideradas // []) | join(" / "))",
            "",
            "**Escolha**: \(.escolha)",
            "",
            "**Justificativa**: \(.justificativa)",
            "",
            "**Score**: \(if .score_justificativa == null then "(n/a — decisao do orquestrador)" else (.score_justificativa | tostring) end)",
            "",
            "**Referencias**: \((.referencias // []) | if length == 0 then "(nenhuma)" else join(", ") end)",
            "",
            "**Artefato originador**: \(.artefato_originador // "(nenhum)")",
            ""
          )
        end
      ),
      ""
  ' "$1"
}

# _rp_render_secao_4 STATE_FILE
_rp_render_secao_4() {
  jq -r '
    (.bloqueios_humanos // []) as $blocks
    | "## 4. Bloqueios Humanos",
      "",
      "Total: \($blocks | length) bloqueios.",
      "",
      "### 4.1 Pendentes (aguardando resposta)",
      "",
      (
        ($blocks | map(select(.status == "aguardando"))) as $pending
        | if ($pending | length) == 0 then
            "(Nenhum bloqueio pendente neste momento.)"
          else
            ($pending[] |
              "#### \(.id) — disparado em \(.disparado_em)",
              "",
              "**Pergunta**: \(.pergunta)",
              "",
              "**Contexto para resposta**: \(.contexto_para_resposta)",
              "",
              "**Opcoes recomendadas**:",
              ((.opcoes_recomendadas // [])
               | if length == 0 then "- (sem opcoes especificas)"
                 else (map("- " + .) | join("\n")) end),
              "",
              "**Status**: \(.status)",
              ""
            )
          end
      ),
      "",
      "### 4.2 Respondidos",
      "",
      (
        ($blocks | map(select(.status == "respondido"))) as $resp
        | if ($resp | length) == 0 then
            "(Nenhum bloqueio respondido nesta execucao.)"
          else
            ($resp[] |
              "#### \(.id) — disparado em \(.disparado_em)",
              "",
              "**Pergunta**: \(.pergunta)",
              "",
              "**Resposta humana**: \(.resposta_humana // "?")",
              "",
              "**Respondido em**: \(.respondido_em // "?")",
              ""
            )
          end
      ),
      "",
      "### 4.3 Sem bloqueios",
      "",
      (if ($blocks | length) == 0 then
         "Nenhum bloqueio humano nesta execucao."
       else
         "(Esta secao se aplica apenas a execucoes sem bloqueios — \($blocks | length) registrados acima.)"
       end),
      ""
  ' "$1"
}

# _rp_render_secao_5 STATE_FILE
_rp_render_secao_5() {
  jq -r '
    (.sugestoes // []) as $sugs
    | "## 5. Sugestoes para Skills Globais",
      "",
      "Total: \($sugs | length) sugestoes.",
      "",
      "### 5.1 Severidade impeditiva (viraram issues)",
      "",
      (
        ($sugs | map(select(.severidade == "impeditiva"))) as $imp
        | if ($imp | length) == 0 then
            "(Nenhuma sugestao impeditiva nesta execucao.)"
          else
            ($imp[] |
              "#### \(.id) — skill `\(.skill_afetada)` — issue \(.issue_aberta // "(nao aberta)")",
              "",
              "**Diagnostico**: \(.diagnostico)",
              "",
              "**Proposta**: \(.proposta)",
              ""
            )
          end
      ),
      "",
      "### 5.2 Severidade aviso",
      "",
      (
        ($sugs | map(select(.severidade == "aviso"))) as $av
        | if ($av | length) == 0 then
            "(Nenhuma sugestao com severidade aviso.)"
          else
            ($av[] |
              "#### \(.id) — skill `\(.skill_afetada)`",
              "",
              "**Diagnostico**: \(.diagnostico)",
              "",
              "**Proposta**: \(.proposta)",
              ""
            )
          end
      ),
      "",
      "### 5.3 Severidade informativa",
      "",
      (
        ($sugs | map(select(.severidade == "informativa"))) as $inf
        | if ($inf | length) == 0 then
            "(Nenhuma sugestao informativa.)"
          else
            ($inf[] |
              "#### \(.id) — skill `\(.skill_afetada)`",
              "",
              "**Diagnostico**: \(.diagnostico)",
              "",
              "**Proposta**: \(.proposta)",
              ""
            )
          end
      ),
      "",
      "### 5.4 Sem sugestoes",
      "",
      (if ($sugs | length) == 0 then
         "Nenhuma sugestao para skills globais nesta execucao."
       else
         "(Esta secao se aplica apenas a execucoes sem sugestoes — \($sugs | length) registradas acima.)"
       end),
      ""
  ' "$1"
}

# _rp_render_secao_6 LICOES IS_FINAL
_rp_render_secao_6() {
  printf '## 6. Licoes Aprendidas\n\n'
  if [ "$2" = 1 ] && [ -n "$1" ]; then
    printf '%s\n\n' "$1"
  elif [ "$2" = 1 ]; then
    printf '(Relatorio final invocado sem --licoes-aprendidas — operador deve preencher esta secao manualmente OU re-invocar com flag.)\n\n'
  else
    printf '(Sera preenchido no relatorio final.)\n\n'
  fi
}

# _rp_render_apendice STATE_FILE
_rp_render_apendice() {
  jq -r '
    "---",
    "",
    "**Apendice A — Caminhos relevantes**",
    "",
    "- Estado: `\(.execucao.projeto_alvo_path)/.claude/agente-00c-state/state.json`",
    "- Backups de estado: `\(.execucao.projeto_alvo_path)/.claude/agente-00c-state/state-history/`",
    "- Sugestoes detalhadas: `\(.execucao.projeto_alvo_path)/.claude/agente-00c-suggestions.md`",
    "- Whitelist: `\(.execucao.projeto_alvo_path)/.claude/agente-00c-whitelist`",
    "- Artefatos da pipeline: `\(.execucao.projeto_alvo_path)/docs/specs/<feature>/`",
    ""
  ' "$1"
}

_rp_cmd_generate() {
  _sd=""
  _final=0
  _para=""
  _licoes=""
  while [ "$#" -gt 0 ]; do
    case "$1" in
      --state-dir)          _sd=$2;     shift 2 ;;
      --final)              _final=1;   shift ;;
      --paragrafo-resumo)   _para=$2;   shift 2 ;;
      --licoes-aprendidas)  _licoes=$2; shift 2 ;;
      *) _rp_die_usage "generate: flag desconhecida: $1" ;;
    esac
  done
  [ -n "$_sd" ] || _rp_die_usage "generate: --state-dir obrigatorio"
  _rp_require_jq
  _sf=$(_rp_state_file "$_sd")
  [ -f "$_sf" ] || _rp_die "generate: state.json ausente em $_sd" 1

  _now=$(_rp_iso_now)
  _rp_render_header "$_sf" "$_now"
  _rp_render_secao_1 "$_sf" "$_para"
  _rp_render_secao_2 "$_sf"
  _rp_render_secao_3 "$_sf"
  _rp_render_secao_4 "$_sf"
  _rp_render_secao_5 "$_sf"
  _rp_render_secao_6 "$_licoes" "$_final"
  _rp_render_apendice "$_sf"
}

_rp_cmd_validate() {
  _rf=""
  while [ "$#" -gt 0 ]; do
    case "$1" in
      --report-file) _rf=$2; shift 2 ;;
      *) _rp_die_usage "validate: flag desconhecida: $1" ;;
    esac
  done
  [ -n "$_rf" ] || _rp_die_usage "validate: --report-file obrigatorio"
  [ -f "$_rf" ] || _rp_die "validate: report-file nao existe: $_rf" 1

  _missing=""
  for _h in '## 1. Resumo Executivo' \
            '## 2. Linha do Tempo' \
            '## 3. Decisoes' \
            '## 4. Bloqueios Humanos' \
            '## 5. Sugestoes para Skills Globais' \
            '## 6. Licoes Aprendidas'; do
    if ! grep -qF -- "$_h" "$_rf"; then
      _missing="$_missing
  - $_h"
    fi
  done

  if [ -z "$_missing" ]; then
    return 0
  fi
  printf '%s: relatorio incompleto — secoes faltando:%s\n' \
    "$_RP_NAME" "$_missing" >&2
  exit 1
}

# ---------- Dispatch ----------

if [ "$#" -lt 1 ]; then
  cat >&2 <<'HELP'
report.sh — gera relatorio do agente-00C com 6 secoes (FR-011, SC-001).

USO:
  report.sh generate --state-dir DIR [--final] [--paragrafo-resumo TEXT]
                                      [--licoes-aprendidas TEXT]
  report.sh validate --report-file FILE

IMPORTANTE: caller deve aplicar secrets-filter externamente:

  report.sh generate --state-dir <SD> [...] \
    | secrets-filter.sh scrub --env-file <PAP>/.env \
    > <PAP>/.claude/agente-00c-report.md
  report.sh validate --report-file <PAP>/.claude/agente-00c-report.md

EXIT (validate):
  0 todas as 6 secoes presentes
  1 alguma secao faltando (lista em stderr)
HELP
  exit 2
fi

_RP_SUBCMD=$1
shift

case "$_RP_SUBCMD" in
  generate)        _rp_cmd_generate "$@" ;;
  validate)        _rp_cmd_validate "$@" ;;
  -h|--help|help)  exit 0 ;;
  *) _rp_die_usage "subcomando desconhecido: $_RP_SUBCMD" ;;
esac
