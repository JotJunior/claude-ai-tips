# install.sh — comando `cstk install`.
#
# Ref: docs/specs/cstk-cli/contracts/cli-commands.md §install
#      docs/specs/cstk-cli/spec.md FR-001/002/007/009/011/012
#      docs/specs/cstk-cli/quickstart.md Scenario 1
#
# Funcao exportada:
#   install_main "$@"   — entry point chamado por cli/cstk
#
# Sintaxe:
#   cstk install [SKILL...] [--profile NAME] [--scope global|project]
#                [--from URL] [--dry-run] [--yes] [--interactive] [--help]
#
# Resolucao de URL (--from):
#   - URL absoluta (http://, https://, file://) -> usada como tarball_url;
#     sha256_url e tarball_url + ".sha256"
#   - Sem --from: cai em $CSTK_RELEASE_URL (escape hatch para fixtures de teste);
#     se ausente, aborta com mensagem apontando para o bootstrap (FASE 3.2 ainda
#     vai entregar o resolver de "ultima release" via API do GitHub)
#
# Hooks de language-* (FR-009b/c/d): integracao em FASE 7.2; install desta
# fase apenas copia skills.
#
# Modo interativo (FR-009): integracao em FASE 8.1.5; install aceita a flag
# mas reporta nao-implementado com exit 2 ate la.
#
# Exit codes (POSIX + contract):
#   0 sucesso (ou dry-run completo)
#   1 erro geral (rede, filesystem, checksum, catalog malformado)
#   2 uso incorreto (flag invalida, profile/skill desconhecido, --interactive)
#   3 lock detido por outro processo
#
# POSIX sh + tar/curl/find/cp. Sourceia common, compat, http, lock, tarball,
# hash, manifest, profiles do mesmo cli/lib/.

if [ -n "${_CSTK_INSTALL_LOADED:-}" ]; then
  return 0 2>/dev/null
fi
_CSTK_INSTALL_LOADED=1

# shellcheck source=/dev/null
. "${CSTK_LIB:?CSTK_LIB must be set}/common.sh"
# shellcheck source=/dev/null
. "${CSTK_LIB}/compat.sh"
# shellcheck source=/dev/null
. "${CSTK_LIB}/http.sh"
# shellcheck source=/dev/null
. "${CSTK_LIB}/lock.sh"
# shellcheck source=/dev/null
. "${CSTK_LIB}/tarball.sh"
# shellcheck source=/dev/null
. "${CSTK_LIB}/hash.sh"
# shellcheck source=/dev/null
. "${CSTK_LIB}/manifest.sh"
# shellcheck source=/dev/null
. "${CSTK_LIB}/profiles.sh"

_install_print_help() {
  cat >&2 <<'HELP'
cstk install — instala skills do toolkit em escopo global ou de projeto.

USO:
  cstk install [SKILL...] [--profile NAME] [--scope global|project]
               [--from URL] [--dry-run] [--yes] [--interactive]

ARGS:
  SKILL...       Cherry-pick por nome (uniao com --profile, se ambos).

OPCOES:
  --profile N    Perfil declarado no catalog. Default: sdd.
  --scope S      global (~/.claude/skills/) ou project (./.claude/skills/).
                 Default: global.
  --from URL     URL do tarball (.tar.gz). Default: $CSTK_RELEASE_URL ou erro
                 (resolver de ultima release vem na FASE 3.2).
  --dry-run      Mostra plano sem escrever nada.
  --yes          Pula confirmacoes interativas.
  --interactive  Seletor numerado em TTY (FASE 8 — nao implementado ainda).
  --help         Imprime esta mensagem.

EXEMPLOS:
  cstk install --from file:///tmp/release/cstk-v0.1.0.tar.gz
  cstk install specify plan --profile sdd --dry-run
  cstk install --scope project --from URL
HELP
}

