# WordPress Nginx Multi-Site Installer

Este é um conjunto de scripts para instalar WordPress com Nginx e PHP-FPM, com suporte para múltiplos sites em um único servidor.

## Arquivos

- `server-setup.sh`: Script para configuração inicial do servidor (Nginx, MySQL, PHP)
- `install-wordpress.sh`: Script para instalar sites WordPress (pode ser executado múltiplas vezes)
- `nginx-ssl.mustache`: Template para configuração Nginx com SSL
- `nginx-nonssl.mustache`: Template para configuração Nginx sem SSL

## Como usar

### 1. instalar o git e clonar o repositório

```bash
apt install git -y
git clone https://github.com/overdigo/wordpress-nginx
cd wordpress-nginx
```

### 2. Configuração inicial do servidor (apenas uma vez)

```bash
chmod +x server-setup.sh && bash server-setup.sh
```

Este script instala e configura Nginx, MySQL e PHP, além de otimizar as configurações para melhor desempenho. Guarde a senha do MySQL root que será exibida ao final da instalação.

### 3. Instalação de sites WordPress (para cada site)

```bash
chmod +x install-wordpress.sh && bash install-wordpress.sh
```

Este script pode ser executado várias vezes para instalar diferentes sites WordPress no mesmo servidor. Cada site terá:

- Um diretório dedicado baseado no domínio: `/var/www/dominio.com`
- Um banco de dados dedicado
- Uma configuração Nginx específica
- Opção de SSL (com certificado autoassinado) ou não SSL

## Características principais

- **Múltiplos sites no mesmo servidor**: Cada domínio possui seu próprio diretório e configuração
- Detecção automática de SSL baseada na URL fornecida
- Suporte para diferentes versões do PHP
- Pool PHP dedicado para área administrativa com limites de recursos ampliados
- Sistema de templates para configurações Nginx

## Como funciona o sistema de templates

O script utiliza arquivos `.mustache` como templates para as configurações Nginx. Variáveis são substituídas pelos valores reais durante a instalação.

Você pode usar as seguintes variáveis nos templates:
- `{{DOMAIN}}`: O domínio do site
- `{{PHP_VERSION}}`: A versão do PHP (ex: 8.4)
- `{{PHP_VERSION_NO_DOT}}`: A versão do PHP sem ponto (ex: 84)
- `{{SITE_ROOT}}`: O caminho do diretório do site (ex: /var/www/dominio.com)

## Comandos úteis

### MySQL Tuner (otimização do MySQL)
```bash
bash <(wget -O - https://raw.githubusercontent.com/overdigo/wordpress-nginx/master/mysqltuner.sh)
```

### Benchmark do servidor
```bash
wget https://freevps.us/downloads/bench.sh -O - -o /dev/null|bash
```
