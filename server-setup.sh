#!/bin/bash

# Função para verificar se já está instalado
is_installed() {
    if command -v $1 &> /dev/null; then
        return 0  # Já instalado
    else
        return 1  # Não instalado
    fi
}

# Coleta informações do usuário
read -p "Digite a versão do PHP a ser instalada (ex: 8.4): " PHP_VERSION

# Gera senha root do MySQL
MYSQL_ROOT_PASS=$(openssl rand -hex 8)

# Atualiza sistema e adiciona repositórios
apt update && apt upgrade -y

# Instala Nginx via WordOps PPA (apenas se não estiver instalado)
if ! is_installed nginx; then
    echo "Instalando Nginx..."
    apt install -y software-properties-common
    add-apt-repository ppa:wordops/nginx-wo -uy
    apt install -y nginx-custom nginx-wo
    
    # Configuração otimizada do Nginx
    wget -O /etc/nginx/nginx.conf https://raw.githubusercontent.com/overdigo/wordpress-nginx/master/nginx/nginx.conf
else
    echo "Nginx já está instalado, pulando..."
fi

# PHP (Ondrej PPA)
if ! dpkg -l | grep -q "php${PHP_VERSION}"; then
    echo "Instalando PHP ${PHP_VERSION}..."
    add-apt-repository ppa:ondrej/php -y

    # Instala pacotes PHP
    apt install -y php${PHP_VERSION}-fpm php${PHP_VERSION}-mysql php${PHP_VERSION}-xml php${PHP_VERSION}-curl php${PHP_VERSION}-gd php${PHP_VERSION}-mbstring php${PHP_VERSION}-imagick php${PHP_VERSION}-zip php${PHP_VERSION}-intl php${PHP_VERSION}-redis
    
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
    
    # Reinicia PHP-FPM
    systemctl restart php${PHP_VERSION}-fpm
else
    echo "PHP ${PHP_VERSION} já está instalado, pulando..."
fi

# MySQL
if ! is_installed mysql; then
    echo "Instalando MySQL..."
    wget https://dev.mysql.com/get/mysql-apt-config_0.8.24-1_all.deb
    DEBIAN_FRONTEND=noninteractive dpkg -i mysql-apt-config_0.8.24-1_all.deb
    apt update
    apt install -y mysql-server
  
    # Configura MySQL com senha
    systemctl start mysql
    mysql <<EOF
ALTER USER 'root'@'localhost' IDENTIFIED BY '$MYSQL_ROOT_PASS';
FLUSH PRIVILEGES;
EOF
else
    echo "MySQL já está instalado, pulando..."
    echo "Nota: Usando senha existente do MySQL root."
    MYSQL_ROOT_PASS="[senha_existente]"
fi

# Instala WP-CLI
if ! is_installed wp; then
    echo "Instalando WP-CLI..."
    curl -O https://raw.githubusercontent.com/wp-cli/builds/gh-pages/phar/wp-cli.phar
    chmod +x wp-cli.phar
    mv wp-cli.phar /usr/local/bin/wp
else
    echo "WP-CLI já está instalado, pulando..."
fi

# Informações finais
echo -e "\nConfiguração do servidor concluída! Detalhes:"
echo "Versão do PHP: $PHP_VERSION"
echo "Senha do MySQL Root: $MYSQL_ROOT_PASS"
echo -e "\nAgora você pode usar o script install-wordpress.sh para instalar sites WordPress." 