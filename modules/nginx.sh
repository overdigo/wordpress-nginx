#!/bin/bash
# =============================================================================
# MÓDULO: Nginx - Instalação e configuração do Nginx
# =============================================================================
# Uso standalone: sudo ./modules/nginx.sh [--source official|wordops|ubuntu]
# =============================================================================

set -e

# Carregar módulo comum
MODULES_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" &> /dev/null && pwd)
source "$MODULES_DIR/common.sh"

# Diretório base do projeto
SCRIPT_DIR=$(get_script_dir)

# =============================================================================
# VARIÁVEIS
# =============================================================================
NGINX_SOURCE="${NGINX_SOURCE:-}"
FORCE=false

# =============================================================================
# FUNÇÕES
# =============================================================================

show_help() {
  echo -e "${BOLD}Módulo Nginx - Instalação e Configuração${NC}"
  echo ""
  echo "Uso: $0 [OPÇÕES]"
  echo ""
  echo "Opções:"
  echo "  -s, --source SOURCE   Fonte de instalação (official, wordops, ubuntu)"
  echo "  -f, --force           Não pede confirmação"
  echo "  -h, --help            Exibe esta mensagem"
  echo ""
  echo "Fontes disponíveis:"
  echo "  official  - Nginx.org (versão mais recente)"
  echo "  wordops   - Nginx-EE com Brotli, Headers More, etc"
  echo "  ubuntu    - Repositório padrão do Ubuntu"
  echo ""
  echo "Exemplos:"
  echo "  $0 --source official       # Instala do nginx.org"
  echo "  $0 --source wordops        # Instala Nginx-EE"
  echo "  $0                         # Menu interativo"
}

# Menu interativo
interactive_select_source() {
  echo -e "\n${CYAN}Selecione a fonte de instalação do Nginx:${NC}"
  echo ""
  echo "  1) Nginx Oficial (nginx.org) - Versão mais recente"
  echo "  2) Nginx-EE WordOps (Com Brotli, Headers More, PageSpeed)"
  echo "  3) Nginx Ubuntu (Padrão do sistema)"
  echo ""
  echo "  0) Cancelar"
  echo ""
  read -p "Escolha [0-3]: " choice
  
  case $choice in
    0) exit 0 ;;
    1) NGINX_SOURCE="official" ;;
    2) NGINX_SOURCE="wordops" ;;
    3) NGINX_SOURCE="ubuntu" ;;
    *) 
      msg_error "Opção inválida"
      interactive_select_source
      ;;
  esac
}

# Instalar Nginx Oficial
install_nginx_official() {
  msg_info "Instalando Nginx do repositório oficial (nginx.org)..."
  
  apt install -y curl gnupg2 ca-certificates lsb-release ubuntu-keyring
  
  curl https://nginx.org/keys/nginx_signing.key | gpg --dearmor | tee /usr/share/keyrings/nginx-archive-keyring.gpg >/dev/null
  
  echo "deb [signed-by=/usr/share/keyrings/nginx-archive-keyring.gpg] http://nginx.org/packages/ubuntu $(lsb_release -cs) nginx" | tee /etc/apt/sources.list.d/nginx.list
  
  apt update
  apt install -y nginx
  
  msg_success "Nginx Oficial instalado"
}

# Instalar Nginx WordOps/EE
install_nginx_wordops() {
  msg_info "Instalando Nginx-EE do repositório WordOps..."
  
  apt install -y software-properties-common
  add-apt-repository ppa:wordops/nginx-wo -y
  sleep 1
  apt update
  apt install -y nginx-custom nginx-wo
  
  msg_success "Nginx-EE WordOps instalado"
}

# Instalar Nginx Ubuntu
install_nginx_ubuntu() {
  msg_info "Instalando Nginx do repositório Ubuntu..."
  
  apt install -y nginx libnginx-mod-http-brotli-filter libnginx-mod-http-headers-more-filter
  
  msg_success "Nginx Ubuntu instalado"
}

# Configurar diretórios e SSL
configure_nginx_base() {
  msg_info "Configurando diretórios base do Nginx..."
  
  mkdir -p /etc/nginx/sites-enabled/
  mkdir -p /etc/nginx/sites-available/
  mkdir -p /etc/nginx/snippets/
  mkdir -p /etc/nginx/ssl
  
  # Gerar certificado self-signed
  msg_info "Gerando certificado SSL self-signed..."
  openssl ecparam -name prime256v1 -out /tmp/ecparam.pem
  openssl req -x509 -nodes -days 365 -newkey ec:/tmp/ecparam.pem \
      -keyout /etc/nginx/ssl/selfsigned.key \
      -out /etc/nginx/ssl/selfsigned.crt \
      -subj "/C=BR/ST=State/L=City/O=Organization/CN=localhost"
  rm /tmp/ecparam.pem
  
  msg_success "Certificado SSL gerado"
}

