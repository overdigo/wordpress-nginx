#!/bin/bash

if (( EUID != 0 )); then
    echo "Erro: Este script deve ser executado como root ou sudo!" >&2
    exit 100
fi

timedatectl set-timezone America/Sao_Paulo

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" &> /dev/null && pwd)

# Function to check if a command exists
command_exists() {
  command -v "$1" &> /dev/null
}

# =================================================================
# FUNÇÕES DE COLETA DE CONFIGURAÇÃO COM CONFIRMAÇÃO
# =================================================================

# Cores para melhor visualização
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color
BOLD='\033[1m'

# Função para exibir o menu de PHP
select_php_version() {
  echo -e "\n${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
  echo -e "${BOLD}📦 Versão do PHP${NC}"
  echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
  read -p "Digite a versão do PHP (ex: 8.1, 8.2, 8.3, 8.4): " PHP_VERSION
  PHP_VERSION_NO_DOT=${PHP_VERSION//./}
}

# Função para selecionar Nginx
select_nginx() {
  echo -e "\n${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
  echo -e "${BOLD}🌐 Servidor Nginx${NC}"
  echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
  
  if command_exists nginx; then
    echo -e "${GREEN}✓ Nginx já está instalado${NC}"
    NGINX_CHOICE="0"
    NGINX_DESCRIPTION="Já instalado"
    return
  fi
  
  echo "1) Nginx (repositório oficial nginx.org)"
  echo "2) Nginx-EE (repositório WordOps)"
  echo "3) Nginx (repositório Ubuntu)"
  read -p "Escolha (1, 2, ou 3): " NGINX_CHOICE
  
  case $NGINX_CHOICE in
    1) NGINX_DESCRIPTION="Nginx (nginx.org)" ;;
    2) NGINX_DESCRIPTION="Nginx-EE (WordOps)" ;;
    3) NGINX_DESCRIPTION="Nginx (Ubuntu)" ;;
    *) NGINX_DESCRIPTION="Inválido"; NGINX_CHOICE="" ;;
  esac
}

# Função para selecionar Database
select_database() {
  echo -e "\n${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
  echo -e "${BOLD}🗄️  Servidor de Banco de Dados${NC}"
  echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
  
  if command_exists mysql; then
    echo -e "${GREEN}✓ MySQL/MariaDB já está instalado${NC}"
    DB_CHOICE="0"
    DB_DESCRIPTION="Já instalado"
    DB_VERSION_CHOICE=""
    return
  fi
  
  echo "1) MySQL"
  echo "2) MariaDB"
  read -p "Escolha (1 ou 2): " DB_CHOICE
  
  if [ "$DB_CHOICE" == "1" ]; then
    echo -e "\n${YELLOW}Versões do MySQL disponíveis:${NC}"
    echo "1) MySQL 8.4"
    echo "2) MySQL 8.0"
    read -p "Escolha (1 ou 2): " DB_VERSION_CHOICE
    
    case $DB_VERSION_CHOICE in
      1) DB_DESCRIPTION="MySQL 8.4" ;;
      2) DB_DESCRIPTION="MySQL 8.0" ;;
      *) DB_DESCRIPTION="MySQL (versão inválida)"; DB_VERSION_CHOICE="" ;;
    esac
    
  elif [ "$DB_CHOICE" == "2" ]; then
    echo -e "\n${YELLOW}Versões LTS do MariaDB disponíveis:${NC}"
    echo "1) MariaDB 10.11"
    echo "2) MariaDB 10.6"
    echo "3) MariaDB 10.5"
    read -p "Escolha (1, 2, ou 3): " DB_VERSION_CHOICE
    
    case $DB_VERSION_CHOICE in
      1) DB_DESCRIPTION="MariaDB 10.11" ;;
      2) DB_DESCRIPTION="MariaDB 10.6" ;;
      3) DB_DESCRIPTION="MariaDB 10.5" ;;
      *) DB_DESCRIPTION="MariaDB (versão inválida)"; DB_VERSION_CHOICE="" ;;
    esac
  else
    DB_DESCRIPTION="Inválido"
    DB_CHOICE=""
  fi
}

