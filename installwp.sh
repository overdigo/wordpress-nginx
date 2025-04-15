#!/bin/bash

# Coleta informações do usuário
read -p "Digite o domínio do site (ex: 192-168-0-117.sslip.io): " DOMAIN
read -p "Digite seu email: " ADMIN_EMAIL
read -p "Digite a versão do PHP a ser instalada (ex: 8.4): " PHP_VERSION

# Gera credenciais aleatórias
DB_NAME=$(openssl rand -hex 4)
DB_USER=$(openssl rand -hex 4)
DB_PASS=$(openssl rand -hex 8)
WP_ADMIN_USER="${DOMAIN%%.*}_$(openssl rand -hex 3)"
WP_ADMIN_PASS=$(openssl rand -hex 8)

# Atualiza sistema e adiciona repositórios
apt update && apt upgrade -y

# Instala Nginx via WordOps PPA
apt install -y software-properties-common
add-apt-repository ppa:wordops/nginx-wo -uy
apt install -y nginx-custom nginx-wo

# PHP (Ondrej PPA)
add-apt-repository ppa:ondrej/php -y

# MySQL 8.8 LTS
wget https://dev.mysql.com/get/mysql-apt-config_0.8.24-1_all.deb
DEBIAN_FRONTEND=noninteractive dpkg -i mysql-apt-config_0.8.24-1_all.deb
apt update

# Instala pacotes principais
apt install -y mysql-server php${PHP_VERSION}-fpm php${PHP_VERSION}-mysql php${PHP_VERSION}-xml php${PHP_VERSION}-curl php${PHP_VERSION}-gd php${PHP_VERSION}-mbstring php${PHP_VERSION}-imagick php${PHP_VERSION}-zip php${PHP_VERSION}-intl php${PHP_VERSION}-redis

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

# Configura MySQL
systemctl start mysql
mysql <<EOF
ALTER USER 'root'@'localhost' IDENTIFIED BY '$DB_PASS';
CREATE DATABASE $DB_NAME;
CREATE USER '$DB_USER'@'localhost' IDENTIFIED BY '$DB_PASS';
GRANT ALL PRIVILEGES ON $DB_NAME.* TO '$DB_USER'@'localhost';
FLUSH PRIVILEGES;
EOF

# Instala WP-CLI
curl -O https://raw.githubusercontent.com/wp-cli/builds/gh-pages/phar/wp-cli.phar
chmod +x wp-cli.phar
mv wp-cli.phar /usr/local/bin/wp

# Configura WordPress com HTTPS
cd /var/www/html
wp core download --locale=pt_BR --allow-root
wp config create --dbname=$DB_NAME --dbuser=$DB_USER --dbpass=$DB_PASS --allow-root
wp core install --url="https://$DOMAIN" --title="$DOMAIN" --admin_user="$WP_ADMIN_USER" --admin_password="$WP_ADMIN_PASS" --admin_email="$ADMIN_EMAIL" --allow-root

# Configura Nginx com SSL para domínios locais
mkdir -p /etc/nginx/ssl
openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
  -keyout /etc/nginx/ssl/$DOMAIN.key \
  -out /etc/nginx/ssl/$DOMAIN.crt \
  -subj "/CN=$DOMAIN"

cat > /etc/nginx/sites-available/wordpress <<EOF
upstream php${PHP_VERSION/.} {
    least_conn;

    server unix:/run/php/php${PHP_VERSION}-fpm1.sock;
    server unix:/run/php/php${PHP_VERSION}-fpm2.sock;

    keepalive 5;
}

upstream php${PHP_VERSION/.}_admin {
    server unix:/run/php/php${PHP_VERSION}-fpm-admin.sock;

    keepalive 5;
}

server {
    listen 80;
    server_name $DOMAIN;
    return 301 https://\$host\$request_uri;
}

server {
    listen 443 ssl;
    server_name $DOMAIN;

    http2 on;

    ssl_certificate /etc/nginx/ssl/$DOMAIN.crt;
    ssl_certificate_key /etc/nginx/ssl/$DOMAIN.key;

    root /var/www/html;
    index index.php;

    location / {
        try_files \$uri \$uri/ /index.php?\$args;
    }

    location ~ \.php$ {
        include snippets/fastcgi-php.conf;
        
        # Use admin pool for wp-admin and wp-login
        if (\$uri ~* "/wp-admin/|wp-login.php") {
            fastcgi_pass php${PHP_VERSION/.}_admin;
        }
        
        # Default pool for all other requests
        if (\$uri !~* "/wp-admin/|wp-login.php") {
            fastcgi_pass php${PHP_VERSION/.};
        }
    }
}
EOF

ln -s /etc/nginx/sites-available/wordpress /etc/nginx/sites-enabled/
nginx -t && systemctl restart nginx
chown -R www-data:www-data /var/www/html
find /var/www/html -type d -exec chmod 755 {} \;
find /var/www/html -type f -exec chmod 644 {} \;

# Informações finais
echo -e "\nInstalação concluída! Detalhes:"
echo "URL segura: https://$DOMAIN"
echo "Certificado SSL auto-assinado configurado (aceite o aviso do navegador)"
echo "Banco de Dados: $DB_NAME"
echo "Usuário BD: $DB_USER"
echo "Senha BD: $DB_PASS"
echo "Usuário WordPress: $WP_ADMIN_USER"
echo "Senha WordPress: $WP_ADMIN_PASS"
echo "Email Administrador: $ADMIN_EMAIL"
echo "Versão do PHP: $PHP_VERSION"
echo "Pool de admin configurado com limites maiores para wp-admin"