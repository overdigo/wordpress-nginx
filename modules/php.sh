#!/bin/bash
# =============================================================================
# MÓDULO: PHP - Instalação e configuração do PHP
# =============================================================================
# Uso standalone: sudo ./modules/php.sh [--version 8.3] [--reinstall]
# =============================================================================

set -e

# Carregar módulo comum
MODULES_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" &> /dev/null && pwd)
source "$MODULES_DIR/common.sh"

# Diretório base do projeto
SCRIPT_DIR=$(get_script_dir)

# =============================================================================
# VARIÁVEIS DE CONFIGURAÇÃO
# =============================================================================
PHP_VERSION="${PHP_VERSION:-}"
REINSTALL=false
FORCE=false

# =============================================================================
# FUNÇÕES
# =============================================================================

show_help() {
  echo -e "${BOLD}Módulo PHP - Instalação e Configuração${NC}"
  echo ""
  echo "Uso: $0 [OPÇÕES]"
  echo ""
  echo "Opções:"
  echo "  -v, --version VERSION   Especifica a versão do PHP (ex: 8.1, 8.2, 8.3, 8.4, 8.5)"
  echo "  -r, --reinstall         Reinstala o PHP mesmo se já instalado"
  echo "  -f, --force             Não pede confirmação"
  echo "  -h, --help              Exibe esta mensagem"
  echo ""
  echo "Exemplos:"
  echo "  $0 --version 8.4              # Instala PHP 8.4"
  echo "  $0 --version 8.3 --reinstall  # Reinstala/atualiza para PHP 8.3"
  echo "  $0                            # Menu interativo"
}

# Verificar se uma versão específica do PHP está instalada
php_version_installed() {
  local version=$1
  dpkg -l | grep -q "php${version}-fpm" 2>/dev/null
}

# Listar versões do PHP instaladas
list_installed_php() {
  echo -e "${CYAN}Versões do PHP instaladas:${NC}"
  for ver in 8.1 8.2 8.3 8.4 8.5; do
    if php_version_installed "$ver"; then
      if [ "$(php -v 2>/dev/null | head -1 | grep -oP '\d+\.\d+')" == "$ver" ]; then
        echo -e "  ${GREEN}✓ PHP $ver (ativo)${NC}"
      else
        echo -e "  ${YELLOW}● PHP $ver (instalado)${NC}"
      fi
    fi
  done
}

# Menu interativo de seleção de versão
interactive_select_version() {
  echo -e "\n${CYAN}Selecione a versão do PHP para instalar:${NC}"
  echo ""
  echo "  1) PHP 8.1 (LTS - suporte até 2025)"
  echo "  2) PHP 8.2 (Estável)"
  echo "  3) PHP 8.3 (Recomendado - mais recente estável)"
  echo "  4) PHP 8.4 (Cutting Edge)"
  echo "  5) PHP 8.5 (Desenvolvimento - instável)"
  echo ""
  echo "  0) Cancelar"
  echo ""
  read -p "Escolha [0-5]: " choice
  
  case $choice in
    0) exit 0 ;;
    1) PHP_VERSION="8.1" ;;
    2) PHP_VERSION="8.2" ;;
    3) PHP_VERSION="8.3" ;;
    4) PHP_VERSION="8.4" ;;
    5) PHP_VERSION="8.5" ;;
    *) 
      msg_error "Opção inválida"
      interactive_select_version
      ;;
  esac
}