# Função para exibir resumo das configurações
show_summary() {
  echo -e "\n${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
  echo -e "${BOLD}📋 RESUMO DAS CONFIGURAÇÕES${NC}"
  echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
  echo -e "  ${BOLD}1)${NC} PHP:      ${CYAN}$PHP_VERSION${NC}"
  echo -e "  ${BOLD}2)${NC} Nginx:    ${CYAN}$NGINX_DESCRIPTION${NC}"
  echo -e "  ${BOLD}3)${NC} Database: ${CYAN}$DB_DESCRIPTION${NC}"
  echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
}

# Função principal de coleta de configuração
collect_configuration() {
  while true; do
    # Coleta inicial
    if [ -z "$PHP_VERSION" ]; then
      select_php_version
    fi
    
    if [ -z "$NGINX_CHOICE" ]; then
      select_nginx
    fi
    
    if [ -z "$DB_CHOICE" ]; then
      select_database
    fi
    
    # Exibe resumo
    show_summary
    
    # Pergunta confirmação
    echo -e "\n${YELLOW}O que você deseja fazer?${NC}"
    echo "  c) Confirmar e iniciar instalação"
    echo "  1) Editar versão do PHP"
    echo "  2) Editar escolha do Nginx"
    echo "  3) Editar escolha do Database"
    echo "  q) Cancelar e sair"
    read -p "Escolha: " CONFIRM_CHOICE
    
    case $CONFIRM_CHOICE in
      c|C)
        # Validar se todas as escolhas são válidas
        if [ -z "$PHP_VERSION" ]; then
          echo -e "${RED}Erro: Versão do PHP não definida${NC}"
          continue
        fi
        if [ -z "$NGINX_CHOICE" ] && ! command_exists nginx; then
          echo -e "${RED}Erro: Escolha do Nginx inválida${NC}"
          continue
        fi
        if [ -z "$DB_CHOICE" ] && ! command_exists mysql; then
          echo -e "${RED}Erro: Escolha do Database inválida${NC}"
          continue
        fi
        if [ "$DB_CHOICE" != "0" ] && [ -n "$DB_CHOICE" ] && [ -z "$DB_VERSION_CHOICE" ]; then
          echo -e "${RED}Erro: Versão do Database não definida${NC}"
          continue
        fi
        
        echo -e "\n${GREEN}✓ Configurações confirmadas! Iniciando instalação...${NC}\n"
        break
        ;;
      1)
        PHP_VERSION=""
        select_php_version
        ;;
      2)
        if command_exists nginx; then
          echo -e "${YELLOW}Nginx já está instalado, não pode ser alterado.${NC}"
        else
          NGINX_CHOICE=""
          NGINX_DESCRIPTION=""
          select_nginx
        fi
        ;;
      3)
        if command_exists mysql; then
          echo -e "${YELLOW}Database já está instalado, não pode ser alterado.${NC}"
        else
          DB_CHOICE=""
          DB_VERSION_CHOICE=""
          DB_DESCRIPTION=""
          select_database
        fi
        ;;
      q|Q)
        echo -e "${RED}Instalação cancelada pelo usuário.${NC}"
        exit 0
        ;;
      *)
        echo -e "${RED}Opção inválida. Tente novamente.${NC}"
        ;;
    esac
  done
}

# =================================================================
# INÍCIO DO SCRIPT
# =================================================================

echo -e "${BOLD}"
echo "╔═══════════════════════════════════════════════════════════╗"
echo "║     WordPress + Nginx Server Setup Script                 ║"
echo "║     Configuração interativa com confirmação               ║"
echo "╚═══════════════════════════════════════════════════════════╝"
echo -e "${NC}"

# Coleta todas as configurações com confirmação
collect_configuration

# Save PHP version to global environment
echo "export DEFAULT_PHP_VERSION=$PHP_VERSION" > /etc/profile.d/wordpress-nginx-env.sh
chmod +x /etc/profile.d/wordpress-nginx-env.sh

# Generate a random MySQL root password
MYSQL_ROOT_PASSWORD=$(openssl rand -base64 12)

export DEBIAN_FRONTEND=noninteractive

# Update the system
echo "Updating system..."
apt update && apt upgrade -y