# install_main: entry point. Argumentos parseados e fluxo orquestrado em
# fases (parse -> URL -> stage -> selecao -> apply -> summary).
install_main() {
  _install_reset_state

  if ! _install_parse_args "$@"; then
    return 2
  fi

  if [ "$_install_help" = 1 ]; then
    _install_print_help
    return 0
  fi

  if [ "$_install_interactive" = 1 ]; then
    log_error "install: --interactive nao implementado nesta fase (vem em FASE 8)"
    log_error "         use --profile NAME ou cherry-pick SKILL... por enquanto"
    return 2
  fi

  if ! _install_resolve_scope_dir; then
    return 1
  fi

  if ! _install_resolve_urls; then
    return 1
  fi

  if ! _install_validate_project_scope; then
    return 1
  fi

  # Stage download em tempdir privado. Trap garante cleanup mesmo em interrupt.
  _install_staged=$(mktemp -d 2>/dev/null) || {
    log_error "install: mktemp -d falhou"
    return 1
  }
  trap '_install_cleanup' EXIT INT TERM

  if ! download_and_verify "$_install_tarball_url" "$_install_sha256_url" "$_install_staged"; then
    return 1
  fi

  if ! _install_locate_catalog; then
    return 1
  fi

  if ! _install_resolve_selection; then
    return 2
  fi

  if [ -z "$_install_selection" ]; then
    log_warn "install: nenhuma skill selecionada"
    _install_emit_summary
    return 0
  fi

  # Lock + scope dir creation (skip em dry-run; nada e escrito).
  if [ "$_install_dry_run" != 1 ]; then
    if ! mkdir -p -- "$_install_scope_dir" 2>/dev/null; then
      log_error "install: nao foi possivel criar $_install_scope_dir"
      return 1
    fi
    if ! acquire_lock "$_install_scope_dir/.cstk.lock"; then
      return 3
    fi
    # acquire_lock substitui o trap; re-instala combinacao (release + cleanup).
    trap '_install_cleanup' EXIT INT TERM
  fi

  _install_now=$(iso_now_utc)
  _install_manifest_path=$(manifest_default_path "$_install_scope") || {
    log_error "install: nao consegui resolver manifest path"
    return 1
  }

  # Itera selecao. for-loop com IFS=newline para nao perder counters em
  # subshell (pipe-based while-read teria esse bug).
  _install_old_ifs=$IFS
  IFS='
'
  for _install_skill in $_install_selection; do
    IFS=$_install_old_ifs
    _install_process_skill "$_install_skill" || {
      log_error "install: falha ao processar $_install_skill"
      return 1
    }
    IFS='
'
  done
  IFS=$_install_old_ifs

  _install_emit_summary
  return 0
}

# _install_reset_state: zera variaveis globais entre invocacoes (testes
# podem chamar install_main multiplas vezes via dot-source).
_install_reset_state() {
  _install_help=0
  _install_interactive=0
  _install_dry_run=0
  _install_yes=0
  _install_scope=global
  _install_profile=""
  _install_explicit_skills=""
  _install_from=""
  _install_tarball_url=""
  _install_sha256_url=""
  _install_scope_dir=""
  _install_staged=""
  _install_catalog_dir=""
  _install_release_version=""
  _install_selection=""
  _install_manifest_path=""
  _install_now=""
  _install_count_installed=0
  _install_count_updated=0
  _install_count_preserved=0
  _install_count_missing=0
}

_install_cleanup() {
  if [ -n "${_CSTK_LOCK_DIR:-}" ]; then
    release_lock 2>/dev/null || :
  fi
  if [ -n "${_install_staged:-}" ] && [ -d "$_install_staged" ]; then
    rm -rf -- "$_install_staged" 2>/dev/null || :
  fi
}

# _install_parse_args: traduz argv em variaveis _install_*. Aceita flags em
# qualquer ordem; --profile/--scope/--from exigem valor; demais sao booleanas.
_install_parse_args() {
  while [ "$#" -gt 0 ]; do
    case "$1" in
      --help|-h) _install_help=1; shift ;;
      --interactive|-i) _install_interactive=1; shift ;;
      --dry-run) _install_dry_run=1; shift ;;
      --yes|-y) _install_yes=1; shift ;;
      --profile)
        if [ "$#" -lt 2 ] || [ -z "$2" ]; then
          log_error "install: --profile exige valor"
          return 1
        fi
        _install_profile=$2
        shift 2
        ;;
      --profile=*)
        _install_profile=${1#--profile=}
        if [ -z "$_install_profile" ]; then
          log_error "install: --profile= sem valor"
          return 1
        fi
        shift
        ;;
      --scope)
        if [ "$#" -lt 2 ]; then
          log_error "install: --scope exige valor (global|project)"
          return 1
        fi
        case "$2" in
          global|project) _install_scope=$2 ;;
          *) log_error "install: --scope invalido: $2 (use global|project)"; return 1 ;;
        esac
        shift 2
        ;;
      --scope=*)
        _install_scope=${1#--scope=}
        case "$_install_scope" in
          global|project) ;;
          *) log_error "install: --scope invalido: $_install_scope"; return 1 ;;
        esac
        shift
        ;;
      --from)
        if [ "$#" -lt 2 ] || [ -z "$2" ]; then
          log_error "install: --from exige valor (URL ou tag)"
          return 1
        fi
        _install_from=$2
        shift 2
        ;;
      --from=*)
        _install_from=${1#--from=}
        shift
        ;;
      --) shift; break ;;
      -*)
        log_error "install: flag desconhecida: $1"
        return 1
        ;;
      *)
        # SKILL cherry-pick. Concatena com newline para sort -u depois.
        if [ -z "$_install_explicit_skills" ]; then
          _install_explicit_skills=$1
        else
          _install_explicit_skills="$_install_explicit_skills
