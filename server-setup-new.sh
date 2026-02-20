#!/bin/bash
# =============================================================================
# WordPress + Nginx Server Setup Script (Modular Version)
# =============================================================================
# Este script orquestra a instalação de todos os componentes usando módulos
# independentes que podem ser executados separadamente.
#
# Uso completo: sudo ./server-setup.sh
# Uso modular:  sudo ./modules/php.sh --version 8.4
#               sudo ./modules/nginx.sh --source official
#               sudo ./modules/database.sh --type mysql --version 8.4
#               sudo ./modules/cache.sh --server dragonfly
#               sudo ./modules/firewall.sh --apply
#               sudo ./modules/system.sh --all
# =============================================================================

set -e

# Obter diretório do script
SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" &> /dev/null && pwd)
MODULES_DIR="$SCRIPT_DIR/modules"

# Carregar módulos
source "$MODULES_DIR/common.sh"
source "$MODULES_DIR/config.sh"

# =============================================================================
# FUNÇÕES
# =============================================================================

show_help() {
  echo -e "${BOLD}WordPress + Nginx Server Setup Script${NC}"
  echo ""
  echo "Uso: $0 [OPÇÕES]"
  echo ""
  echo "Modos de execução:"
  echo "  (sem argumentos)      Instalação interativa completa"
  echo "  -m, --module MODULE   Executa apenas um módulo específico"
  echo "  -l, --list            Lista módulos disponíveis"
  echo "  -h, --help            Exibe esta mensagem"
  echo ""
  echo "Módulos disponíveis:"
  echo "  php         Instalação do PHP"
  echo "  nginx       Instalação do Nginx"
  echo "  database    Instalação do MySQL/MariaDB"
  echo "  cache       Instalação do Redis/Valkey/DragonflyDB"
  echo "  firewall    Configuração do nftables"
  echo "  system      Configurações do sistema"
  echo ""
  echo "Exemplos:"
  echo "  $0                              # Instalação completa interativa"
  echo "  $0 -m php                       # Apenas módulo PHP"
  echo "  $0 -m php -- --version 8.4      # PHP 8.4 direto"
  echo ""
  echo "Execução direta de módulos:"
  echo "  ./modules/php.sh --version 8.4"
  echo "  ./modules/nginx.sh --source official"
  echo "  ./modules/database.sh --type mysql --version 8.4"
  echo "  ./modules/cache.sh --server dragonfly"
}

list_modules() {
  echo -e "${BOLD}Módulos disponíveis:${NC}"
  echo ""
  
  for module in php nginx database cache firewall system; do
    if [ -f "$MODULES_DIR/${module}.sh" ]; then
      echo -e "  ${GREEN}✓${NC} ${module}"
      # Extrair descrição do arquivo
      head -5 "$MODULES_DIR/${module}.sh" | grep -oP '(?<=MÓDULO: ).*' | sed 's/^/    /'
    else
      echo -e "  ${RED}✗${NC} ${module} (não encontrado)"
    fi
  done
  
  echo ""
  echo "Use: ./modules/<módulo>.sh --help para ver opções específicas"
}

run_module() {
  local module=$1
  shift
  
  local module_path="$MODULES_DIR/${module}.sh"
  
  if [ ! -f "$module_path" ]; then
    msg_error "Módulo não encontrado: $module"
    list_modules
    exit 1
  fi
  
  chmod +x "$module_path"
  exec "$module_path" "$@"
}

# =============================================================================
# INSTALAÇÃO COMPLETA
# =============================================================================

