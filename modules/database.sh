#!/bin/bash
# =============================================================================
# MÓDULO: Database - Instalação do MySQL/MariaDB
# =============================================================================
# Uso standalone: sudo ./modules/database.sh [--type mysql|mariadb] [--version X.X]
# =============================================================================

set -e

# Carregar módulo comum
MODULES_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" &> /dev/null && pwd)
source "$MODULES_DIR/common.sh"

# Diretório base do projeto
SCRIPT_DIR=$(get_script_dir)

# =============================================================================
# VARIÁVEIS
# =============================================================================
DB_TYPE="${DB_TYPE:-}"
DB_VERSION="${DB_VERSION:-}"
MYSQL_ROOT_PASSWORD="${MYSQL_ROOT_PASSWORD:-}"
FORCE=false

# =============================================================================
# FUNÇÕES
# =============================================================================

show_help() {
  echo -e "${BOLD}Módulo Database - Instalação do MySQL/MariaDB${NC}"
  echo ""
  echo "Uso: $0 [OPÇÕES]"
  echo ""
  echo "Opções:"
  echo "  -t, --type TYPE       Tipo de database (mysql, mariadb)"
  echo "  -v, --version VERSION Versão específica"
  echo "  -p, --password PASS   Senha root (gerada automaticamente se omitida)"
  echo "  -f, --force           Não pede confirmação"
  echo "  -h, --help            Exibe esta mensagem"
  echo ""
  echo "Versões disponíveis:"
  echo "  MySQL: 8.4 (LTS), 8.0"
  echo "  MariaDB: 10.11 (LTS), 10.6, 10.5"
  echo ""
  echo "Exemplos:"
  echo "  $0 --type mysql --version 8.4"
  echo "  $0 --type mariadb --version 10.11"
  echo "  $0                      # Menu interativo"
}

# Menu interativo
interactive_select_database() {
  echo -e "\n${CYAN}Selecione o Database:${NC}"
  echo ""
  echo "  1) MySQL"
  echo "  2) MariaDB"
  echo ""
  echo "  0) Cancelar"
  echo ""
  read -p "Escolha [0-2]: " choice
  
  case $choice in
    0) exit 0 ;;
    1) 
      DB_TYPE="mysql"
      echo -e "\n${CYAN}Selecione a versão do MySQL:${NC}"
      echo "  1) MySQL 8.4 LTS (Recomendado - suporte até 2032)"
      echo "  2) MySQL 8.0 (Legacy - suporte até 2026)"
      read -p "Escolha [1-2]: " ver
      case $ver in
        1) DB_VERSION="8.4" ;;
        2) DB_VERSION="8.0" ;;
        *) DB_VERSION="8.4" ;;
      esac
      ;;
    2)
      DB_TYPE="mariadb"
      echo -e "\n${CYAN}Selecione a versão do MariaDB:${NC}"
      echo "  1) MariaDB 10.11 LTS (Recomendado)"
      echo "  2) MariaDB 10.6 LTS"
      echo "  3) MariaDB 10.5 LTS"
      read -p "Escolha [1-3]: " ver
      case $ver in
        1) DB_VERSION="10.11" ;;
        2) DB_VERSION="10.6" ;;
        3) DB_VERSION="10.5" ;;
        *) DB_VERSION="10.11" ;;
      esac
      ;;
    *) 
      msg_error "Opção inválida"
      interactive_select_database
      ;;
  esac
}

# Gerar senha root
generate_root_password() {
  if [ -z "$MYSQL_ROOT_PASSWORD" ]; then
    MYSQL_ROOT_PASSWORD=$(openssl rand -base64 12)
    msg_info "Senha root gerada automaticamente"
  fi
}

# Instalar MySQL
install_mysql() {
  local version=$1
  
  msg_info "Instalando MySQL $version..."
  
  apt install -y debconf-utils
  
  if [ "$version" == "8.4" ]; then
    echo "mysql-apt-config mysql-apt-config/select-server select mysql-8.4" | debconf-set-selections
  else
    echo "mysql-apt-config mysql-apt-config/select-server select mysql-8.0" | debconf-set-selections
  fi
  
  wget -q https://dev.mysql.com/get/mysql-apt-config_0.8.34-1_all.deb
  DEBIAN_FRONTEND=noninteractive dpkg -i mysql-apt-config_0.8.34-1_all.deb
  rm -f mysql-apt-config_0.8.34-1_all.deb
  
  apt-key adv --keyserver keyserver.ubuntu.com --recv-keys B7B3B788A8D3785C 2>/dev/null || true
  apt update
  apt install -y mysql-server libjemalloc2
  
  # Configurar senha root
  mysql --execute="ALTER USER 'root'@'localhost' IDENTIFIED WITH mysql_native_password BY '$MYSQL_ROOT_PASSWORD'; FLUSH PRIVILEGES;"
  
  msg_success "MySQL $version instalado"
}