$1"
        fi
        shift
        ;;
    esac
  done

  # Posicionais apos `--`.
  while [ "$#" -gt 0 ]; do
    if [ -z "$_install_explicit_skills" ]; then
      _install_explicit_skills=$1
    else
      _install_explicit_skills="$_install_explicit_skills
$1"
    fi
    shift
  done

  # Default profile = sdd quando nada e informado (FR-009).
  if [ -z "$_install_profile" ] && [ -z "$_install_explicit_skills" ]; then
    _install_profile=sdd
  fi
  return 0
}

# _install_resolve_scope_dir: traduz scope -> path.
_install_resolve_scope_dir() {
  case "$_install_scope" in
    global)
      _install_scope_dir="${HOME:?HOME nao setado}/.claude/skills"
      ;;
    project)
      _install_scope_dir="./.claude/skills"
      ;;
    *)
      log_error "install: scope invalido (bug interno): $_install_scope"
      return 1
      ;;
  esac
  return 0
}

# _install_validate_project_scope: heuristica para evitar instalar em CWD
# que claramente nao e projeto. Skipa em --yes ou em scope=global.
_install_validate_project_scope() {
  if [ "$_install_scope" != project ]; then
    return 0
  fi
  if [ "$_install_yes" = 1 ]; then
    return 0
  fi
  # Indicadores de projeto (algum precisa estar presente no CWD).
  if [ -d ./.git ] || [ -f ./package.json ] || [ -f ./go.mod ] \
     || [ -f ./Cargo.toml ] || [ -f ./pyproject.toml ] \
     || [ -f ./requirements.txt ] || [ -f ./pom.xml ] \
     || [ -f ./Gemfile ] || [ -f ./CLAUDE.md ] || [ -d ./.claude ]; then
    return 0
  fi
  log_error "install: CWD nao parece ser um projeto (sem .git/, package.json, go.mod, etc.)"
  log_error "         re-execute com --yes para confirmar instalacao em $(pwd)"
  return 1
}

# _install_resolve_urls: mapeia --from / env para o par (tarball, sha256).
_install_resolve_urls() {
  if [ -z "$_install_from" ]; then
    _install_from=${CSTK_RELEASE_URL:-}
  fi
  if [ -z "$_install_from" ]; then
    log_error "install: --from URL ausente e \$CSTK_RELEASE_URL nao setado"
    log_error "         resolver de \"ultima release\" vem na FASE 3.2 (bootstrap)"
    log_error "         use --from <url-do-tarball> por enquanto"
    return 1
  fi
  case "$_install_from" in
    http://*|https://*|file://*)
      _install_tarball_url=$_install_from
      _install_sha256_url="${_install_from}.sha256"
      ;;
    *)
      log_error "install: --from precisa ser URL (http:// https:// file://); recebido: $_install_from"
      log_error "         resolver de tag (--from v3.2.0) vem na FASE 3.2 + 9.2"
      return 1
      ;;
  esac
  return 0
}

# _install_locate_catalog: encontra catalog/ na arvore extraida e valida
# presenca de VERSION + profiles.txt.
_install_locate_catalog() {
  # find -maxdepth e BSD/GNU; coerente com tests/run.sh.
  _install_catalog_dir=$(find "$_install_staged" -maxdepth 3 -type d -name catalog 2>/dev/null | head -1)
  if [ -z "$_install_catalog_dir" ] || [ ! -d "$_install_catalog_dir" ]; then
    log_error "install: catalog/ nao encontrado no tarball"
    return 1
  fi
  if [ ! -f "$_install_catalog_dir/VERSION" ]; then
    log_error "install: $_install_catalog_dir/VERSION ausente"
    return 1
  fi
  if [ ! -f "$_install_catalog_dir/profiles.txt" ]; then
    log_error "install: $_install_catalog_dir/profiles.txt ausente"
    return 1
  fi
  _install_release_version=$(head -n 1 -- "$_install_catalog_dir/VERSION" | tr -d '[:space:]')
  if [ -z "$_install_release_version" ]; then
    log_error "install: $_install_catalog_dir/VERSION vazio"
    return 1
  fi
  return 0
}

