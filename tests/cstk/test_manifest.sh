#!/bin/sh
# test_manifest.sh — cobre cli/lib/manifest.sh
#
# Cenarios cobrem:
#   - Schema detection (v1 OK, header desconhecido aborta)
#   - read em manifest inexistente / vazio / com entradas
#   - write_manifest atomico (header presente, dados via stdin)
#   - upsert_entry: novo (append), existente (replace), idempotencia
#   - remove_entry: existente (remove), inexistente (no-op)
#   - lookup_entry: exit 0 se encontra, exit 1 se nao
#   - manifest_default_path para global e project
#   - protecao contra schema desconhecido (versao futura)

TESTS_ROOT="${TESTS_ROOT:-$(cd "$(dirname "$0")/.." && pwd)}"
REPO_ROOT="${REPO_ROOT:-$(cd "$TESTS_ROOT/.." && pwd)}"

. "$TESTS_ROOT/lib/harness.sh"

CSTK_LIB="$REPO_ROOT/cli/lib"
export CSTK_LIB

# Helper: escreve manifest valido com N entradas no path dado.
_seed_manifest() {
  _path=$1; shift
  mkdir -p "$(dirname "$_path")"
  {
    printf '# cstk manifest v1\n'
    printf '# schema: <skill-name>\\t<toolkit-version>\\t<source-sha256>\\t<installed-at-iso>\n'
    for line in "$@"; do
      printf '%s\n' "$line"
    done
  } > "$_path"
}

# ==== detect_schema_version ====

scenario_detect_schema_v1() {
  _m="$TMPDIR_TEST/.cstk-manifest"
  _seed_manifest "$_m" "specify	3.2.0	abc123	2026-04-22T00:00:00Z"
  capture sh -c ". $CSTK_LIB/manifest.sh && detect_schema_version $_m"
  if [ "$_CAPTURED_EXIT" != "0" ]; then
    _fail "detect v1" "exit $_CAPTURED_EXIT; stderr=$_CAPTURED_STDERR"
    return 1
  fi
  if [ "$_CAPTURED_STDOUT" != "v1" ]; then
    _fail "detect v1 stdout" "esperado 'v1', obtido '$_CAPTURED_STDOUT'"
    return 1
  fi
}

scenario_detect_schema_inexistente_ok() {
  # Manifest inexistente == "v1" (sera criado com header v1)
  capture sh -c ". $CSTK_LIB/manifest.sh && detect_schema_version $TMPDIR_TEST/no-existe.txt"
  if [ "$_CAPTURED_EXIT" != "0" ]; then
    _fail "detect inexistente" "exit $_CAPTURED_EXIT"
    return 1
  fi
  [ "$_CAPTURED_STDOUT" = "v1" ] || { _fail "detect inexistente stdout" "$_CAPTURED_STDOUT"; return 1; }
}

scenario_detect_schema_desconhecido_aborta() {
  _m="$TMPDIR_TEST/.cstk-manifest-bogus"
  printf '# cstk manifest v999-future\nspec\t9.0.0\txxx\t2050-01-01T00:00:00Z\n' > "$_m"
  capture sh -c ". $CSTK_LIB/manifest.sh && detect_schema_version $_m"
  if [ "$_CAPTURED_EXIT" != "1" ]; then
    _fail "detect schema futuro" "exit esperado 1, obtido $_CAPTURED_EXIT"
    return 1
  fi
  assert_stderr_contains "header desconhecido" || return 1
}

# ==== read_manifest ====

scenario_read_inexistente_vazio() {
  capture sh -c ". $CSTK_LIB/manifest.sh && read_manifest $TMPDIR_TEST/nada.tsv"
  if [ "$_CAPTURED_EXIT" != "0" ]; then
    _fail "read inexistente exit" "$_CAPTURED_EXIT"
    return 1
  fi
  if [ -n "$_CAPTURED_STDOUT" ]; then
    _fail "read inexistente stdout" "esperava vazio, obtido '$_CAPTURED_STDOUT'"
    return 1
  fi
}

