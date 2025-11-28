#!/bin/bash

if (( EUID != 0 )); then
    echo "Erro: Este script deve ser executado como root ou sudo!" >&2
    exit 100
fi

# Function to check if a command exists
command_exists() {
  command -v "$1" &> /dev/null
}

# Ask user for PHP version
read -p "PHP version to install (e.g., 8.1): " PHP_VERSION

# Generate a random MySQL root password
MYSQL_ROOT_PASSWORD=$(openssl rand -base64 12)

# Update the system
echo "Updating system..."
apt update && apt upgrade -y

# Install Nginx if not already installed
if ! command_exists nginx && ! command_exists openresty; then
  # Ask user for Nginx server
  echo "Choose your Nginx server:"
  echo "1) Nginx (official repository)"
  echo "2) Nginx-EE (WordOps)"
  echo "3) OpenResty"
  read -p "Enter your choice (1, 2, or 3): " NGINX_CHOICE

  case $NGINX_CHOICE in
    1)
      echo "Installing Nginx from official repository..."
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
      echo "Installing OpenResty..."
      apt install -y --no-install-recommends wget gnupg ca-certificates
      wget -O - https://openresty.org/package/pubkey.gpg | apt-key add -
      echo "deb http://openresty.org/package/ubuntu $(lsb_release -sc) main" | tee /etc/apt/sources.list.d/openresty.list
      apt update
      apt install -y openresty
      WEB_SERVER_SERVICE_NAME="openresty"
      # Symlink openresty's nginx to be found by other scripts
      if [ -f /usr/local/openresty/nginx/sbin/nginx ] && [ ! -f /usr/local/bin/nginx ]; then
          ln -s /usr/local/openresty/nginx/sbin/nginx /usr/local/bin/nginx
      fi
      ;;
    *)
      echo "Invalid choice. Exiting."
      exit 1
      ;;
  esac
fi

mkdir -p /etc/nginx/sites-enabled/
mkdir -p /etc/nginx/sites-available/
mkdir -p /etc/nginx/snippets/
wget -q -O /tmp/nginx.conf https://raw.githubusercontent.com/overdigo/wordpress-nginx/master/nginx/nginx.conf
wget -q -O /tmp/fastcgi.conf https://raw.githubusercontent.com/overdigo/wordpress-nginx/master/nginx/fastcgi.conf
wget -q -O /tmp/fastcgi-php.conf https://raw.githubusercontent.com/overdigo/wordpress-nginx/blob/master/nginx/snippets/fastcgi-php.conf
mv /tmp/nginx.conf /etc/nginx/nginx.conf | yes
mv /tmp/fastcgi.conf /etc/nginx/fastcgi.conf | yes
mv /tmp/fastcgi-php.conf /etc/nginx/snippets/fastcgi-php.conf | yes

# Install PHP if not already installed
if ! command_exists php; then
  echo "Installing PHP $PHP_VERSION..."
  add-apt-repository ppa:ondrej/php -y
  sleep 1
  apt update
  apt install php$PHP_VERSION-{fpm,mysql,curl,gd,common,xml,zip,xsl,bcmath,mbstring,imagick,cli,opcache,redis,intl,yaml}
fi

# Baixa configurações personalizadas do PHP
echo "Baixando configurações do PHP..."
wget -q -O /tmp/php-fpm.conf https://raw.githubusercontent.com/overdigo/wordpress-nginx/master/php/${PHP_VERSION}/fpm/php-fpm.conf
wget -q -O /tmp/php.ini https://raw.githubusercontent.com/overdigo/wordpress-nginx/master/php/${PHP_VERSION}/fpm/php.ini
wget -q -O /tmp/sock1.conf https://raw.githubusercontent.com/overdigo/wordpress-nginx/master/php/${PHP_VERSION}/fpm/pool.d/sock1.conf
wget -q -O /tmp/sock2.conf https://raw.githubusercontent.com/overdigo/wordpress-nginx/master/php/${PHP_VERSION}/fpm/pool.d/sock2.conf
wget -q -O /tmp/admin.conf https://raw.githubusercontent.com/overdigo/wordpress-nginx/master/php/${PHP_VERSION}/fpm/pool.d/admin.conf
wget -q -O /tmp/tcp.conf.disable https://raw.githubusercontent.com/overdigo/wordpress-nginx/master/php/${PHP_VERSION}/fpm/pool.d/tcp.conf.disable

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
mv /tmp/tcp.conf.disable /etc/php/${PHP_VERSION}/fpm/pool.d/tcp.conf.disable