# Install Nginx based on user selection
if [ "$NGINX_CHOICE" != "0" ] && ! command_exists nginx; then
  case $NGINX_CHOICE in
    1)
      echo "Installing Nginx from official nginx.org repository..."
      apt install -y curl gnupg2 ca-certificates lsb-release ubuntu-keyring
      curl https://nginx.org/keys/nginx_signing.key | gpg --dearmor | tee /usr/share/keyrings/nginx-archive-keyring.gpg >/dev/null
      echo "deb [signed-by=/usr/share/keyrings/nginx-archive-keyring.gpg] http://nginx.org/packages/ubuntu `lsb_release -cs` nginx" | tee /etc/apt/sources.list.d/nginx.list
      apt update
      apt install -y nginx
      WEB_SERVER_SERVICE_NAME="nginx"
      ;;
    2)
      echo "Installing Nginx-EE from WordOps repository..."
      apt install -y software-properties-common
      add-apt-repository ppa:wordops/nginx-wo -y
      sleep 1
      apt update
      apt install -y nginx-custom nginx-wo
      WEB_SERVER_SERVICE_NAME="nginx"
      ;;
    3)
      echo "Installing Nginx from Ubuntu repository..."
      apt install -y nginx libnginx-mod-http-brotli-filter libnginx-mod-http-headers-more-filter
      WEB_SERVER_SERVICE_NAME="nginx"
      ;;
  esac
fi

mkdir -p /etc/nginx/sites-enabled/
mkdir -p /etc/nginx/sites-available/
mkdir -p /etc/nginx/snippets/
mkdir -p /etc/nginx/ssl
openssl ecparam -name prime256v1 -out ecparam.pem
openssl req -x509 -nodes -days 365 -newkey ec:ecparam.pem \
    -keyout /etc/nginx/ssl/selfsigned.key \
    -out /etc/nginx/ssl/selfsigned.crt \
    -subj "/C=BR/ST=State/L=City/O=Organization/CN=localhost"
rm ecparam.pem
cp "$SCRIPT_DIR/nginx/nginx.conf" /etc/nginx/nginx.conf
cp "$SCRIPT_DIR/nginx/default" /etc/nginx/sites-available/default
ln -sf /etc/nginx/sites-available/default /etc/nginx/sites-enabled/default
cp "$SCRIPT_DIR/nginx/fastcgi.conf" /etc/nginx/fastcgi.conf
cp "$SCRIPT_DIR/nginx/snippets/fastcgi-php.conf" /etc/nginx/snippets/fastcgi-php.conf

# Download 8G Firewall (advanced security rules for Nginx)
echo "Baixando 8G Firewall..."
wget -q -O /etc/nginx/conf.d/8g-firewall.conf https://github.com/t18d/nG-SetEnvIf/raw/refs/heads/develop/8g-firewall.conf
wget -q -O /etc/nginx/snippets/8g.conf https://github.com/t18d/nG-SetEnvIf/raw/refs/heads/develop/8g.conf
echo "8G Firewall instalado com sucesso!"

# Install PHP if not already installed
if ! command_exists php; then
  echo "Installing PHP $PHP_VERSION..."
  add-apt-repository ppa:ondrej/php -y
  sleep 1
  apt update
  
  PHP_PACKAGES="php${PHP_VERSION}-fpm php${PHP_VERSION}-mysql php${PHP_VERSION}-curl php${PHP_VERSION}-gd php${PHP_VERSION}-common php${PHP_VERSION}-xml php${PHP_VERSION}-zip php${PHP_VERSION}-xsl php${PHP_VERSION}-bcmath php${PHP_VERSION}-mbstring php${PHP_VERSION}-imagick php${PHP_VERSION}-cli php${PHP_VERSION}-opcache php${PHP_VERSION}-redis php${PHP_VERSION}-intl php${PHP_VERSION}-yaml"

  if [ "$PHP_VERSION" == "8.5" ]; then
    PHP_PACKAGES=$(echo "$PHP_PACKAGES" | sed "s/php8.5-opcache//")
  fi

  apt-get install -y --ignore-missing $PHP_PACKAGES
fi

# Gera configurações personalizadas do PHP a partir dos templates locais
echo "Gerando configurações do PHP..."

