#!/bin/bash

# =================================================================
# CORES E FORMATAÇÃO
# =================================================================
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color
BOLD='\033[1m'

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
    sed -i "s|{{SECURE_DIR}}|$SECURE_DIR_NAME|g" "/tmp/template.tmp"
    
    # Move para o destino final
    mv "/tmp/template.tmp" "$output"
}

# Diretório do script atual
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Carrega variáveis de ambiente globais se existirem
if [ -f /etc/profile.d/wordpress-nginx-env.sh ]; then
    source /etc/profile.d/wordpress-nginx-env.sh
fi

# =================================================================
# FUNÇÕES DE COLETA DE CONFIGURAÇÃO COM CONFIRMAÇÃO
# =================================================================

# Função para coletar URL do site
select_site_url() {
  echo -e "\n${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
  echo -e "${BOLD}🌐 URL do Site${NC}"
  echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
  read -p "Digite a URL completa (ex: https://exemplo.com): " FULL_URL
  
  # Extrai o domínio da URL
  DOMAIN=$(echo "$FULL_URL" | sed -e 's|^[^/]*//||' -e 's|/.*$||')
  
  # Normaliza a URL para sempre usar HTTPS
  if [[ "$FULL_URL" != https://* ]] && [[ "$FULL_URL" != http://* ]]; then
      # Se não especificou protocolo, adiciona https://
      DOMAIN="$FULL_URL"
      FULL_URL="https://$DOMAIN"
  fi
  
  SITE_ROOT="/var/www/$DOMAIN"
}

# Função para coletar email
select_admin_email() {
  echo -e "\n${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
  echo -e "${BOLD}📧 Email do Administrador${NC}"
  echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
  read -p "Digite seu email: " ADMIN_EMAIL
}

# Função para coletar versão do PHP
select_php_version() {
  echo -e "\n${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
  echo -e "${BOLD}📦 Versão do PHP${NC}"
  echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
  
  local DEFAULT_PHP_MSG=""
  if [ -n "$DEFAULT_PHP_VERSION" ]; then
      DEFAULT_PHP_MSG=" [padrão: $DEFAULT_PHP_VERSION]"
  fi
  
  read -p "Digite a versão do PHP (ex: 8.1, 8.2, 8.3)${DEFAULT_PHP_MSG}: " PHP_VERSION_INPUT
  
  if [ -z "$PHP_VERSION_INPUT" ] && [ -n "$DEFAULT_PHP_VERSION" ]; then
      PHP_VERSION="$DEFAULT_PHP_VERSION"
  else
      PHP_VERSION="$PHP_VERSION_INPUT"
  fi
}

# Função para coletar senha do MySQL
select_mysql_password() {
  echo -e "\n${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
  echo -e "${BOLD}🔐 Senha do MySQL Root${NC}"
  echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
  read -s -p "Digite a senha do MySQL root: " MYSQL_ROOT_PASS
  echo ""
  MYSQL_PASS_DISPLAY="••••••••"
}

# Função para coletar configuração de FastCGI Cache
select_fastcgi_cache() {
  echo -e "\n${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
  echo -e "${BOLD}⚡ FastCGI Cache (Page Caching)${NC}"
  echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
  echo -e "O FastCGI Cache armazena páginas HTML em disco/memória"
  echo -e "Benefícios: ${GREEN}Páginas até 10x mais rápidas${NC}"
  echo -e "Bypass automático: usuários logados, carrinho, checkout"
  echo -e "Compatível com: nginx-helper plugin (purge automático)"
  echo ""
  read -p "Habilitar FastCGI Cache? (s/N): " CACHE_CHOICE
  
  case $CACHE_CHOICE in
    s|S|sim|SIM|y|Y|yes|YES)
      ENABLE_FASTCGI_CACHE="yes"
      CACHE_DISPLAY="${GREEN}Habilitado${NC}"
      ;;
    *)
      ENABLE_FASTCGI_CACHE="no"
      CACHE_DISPLAY="${YELLOW}Desabilitado${NC}"
      ;;
  esac
}