# Instalar MariaDB
install_mariadb() {
  local version=$1
  
  msg_info "Instalando MariaDB $version..."
  
  apt install -y apt-transport-https curl libjemalloc2
  
  curl -o /etc/apt/trusted.gpg.d/mariadb_release_signing_key.asc 'https://mariadb.org/mariadb_release_signing_key.asc'
  sh -c "echo 'deb https://mirrors.xtom.de/mariadb/repo/$version/ubuntu $(lsb_release -cs) main' > /etc/apt/sources.list.d/mariadb.list"
  
  apt update
  apt install -y mariadb-server
  
  # Configurar senha root
  mysql --execute="ALTER USER 'root'@'localhost' IDENTIFIED BY '$MYSQL_ROOT_PASSWORD'; FLUSH PRIVILEGES;"
  
  msg_success "MariaDB $version instalado"
}

# Configurar systemd override
configure_systemd_override() {
  local service_name=$1
  
  msg_info "Configurando otimizações do systemd..."
  
  mkdir -p "/etc/systemd/system/${service_name}.service.d"
  
  cat <<EOF > "/etc/systemd/system/${service_name}.service.d/override.conf"
[Service]
LimitNOFILE=131072
LimitNOFILESoft=131072
Nice=-5
LimitCore=1G
#Environment="LD_PRELOAD=/usr/lib/x86_64-linux-gnu/libjemalloc.so.2"
Environment="LD_PRELOAD=/usr/lib/x86_64-linux-gnu/libtcmalloc_minimal.so.4"
Environment="TZ=America/Sao_Paulo"
EOF
  
  systemctl daemon-reload
}

# Configurar database baseado na memória do sistema
setup_db_config() {
  local db_type=$1
  local db_version=$2
  
  msg_info "Configurando otimizações baseadas na memória do sistema..."
  
  # Obter memória total em MB
  local total_mem=$(free -m | awk '/^Mem:/{print $2}')
  
  echo "Sistema possui $total_mem MB de RAM"
  
  # Determinar perfil
  local PROFILE
  if [ $total_mem -lt 4096 ]; then
    PROFILE="small"
    echo "Usando perfil SMALL (< 4GB RAM)"
  elif [ $total_mem -lt 16384 ]; then
    PROFILE="medium"
    echo "Usando perfil MEDIUM (4-16GB RAM)"
  else
    PROFILE="large"
    echo "Usando perfil LARGE (> 16GB RAM)"
  fi
  
  # Calcular alocações de memória
  local buffer_pool_mb=$((total_mem * 70 / 100))
  local pool_instances=$((buffer_pool_mb / 1024))
  [ $pool_instances -lt 1 ] && pool_instances=1
  [ $pool_instances -gt 64 ] && pool_instances=64
  
  local chunk_mb=$((buffer_pool_mb / pool_instances))
  [ $chunk_mb -lt 128 ] && chunk_mb=128
  
  # Configurações baseadas no perfil
  case $PROFILE in
    small)
      local MAX_CONNECTIONS=100
      local THREAD_CACHE_SIZE=8
      local TABLE_OPEN_CACHE=800
      local INNODB_IO_CAP=200
      local LOG_BUFFER="16M"
      local REDO_LOG_MB=256
      ;;
    medium)
      local MAX_CONNECTIONS=300
      local THREAD_CACHE_SIZE=24
      local TABLE_OPEN_CACHE=4000
      local INNODB_IO_CAP=600
      local LOG_BUFFER="32M"
      local REDO_LOG_MB=512
      ;;
    large)
      local MAX_CONNECTIONS=800
      local THREAD_CACHE_SIZE=64
      local TABLE_OPEN_CACHE=10000
      local INNODB_IO_CAP=2000
      local LOG_BUFFER="64M"
      local REDO_LOG_MB=2048
      ;;
  esac
  
  # Formatar tamanho do buffer pool
  local BUFFER_POOL_SIZE
  if [ $buffer_pool_mb -ge 1024 ]; then
    BUFFER_POOL_SIZE="$((buffer_pool_mb / 1024))G"
  else
    BUFFER_POOL_SIZE="${buffer_pool_mb}M"
  fi
  
  # Config de redo log
  local REDO_LOG_CONFIG
  if [ "$db_type" == "mysql" ]; then
    REDO_LOG_CONFIG="innodb_redo_log_capacity = ${REDO_LOG_MB}M"
  else
    REDO_LOG_CONFIG="innodb_log_file_size = ${REDO_LOG_MB}M"
  fi
  
  # Criar configuração
  mkdir -p /etc/mysql/conf.d
  
  cat > /etc/mysql/conf.d/z-wordpress-optimized.cnf <<EOF
# =============================================================================
# WordPress Optimized Configuration
# Generated by server-setup modules
# DB: $db_type $db_version | RAM: ${total_mem}MB | Profile: $PROFILE
# =============================================================================