scenario_read_pula_comentarios() {
  _m="$TMPDIR_TEST/.cstk-manifest"
  _seed_manifest "$_m" \
    "specify	3.2.0	abc	2026-04-22T00:00:00Z" \
    "plan	3.2.0	def	2026-04-22T00:00:00Z"
  capture sh -c ". $CSTK_LIB/manifest.sh && read_manifest $_m"
  if [ "$_CAPTURED_EXIT" != "0" ]; then
    _fail "read exit" "$_CAPTURED_EXIT"
    return 1
  fi
  # Saida: 2 linhas; sem comentarios; sem header
  _count=$(printf '%s\n' "$_CAPTURED_STDOUT" | wc -l | awk '{print $1}')
  if [ "$_count" != "2" ]; then
    _fail "read count" "esperado 2 linhas, obtido $_count: $_CAPTURED_STDOUT"
    return 1
  fi
  echo "$_CAPTURED_STDOUT" | grep -qE '^specify\b' || { _fail "read specify" "linha specify ausente"; return 1; }
  echo "$_CAPTURED_STDOUT" | grep -qE '^plan\b' || { _fail "read plan" "linha plan ausente"; return 1; }
  echo "$_CAPTURED_STDOUT" | grep -q '^#' && { _fail "read comentarios" "comentarios vazaram para output"; return 1; }
  return 0
}

# ==== write_manifest ====

scenario_write_cria_com_header() {
  _m="$TMPDIR_TEST/skills/.cstk-manifest"
  mkdir -p "$(dirname "$_m")"
  capture sh -c ". $CSTK_LIB/manifest.sh && printf 'foo\t1.0\tabc\t2026-01-01T00:00:00Z\n' | write_manifest $_m"
  if [ "$_CAPTURED_EXIT" != "0" ]; then
    _fail "write exit" "$_CAPTURED_EXIT; stderr=$_CAPTURED_STDERR"
    return 1
  fi
  if [ ! -f "$_m" ]; then
    _fail "write arquivo nao criado" "$_m"
    return 1
  fi
  head -n 1 "$_m" | grep -q '^# cstk manifest v1$' || { _fail "write header" "$(head -n 1 $_m)"; return 1; }
  grep -q '^foo	1.0	abc	2026-01-01T00:00:00Z$' "$_m" || { _fail "write data" "linha data ausente"; return 1; }
}

scenario_write_atomico_sobrescreve() {
  _m="$TMPDIR_TEST/skills/.cstk-manifest"
  mkdir -p "$(dirname "$_m")"
  _seed_manifest "$_m" "old	0.1	xxx	2024-01-01T00:00:00Z"
  capture sh -c ". $CSTK_LIB/manifest.sh && printf 'new\t2.0\tyyy\t2026-04-24T00:00:00Z\n' | write_manifest $_m"
  if [ "$_CAPTURED_EXIT" != "0" ]; then
    _fail "write sobrescrita exit" "$_CAPTURED_EXIT"
    return 1
  fi
  grep -q '^new	2.0	yyy	2026-04-24T00:00:00Z$' "$_m" || { _fail "write nova entrada" ""; return 1; }
  grep -q '^old	0.1' "$_m" && { _fail "write nao sobrescreveu" "old ainda presente"; return 1; }
  return 0
}

scenario_write_dir_pai_inexistente_falha() {
  capture sh -c ". $CSTK_LIB/manifest.sh && printf 'x\t1\tA\tts\n' | write_manifest /nao/existe/jamais/.cstk-manifest"
  if [ "$_CAPTURED_EXIT" != "1" ]; then
    _fail "write dir pai ausente" "exit esperado 1, obtido $_CAPTURED_EXIT"
    return 1
  fi
  assert_stderr_contains "nao existe" || return 1
}

# ==== upsert_entry ====

