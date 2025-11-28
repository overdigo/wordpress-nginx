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
    sed -i "s|{{SITE_ROOT}}|$SITE_ROOT|g" "/tmp/template.tmp"
    
    # Move para o destino final
    mv "/tmp/template.tmp" "$output"
}

# Diretório do script atual
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Coleta informações do usuário
read -p "Digite a URL completa do site (ex: http://192-168-0-117.sslip.io ou https://exemplo.com): " FULL_URL
read -p "Digite seu email: " ADMIN_EMAIL
read -p "Digite a versão do PHP a ser instalada (ex: 8.4): " PHP_VERSION
read -p "Digite a senha do MySQL root: " MYSQL_ROOT_PASS

# Extrai o domínio da URL
DOMAIN=$(echo "$FULL_URL" | sed -e 's|^[^/]*//||' -e 's|/.*$||')

# Define caminho do site baseado no domínio
SITE_ROOT="/var/www/$DOMAIN"

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
    SITE_ROOT="/var/www/$DOMAIN"
    echo "Protocolo não especificado, usando HTTPS por padrão..."
fi

# Cria diretório para o site se não existir
if [ ! -d "$SITE_ROOT" ]; then
    echo "Criando diretório para o site: $SITE_ROOT"
    mkdir -p "$SITE_ROOT"
else
    echo "Diretório do site já existe: $SITE_ROOT"
    read -p "Continuar mesmo assim? Isso pode sobrescrever dados existentes. (s/n): " CONTINUE
    if [[ "$CONTINUE" != "s" && "$CONTINUE" != "S" ]]; then
        echo "Instalação cancelada."
        exit 1
    fi
fi

# Gera credenciais aleatórias
DB_NAME="${DOMAIN//[.-]/_}_$(openssl rand -hex 3)"
DB_USER="${DOMAIN//[.-]/_}_$(openssl rand -hex 3)"
DB_PASS=$(openssl rand -hex 8)
WP_ADMIN_USER="${DOMAIN%%.*}_$(openssl rand -hex 3)"
WP_ADMIN_PASS=$(openssl rand -hex 8)

# Configura banco de dados para o site
echo "Criando banco de dados para $DOMAIN..."
mysql -u root -p"$MYSQL_ROOT_PASS" <<EOF
CREATE DATABASE $DB_NAME;
CREATE USER '$DB_USER'@'localhost' IDENTIFIED BY '$DB_PASS';
GRANT ALL PRIVILEGES ON $DB_NAME.* TO '$DB_USER'@'localhost';
FLUSH PRIVILEGES;
EOF

# Configura WordPress
echo "Instalando WordPress em $SITE_ROOT..."
cd "$SITE_ROOT"
wp core download --locale=pt_BR --allow-root
wp config create --dbname=$DB_NAME --dbuser=$DB_USER --dbpass=$DB_PASS --allow-root
wp core install --url="$FULL_URL" --title="$DOMAIN" --admin_user="$WP_ADMIN_USER" --admin_password="$WP_ADMIN_PASS" --admin_email="$ADMIN_EMAIL" --allow-root

# Set permalink structure to /%postname%/
wp rewrite structure '/%postname%/' --allow-root
wp rewrite flush --hard --allow-root

# Insert configurations above the specified comment in wp-config.php
sed -i "/\/\* That's all, stop editing! Happy publishing. \*\//i \
define('WP_MEMORY_LIMIT', '256M');\
define('WP_MAX_MEMORY_LIMIT', '256M');\
define('CONCATENATE_SCRIPTS', false);\
define('WP_POST_REVISIONS', 10);\
define('MEDIA_TRASH', true);\
define('EMPTY_TRASH_DAYS', 15);\
define('WP_AUTO_UPDATE_CORE', 'minor');\
define ('DISABLE_WP_CRON', true);\
" $SITE_ROOT/wp-config.php

