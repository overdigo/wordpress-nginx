#!/bin/bash
# =============================================================================
# MÓDULO: Config - Funções de coleta de configuração interativa
# =============================================================================
# Este módulo gerencia a coleta de configurações do usuário
# =============================================================================

# Carregar módulo comum se ainda não carregado
MODULES_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" &> /dev/null && pwd)
source "$MODULES_DIR/common.sh" 2>/dev/null || true

# =============================================================================
# FUNÇÕES DE SELEÇÃO
# =============================================================================

# Função para exibir o menu de PHP
select_php_version() {
  echo -e "\n${CYAN}Selecione a versão do PHP:${NC}"
  echo "  1) PHP 8.1 (LTS - suporte até 2025)"
  echo "  2) PHP 8.2 (Estável)"
  echo "  3) PHP 8.3 (Recomendado - mais recente estável)"
  echo "  4) PHP 8.4 (Cutting Edge)"
  echo "  5) PHP 8.5 (Desenvolvimento - instável)"
  read -p "Escolha [1-5]: " php_choice
  
  case $php_choice in
    1) PHP_VERSION="8.1" ;;
    2) PHP_VERSION="8.2" ;;
    3) PHP_VERSION="8.3" ;;
    4) PHP_VERSION="8.4" ;;
    5) PHP_VERSION="8.5" ;;
    *) 
      echo -e "${RED}Opção inválida. Usando PHP 8.3 como padrão.${NC}"
      PHP_VERSION="8.3"
      ;;
  esac
  
  # Calcular versão sem ponto para uso em templates
  PHP_VERSION_NO_DOT=$(echo "$PHP_VERSION" | tr -d '.')
  
  export PHP_VERSION
  export PHP_VERSION_NO_DOT
}

# Função para selecionar Nginx
select_nginx() {
  echo -e "\n${CYAN}Selecione a versão do Nginx:${NC}"
  echo "  0) Não instalar Nginx (pular)"
  echo "  1) Nginx Oficial (nginx.org) - Versão mais recente"
  echo "  2) Nginx-EE WordOps (Com Brotli, Headers More, etc)"
  echo "  3) Nginx Ubuntu (Padrão do sistema)"
  read -p "Escolha [0-3]: " nginx_choice
  
  case $nginx_choice in
    0) 
      NGINX_CHOICE="0"
      NGINX_DESCRIPTION="Não instalar"
      ;;
    1)
      NGINX_CHOICE="1"
      NGINX_DESCRIPTION="Nginx Oficial (nginx.org)"
      ;;
    2)
      NGINX_CHOICE="2"
      NGINX_DESCRIPTION="Nginx-EE WordOps"
      ;;
    3)
      NGINX_CHOICE="3"
      NGINX_DESCRIPTION="Nginx Ubuntu"
      ;;
    *)
      echo -e "${RED}Opção inválida. Usando Nginx Oficial.${NC}"
      NGINX_CHOICE="1"
      NGINX_DESCRIPTION="Nginx Oficial (nginx.org)"
      ;;
  esac
  
  export NGINX_CHOICE
  export NGINX_DESCRIPTION
}