# Instalar repositório do PHP
install_php_repo() {
  if ! grep -q "ondrej/php" /etc/apt/sources.list.d/*.list 2>/dev/null; then
    msg_info "Adicionando repositório ondrej/php..."
    add-apt-repository ppa:ondrej/php -y
    sleep 1
    apt update
  fi
}

# Instalar pacotes do PHP
install_php_packages() {
  local version=$1
  
  msg_info "Instalando PHP $version..."
  
  PHP_PACKAGES="php${version}-fpm php${version}-mysql php${version}-curl php${version}-gd php${version}-common php${version}-xml php${version}-zip php${version}-xsl php${version}-bcmath php${version}-mbstring php${version}-imagick php${version}-cli php${version}-opcache php${version}-redis php${version}-intl php${version}-yaml"
  
  # PHP 8.5 não tem opcache separado
  if [ "$version" == "8.5" ]; then
    PHP_PACKAGES=$(echo "$PHP_PACKAGES" | sed "s/php8.5-opcache//")
  fi
  
  apt-get install -y --ignore-missing $PHP_PACKAGES
  
  msg_success "Pacotes PHP $version instalados"
}

# Configurar PHP (copiar configurações otimizadas)
configure_php() {
  local version=$1
  
  msg_info "Configurando PHP $version..."
  
  export PHP_VERSION="$version"
  export PHP_VERSION_NO_DOT=$(echo "$version" | tr -d '.')
  
  # Processar templates
  process_mustache "$SCRIPT_DIR/php/php-fpm.mustache" "/tmp/php-fpm.conf"
  process_mustache "$SCRIPT_DIR/php/php-admin.mustache" "/tmp/admin.conf"
  process_mustache "$SCRIPT_DIR/php/get-sock-1.mustache" "/tmp/sock1.conf"
  process_mustache "$SCRIPT_DIR/php/get-sock-2.mustache" "/tmp/sock2.conf"
  process_mustache "$SCRIPT_DIR/php/sock-other.mustache" "/tmp/sock-other.conf"
  
  cp "$SCRIPT_DIR/php/php.ini" "/tmp/php.ini"
  
  # Backup das configurações originais (se existirem)
  if [ -f "/etc/php/${version}/fpm/php-fpm.conf" ]; then
    msg_info "Fazendo backup das configurações existentes..."
    cp "/etc/php/${version}/fpm/php-fpm.conf" "/etc/php/${version}/fpm/php-fpm.conf.bkp" 2>/dev/null || true
    cp "/etc/php/${version}/fpm/php.ini" "/etc/php/${version}/fpm/php.ini.bkp" 2>/dev/null || true
    cp "/etc/php/${version}/fpm/pool.d/www.conf" "/etc/php/${version}/fpm/pool.d/www.conf.bkp" 2>/dev/null || true
  fi
  
  # Remover pool padrão
  rm -f "/etc/php/${version}/fpm/pool.d/www.conf"
  
  # Aplicar novas configurações
  msg_info "Aplicando configurações otimizadas..."
  mv /tmp/php-fpm.conf "/etc/php/${version}/fpm/php-fpm.conf"
  cp /tmp/php.ini "/etc/php/${version}/fpm/php.ini"
  mv /tmp/php.ini "/etc/php/${version}/cli/php.ini"
  mv /tmp/sock1.conf "/etc/php/${version}/fpm/pool.d/sock1.conf"
  mv /tmp/sock2.conf "/etc/php/${version}/fpm/pool.d/sock2.conf"
  mv /tmp/admin.conf "/etc/php/${version}/fpm/pool.d/admin.conf"
  mv /tmp/sock-other.conf "/etc/php/${version}/fpm/pool.d/sock-other.conf"
  
  msg_success "Configurações do PHP $version aplicadas"
}

# Reiniciar serviço PHP-FPM
restart_php_fpm() {
  local version=$1
  
  msg_info "Reiniciando PHP-FPM $version..."
  systemctl restart "php${version}-fpm"
  
  if systemctl is-active --quiet "php${version}-fpm"; then
    msg_success "PHP-FPM $version está rodando"
  else
    msg_error "Erro ao iniciar PHP-FPM $version"
    systemctl status "php${version}-fpm" --no-pager
    return 1
  fi
}

# Função principal de instalação
install_php() {
  local version=$1
  
  msg_header "Instalação do PHP $version"
  
  # Verificar se já está instalado
  if php_version_installed "$version" && [ "$REINSTALL" != true ]; then
    msg_warning "PHP $version já está instalado."
    echo ""
    read -p "Deseja reinstalar/reconfigurar? [s/N]: " confirm
    if [[ ! "$confirm" =~ ^[Ss]$ ]]; then
      msg_info "Operação cancelada"
      return 0
    fi
    REINSTALL=true
  fi
  
  # Confirmar instalação
  if [ "$FORCE" != true ]; then
    echo ""
    echo -e "${YELLOW}Será instalado:${NC}"
    echo "  - PHP $version com FPM"
    echo "  - Extensões: mysql, curl, gd, xml, zip, bcmath, mbstring, imagick, redis, intl, yaml"
    echo "  - Configurações otimizadas para WordPress"
    echo ""
    read -p "Continuar? [S/n]: " confirm
    if [[ "$confirm" =~ ^[Nn]$ ]]; then
      msg_info "Operação cancelada"
      return 0
    fi
  fi
  
  # Executar instalação
  install_php_repo
  install_php_packages "$version"
  configure_php "$version"
  restart_php_fpm "$version"
  
  # Salvar versão como padrão
  save_php_version "$version"
  
  msg_success "PHP $version instalado e configurado com sucesso!"
  
  echo ""
  echo -e "${CYAN}Informações:${NC}"
  echo "  Versão: $(php -v | head -1)"
  echo "  FPM Socket: /run/php/php${version}-fpm.sock"
  echo "  Config: /etc/php/${version}/fpm/"
}

# Desinstalar versão do PHP
uninstall_php() {
  local version=$1
  
  if ! php_version_installed "$version"; then
    msg_error "PHP $version não está instalado"
    return 1
  fi
  
  msg_warning "Desinstalando PHP $version..."
  
  systemctl stop "php${version}-fpm" 2>/dev/null || true
  apt-get remove -y "php${version}-*"
  apt-get autoremove -y
  
  msg_success "PHP $version desinstalado"
}

# =============================================================================
# PROCESSAMENTO DE ARGUMENTOS
# =============================================================================
parse_args() {
  while [[ $# -gt 0 ]]; do
    case $1 in
      -v|--version)
        PHP_VERSION="$2"
        shift 2
        ;;
      -r|--reinstall)
        REINSTALL=true
        shift
        ;;
      -f|--force)
        FORCE=true
        shift
        ;;
      -h|--help)
        show_help
        exit 0
        ;;
      --list)
        list_installed_php
        exit 0
        ;;
      --uninstall)
        UNINSTALL_VERSION="$2"
        shift 2
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
  
  # Se foi solicitada desinstalação
  if [ -n "$UNINSTALL_VERSION" ]; then
    uninstall_php "$UNINSTALL_VERSION"
    exit 0
  fi
  
  # Se versão não especificada, mostrar menu interativo
  if [ -z "$PHP_VERSION" ]; then
    echo -e "${BOLD}╔═══════════════════════════════════════════════════════════╗${NC}"
    echo -e "${BOLD}║           Instalador de PHP Modular                       ║${NC}"
    echo -e "${BOLD}╚═══════════════════════════════════════════════════════════╝${NC}"
    echo ""
    list_installed_php
    interactive_select_version
  fi
  
  # Validar versão
  if [[ ! "$PHP_VERSION" =~ ^8\.[1-5]$ ]]; then
    msg_error "Versão inválida: $PHP_VERSION"
    msg_info "Versões suportadas: 8.1, 8.2, 8.3, 8.4, 8.5"
    exit 1
  fi
  
  install_php "$PHP_VERSION"
}

# Executar apenas se chamado diretamente (não como source)
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  main "$@"
fi
