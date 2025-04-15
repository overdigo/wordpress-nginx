#!/bin/bash

# Função para substituir variáveis em templates
render_template() {
    local template="$1"
    local output="$2"
    
    # Cria uma cópia temporária do template
    cp "$template" "/tmp/template.tmp"
    
    # Substitui as variáveis
    sed -i "s/{{DOMAIN}}/$DOMAIN/g" "/tmp/template.tmp"
    sed -i "s/{{PHP_VERSION}}/$PHP_VERSION/g" "/tmp/template.tmp"
    sed -i "s/{{PHP_VERSION_NO_DOT}}/${PHP_VERSION/.}/g" "/tmp/template.tmp"
    
    # Move para o destino final
    mv "/tmp/template.tmp" "$output"
}

# Diretório do script atual
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Coleta informações do usuário
read -p "Digite a URL completa do site (ex: http://192-168-0-117.sslip.io ou https://192-168-0-117.sslip.io): " FULL_URL
read -p "Digite seu email: " ADMIN_EMAIL
read -p "Digite a versão do PHP a ser instalada (ex: 8.4): " PHP_VERSION

# Extrai o domínio da URL
DOMAIN=$(echo "$FULL_URL" | sed -e 's|^[^/]*//||' -e 's|/.*$||')

# Verifica se é SSL ou não
if [[ "$FULL_URL" == https://* ]]; then
    USE_SSL=true
    echo "Configurando com SSL..."
elif [[ "$FULL_URL" == http://* ]]; then
    USE_SSL=false
    echo "Configurando sem SSL..."
else
    # Se o usuário não especificar protocolo, assume HTTPS
    USE_SSL=true
    DOMAIN="$FULL_URL"
    FULL_URL="https://$DOMAIN"
    echo "Protocolo não especificado, usando HTTPS por padrão..."
fi

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

# Configura WordPress
cd /var/www/html
wp core download --locale=pt_BR --allow-root
wp config create --dbname=$DB_NAME --dbuser=$DB_USER --dbpass=$DB_PASS --allow-root
wp core install --url="$FULL_URL" --title="$DOMAIN" --admin_user="$WP_ADMIN_USER" --admin_password="$WP_ADMIN_PASS" --admin_email="$ADMIN_EMAIL" --allow-root

# Configuração para SSL ou não-SSL usando templates
if [ "$USE_SSL" = true ]; then
    # Cria certificado SSL autoassinado
    mkdir -p /etc/nginx/ssl
    openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
      -keyout /etc/nginx/ssl/$DOMAIN.key \
      -out /etc/nginx/ssl/$DOMAIN.crt \
      -subj "/CN=$DOMAIN"
      
    # Renderiza o template com SSL
    render_template "$SCRIPT_DIR/nginx-ssl.mustache" "/etc/nginx/sites-available/wordpress"
else
    # Renderiza o template sem SSL
    render_template "$SCRIPT_DIR/nginx-nonssl.mustache" "/etc/nginx/sites-available/wordpress"
fi

# Aplica configuração
ln -s /etc/nginx/sites-available/wordpress /etc/nginx/sites-enabled/
rm -f /etc/nginx/sites-enabled/default
nginx -t && systemctl restart nginx
chown -R www-data:www-data /var/www/html
find /var/www/html -type d -exec chmod 755 {} \;
find /var/www/html -type f -exec chmod 644 {} \;

# Informações finais
echo -e "\nInstalação concluída! Detalhes:"
if [ "$USE_SSL" = true ]; then
    echo "URL do site: $FULL_URL (SSL ativado)"
    echo "Certificado SSL auto-assinado configurado (aceite o aviso do navegador)"
else
    echo "URL do site: $FULL_URL (sem SSL)"
fi
echo "Banco de Dados: $DB_NAME"
echo "Usuário BD: $DB_USER"
echo "Senha BD: $DB_PASS"
echo "Usuário WordPress: $WP_ADMIN_USER"
echo "Senha WordPress: $WP_ADMIN_PASS"
echo "Email Administrador: $ADMIN_EMAIL"
echo "Versão do PHP: $PHP_VERSION"
echo "Pool de admin configurado com limites maiores para wp-admin" 