# Função para selecionar Database
select_database() {
  echo -e "\n${CYAN}Selecione o Database:${NC}"
  echo "  0) Não instalar Database (pular)"
  echo "  1) MySQL"
  echo "  2) MariaDB"
  read -p "Escolha [0-2]: " db_choice
  
  case $db_choice in
    0)
      DB_CHOICE="0"
      DB_VERSION_CHOICE=""
      DB_DESCRIPTION="Não instalar"
      ;;
    1)
      DB_CHOICE="1"
      echo -e "\n${CYAN}Selecione a versão do MySQL:${NC}"
      echo "  1) MySQL 8.4 LTS (Recomendado - suporte até 2032)"
      echo "  2) MySQL 8.0 (Legacy - suporte até 2026)"
      read -p "Escolha [1-2]: " mysql_version
      case $mysql_version in
        1) 
          DB_VERSION_CHOICE="1"
          DB_DESCRIPTION="MySQL 8.4 LTS"
          ;;
        2)
          DB_VERSION_CHOICE="2"
          DB_DESCRIPTION="MySQL 8.0"
          ;;
        *)
          echo -e "${RED}Opção inválida. Usando MySQL 8.4.${NC}"
          DB_VERSION_CHOICE="1"
          DB_DESCRIPTION="MySQL 8.4 LTS"
          ;;
      esac
      ;;
    2)
      DB_CHOICE="2"
      echo -e "\n${CYAN}Selecione a versão do MariaDB:${NC}"
      echo "  1) MariaDB 10.11 LTS (Recomendado)"
      echo "  2) MariaDB 10.6 LTS"
      echo "  3) MariaDB 10.5 LTS"
      read -p "Escolha [1-3]: " mariadb_version
      case $mariadb_version in
        1)
          DB_VERSION_CHOICE="1"
          DB_DESCRIPTION="MariaDB 10.11 LTS"
          ;;
        2)
          DB_VERSION_CHOICE="2"
          DB_DESCRIPTION="MariaDB 10.6 LTS"
          ;;
        3)
          DB_VERSION_CHOICE="3"
          DB_DESCRIPTION="MariaDB 10.5 LTS"
          ;;
        *)
          echo -e "${RED}Opção inválida. Usando MariaDB 10.11.${NC}"
          DB_VERSION_CHOICE="1"
          DB_DESCRIPTION="MariaDB 10.11 LTS"
          ;;
      esac
      ;;
    *)
      echo -e "${RED}Opção inválida.${NC}"
      DB_CHOICE=""
      DB_VERSION_CHOICE=""
      DB_DESCRIPTION=""
      select_database  # Recursão para nova tentativa
      return
      ;;
  esac
  
  export DB_CHOICE
  export DB_VERSION_CHOICE
  export DB_DESCRIPTION
}

# Função para selecionar Cache Server
select_cache_server() {
  echo -e "\n${CYAN}Selecione o Cache Server:${NC}"
  echo "  0) Instalar depois manualmente"
  echo "  1) DragonflyDB (25x mais rápido que Redis, Redis-compatible)"
  echo "  2) Valkey (Fork open-source do Redis)"
  echo "  3) Redis (Tradicional, estável)"
  echo "  4) Nenhum (não usar cache)"
  read -p "Escolha [0-4]: " cache_choice
  
  case $cache_choice in
    0)
      CACHE_CHOICE="0"
      CACHE_DESCRIPTION="Instalar manualmente depois"
      ;;
    1)
      CACHE_CHOICE="1"
      CACHE_DESCRIPTION="DragonflyDB (Ultra-rápido)"
      ;;
    2)
      CACHE_CHOICE="2"
      CACHE_DESCRIPTION="Valkey (Open-source)"
      ;;
    3)
      CACHE_CHOICE="3"
      CACHE_DESCRIPTION="Redis (Tradicional)"
      ;;
    4)
      CACHE_CHOICE="4"
      CACHE_DESCRIPTION="Sem cache"
      ;;
    *)
      echo -e "${RED}Opção inválida.${NC}"
      CACHE_CHOICE=""
      CACHE_DESCRIPTION=""
      select_cache_server  # Recursão para nova tentativa
      return
      ;;
  esac
  
  export CACHE_CHOICE
  export CACHE_DESCRIPTION
}

# Função para exibir resumo das configurações
show_summary() {
  echo -e "\n${BOLD}╔═══════════════════════════════════════════════════════════╗${NC}"
  echo -e "${BOLD}║              RESUMO DAS CONFIGURAÇÕES                     ║${NC}"
  echo -e "${BOLD}╠═══════════════════════════════════════════════════════════╣${NC}"
  echo -e "${BOLD}║${NC} PHP:       ${GREEN}$PHP_VERSION${NC}"
  echo -e "${BOLD}║${NC} Nginx:     ${GREEN}${NGINX_DESCRIPTION:-N/A}${NC}"
  echo -e "${BOLD}║${NC} Database:  ${GREEN}${DB_DESCRIPTION:-N/A}${NC}"
  echo -e "${BOLD}║${NC} Cache:     ${GREEN}${CACHE_DESCRIPTION:-N/A}${NC}"
  echo -e "${BOLD}╚═══════════════════════════════════════════════════════════╝${NC}"
}