run_full_installation() {
  msg_header "WordPress + Nginx Server Setup"
  
  echo -e "${BOLD}"
  echo "╔═══════════════════════════════════════════════════════════╗"
  echo "║     WordPress + Nginx Server Setup Script                 ║"
  echo "║     Configuração interativa com confirmação               ║"
  echo "╚═══════════════════════════════════════════════════════════╝"
  echo -e "${NC}"
  
  # Coletar configurações interativas
  collect_configuration
  
  # Salvar versão do PHP
  save_php_version "$PHP_VERSION"
  
  # Gerar senha MySQL root
  MYSQL_ROOT_PASSWORD=$(openssl rand -base64 12)
  export MYSQL_ROOT_PASSWORD
  
  export DEBIAN_FRONTEND=noninteractive
  
  # ==========================================================================
  # ATUALIZAÇÃO DO SISTEMA
  # ==========================================================================
  msg_header "Atualizando Sistema"
  apt update && apt upgrade -y
  
  # ==========================================================================
  # NGINX
  # ==========================================================================
  if [ "$NGINX_CHOICE" != "0" ] && ! command_exists nginx; then
    msg_header "Instalando Nginx"
    
    local nginx_source
    case $NGINX_CHOICE in
      1) nginx_source="official" ;;
      2) nginx_source="wordops" ;;
      3) nginx_source="ubuntu" ;;
    esac
    
    source "$MODULES_DIR/nginx.sh"
    FORCE=true install_nginx "$nginx_source"
  else
    msg_info "Nginx já instalado ou pulado"
    # Apenas configurar se já existe
    if command_exists nginx; then
      source "$MODULES_DIR/nginx.sh"
      configure_nginx_base
      copy_nginx_configs
      install_8g_firewall
      restart_nginx
    fi
  fi
  
  # ==========================================================================
  # PHP
  # ==========================================================================
  msg_header "Instalando PHP"
  source "$MODULES_DIR/php.sh"
  
  if ! php_version_installed "$PHP_VERSION"; then
    FORCE=true install_php "$PHP_VERSION"
  else
    msg_info "PHP $PHP_VERSION já instalado, reconfigurando..."
    configure_php "$PHP_VERSION"
    restart_php_fpm "$PHP_VERSION"
  fi
  
  # ==========================================================================
  # DATABASE
  # ==========================================================================
  if [ "$DB_CHOICE" != "0" ] && ! command_exists mysql; then
    msg_header "Instalando Database"
    source "$MODULES_DIR/database.sh"
    
    local db_type db_version
    case $DB_CHOICE in
      1) 
        db_type="mysql"
        case $DB_VERSION_CHOICE in
          1) db_version="8.4" ;;
          2) db_version="8.0" ;;
        esac
        ;;
      2)
        db_type="mariadb"
        case $DB_VERSION_CHOICE in
          1) db_version="10.11" ;;
          2) db_version="10.6" ;;
          3) db_version="10.5" ;;
        esac
        ;;
    esac
    
    DB_TYPE="$db_type"
    DB_VERSION="$db_version"
    FORCE=true install_database "$db_type" "$db_version"
  else
    msg_info "Database já instalado ou pulado"
  fi
  
  # ==========================================================================
  # CACHE SERVER
  # ==========================================================================
  if [ "$CACHE_CHOICE" != "0" ] && [ "$CACHE_CHOICE" != "4" ]; then
    if ! command_exists redis-server && ! command_exists dragonfly && ! command_exists valkey-server; then
      msg_header "Instalando Cache Server"
      source "$MODULES_DIR/cache.sh"
      
      local cache_server
      case $CACHE_CHOICE in
        1) cache_server="dragonfly" ;;
        2) cache_server="valkey" ;;
        3) cache_server="redis" ;;
      esac
      
      FORCE=true install_cache "$cache_server"
    else
      msg_info "Cache server já instalado"
    fi
  else
    msg_info "Cache server não selecionado"
  fi
  
  # ==========================================================================
  # WP-CLI
  # ==========================================================================
  if ! command_exists wp; then
    msg_header "Instalando WP-CLI"
    source "$MODULES_DIR/system.sh"
    install_wpcli
  fi
  
  # ==========================================================================
  # CONFIGURAÇÕES DO SISTEMA
  # ==========================================================================
  msg_header "Aplicando Configurações do Sistema"
  source "$MODULES_DIR/system.sh"
  apply_sysctl
  
  # ==========================================================================
  # FIREWALL
  # ==========================================================================
  msg_header "Configurando Firewall"
  source "$MODULES_DIR/firewall.sh"
  FORCE=true apply_firewall
  
  # ==========================================================================
  # FINALIZAÇÃO
  # ==========================================================================
  msg_header "Instalação Concluída!"
  
  # Salvar informações
  mkdir -p ~/.iw
  {
    echo "========================================"
    echo "Setup realizado em: $(date)"
    echo "========================================"
    echo "PHP version: $PHP_VERSION"
    echo "MySQL root password: $MYSQL_ROOT_PASSWORD"
    echo ""
    echo "Lembre-se de salvar a senha do MySQL root!"
  } | tee ~/.iw/server.txt
  
  echo ""
  echo -e "${CYAN}Resumo da Instalação:${NC}"
  echo "  PHP: $PHP_VERSION"
  echo "  Nginx: ${NGINX_DESCRIPTION:-N/A}"
  echo "  Database: ${DB_DESCRIPTION:-N/A}"
  echo "  Cache: ${CACHE_DESCRIPTION:-N/A}"
  echo ""
  echo -e "${YELLOW}Security Notice:${NC}"
  echo "  - MySQL configurado para aceitar apenas conexões locais"
  echo "  - Firewall nftables configurado com rate limiting em SSH"
  echo "  - Considere instalar fail2ban para segurança adicional"
  echo ""
  echo -e "${GREEN}Próximos passos:${NC}"
  echo "  - Execute ./install-wordpress.sh para instalar um site"
  echo "  - Credenciais salvas em: ~/.iw/server.txt"
}

# =============================================================================
# PROCESSAMENTO DE ARGUMENTOS
# =============================================================================
main() {
  check_root
  setup_environment
  
  # Se nenhum argumento, executar instalação completa
  if [ $# -eq 0 ]; then
    run_full_installation
    exit 0
  fi
  
  # Processar argumentos
  while [[ $# -gt 0 ]]; do
    case $1 in
      -h|--help)
        show_help
        exit 0
        ;;
      -l|--list)
        list_modules
        exit 0
        ;;
      -m|--module)
        MODULE="$2"
        shift 2
        # Resto dos argumentos vão para o módulo
        if [[ "$1" == "--" ]]; then
          shift
        fi
        run_module "$MODULE" "$@"
        exit 0
        ;;
      *)
        msg_error "Opção desconhecida: $1"
        show_help
        exit 1
        ;;
    esac
  done
}

main "$@"