# Função para processar templates mustache
process_mustache() {
    local input=$1
    local output=$2
    sed -e "s/{{PHP_VERSION}}/$PHP_VERSION/g" \
        -e "s/{{PHP_VERSION_NO_DOT}}/$PHP_VERSION_NO_DOT/g" \
        "$input" > "$output"
}

process_mustache "$SCRIPT_DIR/php/php-fpm.mustache" "/tmp/php-fpm.conf"
process_mustache "$SCRIPT_DIR/php/php-admin.mustache" "/tmp/admin.conf"
process_mustache "$SCRIPT_DIR/php/get-sock-1.mustache" "/tmp/sock1.conf"
process_mustache "$SCRIPT_DIR/php/get-sock-2.mustache" "/tmp/sock2.conf"
process_mustache "$SCRIPT_DIR/php/sock-other.mustache" "/tmp/sock-other.conf"

cp "$SCRIPT_DIR/php/php.ini" "/tmp/php.ini"

# Faz backup das configurações originais
echo "Fazendo backup das configurações padrão..."
cp /etc/php/${PHP_VERSION}/fpm/php-fpm.conf /etc/php/${PHP_VERSION}/fpm/php-fpm.conf.bkp
cp /etc/php/${PHP_VERSION}/fpm/php.ini /etc/php/${PHP_VERSION}/fpm/php.ini.bkp
cp /etc/php/${PHP_VERSION}/fpm/pool.d/www.conf /etc/php/${PHP_VERSION}/fpm/pool.d/www.conf.bkp
rm /etc/php/${PHP_VERSION}/fpm/pool.d/www.conf

# Substitui configurações
echo "Aplicando novas configurações..."
mv /tmp/php-fpm.conf /etc/php/${PHP_VERSION}/fpm/php-fpm.conf
cp /tmp/php.ini /etc/php/${PHP_VERSION}/fpm/php.ini
mv /tmp/php.ini /etc/php/${PHP_VERSION}/cli/php.ini  # Aplica também para CLI
mv /tmp/sock1.conf /etc/php/${PHP_VERSION}/fpm/pool.d/sock1.conf
mv /tmp/sock2.conf /etc/php/${PHP_VERSION}/fpm/pool.d/sock2.conf
mv /tmp/admin.conf /etc/php/${PHP_VERSION}/fpm/pool.d/admin.conf
mv /tmp/sock-other.conf /etc/php/${PHP_VERSION}/fpm/pool.d/sock-other.conf

WEB_SERVER_SERVICE_NAME="" # This will be set to 'nginx'
DB_SERVICE_NAME="" # This will be set to 'mysql' or 'mariadb' if a DB is installed.
DB_TYPE="" # This will be set to 'mysql' or 'mariadb'
DB_VERSION="" # This will be set to the DB version (e.g., '8.4', '10.11')