WEB_SERVER_SERVICE_NAME="" # This will be set to 'nginx' or 'openresty'
DB_SERVICE_NAME="" # This will be set to 'mysql' or 'mariadb' if a DB is installed.

# Function to detect system memory and choose appropriate DB config
setup_db_config() {
  DB_TYPE=$1 # "mysql" or "mariadb"
  
  # Get total memory in MB
  total_mem=$(free -m | awk '/^Mem:/{print $2}')
  
  echo "System has $total_mem MB of RAM"
  
  local config_file
  local dest_config_file
  if [ $total_mem -lt 4096 ]; then
    echo "Using small DB configuration (optimized for systems with less than 4GB RAM)"
    config_file="mysql/my-small.cnf"
    dest_config_file="/etc/mysql/conf.d/my-small.cnf"
  elif [ $total_mem -lt 16384 ]; then
    echo "Using medium DB configuration (optimized for systems with 4-16GB RAM)"
    config_file="mysql/my-medium.cnf"
    dest_config_file="/etc/mysql/conf.d/my-medium.cnf"
  else
    echo "Using large DB configuration (optimized for systems with more than 16GB RAM)"
    config_file="mysql/my-large.cnf"
    dest_config_file="/etc/mysql/conf.d/my-large.cnf"
  fi

  # For MySQL 8.0+, query_cache is removed. We remove it for all for simplicity and compatibility.
  echo "Applying DB configuration and removing deprecated query_cache settings..."
  # Create the directory if it doesn't exist
  mkdir -p "$(dirname "$dest_config_file")"
  sed '/query_cache/d' "$config_file" > "$dest_config_file"

  # Restart DB to apply new configuration
  echo "Restarting $DB_TYPE..."
  systemctl restart $DB_TYPE
}

