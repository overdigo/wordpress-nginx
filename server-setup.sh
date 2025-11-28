#!/bin/bash

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
if ! command_exists nginx; then
  echo "Installing Nginx..."
  apt install -y software-properties-common
  add-apt-repository ppa:wordops/nginx-wo -y
  sleep 1
  apt update
  apt install -y nginx-custom nginx-wo
fi

wget -q -O /tmp/nginx.conf https://raw.githubusercontent.com/overdigo/wordpress-nginx/master/nginx/nginx.conf
mv /tmp/nginx.conf /etc/nginx/nginx.conf

# Install PHP if not already installed
if ! command_exists php; then
  echo "Installing PHP $PHP_VERSION..."
  add-apt-repository ppa:ondrej/php -y
  sleep 1
  apt update
  apt install -y php$PHP_VERSION-fpm php$PHP_VERSION-mysql php$PHP_VERSION-curl php$PHP_VERSION-intl php$PHP_VERSION-gd php$PHP_VERSION-mbstring php$PHP_VERSION-xml php$PHP_VERSION-zip php$PHP_VERSION-bcmath php$PHP_VERSION-imagick
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

# Install MySQL if not already installed
if ! command_exists mysql; then
  echo "Installing MySQL..."
  wget https://dev.mysql.com/get/mysql-apt-config_0.8.24-1_all.deb
  DEBIAN_FRONTEND=noninteractive dpkg -i mysql-apt-config_0.8.24-1_all.deb
  apt update
  apt install -y mysql-server
  
  # Setup MySQL root password
  mysql --execute="ALTER USER 'root'@'localhost' IDENTIFIED WITH mysql_native_password BY '$MYSQL_ROOT_PASSWORD'; FLUSH PRIVILEGES;"
fi

# Function to detect system memory and choose appropriate MySQL config
setup_mysql_config() {
  # Get total memory in MB
  total_mem=$(free -m | awk '/^Mem:/{print $2}')
  
  echo "System has $total_mem MB of RAM"
  
  if [ $total_mem -lt 4096 ]; then
    echo "Using small MySQL configuration (optimized for systems with less than 4GB RAM)"
    cp mysql/my-small.cnf /etc/mysql/mysql.conf.d/my-small.cnf
  elif [ $total_mem -lt 16384 ]; then
    echo "Using medium MySQL configuration (optimized for systems with 4-16GB RAM)"
    cp mysql/my-medium.cnf /etc/mysql/mysql.conf.d/my-medium.cnf
  else
    echo "Using large MySQL configuration (optimized for systems with more than 16GB RAM)"
    cp mysql/my-large.cnf /etc/mysql/mysql.conf.d/my-large.cnf
  fi
  
  # Restart MySQL to apply new configuration
  systemctl restart mysql
}

# Install WP-CLI if not already installed
if ! command_exists wp; then
  echo "Installing WP-CLI..."
  curl -O https://raw.githubusercontent.com/wp-cli/builds/gh-pages/phar/wp-cli.phar
  chmod +x wp-cli.phar
  mv wp-cli.phar /usr/local/bin/wp
fi

# Apply appropriate MySQL configuration based on system memory
echo "Configuring MySQL..."
setup_mysql_config

# Restart services
systemctl restart php$PHP_VERSION-fpm
systemctl restart nginx
systemctl restart mysql

# Final message
{
  echo -e "\nSetup completed successfully!"
  echo "PHP version: $PHP_VERSION"
  echo "MySQL root password: $MYSQL_ROOT_PASSWORD"
  echo "Remember to save your MySQL root password!"

  # Security notice
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