# Function to detect system memory and generate optimized DB config
setup_db_config() {
  local DB_TYPE=$1 # "mysql" or "mariadb"
  local DB_VERSION=$2 # ex: "8.4", "8.0", "10.11"
  
  # Get total memory in MB
  local total_mem=$(free -m | awk '/^Mem:/{print $2}')
  
  echo "System has $total_mem MB of RAM"
  echo "Configuring for $DB_TYPE $DB_VERSION..."
  
  # Determine profile based on RAM
  local PROFILE
  if [ $total_mem -lt 4096 ]; then
    PROFILE="small"
    echo "Using SMALL profile (< 4GB RAM)"
  elif [ $total_mem -lt 16384 ]; then
    PROFILE="medium"
    echo "Using MEDIUM profile (4-16GB RAM)"
  else
    PROFILE="large"
    echo "Using LARGE profile (> 16GB RAM)"
  fi
  
  # Calculate memory allocations (values in MB)
  local buffer_pool_mb=$((total_mem * 70 / 100))
  
  # Calculate buffer pool instances (1 per GB, max 64)
  local pool_instances=$((buffer_pool_mb / 1024))
  [ $pool_instances -lt 1 ] && pool_instances=1
  [ $pool_instances -gt 64 ] && pool_instances=64
  
  # Calculate chunk size (pool / instances, min 128M)
  local chunk_mb=$((buffer_pool_mb / pool_instances))
  [ $chunk_mb -lt 128 ] && chunk_mb=128
  
  # Set variables based on profile
  case $PROFILE in
    small)
      local MAX_CONNECTIONS=100
      local THREAD_STACK="192K"
      local THREAD_CACHE_SIZE=8
      local SORT_BUFFER="512K"
      local JOIN_BUFFER="256K"
      local READ_BUFFER="1M"
      local READ_RND_BUFFER="1M"
      local TMP_TABLE="64M"
      local TABLE_OPEN_CACHE=800
      local TABLE_DEF_CACHE=400
      local TABLE_OPEN_CACHE_INSTANCES=""
      local INNODB_FLUSH_TRX=2
      local INNODB_IO_CAP=200
      local INNODB_IO_CAP_MAX=""
      local INNODB_READ_THREADS=4
      local INNODB_WRITE_THREADS=4
      local INNODB_OPEN_FILES=400
      local KEY_BUFFER="32M"
      local MYISAM_SORT="64M"
      local MAX_PACKET="64M"
      local LONG_QUERY=2
      local LOG_BUFFER="16M"
      local REDO_LOG_MB=256
      local INNODB_FLUSH_NEIGHBORS=""
      local INNODB_LRU_SCAN=""
      local PERF_SCHEMA=""
      ;;
    medium)
      local MAX_CONNECTIONS=300
      local THREAD_STACK="256K"
      local THREAD_CACHE_SIZE=24
      local SORT_BUFFER="4M"
      local JOIN_BUFFER="4M"
      local READ_BUFFER="2M"
      local READ_RND_BUFFER="2M"
      local TMP_TABLE="256M"
      local TABLE_OPEN_CACHE=4000
      local TABLE_DEF_CACHE=2000
      local TABLE_OPEN_CACHE_INSTANCES=""
      local INNODB_FLUSH_TRX=2
      local INNODB_IO_CAP=600
      local INNODB_IO_CAP_MAX=""
      local INNODB_READ_THREADS=6
      local INNODB_WRITE_THREADS=6
      local INNODB_OPEN_FILES=1000
      local KEY_BUFFER="128M"
      local MYISAM_SORT="128M"
      local MAX_PACKET="128M"
      local LONG_QUERY=2
      local LOG_BUFFER="32M"
      local REDO_LOG_MB=512
      local INNODB_FLUSH_NEIGHBORS=""
      local INNODB_LRU_SCAN=""
      local PERF_SCHEMA=""
      ;;
    large)
      local MAX_CONNECTIONS=800
      local THREAD_STACK="384K"
      local THREAD_CACHE_SIZE=64
      local SORT_BUFFER="16M"
      local JOIN_BUFFER="8M"
      local READ_BUFFER="8M"
      local READ_RND_BUFFER="8M"
      local TMP_TABLE="512M"
      local TABLE_OPEN_CACHE=10000
      local TABLE_DEF_CACHE=5000
      local TABLE_OPEN_CACHE_INSTANCES="table_open_cache_instances = 16"
      local INNODB_FLUSH_TRX=1
      local INNODB_IO_CAP=2000
      local INNODB_IO_CAP_MAX="innodb_io_capacity_max = 4000"
      local INNODB_READ_THREADS=12
      local INNODB_WRITE_THREADS=12
      local INNODB_OPEN_FILES=8000
      local KEY_BUFFER="256M"
      local MYISAM_SORT="256M"
      local MAX_PACKET="256M"
      local LONG_QUERY=1
      local LOG_BUFFER="64M"
      local REDO_LOG_MB=2048
      local INNODB_FLUSH_NEIGHBORS="innodb_flush_neighbors = 0"
      local INNODB_LRU_SCAN="innodb_lru_scan_depth = 1024"
      local PERF_SCHEMA="performance_schema = ON