scenario_upsert_skill_nova_append() {
  _m="$TMPDIR_TEST/skills/.cstk-manifest"
  mkdir -p "$(dirname "$_m")"
  capture sh -c ". $CSTK_LIB/manifest.sh && upsert_entry $_m specify 3.2.0 sha-spec 2026-04-22T00:00:00Z"
  if [ "$_CAPTURED_EXIT" != "0" ]; then
    _fail "upsert nova exit" "$_CAPTURED_EXIT; stderr=$_CAPTURED_STDERR"
    return 1
  fi
  grep -q '^specify	3.2.0	sha-spec	' "$_m" || { _fail "upsert nova ausente" ""; return 1; }
}

scenario_upsert_skill_existente_replace() {
  _m="$TMPDIR_TEST/skills/.cstk-manifest"
  mkdir -p "$(dirname "$_m")"
  _seed_manifest "$_m" \
    "specify	3.2.0	old-sha	2026-04-22T00:00:00Z" \
    "plan	3.2.0	plan-sha	2026-04-22T00:00:00Z"
  capture sh -c ". $CSTK_LIB/manifest.sh && upsert_entry $_m specify 3.3.0 NEW-sha 2026-04-24T00:00:00Z"
  if [ "$_CAPTURED_EXIT" != "0" ]; then
    _fail "upsert replace exit" "$_CAPTURED_EXIT"
    return 1
  fi
  # specify deve ter nova versao
  grep -q '^specify	3.3.0	NEW-sha	2026-04-24T00:00:00Z$' "$_m" || { _fail "upsert replace nova" ""; return 1; }
  # E nao deve ter a antiga
  grep -q '^specify	3.2.0	old-sha' "$_m" && { _fail "upsert replace antiga" "ainda presente"; return 1; }
  # plan deve continuar la, intocado
  grep -q '^plan	3.2.0	plan-sha	' "$_m" || { _fail "upsert preservou plan" ""; return 1; }
  # Apenas 1 entry para specify
  _count=$(grep -c '^specify\b' "$_m")
  if [ "$_count" != "1" ]; then
    _fail "upsert duplicacao" "esperado 1 specify, obtido $_count"
    return 1
  fi
  return 0
}

scenario_upsert_idempotente() {
  _m="$TMPDIR_TEST/skills/.cstk-manifest"
  mkdir -p "$(dirname "$_m")"
  sh -c ". $CSTK_LIB/manifest.sh && upsert_entry $_m specify 1.0 abc 2026-01-01T00:00:00Z" || return 1
  _h1=$(sha256sum "$_m" 2>/dev/null | awk '{print $1}' || shasum -a 256 "$_m" | awk '{print $1}')
  sh -c ". $CSTK_LIB/manifest.sh && upsert_entry $_m specify 1.0 abc 2026-01-01T00:00:00Z" || return 1
  _h2=$(sha256sum "$_m" 2>/dev/null | awk '{print $1}' || shasum -a 256 "$_m" | awk '{print $1}')
  if [ "$_h1" != "$_h2" ]; then
    _fail "upsert idempotencia" "hash mudou apos re-upsert identico: $_h1 vs $_h2"
    return 1
  fi
}

# ==== remove_entry ====

scenario_remove_skill_existente() {
  _m="$TMPDIR_TEST/skills/.cstk-manifest"
  mkdir -p "$(dirname "$_m")"
  _seed_manifest "$_m" \
    "specify	3.2.0	x	ts" \
    "plan	3.2.0	y	ts"
  capture sh -c ". $CSTK_LIB/manifest.sh && remove_entry $_m specify"
  if [ "$_CAPTURED_EXIT" != "0" ]; then
    _fail "remove exit" "$_CAPTURED_EXIT"
    return 1
  fi
  grep -q '^specify\b' "$_m" && { _fail "remove nao removeu" "specify ainda no arquivo"; return 1; }
  grep -q '^plan	3.2.0' "$_m" || { _fail "remove apagou demais" "plan tambem sumiu"; return 1; }
  return 0
}