# _install_resolve_selection: combina cherry-pick explicito + profile,
# dedupa e ordena. Resultado em $_install_selection (uma skill por linha).
_install_resolve_selection() {
  _install_resolved_profile=""
  if [ -n "$_install_profile" ]; then
    _install_resolved_profile=$(resolve_profile "$_install_catalog_dir/profiles.txt" "$_install_profile") || {
      return 1
    }
  fi
  _install_selection=$(
    {
      [ -n "$_install_explicit_skills" ] && printf '%s\n' "$_install_explicit_skills"
      [ -n "$_install_resolved_profile" ] && printf '%s\n' "$_install_resolved_profile"
    } | awk 'NF>0' | sort -u
  )
  return 0
}

# _install_find_skill_src: imprime path da skill no catalog (skills/ ou
# language/*/skills/), ou nada se ausente.
_install_find_skill_src() {
  _isfs_skill=$1
  if [ -d "$_install_catalog_dir/skills/$_isfs_skill" ]; then
    printf '%s\n' "$_install_catalog_dir/skills/$_isfs_skill"
    return 0
  fi
  if [ -d "$_install_catalog_dir/language" ]; then
    for _isfs_lang in "$_install_catalog_dir/language"/*; do
      [ -d "$_isfs_lang/skills/$_isfs_skill" ] || continue
      printf '%s\n' "$_isfs_lang/skills/$_isfs_skill"
      return 0
    done
  fi
  return 1
}

# _install_process_skill: deteccao de estado (3 ramos) + acao correspondente.
_install_process_skill() {
  _ips_skill=$1
  _ips_src=$(_install_find_skill_src "$_ips_skill") || _ips_src=""
  if [ -z "$_ips_src" ]; then
    log_warn "install: skill desconhecida no catalog: $_ips_skill"
    _install_count_missing=$((_install_count_missing + 1))
    return 0
  fi

  _ips_dst="$_install_scope_dir/$_ips_skill"

  # Ramo 1: nao existe em disco -> install fresh
  # Ramo 2: existe em disco e esta no manifest -> overwrite (treat as update)
  # Ramo 3: existe em disco e nao esta no manifest -> preserve (FR-007)
  if [ ! -e "$_ips_dst" ]; then
    _install_apply "$_ips_skill" "$_ips_src" "$_ips_dst" install
    return $?
  fi

  if lookup_entry "$_install_manifest_path" "$_ips_skill" >/dev/null 2>&1; then
    _install_apply "$_ips_skill" "$_ips_src" "$_ips_dst" update
    return $?
  fi

  log_warn "install: preservando skill nao-manifestada (third-party): $_ips_skill"
  _install_count_preserved=$((_install_count_preserved + 1))
  return 0
}

# _install_apply: executa copia + manifest upsert (ou apenas reporta em dry-run).
_install_apply() {
  _ia_skill=$1
  _ia_src=$2
  _ia_dst=$3
  _ia_action=$4

  if [ "$_install_dry_run" = 1 ]; then
    log_info "[dry-run] $_ia_action: $_ia_skill"
  else
    rm -rf -- "$_ia_dst" 2>/dev/null || :
    if ! cp -R -- "$_ia_src" "$_ia_dst"; then
      log_error "install: cp -R falhou para $_ia_skill"
      return 1
    fi
    _ia_sha=$(hash_dir "$_ia_dst") || {
      log_error "install: hash_dir falhou para $_ia_skill"
      return 1
    }
    if ! upsert_entry "$_install_manifest_path" "$_ia_skill" \
                      "$_install_release_version" "$_ia_sha" "$_install_now"; then
      log_error "install: upsert manifest falhou para $_ia_skill"
      return 1
    fi
  fi

  case "$_ia_action" in
    install) _install_count_installed=$((_install_count_installed + 1)) ;;
    update)  _install_count_updated=$((_install_count_updated + 1)) ;;
  esac
  return 0
}

# _install_emit_summary: bloco em stderr conforme contract §install.
_install_emit_summary() {
  _ies_prefix=""
  if [ "$_install_dry_run" = 1 ]; then
    _ies_prefix="(dry-run) "
  fi
  {
    printf '==> %scstk install summary\n' "$_ies_prefix"
    printf '  installed: %d\n' "$_install_count_installed"
    printf '  updated: %d\n' "$_install_count_updated"
    printf '  preserved (third-party): %d\n' "$_install_count_preserved"
    printf '  missing from catalog: %d\n' "$_install_count_missing"
    printf '  scope: %s\n' "$_install_scope"
    printf '  toolkit version: %s\n' "${_install_release_version:-?}"
  } >&2
}
