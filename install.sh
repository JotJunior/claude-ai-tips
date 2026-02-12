#!/usr/bin/env bash
set -euo pipefail

REPO="JotJunior/claude-ai-tips"
BRANCH="main"
BASE_URL="https://raw.githubusercontent.com/${REPO}/${BRANCH}"

# --- files to install ---
FILES=(
  "commands/create-tasks.md"
  "commands/create-use-case.md"
  "commands/execute-task.md"
  "commands/initialize-docs.md"
  "commands/review-task.md"
  "skills/advisor/SKILL.md"
  "skills/conselheiro-estrategico/SKILL.md"
  "skills/create-tasks/SKILL.md"
  "skills/create-tasks/template-tasks-index.md"
  "skills/create-tasks/template-tasks-milestone.md"
  "skills/doc-generate-use-case/SKILL.md"
  "skills/doc-generate-use-case/template-uc.md"
  "skills/doc-validate/SKILL.md"
  "agents/documentation-agent/agent.md"
)

# --- colors ---
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# --- parse args ---
GLOBAL=false
for arg in "$@"; do
  case "$arg" in
    --global|-g) GLOBAL=true ;;
    --help|-h)
      echo "Usage: install.sh [OPTIONS]"
      echo ""
      echo "Instala commands, skills e agents do Claude Code Toolkit."
      echo ""
      echo "Options:"
      echo "  --global, -g    Instala em ~/.claude/ (global)"
      echo "  --help, -h      Mostra esta mensagem"
      echo ""
      echo "Por padrão, instala em .claude/ no diretório atual (projeto)."
      exit 0
      ;;
    *)
      echo -e "${RED}Opção desconhecida: ${arg}${NC}"
      exit 1
      ;;
  esac
done

# --- determine target ---
if [ "$GLOBAL" = true ]; then
  TARGET_DIR="$HOME/.claude"
  echo -e "${BLUE}Instalando globalmente em ${TARGET_DIR}${NC}"
else
  TARGET_DIR="$(pwd)/.claude"
  echo -e "${BLUE}Instalando no projeto em ${TARGET_DIR}${NC}"
fi

# --- check for curl or wget ---
if command -v curl &>/dev/null; then
  FETCH="curl -fsSL"
elif command -v wget &>/dev/null; then
  FETCH="wget -qO-"
else
  echo -e "${RED}Erro: curl ou wget é necessário.${NC}"
  exit 1
fi

# --- download files ---
OK=0
FAIL=0

for file in "${FILES[@]}"; do
  dest="${TARGET_DIR}/${file}"
  dir="$(dirname "$dest")"

  mkdir -p "$dir"

  if $FETCH "${BASE_URL}/${file}" > "$dest" 2>/dev/null; then
    echo -e "  ${GREEN}+${NC} ${file}"
    ((OK++))
  else
    echo -e "  ${RED}x${NC} ${file}"
    ((FAIL++))
    rm -f "$dest"
  fi
done

# --- summary ---
echo ""
echo -e "${GREEN}Instalação concluída!${NC}"
echo -e "  ${GREEN}${OK}${NC} arquivos instalados"
if [ "$FAIL" -gt 0 ]; then
  echo -e "  ${RED}${FAIL}${NC} arquivos falharam"
fi
echo ""
echo -e "${YELLOW}Destino:${NC} ${TARGET_DIR}"
echo -e "${YELLOW}Commands:${NC} $(ls -1 "${TARGET_DIR}/commands/" 2>/dev/null | wc -l | tr -d ' ') arquivos"
echo -e "${YELLOW}Skills:${NC}   $(find "${TARGET_DIR}/skills/" -name "*.md" 2>/dev/null | wc -l | tr -d ' ') arquivos"
echo -e "${YELLOW}Agents:${NC}   $(find "${TARGET_DIR}/agents/" -name "*.md" 2>/dev/null | wc -l | tr -d ' ') arquivos"