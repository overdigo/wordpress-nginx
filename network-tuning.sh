#!/bin/bash
# =============================================================================
# NETWORK PERFORMANCE TUNING SCRIPT
# =============================================================================
# Script de otimização de rede baseado em:
# https://talawah.io/blog/extreme-http-performance-tuning-one-point-two-million/
#
# Este script deve ser executado no boot do servidor ou manualmente.
# Adicione ao /etc/rc.local ou crie um serviço systemd.
# =============================================================================

set -e

# Cores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[OK]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# =============================================================================
# 1. IRQ AFFINITY - Desabilitar irqbalance e configurar afinidade manual
# =============================================================================
configure_irq_affinity() {
    log_info "Configurando IRQ Affinity..."
    
    # Verificar se irqbalance está instalado e rodando
    if systemctl is-active --quiet irqbalance 2>/dev/null; then
        log_info "Parando irqbalance service..."
        systemctl stop irqbalance.service
        systemctl disable irqbalance.service
        log_success "irqbalance desabilitado"
    else
        log_info "irqbalance não está ativo"
    fi
    
    # Detectar interface de rede principal
    IFACE=$(ip route get 8.8.8.8 | awk '{print $5; exit}')
    
    if [ -z "$IFACE" ]; then
        log_warning "Não foi possível detectar interface de rede principal"
        return 1
    fi
    
    log_info "Interface detectada: $IFACE"
    
    # Obter IRQs da interface
    IRQS=($(grep "$IFACE" /proc/interrupts | awk '{print $1}' | tr -d :))
    
    if [ ${#IRQS[@]} -eq 0 ]; then
        log_warning "Nenhum IRQ encontrado para $IFACE"
        return 1
    fi
    
    log_info "IRQs encontrados: ${IRQS[*]}"
    
    # Configurar afinidade de CPU para cada IRQ
    for i in "${!IRQS[@]}"; do
        IRQ="${IRQS[$i]}"
        if [ -f "/proc/irq/${IRQ}/smp_affinity_list" ]; then
            echo "$i" > "/proc/irq/${IRQ}/smp_affinity_list" 2>/dev/null || true
            log_success "IRQ $IRQ -> CPU $i"
        fi
    done
    
    log_success "IRQ Affinity configurado"
}

# =============================================================================
# 2. XPS (Transmit Packet Steering) - Otimiza envio de pacotes
# =============================================================================
configure_xps() {
    log_info "Configurando XPS (Transmit Packet Steering)..."
    
    # Detectar interface de rede principal
    IFACE=$(ip route get 8.8.8.8 | awk '{print $5; exit}')
    
    if [ -z "$IFACE" ]; then
        log_warning "Não foi possível detectar interface de rede principal"
        return 1
    fi
    
    # Obter número de CPUs
    NUM_CPUS=$(nproc)
    
    log_info "Configurando XPS para $IFACE com $NUM_CPUS CPUs"
    
    # Configurar XPS para cada fila TX
    for i in $(seq 0 $((NUM_CPUS - 1))); do
        XPS_FILE="/sys/class/net/${IFACE}/queues/tx-${i}/xps_cpus"
        if [ -f "$XPS_FILE" ]; then
            # Criar máscara hexadecimal para CPU i
            MASK=$(printf '%x' $((1 << i)))
            echo "$MASK" > "$XPS_FILE" 2>/dev/null || true
            log_success "TX queue $i -> CPU $i (mask: 0x$MASK)"
        fi
    done
    
    log_success "XPS configurado"
}

# =============================================================================
# 3. INTERRUPT MODERATION - Configurar adaptive-rx (AWS ENA / drivers modernos)
# =============================================================================
configure_interrupt_moderation() {
    log_info "Configurando Interrupt Moderation..."
    
    # Detectar interface de rede principal
    IFACE=$(ip route get 8.8.8.8 | awk '{print $5; exit}')
    
    if [ -z "$IFACE" ]; then
        log_warning "Não foi possível detectar interface de rede principal"
        return 1
    fi
    
    # Verificar se ethtool está disponível
    if ! command -v ethtool &> /dev/null; then
        log_warning "ethtool não encontrado, pulando configuração de interrupt moderation"
        return 1
    fi
    
    # Verificar driver
    DRIVER=$(ethtool -i "$IFACE" 2>/dev/null | grep driver | awk '{print $2}')
    log_info "Driver detectado: $DRIVER"
    
    # Configurar interrupt coalescing
    # Tentar configurar adaptive-rx (funciona em ENA, ixgbe, i40e, etc.)
    if ethtool -C "$IFACE" adaptive-rx on 2>/dev/null; then
        log_success "adaptive-rx habilitado"
    else
        log_info "adaptive-rx não suportado por $DRIVER"
    fi
    
    # Configurar tx-usecs para melhor throughput
    if ethtool -C "$IFACE" tx-usecs 256 2>/dev/null; then
        log_success "tx-usecs = 256"
    else
        log_info "tx-usecs não configurável"
    fi
    
    log_success "Interrupt Moderation configurado"
}

# =============================================================================
# 4. RING BUFFER SIZE - Aumentar buffers da NIC
# =============================================================================
configure_ring_buffers() {
    log_info "Configurando Ring Buffers..."
    
    # Detectar interface de rede principal
    IFACE=$(ip route get 8.8.8.8 | awk '{print $5; exit}')
    
    if [ -z "$IFACE" ]; then
        log_warning "Não foi possível detectar interface de rede principal"
        return 1
    fi
    
    # Verificar se ethtool está disponível
    if ! command -v ethtool &> /dev/null; then
        log_warning "ethtool não encontrado"
        return 1
    fi
    
    # Obter valores máximos suportados
    MAX_RX=$(ethtool -g "$IFACE" 2>/dev/null | grep -A 4 "Pre-set" | grep RX: | head -1 | awk '{print $2}')
    MAX_TX=$(ethtool -g "$IFACE" 2>/dev/null | grep -A 4 "Pre-set" | grep TX: | head -1 | awk '{print $2}')
    
    if [ -n "$MAX_RX" ] && [ -n "$MAX_TX" ]; then
        # Configurar para valores máximos
        ethtool -G "$IFACE" rx "$MAX_RX" tx "$MAX_TX" 2>/dev/null || true
        log_success "Ring buffers: RX=$MAX_RX TX=$MAX_TX"
    else
        log_info "Não foi possível obter valores máximos de ring buffer"
    fi
    
    log_success "Ring Buffers configurados"
}

# =============================================================================
# 5. TCP/IP STACK TUNING (aplicado via sysctl, aqui apenas verificação)
# =============================================================================
verify_sysctl_settings() {
    log_info "Verificando configurações sysctl aplicadas..."
    
    # Verificar se as configurações principais estão aplicadas
    local settings=(
        "net.core.busy_poll"
        "net.core.busy_read"
        "net.ipv4.tcp_congestion_control"
        "net.ipv4.tcp_fastopen"
        "net.core.somaxconn"
    )
    
    for setting in "${settings[@]}"; do
        value=$(sysctl -n "$setting" 2>/dev/null || echo "N/A")
        log_info "$setting = $value"
    done
    
    log_success "Verificação de sysctl concluída"
}

# =============================================================================
# 6. DISPLAY CURRENT STATUS
# =============================================================================
show_status() {
    log_info "=== STATUS ATUAL DA REDE ==="
    
    IFACE=$(ip route get 8.8.8.8 | awk '{print $5; exit}')
    
    if [ -n "$IFACE" ]; then
        echo ""
        log_info "Interface: $IFACE"
        
        # Driver info
        if command -v ethtool &> /dev/null; then
            DRIVER=$(ethtool -i "$IFACE" 2>/dev/null | grep driver | awk '{print $2}')
            log_info "Driver: $DRIVER"
            
            # Coalescing settings
            echo ""
            log_info "Interrupt Coalescing:"
            ethtool -c "$IFACE" 2>/dev/null | head -10
            
            # Ring buffer settings
            echo ""
            log_info "Ring Buffers:"
            ethtool -g "$IFACE" 2>/dev/null | tail -5
        fi
        
        # IRQ affinity
        echo ""
        log_info "IRQ Affinity:"
        IRQS=($(grep "$IFACE" /proc/interrupts | awk '{print $1}' | tr -d :))
        for IRQ in "${IRQS[@]}"; do
            if [ -f "/proc/irq/${IRQ}/smp_affinity_list" ]; then
                AFFINITY=$(cat "/proc/irq/${IRQ}/smp_affinity_list")
                echo "  IRQ $IRQ -> CPU $AFFINITY"
            fi
        done
    fi
    
    echo ""
}

# =============================================================================
# MAIN
# =============================================================================
main() {
    echo ""
    echo "=============================================="
    echo "  Network Performance Tuning Script"
    echo "  Based on: Extreme HTTP Performance Tuning"
    echo "=============================================="
    echo ""
    
    # Verificar se está rodando como root
    if [ "$EUID" -ne 0 ]; then
        log_error "Este script deve ser executado como root"
        exit 1
    fi
    
    case "${1:-all}" in
        irq)
            configure_irq_affinity
            ;;
        xps)
            configure_xps
            ;;
        interrupt)
            configure_interrupt_moderation
            ;;
        ring)
            configure_ring_buffers
            ;;
        sysctl)
            verify_sysctl_settings
            ;;
        status)
            show_status
            ;;
        all)
            configure_irq_affinity
            echo ""
            configure_xps
            echo ""
            configure_interrupt_moderation
            echo ""
            configure_ring_buffers
            echo ""
            verify_sysctl_settings
            echo ""
            show_status
            ;;
        *)
            echo "Uso: $0 {all|irq|xps|interrupt|ring|sysctl|status}"
            echo ""
            echo "  all       - Executar todas as otimizações"
            echo "  irq       - Configurar IRQ affinity"
            echo "  xps       - Configurar XPS (Transmit Packet Steering)"
            echo "  interrupt - Configurar interrupt moderation"
            echo "  ring      - Configurar ring buffers"
            echo "  sysctl    - Verificar configurações sysctl"
            echo "  status    - Mostrar status atual"
            exit 1
            ;;
    esac
    
    echo ""
    log_success "Script concluído!"
    echo ""
}

main "$@"