performance_schema_instrument = 'wait/lock/metadata/sql/%=ON'
performance_schema_instrument = 'statement/%=ON'
performance_schema_consumer_events_statements_current = ON
performance_schema_consumer_events_statements_history = ON"
      ;;
  esac
  
  # Format buffer pool size (use G if >= 1024MB, else use M)
  local BUFFER_POOL_SIZE
  if [ $buffer_pool_mb -ge 1024 ]; then
    BUFFER_POOL_SIZE="$((buffer_pool_mb / 1024))G"
  else
    BUFFER_POOL_SIZE="${buffer_pool_mb}M"
  fi
  
  # Handle redo log configuration based on DB type
  local REDO_LOG_CONFIG
  if [ "$DB_TYPE" == "mysql" ]; then
    # MySQL 8.0.30+ uses innodb_redo_log_capacity
    REDO_LOG_CONFIG="innodb_redo_log_capacity = ${REDO_LOG_MB}M"
  else
    # MariaDB uses innodb_log_file_size
    REDO_LOG_CONFIG="innodb_log_file_size = ${REDO_LOG_MB}M"
  fi

  # Create temporary file for processing
  local tmp_config="/tmp/my-generated.cnf"
  
  # Process mustache template
  sed -e "s/{{TOTAL_RAM_MB}}/$total_mem/g" \
      -e "s/{{DB_TYPE}}/$DB_TYPE/g" \
      -e "s/{{DB_VERSION}}/$DB_VERSION/g" \
      -e "s/{{PROFILE}}/$PROFILE/g" \
      -e "s/{{INNODB_BUFFER_POOL_SIZE}}/$BUFFER_POOL_SIZE/g" \
      -e "s/{{INNODB_BUFFER_POOL_INSTANCES}}/$pool_instances/g" \
      -e "s/{{INNODB_BUFFER_POOL_CHUNK_SIZE}}/${chunk_mb}M/g" \
      -e "s/{{INNODB_LOG_BUFFER_SIZE}}/$LOG_BUFFER/g" \
      -e "s/{{INNODB_REDO_LOG_CONFIG}}/$REDO_LOG_CONFIG/g" \
      -e "s/{{MAX_CONNECTIONS}}/$MAX_CONNECTIONS/g" \
      -e "s/{{THREAD_STACK}}/$THREAD_STACK/g" \
      -e "s/{{THREAD_CACHE_SIZE}}/$THREAD_CACHE_SIZE/g" \
      -e "s/{{SORT_BUFFER_SIZE}}/$SORT_BUFFER/g" \
      -e "s/{{JOIN_BUFFER_SIZE}}/$JOIN_BUFFER/g" \
      -e "s/{{READ_BUFFER_SIZE}}/$READ_BUFFER/g" \
      -e "s/{{READ_RND_BUFFER_SIZE}}/$READ_RND_BUFFER/g" \
      -e "s/{{TMP_TABLE_SIZE}}/$TMP_TABLE/g" \
      -e "s/{{MAX_HEAP_TABLE_SIZE}}/$TMP_TABLE/g" \
      -e "s/{{TABLE_OPEN_CACHE}}/$TABLE_OPEN_CACHE/g" \
      -e "s/{{TABLE_DEFINITION_CACHE}}/$TABLE_DEF_CACHE/g" \
      -e "s/{{TABLE_OPEN_CACHE_INSTANCES}}/$TABLE_OPEN_CACHE_INSTANCES/g" \
      -e "s/{{INNODB_FLUSH_LOG_AT_TRX_COMMIT}}/$INNODB_FLUSH_TRX/g" \
      -e "s/{{INNODB_IO_CAPACITY}}/$INNODB_IO_CAP/g" \
      -e "s/{{INNODB_IO_CAPACITY_MAX}}/$INNODB_IO_CAP_MAX/g" \
      -e "s/{{INNODB_READ_IO_THREADS}}/$INNODB_READ_THREADS/g" \
      -e "s/{{INNODB_WRITE_IO_THREADS}}/$INNODB_WRITE_THREADS/g" \
      -e "s/{{INNODB_OPEN_FILES}}/$INNODB_OPEN_FILES/g" \
      -e "s/{{INNODB_FLUSH_NEIGHBORS}}/$INNODB_FLUSH_NEIGHBORS/g" \
      -e "s/{{INNODB_LRU_SCAN_DEPTH}}/$INNODB_LRU_SCAN/g" \
      -e "s/{{KEY_BUFFER_SIZE}}/$KEY_BUFFER/g" \
      -e "s/{{MYISAM_SORT_BUFFER_SIZE}}/$MYISAM_SORT/g" \
      -e "s/{{MAX_ALLOWED_PACKET}}/$MAX_PACKET/g" \
      -e "s/{{LONG_QUERY_TIME}}/$LONG_QUERY/g" \
      -e "s/{{PERFORMANCE_SCHEMA_CONFIG}}/$PERF_SCHEMA/g" \
      "$SCRIPT_DIR/mysql/my.mustache" > "$tmp_config"
  
  # Remove empty lines from optional configurations
  sed -i '/^$/d' "$tmp_config"
  
  # Create destination directory and copy config
  mkdir -p /etc/mysql/conf.d
  mv "$tmp_config" "/etc/mysql/conf.d/z-wordpress-optimized.cnf"
  
  echo "Configuration saved to /etc/mysql/conf.d/z-wordpress-optimized.cnf"
  echo "Buffer Pool: $BUFFER_POOL_SIZE (${pool_instances} instances)"
  
  # Restart DB to apply new configuration
  echo "Restarting $DB_TYPE..."
  systemctl restart $DB_TYPE
}

