#!/bin/bash
# =============================================================================
# MÓDULO: Cache - Instalação do Redis/Valkey/DragonflyDB
# =============================================================================
# Uso standalone: sudo ./modules/cache.sh [--server dragonfly|valkey|redis]
# =============================================================================

set -e

# Carregar módulo comum
MODULES_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" &> /dev/null && pwd)
source "$MODULES_DIR/common.sh"

# =============================================================================
# VARIÁVEIS
# =============================================================================
CACHE_SERVER="${CACHE_SERVER:-}"
FORCE=false

# =============================================================================
# FUNÇÕES
# =============================================================================

show_help() {
  echo -e "${BOLD}Módulo Cache - Instalação de Cache Server${NC}"
  echo ""
  echo "Uso: $0 [OPÇÕES]"
  echo ""
  echo "Opções:"
  echo "  -s, --server SERVER   Servidor de cache (dragonfly, valkey, redis)"
  echo "  -f, --force           Não pede confirmação"
  echo "  -h, --help            Exibe esta mensagem"
  echo ""
  echo "Servidores disponíveis:"
  echo "  dragonfly - DragonflyDB (25x mais rápido que Redis)"
  echo "  valkey    - Valkey (Fork open-source do Redis)"
  echo "  redis     - Redis (Tradicional, estável)"
  echo ""
  echo "Exemplos:"
  echo "  $0 --server dragonfly"
  echo "  $0 --server redis"
  echo "  $0                    # Menu interativo"
}

# Verificar qual cache está instalado
get_installed_cache() {
  if command_exists dragonfly; then
    echo "dragonfly"
  elif command_exists valkey-server; then
    echo "valkey"
  elif command_exists redis-server; then
    echo "redis"
  else
    echo ""
  fi
}

# Menu interativo
interactive_select_cache() {
  local installed=$(get_installed_cache)
  
  if [ -n "$installed" ]; then
    msg_warning "Cache server já instalado: $installed"
    echo ""
    read -p "Deseja substituir? [s/N]: " confirm
    if [[ ! "$confirm" =~ ^[Ss]$ ]]; then
      exit 0
    fi
  fi
  
  echo -e "\n${CYAN}Selecione o Cache Server:${NC}"
  echo ""
  echo "  1) DragonflyDB (25x mais rápido que Redis, Redis-compatible)"
  echo "  2) Valkey (Fork open-source do Redis, mantido pela Linux Foundation)"
  echo "  3) Redis (Tradicional, mais maduro e estável)"
  echo ""
  echo "  0) Cancelar"
  echo ""
  read -p "Escolha [0-3]: " choice
  
  case $choice in
    0) exit 0 ;;
    1) CACHE_SERVER="dragonfly" ;;
    2) CACHE_SERVER="valkey" ;;
    3) CACHE_SERVER="redis" ;;
    *) 
      msg_error "Opção inválida"
      interactive_select_cache
      ;;
  esac
}

