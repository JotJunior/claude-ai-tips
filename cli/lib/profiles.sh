# profiles.sh — parser e resolvedor de perfis do catalog.
#
# Formato de entrada (data-model.md §Profile, catalog/profiles.txt):
#   # comentarios iniciam com #
#   <profile-name>:<member>
#
# onde <member> e o nome de uma skill OU de outro profile. A resolucao expande
# perfis aninhados ate produzir um set unico de skills.
#
# Funcoes exportadas:
#   profiles_parse <path>          — emite linhas "profile<TAB>member" (skip blank/#)
#   list_profiles <path>           — emite nomes unicos de profiles, ordenados
#   resolve_profile <path> <name>  — emite skills do profile (deduped, sorted),
#                                     expandindo perfis aninhados; aborta com
#                                     exit 1 em ciclo, profile desconhecido ou
#                                     formato invalido
#
# Garantias:
#   - Ciclos sao detectados durante a expansao DFS e abortam com exit 1.
#   - Profile desconhecido aborta com exit 1.
#   - Resolucao e read-only sobre o catalog; nunca escreve no filesystem.
#   - Saida do resolve_profile e dedupada e ordenada (`sort -u`).
#
# POSIX sh + awk. Deps: awk, sort, printf.

if [ -n "${_CSTK_PROFILES_LOADED:-}" ]; then
  return 0 2>/dev/null
fi
_CSTK_PROFILES_LOADED=1

# profiles_parse: imprime linhas "profile<TAB>member", uma por aresta do catalog.
# Pula linhas vazias e comentarios. Aborta com exit 1 se houver linha malformada
# (sem `:` separador, ou com `:` em posicao invalida).
profiles_parse() {
  if [ "$#" -ne 1 ]; then
    printf 'profiles: profiles_parse espera 1 argumento (path)\n' >&2
    return 2
  fi
  _profiles_path=$1
  if [ ! -f "$_profiles_path" ]; then
    printf 'profiles: catalog nao encontrado: %s\n' "$_profiles_path" >&2
    return 1
  fi
  awk -F: '
    /^[[:space:]]*$/ { next }
    /^[[:space:]]*#/ { next }
    {
      if (NF < 2 || $1 == "" || $2 == "") {
        printf "profiles: linha %d malformada: %s\n", NR, $0 > "/dev/stderr"
        err = 1
        next
      }
      if (NF > 2) {
        printf "profiles: linha %d com multiplos `:` nao suportada: %s\n", NR, $0 > "/dev/stderr"
        err = 1
        next
      }
      print $1 "\t" $2
    }
    END { exit err+0 }
  ' "$_profiles_path"
}

# list_profiles: nomes unicos de profiles, ordenados.
list_profiles() {
  if [ "$#" -ne 1 ]; then
    printf 'profiles: list_profiles espera 1 argumento (path)\n' >&2
    return 2
  fi
  _profiles_path=$1
  profiles_parse "$_profiles_path" | awk -F'\t' '{print $1}' | sort -u
}

# resolve_profile: expande recursivamente um profile para o set de skills.
# Profile desconhecido OU ciclo => exit 1 com mensagem em stderr.
# Saida: skills, uma por linha, deduped + sorted (lexicografico).
resolve_profile() {
  if [ "$#" -ne 2 ]; then
    printf 'profiles: resolve_profile espera 2 argumentos (path, name)\n' >&2
    return 2
  fi
  _profiles_path=$1
  _profiles_name=$2
  if [ -z "$_profiles_name" ]; then
    printf 'profiles: nome de profile vazio\n' >&2
    return 2
  fi
  if [ ! -f "$_profiles_path" ]; then
    printf 'profiles: catalog nao encontrado: %s\n' "$_profiles_path" >&2
    return 1
  fi

  # Implementacao em awk: arrays nativos + recursao funcional viabilizam DFS
  # com cycle detection (3-coloring). O equivalente em POSIX sh puro exigiria
  # stack manual + escape de variaveis globais entre frames recursivos.
  awk -F: -v root="$_profiles_name" '
    BEGIN { err = 0; n_skills = 0 }
    /^[[:space:]]*$/ { next }
    /^[[:space:]]*#/ { next }
    {
      if (NF < 2 || $1 == "" || $2 == "") {
        printf "profiles: linha %d malformada: %s\n", NR, $0 > "/dev/stderr"
        err = 1
        next
      }
      if (NF > 2) {
        printf "profiles: linha %d com multiplos `:` nao suportada: %s\n", NR, $0 > "/dev/stderr"
        err = 1
        next
      }
      profile_set[$1] = 1
      # Acumula membros separados por \n (escolhido por nao colidir com nomes
      # de skill, que sao slugs sem newline).
      if ($1 in members) {
        members[$1] = members[$1] "\n" $2
      } else {
        members[$1] = $2
      }
    }
    END {
      if (err) exit 1
      if (!(root in profile_set)) {
        printf "profiles: profile desconhecido: %s\n", root > "/dev/stderr"
        exit 1
      }
      if (dfs(root) != 0) exit 1
      # Coleta skills, ordena, imprime.
      m = 0
      for (s in skills_out) {
        m++
        sorted[m] = s
      }
      # Sort in-place (small N, simple insertion sort).
      for (i = 2; i <= m; i++) {
        key = sorted[i]
        j = i - 1
        while (j >= 1 && sorted[j] > key) {
          sorted[j+1] = sorted[j]
          j--
        }
        sorted[j+1] = key
      }
      for (i = 1; i <= m; i++) print sorted[i]
    }
    function dfs(p,    list, k, m, count, msg) {
      # 3-color DFS: visiting=gray (na pilha atual), visited=black (concluido).
      # Re-encontrar nodo gray => ciclo.
      if (p in visiting) {
        msg = "profiles: ciclo detectado envolvendo profile `" p "`"
        printf "%s\n", msg > "/dev/stderr"
        return 1
      }
      if (p in visited) return 0
      visiting[p] = 1
      count = split(members[p], list, "\n")
      for (k = 1; k <= count; k++) {
        m = list[k]
        if (m == "") continue
        if (m in profile_set) {
          if (dfs(m) != 0) return 1
        } else {
          skills_out[m] = 1
        }
      }
      delete visiting[p]
      visited[p] = 1
      return 0
    }
  ' "$_profiles_path"
}