# Install Database based on user selection
if [ "$DB_CHOICE" != "0" ] && ! command_exists mysql; then
  if [ "$DB_CHOICE" == "1" ]; then
    # MySQL Installation
    apt install -y debconf-utils
    
    if [ "$DB_VERSION_CHOICE" == "1" ]; then
        MYSQL_VERSION="8.4"
        echo "mysql-apt-config mysql-apt-config/select-server select mysql-8.4" | debconf-set-selections
    elif [ "$DB_VERSION_CHOICE" == "2" ]; then
        MYSQL_VERSION="8.0"
        echo "mysql-apt-config mysql-apt-config/select-server select mysql-8.0" | debconf-set-selections
    fi
    
    DB_VERSION="$MYSQL_VERSION"

    echo "Installing MySQL $MYSQL_VERSION..."
    wget -q https://dev.mysql.com/get/mysql-apt-config_0.8.34-1_all.deb
    DEBIAN_FRONTEND=noninteractive dpkg -i mysql-apt-config_0.8.34-1_all.deb
    apt-key adv --keyserver keyserver.ubuntu.com --recv-keys B7B3B788A8D3785C
    apt update
    apt install -y mysql-server libjemalloc2
    
    # Setup MySQL root password
    mysql --execute="ALTER USER 'root'@'localhost' IDENTIFIED WITH mysql_native_password BY '$MYSQL_ROOT_PASSWORD'; FLUSH PRIVILEGES;"
    
    DB_SERVICE_NAME="mysql"
    DB_TYPE="mysql"

    # Cria o diretório de override se não existir
    mkdir -p /etc/systemd/system/mysql.service.d

    # Escreve o conteúdo do override no arquivo
    cat <<EOF > /etc/systemd/system/mysql.service.d/override.conf
[Service]
LimitNOFILE=131072
LimitNOFILESoft=131072
Nice=-5
LimitCore=1G
Environment="LD_PRELOAD=/usr/lib/x86_64-linux-gnu/libjemalloc.so.2"
Environment="TZ=America/Sao_Paulo"
EOF

    # Recarrega as configurações do systemd para aplicar alterações
    systemctl daemon-reload

    # Reinicia o serviço para aplicar as mudanças
    systemctl restart mysql.service

  elif [ "$DB_CHOICE" == "2" ]; then
    # MariaDB Installation
    case $DB_VERSION_CHOICE in
        1) MARIADB_VERSION="10.11" ;;
        2) MARIADB_VERSION="10.6" ;;
        3) MARIADB_VERSION="10.5" ;;
    esac

    echo "Installing MariaDB $MARIADB_VERSION..."
    apt install -y apt-transport-https curl libjemalloc2
    curl -o /etc/apt/trusted.gpg.d/mariadb_release_signing_key.asc 'https://mariadb.org/mariadb_release_signing_key.asc'
    sh -c "echo 'deb https://mirrors.xtom.de/mariadb/repo/$MARIADB_VERSION/ubuntu `lsb_release -cs` main' > /etc/apt/sources.list.d/mariadb.list"
    apt update
    apt install -y mariadb-server
    
    # Setup MariaDB root password
    mysql --execute="ALTER USER 'root'@'localhost' IDENTIFIED BY '$MYSQL_ROOT_PASSWORD'; FLUSH PRIVILEGES;"

    DB_SERVICE_NAME="mariadb"
    DB_TYPE="mariadb"
    DB_VERSION="$MARIADB_VERSION"
    
    # Cria o diretório de override se não existir
    mkdir -p /etc/systemd/system/mariadb.service.d

    # Escreve o conteúdo do override no arquivo
    cat <<EOF > /etc/systemd/system/mariadb.service.d/override.conf