[mysqld]
# InnoDB Buffer Pool
innodb_buffer_pool_size = $BUFFER_POOL_SIZE
innodb_buffer_pool_instances = $pool_instances
innodb_buffer_pool_chunk_size = ${chunk_mb}M

# InnoDB Log / Redo
innodb_log_buffer_size = $LOG_BUFFER
$REDO_LOG_CONFIG

# Connections
max_connections = $MAX_CONNECTIONS
thread_cache_size = $THREAD_CACHE_SIZE

# Tables
table_open_cache = $TABLE_OPEN_CACHE
table_definition_cache = $((TABLE_OPEN_CACHE / 2))

# I/O
innodb_io_capacity = $INNODB_IO_CAP
innodb_flush_log_at_trx_commit = 2

# Query Cache (desativado no MySQL 8+)
# query_cache_type = 0

# Slow Query Log
slow_query_log = 1
slow_query_log_file = /var/log/mysql/slow.log
long_query_time = 2
EOF
  
  msg_success "Configuração salva em /etc/mysql/conf.d/z-wordpress-optimized.cnf"
  echo "Buffer Pool: $BUFFER_POOL_SIZE ($pool_instances instâncias)"
}

# Reiniciar database
restart_database() {
  local service=$1
  
  msg_info "Reiniciando $service..."
  systemctl restart "$service"
  
  if systemctl is-active --quiet "$service"; then
    msg_success "$service está rodando"
  else
    msg_error "Erro ao iniciar $service"
    return 1
  fi
}

# Função principal
install_database() {
  local db_type=$1
  local db_version=$2
  
  msg_header "Instalação do $db_type $db_version"
  
  # Verificar se já está instalado
  if command_exists mysql; then
    msg_warning "Database já está instalado."
    mysql --version
    return 0
  fi
  
  # Gerar senha root
  generate_root_password
  
  # Confirmar instalação
  if [ "$FORCE" != true ]; then
    echo ""
    echo -e "${YELLOW}Será instalado:${NC}"
    echo "  - $db_type $db_version"
    echo "  - Configurações otimizadas para WordPress"
    echo "  - Otimizações de memória automáticas"
    echo ""
    read -p "Continuar? [S/n]: " confirm
    if [[ "$confirm" =~ ^[Nn]$ ]]; then
      msg_info "Operação cancelada"
      return 0
    fi
  fi
  
  # Instalar
  case $db_type in
    mysql)
      install_mysql "$db_version"
      configure_systemd_override "mysql"
      setup_db_config "mysql" "$db_version"
      restart_database "mysql"
      ;;
    mariadb)
      install_mariadb "$db_version"
      configure_systemd_override "mariadb"
      setup_db_config "mariadb" "$db_version"
      restart_database "mariadb"
      ;;
    *)
      msg_error "Tipo de database inválido: $db_type"
      return 1
      ;;
  esac
  
  msg_success "$db_type $db_version instalado com sucesso!"
  
  # Salvar informações
  mkdir -p ~/.iw
  {
    echo "Database: $db_type $db_version"
    echo "Root Password: $MYSQL_ROOT_PASSWORD"
    echo "Installed: $(date)"
  } >> ~/.iw/database.txt
  
  echo ""
  echo -e "${CYAN}Informações:${NC}"
  echo "  Tipo: $db_type $db_version"
  echo "  Senha root: $MYSQL_ROOT_PASSWORD"
  echo "  ${RED}IMPORTANTE: Salve a senha root!${NC}"
  echo ""
  echo "  Credenciais salvas em: ~/.iw/database.txt"
}

# =============================================================================
# PROCESSAMENTO DE ARGUMENTOS
# =============================================================================
parse_args() {
  while [[ $# -gt 0 ]]; do
    case $1 in
      -t|--type)
        DB_TYPE="$2"
        shift 2
        ;;
      -v|--version)
        DB_VERSION="$2"
        shift 2
        ;;
      -p|--password)
        MYSQL_ROOT_PASSWORD="$2"
        shift 2
        ;;
      -f|--force)
        FORCE=true
        shift
        ;;
      -h|--help)
        show_help
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

# =============================================================================
# EXECUÇÃO PRINCIPAL
# =============================================================================
main() {
  check_root
  setup_environment
  
  parse_args "$@"
  
  # Se tipo não especificado, mostrar menu
  if [ -z "$DB_TYPE" ] || [ -z "$DB_VERSION" ]; then
    echo -e "${BOLD}╔═══════════════════════════════════════════════════════════╗${NC}"
    echo -e "${BOLD}║           Instalador de Database Modular                  ║${NC}"
    echo -e "${BOLD}╚═══════════════════════════════════════════════════════════╝${NC}"
    
    if command_exists mysql; then
      echo ""
      echo -e "${YELLOW}Database já instalado:${NC}"
      mysql --version | sed 's/^/  /'
      exit 0
    fi
    
    interactive_select_database
  fi
  
  install_database "$DB_TYPE" "$DB_VERSION"
}

# Executar apenas se chamado diretamente
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  main "$@"
fi