wp theme update --all --allow-root
wp plugin deactivate akismet --allow-root
wp plugin delete akismet --allow-root
wp plugin deactivate hello --allow-root
wp plugin delete hello --allow-root
wp plugin install nginx-helper --activate --allow-root
wp plugin update --all --allow-root

# Set up a cron job to run WordPress cron tasks every 5 minutes
(crontab -l -u www-data 2>/dev/null; echo "*/5 * * * * /usr/local/bin/wp cron event run --due-now --path=$SITE_ROOT --allow-root") | crontab -u www-data -

# Configuração para SSL ou não-SSL usando templates
if [ "$USE_SSL" = true ]; then
    # Cria certificado SSL autoassinado
    mkdir -p /etc/nginx/ssl
    openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
      -keyout /etc/nginx/ssl/$DOMAIN.key \
      -out /etc/nginx/ssl/$DOMAIN.crt \
      -subj "/CN=$DOMAIN"
      
    # Renderiza o template com SSL
    render_template "$SCRIPT_DIR/nginx-ssl.mustache" "/etc/nginx/sites-available/$DOMAIN"
else
    # Renderiza o template sem SSL
    render_template "$SCRIPT_DIR/nginx-nonssl.mustache" "/etc/nginx/sites-available/$DOMAIN"
fi

# Aplica configuração
ln -sf /etc/nginx/sites-available/$DOMAIN /etc/nginx/sites-enabled/
nginx -t && systemctl restart nginx
chown -R www-data:www-data "$SITE_ROOT"
find "$SITE_ROOT" -type d -exec chmod 755 {} \;
find "$SITE_ROOT" -type f -exec chmod 644 {} \;

# Generate a random table prefix
RANDOM_PREFIX=$(openssl rand -base64 4 | tr -dc 'a-z0-9' | cut -c1-6)_

# Update wp-config.php with the new table prefix
sed -i "s/\$table_prefix = 'wp_';/\$table_prefix = '$RANDOM_PREFIX';/" $SITE_ROOT/wp-config.php

# Informações finais
echo -e "\nInstalação concluída! Detalhes do site:"
echo "Domínio: $DOMAIN"
if [ "$USE_SSL" = true ]; then
    echo "URL do site: $FULL_URL (SSL ativado)"
    echo "Certificado SSL auto-assinado configurado (aceite o aviso do navegador)"
else
    echo "URL do site: $FULL_URL (sem SSL)"
fi
echo "Caminho do site: $SITE_ROOT"
echo "Banco de Dados: $DB_NAME"
echo "Usuário BD: $DB_USER"
echo "Senha BD: $DB_PASS"
echo "Usuário WordPress: $WP_ADMIN_USER"
echo "Senha WordPress: $WP_ADMIN_PASS"
echo "Email Administrador: $ADMIN_EMAIL"
echo "Versão do PHP: $PHP_VERSION"
echo "Pool de admin configurado com limites maiores para wp-admin" 
# Final information
>> ~/.iw/wp.txt 
{
  echo -e "\nInstallation completed! Site details:"
  echo "Domain: $DOMAIN"
  if [ "$USE_SSL" = true ]; then
      echo "Site URL: $FULL_URL (SSL enabled)"
      echo "Self-signed SSL certificate configured (accept browser warning)"
  else
      echo "Site URL: $FULL_URL (no SSL)"
  fi
  echo "Site path: $SITE_ROOT"
  echo "Database: $DB_NAME"
  echo "DB User: $DB_USER"
  echo "DB Password: $DB_PASS"
  echo "WordPress Admin Username: $WP_ADMIN_USER"
  echo "WordPress Admin Password: $WP_ADMIN_PASS"
  echo "Admin Email: $ADMIN_EMAIL"
  echo "PHP Version: $PHP_VERSION"
  echo -e "\nYou can now access your WordPress admin at: $FULL_URL/wp-admin/"
} | tee ~/.iw/wp.txt 