# Função principal de coleta de configuração
collect_configuration() {
  msg_header "Configuração Interativa"
  
  # Coleta inicial de todas as configurações
  select_php_version
  
  if ! command_exists nginx; then
    select_nginx
  else
    NGINX_CHOICE="0"
    NGINX_DESCRIPTION="Já instalado"
    msg_info "Nginx já está instalado, pulando seleção."
  fi
  
  if ! command_exists mysql; then
    select_database
  else
    DB_CHOICE="0"
    DB_DESCRIPTION="Já instalado"
    msg_info "Database já está instalado, pulando seleção."
  fi
  
  if ! command_exists redis-server && ! command_exists dragonfly && ! command_exists valkey-server; then
    select_cache_server
  else
    CACHE_CHOICE="0"
    CACHE_DESCRIPTION="Já instalado"
    msg_info "Cache server já está instalado, pulando seleção."
  fi
  
  # Loop de confirmação
  while true; do
    show_summary
    
    echo -e "\n${YELLOW}Confirme as configurações:${NC}"
    echo "  c) Confirmar e iniciar instalação"
    echo "  1) Editar versão do PHP"
    echo "  2) Editar escolha do Nginx"
    echo "  3) Editar escolha do Database"
    echo "  4) Editar escolha do Cache Server"
    echo "  q) Cancelar e sair"
    read -p "Escolha: " CONFIRM_CHOICE
    
    case $CONFIRM_CHOICE in
      c|C)
        # Validar configurações
        if [ -z "$PHP_VERSION" ]; then
          msg_error "Versão do PHP não definida"
          continue
        fi
        if [ -z "$NGINX_CHOICE" ] && ! command_exists nginx; then
          msg_error "Escolha do Nginx inválida"
          continue
        fi
        if [ -z "$DB_CHOICE" ] && ! command_exists mysql; then
          msg_error "Escolha do Database inválida"
          continue
        fi
        if [ "$DB_CHOICE" != "0" ] && [ -n "$DB_CHOICE" ] && [ -z "$DB_VERSION_CHOICE" ]; then
          msg_error "Versão do Database não definida"
          continue
        fi
        if [ -z "$CACHE_CHOICE" ]; then
          msg_error "Escolha do Cache Server inválida"
          continue
        fi
        
        msg_success "Configurações confirmadas! Iniciando instalação..."
        break
        ;;
      1)
        select_php_version
        ;;
      2)
        if command_exists nginx; then
          msg_warning "Nginx já está instalado, não pode ser alterado."
        else
          NGINX_CHOICE=""
          NGINX_DESCRIPTION=""
          select_nginx
        fi
        ;;
      3)
        if command_exists mysql; then
          msg_warning "Database já está instalado, não pode ser alterado."
        else
          DB_CHOICE=""
          DB_VERSION_CHOICE=""
          DB_DESCRIPTION=""
          select_database
        fi
        ;;
      4)
        if command_exists redis-server || command_exists dragonfly || command_exists valkey-server; then
          msg_warning "Cache server já está instalado, não pode ser alterado."
        else
          CACHE_CHOICE=""
          CACHE_DESCRIPTION=""
          select_cache_server
        fi
        ;;
      q|Q)
        msg_error "Instalação cancelada pelo usuário."
        exit 0
        ;;
      *)
        msg_error "Opção inválida. Tente novamente."
        ;;
    esac
  done
}

# =============================================================================
# EXECUÇÃO STANDALONE
# =============================================================================
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  check_root
  collect_configuration
  
  echo ""
  echo "Variáveis exportadas:"
  echo "  PHP_VERSION=$PHP_VERSION"
  echo "  NGINX_CHOICE=$NGINX_CHOICE"
  echo "  DB_CHOICE=$DB_CHOICE"
  echo "  DB_VERSION_CHOICE=$DB_VERSION_CHOICE"
  echo "  CACHE_CHOICE=$CACHE_CHOICE"
fi