# Instalar DragonflyDB
install_dragonfly() {
  msg_info "Instalando DragonflyDB..."
  
  # Instalar dependências
  apt-get install -y redis-tools curl
  
  # Detectar arquitetura
  ARCH=$(uname -m)
  case $ARCH in
    x86_64)
      DRAGONFLY_ARCH="x86_64"
      ;;
    aarch64|arm64)
      DRAGONFLY_ARCH="aarch64"
      ;;
    *)
      msg_error "Arquitetura não suportada: $ARCH"
      msg_warning "Instalando Redis como fallback..."
      install_redis
      return
      ;;
  esac
  
  # Obter última versão
  msg_info "Obtendo última versão do DragonflyDB..."
  DRAGONFLY_VERSION=$(curl -s https://api.github.com/repos/dragonflydb/dragonfly/releases/latest | grep '"tag_name":' | sed -E 's/.*"v([^"]+)".*/\1/')
  
  if [ -z "$DRAGONFLY_VERSION" ]; then
    DRAGONFLY_VERSION="1.14.0"
    msg_warning "Usando versão padrão: v$DRAGONFLY_VERSION"
  else
    msg_info "Versão detectada: v$DRAGONFLY_VERSION"
  fi
  
  # Download
  DOWNLOAD_URL="https://github.com/dragonflydb/dragonfly/releases/download/v${DRAGONFLY_VERSION}/dragonfly-${DRAGONFLY_ARCH}.tar.gz"
  
  msg_info "Baixando de: $DOWNLOAD_URL"
  wget -q --show-progress "$DOWNLOAD_URL" -O /tmp/dragonfly.tar.gz || {
    msg_error "Erro ao baixar DragonflyDB"
    msg_warning "Instalando Redis como fallback..."
    install_redis
    return
  }
  
  # Extrair e instalar
  tar -xzf /tmp/dragonfly.tar.gz -C /tmp/
  mv /tmp/dragonfly-${DRAGONFLY_ARCH} /usr/local/bin/dragonfly
  chmod +x /usr/local/bin/dragonfly
  rm /tmp/dragonfly.tar.gz
  
  # Criar usuário
  if ! id -u dragonfly &>/dev/null; then
    useradd -r -s /bin/false dragonfly
  fi
  
  # Criar diretório de dados
  mkdir -p /var/lib/dragonfly
  chown dragonfly:dragonfly /var/lib/dragonfly
  
  # Criar serviço systemd
  cat <<'EOF' > /etc/systemd/system/dragonfly.service
[Unit]
Description=DragonflyDB - A modern in-memory datastore
Documentation=https://www.dragonflydb.io/docs
After=network.target

[Service]
Type=simple
User=dragonfly
Group=dragonfly
ExecStart=/usr/local/bin/dragonfly --logtostderr --dir /var/lib/dragonfly --bind 127.0.0.1 --port 6379
Restart=always
RestartSec=3
LimitNOFILE=65536

# Performance settings
Nice=-5
CPUSchedulingPolicy=fifo
CPUSchedulingPriority=99
IOSchedulingClass=realtime
IOSchedulingPriority=0

[Install]
WantedBy=multi-user.target
EOF
  
  systemctl daemon-reload
  systemctl enable dragonfly
  systemctl start dragonfly
  
  sleep 3
  
  # Testar
  if redis-cli -p 6379 PING 2>/dev/null | grep -q "PONG"; then
    msg_success "DragonflyDB instalado e funcionando!"
    echo "  Performance: 25x mais rápido que Redis"
    echo "  Memória: 30% mais eficiente"
    echo "  Multi-threaded: Usa todos os cores da CPU"
  else
    msg_warning "DragonflyDB instalado mas não respondendo na porta 6379"
    echo "  Verifique com: systemctl status dragonfly"
  fi
}

# Instalar Valkey
install_valkey() {
  msg_info "Instalando Valkey..."
  
  # Adicionar repositório
  curl -fsSL https://packages.valkey.io/gpg | gpg --dearmor -o /usr/share/keyrings/valkey-archive-keyring.gpg
  echo "deb [signed-by=/usr/share/keyrings/valkey-archive-keyring.gpg] https://packages.valkey.io/deb $(lsb_release -cs) main" | tee /etc/apt/sources.list.d/valkey.list
  
  apt-get update
  apt-get install -y valkey
  
  # Configurar
  sed -i 's/^# maxmemory <bytes>/maxmemory 256mb/' /etc/valkey/valkey.conf
  sed -i 's/^# maxmemory-policy noeviction/maxmemory-policy allkeys-lru/' /etc/valkey/valkey.conf
  
  systemctl enable valkey
  systemctl start valkey
  
  sleep 2
  
  # Testar
  if redis-cli -p 6379 PING 2>/dev/null | grep -q "PONG"; then
    msg_success "Valkey instalado e funcionando!"
    echo "  Licença: BSD (100% open-source)"
    echo "  Mantido pela Linux Foundation"
  else
    msg_warning "Valkey instalado mas não respondendo na porta 6379"
    echo "  Verifique com: systemctl status valkey"
  fi
}

# Instalar Redis
install_redis() {
  msg_info "Instalando Redis..."
  
  apt-get install -y redis-server
  
  # Configurar
  sed -i 's/^# maxmemory <bytes>/maxmemory 256mb/' /etc/redis/redis.conf
  sed -i 's/^# maxmemory-policy noeviction/maxmemory-policy allkeys-lru/' /etc/redis/redis.conf
  
  systemctl enable redis-server
  systemctl start redis-server
  
  sleep 2
  
  # Testar
  if redis-cli -p 6379 PING 2>/dev/null | grep -q "PONG"; then
    msg_success "Redis instalado e funcionando!"
    echo "  Opção mais madura e estável"
  else
    msg_warning "Redis instalado mas não respondendo na porta 6379"
    echo "  Verifique com: systemctl status redis-server"
  fi
}