scenario_remove_inexistente_noop() {
  _m="$TMPDIR_TEST/skills/.cstk-manifest"
  mkdir -p "$(dirname "$_m")"
  _seed_manifest "$_m" "specify	3.2.0	x	ts"
  capture sh -c ". $CSTK_LIB/manifest.sh && remove_entry $_m nao-existe"
  if [ "$_CAPTURED_EXIT" != "0" ]; then
    _fail "remove no-op exit" "$_CAPTURED_EXIT"
    return 1
  fi
  grep -q '^specify\b' "$_m" || { _fail "remove no-op preserva" "specify foi removido por engano"; return 1; }
}

scenario_remove_manifest_inexistente_noop() {
  capture sh -c ". $CSTK_LIB/manifest.sh && remove_entry $TMPDIR_TEST/nao-existe.tsv qualquer"
  if [ "$_CAPTURED_EXIT" != "0" ]; then
    _fail "remove arquivo ausente" "exit esperado 0, obtido $_CAPTURED_EXIT"
    return 1
  fi
}

# ==== lookup_entry ====

scenario_lookup_encontra() {
  _m="$TMPDIR_TEST/skills/.cstk-manifest"
  mkdir -p "$(dirname "$_m")"
  _seed_manifest "$_m" \
    "specify	3.2.0	abc	2026-04-22T00:00:00Z" \
    "plan	3.2.0	def	2026-04-22T00:00:00Z"
  capture sh -c ". $CSTK_LIB/manifest.sh && lookup_entry $_m plan"
  if [ "$_CAPTURED_EXIT" != "0" ]; then
    _fail "lookup encontra exit" "$_CAPTURED_EXIT"
    return 1
  fi
  if [ "$_CAPTURED_STDOUT" != "plan	3.2.0	def	2026-04-22T00:00:00Z" ]; then
    _fail "lookup encontra valor" "stdout='$_CAPTURED_STDOUT'"
    return 1
  fi
}

scenario_lookup_nao_encontra() {
  _m="$TMPDIR_TEST/skills/.cstk-manifest"
  mkdir -p "$(dirname "$_m")"
  _seed_manifest "$_m" "specify	3.2.0	abc	ts"
  capture sh -c ". $CSTK_LIB/manifest.sh && lookup_entry $_m nao-existe"
  if [ "$_CAPTURED_EXIT" != "1" ]; then
    _fail "lookup ausente" "exit esperado 1, obtido $_CAPTURED_EXIT"
    return 1
  fi
  if [ -n "$_CAPTURED_STDOUT" ]; then
    _fail "lookup ausente stdout" "esperado vazio, obtido '$_CAPTURED_STDOUT'"
    return 1
  fi
}

# ==== manifest_default_path ====

scenario_default_path_global() {
  capture sh -c ". $CSTK_LIB/manifest.sh && manifest_default_path global"
  if [ "$_CAPTURED_EXIT" != "0" ]; then
    _fail "default path global exit" "$_CAPTURED_EXIT"
    return 1
  fi
  echo "$_CAPTURED_STDOUT" | grep -q '/.claude/skills/.cstk-manifest$' \
    || { _fail "default path global formato" "$_CAPTURED_STDOUT"; return 1; }
}

scenario_default_path_project() {
  capture sh -c ". $CSTK_LIB/manifest.sh && manifest_default_path project"
  if [ "$_CAPTURED_EXIT" != "0" ]; then
    _fail "default path project exit" "$_CAPTURED_EXIT"
    return 1
  fi
  if [ "$_CAPTURED_STDOUT" != "./.claude/skills/.cstk-manifest" ]; then
    _fail "default path project valor" "$_CAPTURED_STDOUT"
    return 1
  fi
}

scenario_default_path_invalido() {
  capture sh -c ". $CSTK_LIB/manifest.sh && manifest_default_path bogus"
  if [ "$_CAPTURED_EXIT" != "2" ]; then
    _fail "default path invalido" "exit esperado 2, obtido $_CAPTURED_EXIT"
    return 1
  fi
}

run_all_scenarios
