#!/bin/bash
# =============================================================================
# MÓDULO: System - Configurações do sistema (sysctl, timezone, etc)
# =============================================================================
# Uso standalone: sudo ./modules/system.sh [--apply-all|--sysctl|--timezone]
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
ACTION="${ACTION:-all}"
FORCE=false

# =============================================================================
# FUNÇÕES
# =============================================================================

show_help() {
  echo -e "${BOLD}Módulo System - Configurações do Sistema${NC}"
  echo ""
  echo "Uso: $0 [OPÇÕES]"
  echo ""
  echo "Opções:"
  echo "  -a, --all             Aplica todas as configurações (padrão)"
  echo "  -s, --sysctl          Aplica apenas configurações sysctl"
  echo "  -t, --timezone        Configura apenas timezone"
  echo "  -u, --update          Atualiza o sistema (apt update/upgrade)"
  echo "  -w, --wpcli           Instala apenas WP-CLI"
  echo "  -f, --force           Não pede confirmação"
  echo "  -h, --help            Exibe esta mensagem"
  echo ""
  echo "Configurações incluídas:"
  echo "  - Timezone: America/Sao_Paulo"
  echo "  - Sysctl: Otimizações de rede e performance"
  echo "  - WP-CLI: Ferramenta de linha de comando para WordPress"
}

# Configurar timezone
configure_timezone() {
  msg_info "Configurando timezone para America/Sao_Paulo..."
  timedatectl set-timezone America/Sao_Paulo
  msg_success "Timezone configurado"
  echo "  Data/Hora atual: $(date)"
}

# Atualizar sistema
update_system() {
  msg_info "Atualizando sistema..."
  apt update
  apt upgrade -y
  msg_success "Sistema atualizado"
}

# Aplicar configurações sysctl
apply_sysctl() {
  msg_header "Configurações Sysctl"
  
  if [ -f "$SCRIPT_DIR/50-perf.conf" ]; then
    msg_info "Copiando configurações de performance..."
    cp "$SCRIPT_DIR/50-perf.conf" /etc/sysctl.d/50-perf.conf
  else
    msg_info "Criando configurações de performance padrão..."
    cat > /etc/sysctl.d/50-perf.conf <<'EOF'
# =============================================================================
# Performance and Security Tuning
# =============================================================================

# Network Core
net.core.somaxconn = 65535
net.core.netdev_max_backlog = 65535
net.core.rmem_max = 16777216
net.core.wmem_max = 16777216
net.core.rmem_default = 1048576
net.core.wmem_default = 1048576
net.core.optmem_max = 65535

# TCP
net.ipv4.tcp_rmem = 4096 1048576 16777216
net.ipv4.tcp_wmem = 4096 1048576 16777216
net.ipv4.tcp_max_syn_backlog = 65535
net.ipv4.tcp_max_tw_buckets = 1440000
net.ipv4.tcp_tw_reuse = 1
net.ipv4.tcp_fin_timeout = 15
net.ipv4.tcp_keepalive_time = 300
net.ipv4.tcp_keepalive_probes = 5
net.ipv4.tcp_keepalive_intvl = 15
net.ipv4.tcp_slow_start_after_idle = 0
net.ipv4.tcp_mtu_probing = 1
net.ipv4.tcp_fastopen = 3
net.ipv4.tcp_syncookies = 1

# IP
net.ipv4.ip_local_port_range = 1024 65535
net.ipv4.conf.default.rp_filter = 1
net.ipv4.conf.all.rp_filter = 1
net.ipv4.conf.all.accept_redirects = 0
net.ipv4.conf.default.accept_redirects = 0
net.ipv4.conf.all.send_redirects = 0
net.ipv4.conf.default.send_redirects = 0
net.ipv4.icmp_echo_ignore_broadcasts = 1
net.ipv4.icmp_ignore_bogus_error_responses = 1

# IPv6
net.ipv6.conf.all.accept_redirects = 0
net.ipv6.conf.default.accept_redirects = 0

# VM
vm.swappiness = 10
vm.dirty_ratio = 15
vm.dirty_background_ratio = 5
vm.vfs_cache_pressure = 50

# File System
fs.file-max = 2097152
fs.inotify.max_user_watches = 524288
fs.inotify.max_user_instances = 512
fs.nr_open = 2097152

# Kernel
kernel.pid_max = 4194304
kernel.sched_autogroup_enabled = 0
EOF
  fi
  
  msg_info "Aplicando configurações sysctl..."
  sysctl --system > /dev/null 2>&1
  service procps force-reload 2>/dev/null || true
  deb-systemd-invoke restart procps.service 2>/dev/null || true
  
  msg_success "Configurações sysctl aplicadas"
  
  echo ""
  echo -e "${CYAN}Principais configurações:${NC}"
  echo "  net.core.somaxconn: $(sysctl -n net.core.somaxconn)"
  echo "  vm.swappiness: $(sysctl -n vm.swappiness)"
  echo "  fs.file-max: $(sysctl -n fs.file-max)"
}

# Instalar WP-CLI
install_wpcli() {
  msg_info "Instalando WP-CLI..."
  
  if command_exists wp; then
    msg_warning "WP-CLI já está instalado"
    wp --version
    return 0
  fi
  
  curl -sO https://raw.githubusercontent.com/wp-cli/builds/gh-pages/phar/wp-cli.phar
  chmod +x wp-cli.phar
  mv wp-cli.phar /usr/local/bin/wp
  
  msg_success "WP-CLI instalado"
  wp --version
}

# Aplicar todas as configurações
apply_all() {
  msg_header "Configurações do Sistema"
  
  # Confirmar
  if [ "$FORCE" != true ]; then
    echo -e "${YELLOW}Serão aplicadas:${NC}"
    echo "  - Timezone: America/Sao_Paulo"
    echo "  - Atualização do sistema (apt)"
    echo "  - Otimizações sysctl (rede e performance)"
    echo "  - WP-CLI"
    echo ""
    read -p "Continuar? [S/n]: " confirm
    if [[ "$confirm" =~ ^[Nn]$ ]]; then
      msg_info "Operação cancelada"
      return 0
    fi
  fi
  
  configure_timezone
  echo ""
  update_system
  echo ""
  apply_sysctl
  echo ""
  install_wpcli
  
  msg_success "Todas as configurações do sistema foram aplicadas!"
}

# =============================================================================
# PROCESSAMENTO DE ARGUMENTOS
# =============================================================================
parse_args() {
  while [[ $# -gt 0 ]]; do
    case $1 in
      -a|--all)
        ACTION="all"
        shift
        ;;
      -s|--sysctl)
        ACTION="sysctl"
        shift
        ;;
      -t|--timezone)
        ACTION="timezone"
        shift
        ;;
      -u|--update)
        ACTION="update"
        shift
        ;;
      -w|--wpcli)
        ACTION="wpcli"
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
    all)      apply_all ;;
    sysctl)   apply_sysctl ;;
    timezone) configure_timezone ;;
    update)   update_system ;;
    wpcli)    install_wpcli ;;
  esac
}

# Executar apenas se chamado diretamente
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  main "$@"
fi