# Função para exibir resumo das configurações
show_summary() {
  echo -e "\n${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
  echo -e "${BOLD}📋 RESUMO DAS CONFIGURAÇÕES${NC}"
  echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
  echo -e "  ${BOLD}1)${NC} URL:        ${CYAN}$FULL_URL${NC}"
  echo -e "  ${BOLD}  ${NC} Domínio:    ${CYAN}$DOMAIN${NC}"
  echo -e "  ${BOLD}  ${NC} Caminho:    ${CYAN}$SITE_ROOT${NC}"
  echo -e "  ${BOLD}2)${NC} Email:      ${CYAN}$ADMIN_EMAIL${NC}"
  echo -e "  ${BOLD}3)${NC} PHP:        ${CYAN}$PHP_VERSION${NC}"
  echo -e "  ${BOLD}4)${NC} MySQL Pass: ${CYAN}$MYSQL_PASS_DISPLAY${NC}"
  echo -e "  ${BOLD}5)${NC} FastCGI:    $CACHE_DISPLAY"
  echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
  
  # Aviso se o diretório já existe
  if [ -d "$SITE_ROOT" ]; then
    echo -e "  ${YELLOW}⚠️  ATENÇÃO: O diretório $SITE_ROOT já existe!${NC}"
    echo -e "  ${YELLOW}   Continuar pode sobrescrever dados existentes.${NC}"
  fi
}

# Função para validar inputs
validate_inputs() {
  local valid=true
  
  if [ -z "$FULL_URL" ] || [ -z "$DOMAIN" ]; then
    echo -e "${RED}Erro: URL do site não definida${NC}"
    valid=false
  fi
  
  if [ -z "$ADMIN_EMAIL" ]; then
    echo -e "${RED}Erro: Email do administrador não definido${NC}"
    valid=false
  fi
  
  if [ -z "$PHP_VERSION" ]; then
    echo -e "${RED}Erro: Versão do PHP não definida${NC}"
    valid=false
  fi
  
  if [ -z "$MYSQL_ROOT_PASS" ]; then
    echo -e "${RED}Erro: Senha do MySQL não definida${NC}"
    valid=false
  fi
  
  if [ "$valid" = false ]; then
    return 1
  fi
  return 0
}

# Função principal de coleta de configuração
collect_configuration() {
  while true; do
    # Coleta inicial
    if [ -z "$FULL_URL" ]; then
      select_site_url
    fi
    
    if [ -z "$ADMIN_EMAIL" ]; then
      select_admin_email
    fi
    
    if [ -z "$PHP_VERSION" ]; then
      select_php_version
    fi
    
    if [ -z "$MYSQL_ROOT_PASS" ]; then
      select_mysql_password
    fi
    
    if [ -z "$ENABLE_FASTCGI_CACHE" ]; then
      select_fastcgi_cache
    fi
    
    # Exibe resumo
    show_summary
    
    # Pergunta confirmação
    echo -e "\n${YELLOW}O que você deseja fazer?${NC}"
    echo "  c) Confirmar e iniciar instalação"
    echo "  1) Editar URL do site"
    echo "  2) Editar email do administrador"
    echo "  3) Editar versão do PHP"
    echo "  4) Editar senha do MySQL"
    echo "  5) Alterar FastCGI Cache"
    echo "  q) Cancelar e sair"
    read -p "Escolha: " CONFIRM_CHOICE
    
    case $CONFIRM_CHOICE in
      c|C)
        if validate_inputs; then
          echo -e "\n${GREEN}✓ Configurações confirmadas! Iniciando instalação...${NC}\n"
          break
        fi
        ;;
      1)
        FULL_URL=""
        DOMAIN=""
        select_site_url
        ;;
      2)
        ADMIN_EMAIL=""
        select_admin_email
        ;;
      3)
        PHP_VERSION=""
        select_php_version
        ;;
      4)
        MYSQL_ROOT_PASS=""
        select_mysql_password
        ;;
      5)
        ENABLE_FASTCGI_CACHE=""
        select_fastcgi_cache
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
echo "║         WordPress Installation Script                     ║"
echo "║         Configuração interativa com confirmação           ║"
echo "╚═══════════════════════════════════════════════════════════╝"
echo -e "${NC}"

# Coleta todas as configurações com confirmação
collect_configuration