# Função principal
install_cache() {
  local server=$1
  
  msg_header "Instalação do Cache Server: $server"
  
  # Confirmar instalação
  if [ "$FORCE" != true ]; then
    echo ""
    echo -e "${YELLOW}Será instalado:${NC}"
    case $server in
      dragonfly)
        echo "  - DragonflyDB (Redis-compatible)"
        echo "  - 25x mais rápido que Redis"
        echo "  - 30% mais eficiente em memória"
        ;;
      valkey)
        echo "  - Valkey (Fork open-source do Redis)"
        echo "  - 100% compatível com Redis"
        echo "  - Mantido pela Linux Foundation"
        ;;
      redis)
        echo "  - Redis (Tradicional)"
        echo "  - Opção mais madura"
        ;;
    esac
    echo ""
    read -p "Continuar? [S/n]: " confirm
    if [[ "$confirm" =~ ^[Nn]$ ]]; then
      msg_info "Operação cancelada"
      return 0
    fi
  fi
  
  # Parar cache existente se houver
  local existing=$(get_installed_cache)
  if [ -n "$existing" ] && [ "$existing" != "$server" ]; then
    msg_info "Parando $existing existente..."
    case $existing in
      dragonfly) systemctl stop dragonfly 2>/dev/null || true ;;
      valkey) systemctl stop valkey 2>/dev/null || true ;;
      redis) systemctl stop redis-server 2>/dev/null || true ;;
    esac
  fi
  
  # Instalar
  case $server in
    dragonfly) install_dragonfly ;;
    valkey)    install_valkey ;;
    redis)     install_redis ;;
    *)
      msg_error "Servidor inválido: $server"
      return 1
      ;;
  esac
  
  msg_success "Cache server instalado com sucesso!"
  echo ""
  echo -e "${CYAN}Informações:${NC}"
  echo "  Porta: 6379"
  echo "  Teste: redis-cli PING"
}

# =============================================================================
# PROCESSAMENTO DE ARGUMENTOS
# =============================================================================
parse_args() {
  while [[ $# -gt 0 ]]; do
    case $1 in
      -s|--server)
        CACHE_SERVER="$2"
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
      --status)
        show_status
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

# Mostrar status do cache
show_status() {
  local installed=$(get_installed_cache)
  
  if [ -z "$installed" ]; then
    msg_info "Nenhum cache server instalado"
    return
  fi
  
  echo -e "${CYAN}Cache Server Status:${NC}"
  echo ""
  
  case $installed in
    dragonfly)
      echo "  Servidor: DragonflyDB"
      systemctl status dragonfly --no-pager -l | head -10
      ;;
    valkey)
      echo "  Servidor: Valkey"
      systemctl status valkey --no-pager -l | head -10
      ;;
    redis)
      echo "  Servidor: Redis"
      systemctl status redis-server --no-pager -l | head -10
      ;;
  esac
  
  echo ""
  echo "  Teste de conexão:"
  if redis-cli PING 2>/dev/null | grep -q "PONG"; then
    echo -e "  ${GREEN}✓ Respondendo na porta 6379${NC}"
  else
    echo -e "  ${RED}✗ Não respondendo${NC}"
  fi
}

# =============================================================================
# EXECUÇÃO PRINCIPAL
# =============================================================================
main() {
  check_root
  setup_environment
  
  parse_args "$@"
  
  # Se servidor não especificado, mostrar menu
  if [ -z "$CACHE_SERVER" ]; then
    echo -e "${BOLD}╔═══════════════════════════════════════════════════════════╗${NC}"
    echo -e "${BOLD}║           Instalador de Cache Server Modular              ║${NC}"
    echo -e "${BOLD}╚═══════════════════════════════════════════════════════════╝${NC}"
    
    local installed=$(get_installed_cache)
    if [ -n "$installed" ]; then
      echo ""
      echo -e "${YELLOW}Cache instalado:${NC} $installed"
      show_status
    fi
    
    interactive_select_cache
  fi
  
  # Validar servidor
  if [[ ! "$CACHE_SERVER" =~ ^(dragonfly|valkey|redis)$ ]]; then
    msg_error "Servidor inválido: $CACHE_SERVER"
    msg_info "Opções: dragonfly, valkey, redis"
    exit 1
  fi
  
  install_cache "$CACHE_SERVER"
}

# Executar apenas se chamado diretamente
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  main "$@"
fi
