#!/bin/sh
# next-uc-id.sh — calcula o proximo ID de Use Case para um dominio.
#
# Uso:
#   scripts/next-uc-id.sh AUTH           # busca em ./docs/ por padrao
#   scripts/next-uc-id.sh CAD --dir=docs/02-requisitos-casos-uso
#   scripts/next-uc-id.sh                # lista dominios existentes
#
# Saida: o proximo ID completo (ex: UC-AUTH-003) em stdout.
# Se nenhum UC existe para o dominio, retorna UC-{DOMINIO}-001.
#
# POSIX sh — usa find/grep/sort/awk, sem dependencias exoticas.

set -eu

DOCS_DIR="docs"
DOMAIN=""

for arg in "$@"; do
  case "$arg" in
    --dir=*) DOCS_DIR="${arg#--dir=}" ;;
    -h|--help)
      cat <<'USAGE'
next-uc-id.sh — proximo ID de Use Case

Uso:
  next-uc-id.sh DOMINIO [--dir=PATH]

Exemplos:
  next-uc-id.sh AUTH
  next-uc-id.sh CAD --dir=docs/02-requisitos-casos-uso
  next-uc-id.sh --list    # lista dominios existentes e contagem
USAGE
      exit 0
      ;;
    --list)
      DOMAIN="--list"
      ;;
    -*)
      printf 'Argumento desconhecido: %s\n' "$arg" >&2
      exit 2
      ;;
    *)
      if [ -z "$DOMAIN" ]; then
        DOMAIN="$arg"
      fi
      ;;
  esac
done

if [ ! -d "$DOCS_DIR" ]; then
  printf 'Diretorio nao encontrado: %s\n' "$DOCS_DIR" >&2
  exit 1
fi

# Extrai "DOMINIO NNN" de todos os arquivos UC-*.md encontrados
# Formato esperado do arquivo: UC-{DOMINIO}-{NNN}[-descricao].md
UC_FILES=$(find "$DOCS_DIR" -type f -name 'UC-*.md' 2>/dev/null || true)

if [ "$DOMAIN" = "--list" ]; then
  if [ -z "$UC_FILES" ]; then
    printf 'Nenhum UC encontrado em %s\n' "$DOCS_DIR"
    exit 0
  fi
  printf '%s\n' "$UC_FILES" \
    | sed -E 's|.*/UC-([A-Z]+)-([0-9]+).*|\1|' \
    | sort \
    | uniq -c \
    | awk '{printf "  %-10s %d UC(s)\n", $2, $1}'
  exit 0
fi

if [ -z "$DOMAIN" ]; then
  printf 'Uso: next-uc-id.sh DOMINIO [--dir=PATH]\n' >&2
  printf 'Tente --list para ver dominios existentes.\n' >&2
  exit 2
fi

# Valida formato do dominio (uppercase letters, 2-6 chars)
case "$DOMAIN" in
  *[!A-Z]*|"")
    printf 'Dominio invalido: "%s" (use apenas letras maiusculas)\n' "$DOMAIN" >&2
    exit 2
    ;;
esac

# Encontra o maior numero atual para o dominio
MAX=0
if [ -n "$UC_FILES" ]; then
  MAX=$(printf '%s\n' "$UC_FILES" \
    | sed -nE "s|.*/UC-${DOMAIN}-([0-9]+).*|\1|p" \
    | sort -n \
    | tail -n 1 || printf '0')
  MAX=${MAX:-0}
fi

NEXT=$((MAX + 1))

# Formata com 3 digitos (padding)
printf 'UC-%s-%03d\n' "$DOMAIN" "$NEXT"