# Verifica se o diretório já existe (após confirmação)
if [ -d "$SITE_ROOT" ]; then
    echo -e "${YELLOW}Diretório do site já existe: $SITE_ROOT${NC}"
    echo -e "${YELLOW}Continuando com a instalação...${NC}"
fi

# Cria diretório para o site se não existir
if [ ! -d "$SITE_ROOT" ]; then
    echo "Criando diretório para o site: $SITE_ROOT"
    mkdir -p "$SITE_ROOT"
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

# Insert configurations above the specified comment in wp-config.php
# Monta as configurações base
WP_CONFIG_DEFINES="define('WP_MEMORY_LIMIT', '256M');\\
define('WP_MAX_MEMORY_LIMIT', '256M');\\
define('CONCATENATE_SCRIPTS', false);\\
define('WP_POST_REVISIONS', 10);\\
define('MEDIA_TRASH', true);\\
define('EMPTY_TRASH_DAYS', 15);\\
define('WP_AUTO_UPDATE_CORE', 'minor');\\
define('DISABLE_WP_CRON', true);\\
\\
/* Cookie Security Settings */\\
define('FORCE_SSL_ADMIN', true);\\
define('COOKIE_DOMAIN', '$DOMAIN');"

# Adiciona configurações do nginx-helper se cache habilitado
if [ "$ENABLE_FASTCGI_CACHE" = "yes" ]; then
    WP_CONFIG_DEFINES="$WP_CONFIG_DEFINES\\
\\
/* Nginx Helper - FastCGI Cache Settings */\\
define('RT_WP_NGINX_HELPER_CACHE_PATH', '/dev/shm/nginx-cache');"
fi

# Insere as configurações no wp-config.php
sed -i "/\/\* That's all, stop editing! Happy publishing. \*\//i \\
$WP_CONFIG_DEFINES" $SITE_ROOT/wp-config.php

wp theme update --all --path="$SITE_ROOT" --allow-root
wp plugin deactivate akismet --path="$SITE_ROOT" --allow-root
wp plugin delete akismet --path="$SITE_ROOT" --allow-root
wp plugin deactivate hello --path="$SITE_ROOT" --allow-root
wp plugin delete hello --path="$SITE_ROOT" --allow-root
wp plugin install nginx-helper --activate --path="$SITE_ROOT" --allow-root
wp plugin update --all --path="$SITE_ROOT" --allow-root