# Copiar arquivos de configuração
copy_nginx_configs() {
  msg_info "Copiando arquivos de configuração..."
  
  cp "$SCRIPT_DIR/nginx/nginx.conf" /etc/nginx/nginx.conf
  cp "$SCRIPT_DIR/nginx/default" /etc/nginx/sites-available/default
  ln -sf /etc/nginx/sites-available/default /etc/nginx/sites-enabled/default
  cp "$SCRIPT_DIR/nginx/fastcgi.conf" /etc/nginx/fastcgi.conf
  cp "$SCRIPT_DIR/nginx/snippets/fastcgi-php.conf" /etc/nginx/snippets/fastcgi-php.conf
  cp "$SCRIPT_DIR/nginx/snippets/secure.conf" /etc/nginx/snippets/secure.conf
  cp "$SCRIPT_DIR/nginx/snippets/secure-maps.conf" /etc/nginx/snippets/secure-maps.conf
  cp "$SCRIPT_DIR/nginx/snippets/ddos-protection.conf" /etc/nginx/snippets/ddos-protection.conf
  cp "$SCRIPT_DIR/nginx/snippets/fastcgi-cache.conf" /etc/nginx/snippets/fastcgi-cache.conf
  cp "$SCRIPT_DIR/nginx/snippets/fastcgi-cache-location.conf" /etc/nginx/snippets/fastcgi-cache-location.conf
  
  msg_success "Arquivos de configuração copiados"
}

# Instalar 8G Firewall
install_8g_firewall() {
  msg_info "Instalando 8G Firewall..."
  
  wget -q -O /etc/nginx/conf.d/8g-firewall.conf https://github.com/t18d/nG-SetEnvIf/raw/refs/heads/develop/8g-firewall.conf
  wget -q -O /etc/nginx/snippets/8g.conf https://github.com/t18d/nG-SetEnvIf/raw/refs/heads/develop/8g.conf
  
  msg_success "8G Firewall instalado"
}

# Testar e reiniciar Nginx
restart_nginx() {
  msg_info "Testando configuração do Nginx..."
  
  if nginx -t; then
    msg_success "Configuração válida"
    systemctl restart nginx
    
    if systemctl is-active --quiet nginx; then
      msg_success "Nginx está rodando"
    else
      msg_error "Erro ao iniciar Nginx"
      return 1
    fi
  else
    msg_error "Erro na configuração do Nginx"
    return 1
  fi
}

# Função principal
install_nginx() {
  local source=$1
  
  msg_header "Instalação do Nginx"
  
  # Verificar se já está instalado
  if command_exists nginx; then
    msg_warning "Nginx já está instalado."
    nginx -v 2>&1
    echo ""
    read -p "Deseja reconfigurar? [s/N]: " confirm
    if [[ ! "$confirm" =~ ^[Ss]$ ]]; then
      msg_info "Operação cancelada"
      return 0
    fi
    # Apenas reconfigurar
    configure_nginx_base
    copy_nginx_configs
    install_8g_firewall
    restart_nginx
    return 0
  fi
  
  # Confirmar instalação
  if [ "$FORCE" != true ]; then
    echo ""
    echo -e "${YELLOW}Será instalado:${NC}"
    echo "  - Nginx ($source)"
    echo "  - Configurações otimizadas"
    echo "  - Certificado SSL self-signed"
    echo "  - 8G Firewall"
    echo ""
    read -p "Continuar? [S/n]: " confirm
    if [[ "$confirm" =~ ^[Nn]$ ]]; then
      msg_info "Operação cancelada"
      return 0
    fi
  fi
  
  # Instalar baseado na fonte
  case $source in
    official) install_nginx_official ;;
    wordops)  install_nginx_wordops ;;
    ubuntu)   install_nginx_ubuntu ;;
    *)
      msg_error "Fonte inválida: $source"
      return 1
      ;;
  esac
  
  # Configurar
  configure_nginx_base
  copy_nginx_configs
  install_8g_firewall
  restart_nginx
  
  msg_success "Nginx instalado e configurado com sucesso!"
  
  echo ""
  echo -e "${CYAN}Informações:${NC}"
  nginx -v 2>&1 | sed 's/^/  /'
  echo "  Config: /etc/nginx/"
  echo "  Sites: /etc/nginx/sites-available/"
}

# =============================================================================
# PROCESSAMENTO DE ARGUMENTOS
# =============================================================================
parse_args() {
  while [[ $# -gt 0 ]]; do
    case $1 in
      -s|--source)
        NGINX_SOURCE="$2"
        shift 2
        ;;
      -f|--force)
        FORCE=true
        shift
        ;;
      -h|--help)
        show_help
        exit 0
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
  
  # Se fonte não especificada, mostrar menu
  if [ -z "$NGINX_SOURCE" ]; then
    echo -e "${BOLD}╔═══════════════════════════════════════════════════════════╗${NC}"
    echo -e "${BOLD}║           Instalador de Nginx Modular                     ║${NC}"
    echo -e "${BOLD}╚═══════════════════════════════════════════════════════════╝${NC}"
    
    if command_exists nginx; then
      echo ""
      echo -e "${YELLOW}Nginx já instalado:${NC}"
      nginx -v 2>&1 | sed 's/^/  /'
    fi
    
    interactive_select_source
  fi
  
  install_nginx "$NGINX_SOURCE"
}

# Executar apenas se chamado diretamente
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  main "$@"
fi
