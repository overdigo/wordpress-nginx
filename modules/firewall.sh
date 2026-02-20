#!/bin/bash
# =============================================================================
# MÓDULO: Firewall - Configuração do nftables
# =============================================================================
# Uso standalone: sudo ./modules/firewall.sh [--apply|--status|--disable]
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
ACTION="${ACTION:-apply}"
FORCE=false

# =============================================================================
# FUNÇÕES
# =============================================================================

show_help() {
  echo -e "${BOLD}Módulo Firewall - Configuração do nftables${NC}"
  echo ""
  echo "Uso: $0 [OPÇÕES]"
  echo ""
  echo "Opções:"
  echo "  -a, --apply           Aplica as regras do firewall (padrão)"
  echo "  -s, --status          Mostra status atual do firewall"
  echo "  -d, --disable         Desabilita o firewall"
  echo "  -f, --force           Não pede confirmação"
  echo "  -h, --help            Exibe esta mensagem"
  echo ""
  echo "Configurações aplicadas:"
  echo "  - SSH (22): Rate limited (10 conexões/minuto por IP)"
  echo "  - HTTP (80): Aberta"
  echo "  - HTTPS (443): TCP + UDP (HTTP/3)"
  echo "  - ICMP: Rate limited"
  echo "  - Policy: DROP input/forward, ACCEPT output"
}

# Instalar nftables se necessário
ensure_nftables_installed() {
  if ! command_exists nft; then
    msg_info "Instalando nftables..."
    apt install -y nftables
  fi
}

# Aplicar regras do firewall
apply_firewall() {
  msg_header "Configuração do Firewall nftables"
  
  ensure_nftables_installed
  
  # Confirmar
  if [ "$FORCE" != true ]; then
    echo -e "${YELLOW}Regras que serão aplicadas:${NC}"
    echo "  - SSH (22): Rate limited (10 conexões/minuto por IP)"
    echo "  - HTTP (80): Aberta"
    echo "  - HTTPS (443): TCP + UDP (para HTTP/3)"
    echo "  - ICMP: Ping com rate limiting"
    echo "  - Policy: DROP input/forward, ACCEPT output"
    echo ""
    echo -e "${RED}ATENÇÃO: Certifique-se de ter acesso SSH alternativo!${NC}"
    echo ""
    read -p "Continuar? [S/n]: " confirm
    if [[ "$confirm" =~ ^[Nn]$ ]]; then
      msg_info "Operação cancelada"
      return 0
    fi
  fi
  
  msg_info "Aplicando regras do firewall..."
  
  # Verificar se existe arquivo de configuração
  if [ -f "$SCRIPT_DIR/nftables.conf" ]; then
    cp "$SCRIPT_DIR/nftables.conf" /etc/nftables.conf
    msg_success "Arquivo de configuração copiado"
  else
    # Criar configuração padrão
    msg_info "Criando configuração padrão..."
    cat > /etc/nftables.conf <<'EOF'
#!/usr/sbin/nft -f
# =============================================================================
# nftables firewall configuration for WordPress/Nginx server
# =============================================================================

flush ruleset

table inet filter {
    # Rate limiting para SSH
    set ssh_limit {
        type ipv4_addr
        flags dynamic,timeout
        timeout 1m
    }
    
    chain input {
        type filter hook input priority 0; policy drop;
        
        # Allow established/related connections
        ct state established,related accept
        
        # Allow loopback
        iif lo accept
        
        # Drop invalid connections
        ct state invalid drop
        
        # Rate limit SSH (10 per minute per IP)
        tcp dport 22 ct state new \
            add @ssh_limit { ip saddr limit rate 10/minute burst 5 packets } accept
        
        # HTTP/HTTPS
        tcp dport { 80, 443 } accept
        
        # HTTPS UDP for HTTP/3 (QUIC)
        udp dport 443 accept
        
        # ICMP rate limiting
        ip protocol icmp icmp type echo-request limit rate 10/second accept
        ip6 nexthdr icmpv6 icmpv6 type echo-request limit rate 10/second accept
        
        # Allow other essential ICMP
        ip protocol icmp icmp type { destination-unreachable, time-exceeded, parameter-problem } accept
        ip6 nexthdr icmpv6 icmpv6 type { destination-unreachable, time-exceeded, parameter-problem, packet-too-big } accept
    }
    
    chain forward {
        type filter hook forward priority 0; policy drop;
    }
    
    chain output {
        type filter hook output priority 0; policy accept;
    }
}
EOF
  fi
  
  # Aplicar regras
  nft -f /etc/nftables.conf
  
  # Habilitar no boot
  systemctl enable --now nftables
  
  msg_success "Firewall configurado com sucesso!"
  
  echo ""
  show_status
}

# Mostrar status do firewall
show_status() {
  echo -e "${CYAN}Status do Firewall:${NC}"
  echo ""
  
  if ! command_exists nft; then
    msg_warning "nftables não está instalado"
    return
  fi
  
  if ! systemctl is-active --quiet nftables; then
    msg_warning "nftables não está ativo"
    return
  fi
  
  msg_success "nftables está ativo"
  echo ""
  
  echo -e "${CYAN}Regras ativas:${NC}"
  nft list ruleset | grep -E "^table|chain|policy|dport|accept|drop" | head -30
  
  echo ""
  echo -e "${CYAN}Resumo:${NC}"
  echo "  Tabelas: $(nft list tables | wc -l)"
  echo "  Service: $(systemctl is-enabled nftables 2>/dev/null || echo 'disabled')"
}

# Desabilitar firewall
disable_firewall() {
  msg_header "Desabilitando Firewall"
  
  if [ "$FORCE" != true ]; then
    echo -e "${RED}ATENÇÃO: Isso deixará o servidor sem proteção de firewall!${NC}"
    echo ""
    read -p "Tem certeza? [s/N]: " confirm
    if [[ ! "$confirm" =~ ^[Ss]$ ]]; then
      msg_info "Operação cancelada"
      return 0
    fi
  fi
  
  if command_exists nft; then
    nft flush ruleset
    systemctl stop nftables 2>/dev/null || true
    systemctl disable nftables 2>/dev/null || true
    msg_success "Firewall desabilitado"
  else
    msg_info "nftables não está instalado"
  fi
}

# =============================================================================
# PROCESSAMENTO DE ARGUMENTOS
# =============================================================================
parse_args() {
  while [[ $# -gt 0 ]]; do
    case $1 in
      -a|--apply)
        ACTION="apply"
        shift
        ;;
      -s|--status)
        ACTION="status"
        shift
        ;;
      -d|--disable)
        ACTION="disable"
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
  
  case $ACTION in
    apply)   apply_firewall ;;
    status)  show_status ;;
    disable) disable_firewall ;;
  esac
}

# Executar apenas se chamado diretamente
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  main "$@"
fi