[Service]
LimitNOFILE=131072
LimitNOFILESoft=131072
Nice=-5
LimitCore=1G
Environment="LD_PRELOAD=/usr/lib/x86_64-linux-gnu/libjemalloc.so.2"
Environment="TZ=America/Sao_Paulo"
EOF

    # Recarrega as configurações do systemd para aplicar alterações
    systemctl daemon-reload

    # Reinicia o serviço para aplicar as mudanças
    systemctl restart mariadb.service
  fi
fi

# Install WP-CLI if not already installed
if ! command_exists wp; then
  echo "Installing WP-CLI..."
  curl -O https://raw.githubusercontent.com/wp-cli/builds/gh-pages/phar/wp-cli.phar
  chmod +x wp-cli.phar
  mv wp-cli.phar /usr/local/bin/wp
fi

# Apply appropriate DB configuration based on system memory
if [ -n "$DB_SERVICE_NAME" ]; then
  echo "Configuring Database..."
  setup_db_config "$DB_TYPE" "$DB_VERSION"
fi

# Restart services
systemctl restart php$PHP_VERSION-fpm
if [ -n "$WEB_SERVER_SERVICE_NAME" ]; then
  systemctl restart "$WEB_SERVER_SERVICE_NAME"
else
  # If web server was not installed by this script, try restarting nginx by default
  if command_exists nginx; then
    systemctl restart nginx
  fi
fi
mkdir -p ~/.iw ; >> ~/.iw/server.txt
# Final message
{
  echo -e "\nSetup completed successfully!"
  echo "PHP version: $PHP_VERSION"
  echo "MySQL root password: $MYSQL_ROOT_PASSWORD"
  echo "Remember to save your MySQL root password!"

  # Security notice  
  echo -e "\nSecurity Notice:"
  echo "- MySQL is configured to only accept connections from localhost"
  echo "- Firewall nftables configurado com rate limiting em SSH"
  echo "- Consider installing fail2ban for additional security"
} | tee ~/.iw/server.txt

# Security notice
echo -e "\nSecurity Notice:"
echo "- MySQL is configured to only accept connections from localhost"
echo "- Firewall nftables configurado com rate limiting em SSH"
echo "- Consider installing fail2ban for additional security"

# Apply sysctl performance and security settings
echo "Aplicando configurações sysctl..."
cp "$SCRIPT_DIR/50-perf.conf" /etc/sysctl.d/50-perf.conf
sudo sysctl --system && service procps force-reload && deb-systemd-invoke restart procps.service

# =============================================================================
# FIREWALL NFTABLES
# =============================================================================
echo -e "\n${CYAN}Configurando firewall nftables...${NC}"

# Install nftables if not present
if ! command_exists nft; then
    echo "Instalando nftables..."
    apt install -y nftables
fi

# Copy nftables configuration
echo "Aplicando regras de firewall..."
cp "$SCRIPT_DIR/nftables.conf" /etc/nftables.conf

# Apply firewall rules
nft -f /etc/nftables.conf

# Enable nftables on boot
systemctl enable --now nftables

echo -e "${GREEN}✓ Firewall nftables configurado com sucesso!${NC}"
echo "  - SSH (22): Rate limited (10 conexões/minuto por IP)"
echo "  - HTTP (80): Aberta"
echo "  - HTTPS (443): Aberta (TCP + UDP para HTTP/3)"
echo "  - ICMP: Ping com rate limiting"
echo "  - Policy: DROP input/forward, ACCEPT output"

# Show active rules summary
echo -e "\nRegras ativas:"
nft list ruleset | grep -E "^table|chain|policy" | head -20