# Configurar nginx-helper se cache habilitado
if [ "$ENABLE_FASTCGI_CACHE" = "yes" ]; then
    echo "Configurando nginx-helper para FastCGI Cache..."
    
    # Configurar opções do nginx-helper via WP-CLI
    # enable_purge: 1 = habilitar purge
    # cache_method: enable_fastcgi = usar FastCGI cache
    # purge_method: unlink_files = deletar arquivos diretamente (não requer módulo ngx_cache_purge)
    # nginx_cache_path: caminho do cache em RAM
    # Purge automático em várias ações do WordPress
    
    wp option update rt_wp_nginx_helper_options '{
        "enable_purge": "1",
        "cache_method": "enable_fastcgi",
        "purge_method": "unlink_files",
        "enable_map": "0",
        "enable_log": "1",
        "log_level": "INFO",
        "log_filesize": "5",
        "redis_enabled_for_cache": "0",
        "purge_homepage_on_edit": "1",
        "purge_homepage_on_del": "1",
        "purge_archive_on_edit": "1",
        "purge_archive_on_del": "1",
        "purge_archive_on_new_comment": "1",
        "purge_archive_on_deleted_comment": "1",
        "purge_page_on_mod": "1",
        "purge_page_on_new_comment": "1",
        "purge_page_on_deleted_comment": "1",
        "nginx_cache_path": "/dev/shm/nginx-cache"
    }' --format=json --path="$SITE_ROOT" --allow-root
    
    echo -e "${GREEN}✓ nginx-helper configurado!${NC}"
    echo "  Método de purge: unlink_files (deleta arquivos diretamente)"
    echo "  Cache path: /dev/shm/nginx-cache"
    
    # =========================================================================
    # REDIS OBJECT CACHE
    # =========================================================================
    # Instala e configura Redis Cache para object caching
    # Diferente do FastCGI (page cache), o Redis faz cache de objetos PHP
    
    echo ""
    echo "Configurando Redis Object Cache..."
    
    # Verifica se Redis está instalado e rodando
    if command -v redis-cli &> /dev/null && redis-cli ping 2>/dev/null | grep -q "PONG"; then
        echo "  Redis server detectado e rodando"
        
        # Instala plugin Redis Cache
        wp plugin install redis-cache --activate --path="$SITE_ROOT" --allow-root
        
        # Gera um prefixo único para evitar colisão entre sites
        REDIS_PREFIX="${DOMAIN//[.-]/_}_"
        
        # Gera um database number baseado em hash do domínio (0-15)
        REDIS_DB=$(echo -n "$DOMAIN" | md5sum | tr -d -c '0-9' | head -c2)
        REDIS_DB=$((10#$REDIS_DB % 16))
        
        # Adiciona configurações do Redis no wp-config.php
        # Insere ANTES do comentário "That's all"
        sed -i "/\/\* That's all, stop editing! Happy publishing. \*\//i \\
\\
/* Redis Object Cache Settings */\\
define('WP_REDIS_HOST', '127.0.0.1');\\
define('WP_REDIS_PORT', 6379);\\
define('WP_REDIS_DATABASE', $REDIS_DB);\\
define('WP_REDIS_PREFIX', '$REDIS_PREFIX');\\
define('WP_REDIS_TIMEOUT', 1);\\
define('WP_REDIS_READ_TIMEOUT', 1);\\
define('WP_CACHE', true);" $SITE_ROOT/wp-config.php
        
        # Ativa o object cache (copia drop-in para wp-content)
        wp redis enable --path="$SITE_ROOT" --allow-root 2>/dev/null || true
        
        echo -e "${GREEN}✓ Redis Object Cache configurado!${NC}"
        echo "  Host: 127.0.0.1:6379"
        echo "  Database: $REDIS_DB"
        echo "  Prefix: $REDIS_PREFIX"
    else
        echo -e "${YELLOW}⚠ Redis não encontrado ou não está rodando${NC}"
        echo "  Instale Redis com: apt install redis-server"
        echo "  Plugin redis-cache será instalado mas não ativado"
        
        # Instala plugin mas não ativa
        wp plugin install redis-cache --path="$SITE_ROOT" --allow-root
    fi
fi

# Set permalink structure to /%postname%/
# Using wp option update for more reliable permalink setting
wp option update permalink_structure '/%postname%/' --path="$SITE_ROOT" --allow-root
wp rewrite structure '/%postname%/' --path="$SITE_ROOT" --allow-root
wp rewrite flush --hard --path="$SITE_ROOT" --allow-root

# Set up a cron job to run WordPress cron tasks every 5 minutes
(crontab -l -u www-data 2>/dev/null; echo "*/5 * * * * /usr/local/bin/wp cron event run --due-now --path=$SITE_ROOT --allow-root") | crontab -u www-data -

# Configuração do Nginx (Sempre usa SSL com o novo template)
# Cria certificado SSL autoassinado se não existir
mkdir -p /etc/nginx/ssl
if [ ! -f "/etc/nginx/ssl/$DOMAIN.crt" ]; then
    echo "Gerando certificado SSL autoassinado para $DOMAIN..."
    openssl ecparam -name prime256v1 -out ecparam.pem
    openssl req -x509 -nodes -days 365 -newkey ec:ecparam.pem \
        -keyout /etc/nginx/ssl/$DOMAIN.key \
        -out /etc/nginx/ssl/$DOMAIN.crt \
        -subj "/C=BR/ST=State/L=City/O=Organization/CN=$DOMAIN"
    rm ecparam.pem
fi

# Renderiza o template baseado na escolha de cache
if [ "$ENABLE_FASTCGI_CACHE" = "yes" ]; then
    echo "Configurando Nginx com FastCGI Cache habilitado..."
    
    # Cria diretório de cache em RAM (/dev/shm = tmpfs)
    # Muito mais rápido que disco!
    mkdir -p /dev/shm/nginx-cache
    chown www-data:www-data /dev/shm/nginx-cache
    chmod 755 /dev/shm/nginx-cache
    
    # Instala serviço systemd para recriar diretório após reboot
    # (necessário porque /dev/shm é limpo no reboot)
    if [ -f "$SCRIPT_DIR/nginx-cache-dir.service" ]; then
        cp "$SCRIPT_DIR/nginx-cache-dir.service" /etc/systemd/system/
        systemctl daemon-reload
        systemctl enable nginx-cache-dir.service
        echo "  Serviço systemd instalado para persistir após reboot"
    fi
    
    # Copia snippets de cache para o Nginx se não existirem
    if [ ! -f "/etc/nginx/snippets/fastcgi-cache.conf" ]; then
        cp "$SCRIPT_DIR/nginx/snippets/fastcgi-cache.conf" /etc/nginx/snippets/
    fi
    if [ ! -f "/etc/nginx/snippets/fastcgi-cache-location.conf" ]; then
        cp "$SCRIPT_DIR/nginx/snippets/fastcgi-cache-location.conf" /etc/nginx/snippets/
    fi
    
    # Usa template com cache
    render_template "$SCRIPT_DIR/nginx/nginx-cache.mustache" "/etc/nginx/sites-available/$DOMAIN"
    
    echo -e "${GREEN}✓ FastCGI Cache configurado em RAM!${NC}"
    echo "  Diretório de cache: /dev/shm/nginx-cache (tmpfs)"
    echo "  Purge automático: nginx-helper plugin (método: unlink_files)"
else
    echo "Configurando Nginx sem FastCGI Cache..."
    # Usa template padrão sem cache
    render_template "$SCRIPT_DIR/nginx/nginx.mustache" "/etc/nginx/sites-available/$DOMAIN"
fi

# Aplica configuração
ln -sf /etc/nginx/sites-available/$DOMAIN /etc/nginx/sites-enabled/
nginx -t && systemctl restart nginx

# Generate a random table prefix
RANDOM_PREFIX=$(openssl rand -base64 4 | tr -dc 'a-z0-9' | cut -c1-6)_

# Update wp-config.php with the new table prefix
sed -i "s/\$table_prefix = 'wp_';/\$table_prefix = '$RANDOM_PREFIX';/" $SITE_ROOT/wp-config.php

# ============================================================================
# SECURE TOOLS DIRECTORY SETUP
# ============================================================================

# Generate random credentials and folder name
SECURE_DIR_NAME=$(openssl rand -hex 16)
SECURE_USER=$(tr -dc 'a-z' < /dev/urandom | head -c 6)
SECURE_PASS=$(tr -dc 'a-zA-Z0-9' < /dev/urandom | head -c 12)

echo "Configurando diretório seguro de ferramentas..."
echo "Diretório: $SECURE_DIR_NAME"

# Create directory
mkdir -p "$SITE_ROOT/$SECURE_DIR_NAME"

# Download tools
echo "Baixando Adminer..."
wget -q -O "$SITE_ROOT/$SECURE_DIR_NAME/adminer.php" https://www.adminer.org/latest-mysql-en.php

echo "Baixando Opcache GUI..."
wget -q -O "$SITE_ROOT/$SECURE_DIR_NAME/opcache.php" https://raw.githubusercontent.com/amnuts/opcache-gui/master/index.php

# Set permissions
chown -R www-data:www-data "$SITE_ROOT"
find "$SITE_ROOT" -type d -exec chmod 755 {} \;
find "$SITE_ROOT" -type f -exec chmod 644 {} \;

# Create htpasswd file
mkdir -p /etc/nginx/htpasswd
# Use openssl to generate password hash (compatible with crypt() used by nginx basic auth)
# We use -crypt for compatibility, or we can use python/perl if openssl version doesn't support -crypt directly in a way nginx likes, 
# but openssl passwd is usually fine. Nginx supports crypt(), md5, sha1.
# Let's use openssl passwd -5 (SHA-256) if available, or just default.
# Checking if openssl passwd works.
PASS_HASH=$(openssl passwd -5 "$SECURE_PASS" 2>/dev/null || openssl passwd -1 "$SECURE_PASS")
echo "$SECURE_USER:$PASS_HASH" > "/etc/nginx/htpasswd/${DOMAIN}_${SECURE_DIR_NAME}"


# Informações finais
echo -e "\nInstalação concluída! Detalhes do site:"
echo "Domínio: $DOMAIN"
echo "URL do site: $FULL_URL (SSL ativado)"
echo "Certificado SSL auto-assinado configurado (aceite o aviso do navegador)"
echo "Caminho do site: $SITE_ROOT"
echo "Banco de Dados: $DB_NAME"
echo "Usuário BD: $DB_USER"
echo "Senha BD: $DB_PASS"
echo "Usuário WordPress: $WP_ADMIN_USER"
echo "Senha WordPress: $WP_ADMIN_PASS"
echo "Email Administrador: $ADMIN_EMAIL"
echo "Versão do PHP: $PHP_VERSION"
echo "Pool de admin configurado com limites maiores para wp-admin"
echo ""
if [ "$ENABLE_FASTCGI_CACHE" = "yes" ]; then
    echo "=== FASTCGI CACHE (RAM) ==="
    echo "Status: HABILITADO"
    echo "Diretório de cache: /dev/shm/nginx-cache (tmpfs)"
    echo "Tipo: IN-MEMORY (muito mais rápido que disco)"
    echo "Plugin instalado: nginx-helper (purge automático)"
    echo "Header de debug: X-FastCGI-Cache (HIT/MISS/BYPASS)"
    echo ""
    
    # Verifica se Redis foi configurado
    if command -v redis-cli &> /dev/null && redis-cli ping 2>/dev/null | grep -q "PONG"; then
        echo "=== REDIS OBJECT CACHE ==="
        echo "Status: HABILITADO"
        echo "Host: 127.0.0.1:6379"
        echo "Plugin instalado: redis-cache"
        echo "Verificar em: wp-admin > Configurações > Redis"
        echo ""
    fi
fi
echo "=== FERRAMENTAS ADMINISTRATIVAS ==="
echo "URL Adminer/Opcache: $FULL_URL/$SECURE_DIR_NAME/"
echo "Usuário: $SECURE_USER"
echo "Senha: $SECURE_PASS" 
# Final information
mkdir -p ~/.iw ; >> ~/.iw/wp.txt 
{
  echo -e "\nInstallation completed! Site details:"
  echo "Domain: $DOMAIN"
  echo "Site URL: $FULL_URL (SSL enabled)"
  echo "Self-signed SSL certificate configured (accept browser warning)"
  echo "Site path: $SITE_ROOT"
  echo "Database: $DB_NAME"
  echo "DB User: $DB_USER"
  echo "DB Password: $DB_PASS"
  echo "WordPress Admin Username: $WP_ADMIN_USER"
  echo "WordPress Admin Password: $WP_ADMIN_PASS"
  echo "Admin Email: $ADMIN_EMAIL"
  echo "PHP Version: $PHP_VERSION"
  echo ""
  if [ "$ENABLE_FASTCGI_CACHE" = "yes" ]; then
    echo "=== FASTCGI CACHE (RAM) ==="
    echo "Status: ENABLED"
    echo "Cache Directory: /dev/shm/nginx-cache (tmpfs)"
    echo "Type: IN-MEMORY"
    echo "Plugin: nginx-helper (auto purge)"
    echo "Debug Header: X-FastCGI-Cache"
    echo ""
    
    # Verifica se Redis foi configurado
    if command -v redis-cli &> /dev/null && redis-cli ping 2>/dev/null | grep -q "PONG"; then
      echo "=== REDIS OBJECT CACHE ==="
      echo "Status: ENABLED"
      echo "Host: 127.0.0.1:6379"
      echo "Plugin: redis-cache"
      echo ""
    fi
  fi
  echo "=== SECURE TOOLS ==="
  echo "Tools URL: $FULL_URL/$SECURE_DIR_NAME/"
  echo "User: $SECURE_USER"
  echo "Password: $SECURE_PASS"
  echo -e "\nYou can now access your WordPress admin at: $FULL_URL/wp-admin/"
} | tee ~/.iw/wp.txt 
