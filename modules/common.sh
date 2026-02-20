#!/bin/bash
# =============================================================================
# MÓDULO: Common - Funções e variáveis compartilhadas
# =============================================================================
# Este módulo contém funções utilitárias e variáveis usadas por outros módulos
# =============================================================================

# Verificar se está sendo executado como root
check_root() {
  if (( EUID != 0 )); then
    echo "Erro: Este script deve ser executado como root ou sudo!" >&2
    exit 100
  fi
}

# Definir diretório do script (base do projeto)
get_script_dir() {
  if [ -z "$SCRIPT_DIR" ]; then
    # Se não definido, tenta encontrar o diretório base
    if [ -f "${BASH_SOURCE[0]}" ]; then
      SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." &> /dev/null && pwd)
    else
      SCRIPT_DIR=$(pwd)
    fi
  fi
  echo "$SCRIPT_DIR"
}

# Cores para melhor visualização
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color
BOLD='\033[1m'

# Função para verificar se um comando existe
command_exists() {
  command -v "$1" &> /dev/null
}

# Função para exibir mensagens formatadas
msg_info() {
  echo -e "${CYAN}ℹ ${NC}$1"
}

msg_success() {
  echo -e "${GREEN}✓ ${NC}$1"
}

msg_warning() {
  echo -e "${YELLOW}⚠ ${NC}$1"
}

msg_error() {
  echo -e "${RED}✗ ${NC}$1"
}

msg_header() {
  echo -e "\n${BOLD}${BLUE}═══════════════════════════════════════════════════════════${NC}"
  echo -e "${BOLD}${BLUE} $1${NC}"
  echo -e "${BOLD}${BLUE}═══════════════════════════════════════════════════════════${NC}\n"
}

# Função para processar templates mustache
process_mustache() {
  local input=$1
  local output=$2
  local php_version=${PHP_VERSION:-"8.3"}
  local php_version_no_dot=${PHP_VERSION_NO_DOT:-$(echo "$php_version" | tr -d '.')}
  
  sed -e "s/{{PHP_VERSION}}/$php_version/g" \
      -e "s/{{PHP_VERSION_NO_DOT}}/$php_version_no_dot/g" \
      "$input" > "$output"
}

# Função para exibir uso do módulo
show_module_usage() {
  local module_name=$1
  local description=$2
  echo -e "${BOLD}Uso: $module_name [OPÇÕES]${NC}"
  echo ""
  echo -e "$description"
  echo ""
  echo "Opções:"
  echo "  -h, --help     Exibe esta mensagem de ajuda"
  echo "  -y, --yes      Executa sem solicitar confirmação"
  echo "  -v, --version  Especifica a versão (quando aplicável)"
  echo ""
}

# Função para ler versão do PHP do ambiente
get_php_version() {
  if [ -n "$PHP_VERSION" ]; then
    echo "$PHP_VERSION"
  elif [ -f /etc/profile.d/wordpress-nginx-env.sh ]; then
    source /etc/profile.d/wordpress-nginx-env.sh
    echo "${DEFAULT_PHP_VERSION:-8.3}"
  else
    echo "8.3"
  fi
}

# Configurar variáveis de ambiente padrão
setup_environment() {
  export DEBIAN_FRONTEND=noninteractive
  timedatectl set-timezone America/Sao_Paulo 2>/dev/null || true
  SCRIPT_DIR=$(get_script_dir)
}

# Salvar configuração de versão PHP
save_php_version() {
  local version=$1
  echo "export DEFAULT_PHP_VERSION=$version" > /etc/profile.d/wordpress-nginx-env.sh
  chmod +x /etc/profile.d/wordpress-nginx-env.sh
}