# Install Database if not already installed
if ! command_exists mysql; then
  echo "Choose your database server:"
  echo "1) MySQL"
  echo "2) MariaDB"
  read -p "Enter your choice (1 or 2): " DB_CHOICE

  if [ "$DB_CHOICE" == "1" ]; then
    # MySQL Installation
    apt install -y debconf-utils
    echo "Choose MySQL version:"
    echo "1) MySQL 8.4"
    echo "2) MySQL 8.0"
    read -p "Enter your choice (1 or 2): " MYSQL_VERSION_CHOICE

    if [ "$MYSQL_VERSION_CHOICE" == "1" ]; then
        echo "mysql-apt-config mysql-apt-config/select-server select mysql-8.4" | debconf-set-selections
    elif [ "$MYSQL_VERSION_CHOICE" == "2" ]; then
        echo "mysql-apt-config mysql-apt-config/select-server select mysql-8.0" | debconf-set-selections
    else
        echo "Invalid choice. Exiting."
        exit 1
    fi

    echo "Installing MySQL..."
    wget -q https://dev.mysql.com/get/mysql-apt-config_0.8.34-1_all.deb
    DEBIAN_FRONTEND=noninteractive dpkg -i mysql-apt-config_0.8.34-1_all.deb
    apt-key adv --keyserver keyserver.ubuntu.com --recv-keys B7B3B788A8D3785C
    apt update
    apt install -y mysql-server
    
    # Setup MySQL root password
    mysql --execute="ALTER USER 'root'@'localhost' IDENTIFIED WITH mysql_native_password BY '$MYSQL_ROOT_PASSWORD'; FLUSH PRIVILEGES;"
    
    DB_SERVICE_NAME="mysql"

  elif [ "$DB_CHOICE" == "2" ]; then
    # MariaDB Installation
    echo "Choose MariaDB LTS version:"
    echo "1) 10.11"
    echo "2) 10.6"
    echo "3) 10.5"
    read -p "Enter your choice (1, 2, or 3): " MARIADB_VERSION_CHOICE

    case $MARIADB_VERSION_CHOICE in
        1) MARIADB_VERSION="10.11" ;;
        2) MARIADB_VERSION="10.6" ;;
        3) MARIADB_VERSION="10.5" ;;
        *) echo "Invalid choice. Exiting."; exit 1 ;;
    esac

    echo "Installing MariaDB $MARIADB_VERSION..."
    apt install -y apt-transport-https curl
    curl -o /etc/apt/trusted.gpg.d/mariadb_release_signing_key.asc 'https://mariadb.org/mariadb_release_signing_key.asc'
    sh -c "echo 'deb https://mirrors.xtom.de/mariadb/repo/$MARIADB_VERSION/ubuntu `lsb_release -cs` main' > /etc/apt/sources.list.d/mariadb.list"
    apt update
    apt install -y mariadb-server
    
    # Setup MariaDB root password
    mysql --execute="ALTER USER 'root'@'localhost' IDENTIFIED BY '$MYSQL_ROOT_PASSWORD'; FLUSH PRIVILEGES;"

    DB_SERVICE_NAME="mariadb"
  else
    echo "Invalid choice. Exiting."
    exit 1
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
  setup_db_config "$DB_SERVICE_NAME"
fi

# Restart services
systemctl restart php$PHP_VERSION-fpm
if [ -n "$WEB_SERVER_SERVICE_NAME" ]; then
  systemctl restart "$WEB_SERVER_SERVICE_NAME"
else
  # If web server was not installed by this script, try restarting nginx by default
  if command_exists nginx; then
    systemctl restart nginx
  elif command_exists openresty; then
    systemctl restart openresty
  fi
fi

# Final message
{
  echo -e "\nSetup completed successfully!"
  echo "PHP version: $PHP_VERSION"
  echo "MySQL root password: $MYSQL_ROOT_PASSWORD"
  echo "Remember to save your MySQL root password!"

  # Security notice
  >> ~/.iw/server.txt
  echo -e "\nSecurity Notice:"
  echo "- MySQL is configured to only accept connections from localhost"
  echo "- Remember to secure your server with a firewall (e.g., UFW)"
  echo "- Consider installing fail2ban for additional security"
} | tee ~/.iw/server.txt

# Security notice
echo -e "\nSecurity Notice:"
echo "- MySQL is configured to only accept connections from localhost"
echo "- Remember to secure your server with a firewall (e.g., UFW)"
echo "- Consider installing fail2ban for additional security"

# Apply sysctl settings for performance and security
cat <<EOF >> /etc/sysctl.d/99-sysctl.conf
# Increase the maximum number of open file descriptors
fs.file-max = 2097152

# Increase the maximum number of incoming connections
net.core.somaxconn = 65535

# Enable TCP SYN cookies to protect against SYN flood attacks
net.ipv4.tcp_syncookies = 1

# Adjust TCP buffer sizes for better throughput
net.core.rmem_max = 16777216
net.core.wmem_max = 16777216
net.ipv4.tcp_rmem = 4096 87380 16777216
net.ipv4.tcp_wmem = 4096 65536 16777216

# Disable IP source routing
net.ipv4.conf.all.accept_source_route = 0
net.ipv4.conf.default.accept_source_route = 0

# Enable IP spoofing protection
net.ipv4.conf.all.rp_filter = 1
net.ipv4.conf.default.rp_filter = 1

# Disable ICMP redirects
net.ipv4.conf.all.accept_redirects = 0
net.ipv4.conf.default.accept_redirects = 0
EOF

# Apply the changes
sysctl -p 
