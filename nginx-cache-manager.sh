#!/bin/bash
# =============================================================================
# FASTCGI CACHE MANAGEMENT SCRIPT
# =============================================================================
# Gerenciamento do cache FastCGI do Nginx para WordPress
# Cache armazenado em RAM (/dev/shm) para máxima performance
# =============================================================================

CACHE_DIR="/dev/shm/nginx-cache"

# Cores
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

show_help() {
    echo "FastCGI Cache Management"
    echo ""
    echo "Uso: $0 [comando]"
    echo ""
    echo "Comandos:"
    echo "  purge       - Limpa todo o cache"
    echo "  status      - Mostra status do cache"
    echo "  size        - Mostra tamanho do cache"
    echo "  watch       - Monitora uso do cache em tempo real"
    echo "  help        - Mostra esta ajuda"
}

purge_cache() {
    if [ ! -d "$CACHE_DIR" ]; then
        echo -e "${RED}Diretório de cache não encontrado: $CACHE_DIR${NC}"
        exit 1
    fi
    
    echo -e "${YELLOW}Limpando cache FastCGI...${NC}"
    
    # Conta arquivos antes
    COUNT_BEFORE=$(find "$CACHE_DIR" -type f 2>/dev/null | wc -l)
    SIZE_BEFORE=$(du -sh "$CACHE_DIR" 2>/dev/null | cut -f1)
    
    # Remove arquivos de cache
    rm -rf "${CACHE_DIR:?}"/*
    
    echo -e "${GREEN}Cache limpo!${NC}"
    echo "  Arquivos removidos: $COUNT_BEFORE"
    echo "  Espaço liberado: $SIZE_BEFORE"
}

cache_status() {
    if [ ! -d "$CACHE_DIR" ]; then
        echo -e "${RED}Cache desabilitado ou diretório não encontrado${NC}"
        exit 1
    fi
    
    echo "=== FastCGI Cache Status (RAM) ==="
    echo ""
    
    # Tamanho total
    SIZE=$(du -sh "$CACHE_DIR" 2>/dev/null | cut -f1)
    echo "Tamanho total: $SIZE"
    
    # Número de arquivos
    COUNT=$(find "$CACHE_DIR" -type f 2>/dev/null | wc -l)
    echo "Arquivos em cache: $COUNT"
    
    # Arquivo mais antigo
    OLDEST=$(find "$CACHE_DIR" -type f -printf '%T+ %p\n' 2>/dev/null | sort | head -1 | cut -d' ' -f1)
    if [ -n "$OLDEST" ]; then
        echo "Entrada mais antiga: $OLDEST"
    fi
    
    # Arquivo mais recente
    NEWEST=$(find "$CACHE_DIR" -type f -printf '%T+ %p\n' 2>/dev/null | sort -r | head -1 | cut -d' ' -f1)
    if [ -n "$NEWEST" ]; then
        echo "Entrada mais recente: $NEWEST"
    fi
    
    # RAM disponível
    echo ""
    echo "Memória /dev/shm:"
    df -h /dev/shm | tail -1 | awk '{print "  Total: " $2 "  Usado: " $3 "  Disponível: " $4}'
    
    # Verificar permissões
    echo ""
    echo "Permissões:"
    ls -la "$CACHE_DIR" 2>/dev/null | head -3
    
    # Verificar se nginx tem módulo cache_purge
    echo ""
    echo "Módulo ngx_cache_purge:"
    if nginx -V 2>&1 | grep -q 'ngx_cache_purge'; then
        echo -e "  ${GREEN}Instalado${NC}"
    else
        echo -e "  ${YELLOW}Não instalado (use $0 purge para limpar manualmente)${NC}"
    fi
}

cache_size() {
    if [ ! -d "$CACHE_DIR" ]; then
        echo "0"
        exit 0
    fi
    
    du -sh "$CACHE_DIR" 2>/dev/null | cut -f1
}

watch_cache() {
    echo "Monitorando cache FastCGI em RAM (Ctrl+C para sair)..."
    echo ""
    
    while true; do
        clear
        echo "=== FastCGI Cache Monitor (RAM) ==="
        echo "$(date)"
        echo ""
        
        SIZE=$(du -sh "$CACHE_DIR" 2>/dev/null | cut -f1)
        COUNT=$(find "$CACHE_DIR" -type f 2>/dev/null | wc -l)
        
        echo "Tamanho: $SIZE"
        echo "Arquivos: $COUNT"
        
        # RAM info
        echo ""
        echo "Memória /dev/shm:"
        df -h /dev/shm | tail -1 | awk '{print "  Usado: " $3 " / " $2}'
        
        echo ""
        echo "Últimas 10 entradas:"
        find "$CACHE_DIR" -type f -printf '%T+ %p\n' 2>/dev/null | sort -r | head -10 | while read -r line; do
            TIME=$(echo "$line" | cut -d' ' -f1 | cut -d'.' -f1)
            echo "  $TIME"
        done
        
        sleep 5
    done
}

# Main
case "${1:-help}" in
    purge)
        if [ "$EUID" -ne 0 ]; then
            echo -e "${RED}Este comando requer root${NC}"
            exit 1
        fi
        purge_cache
        ;;
    status)
        cache_status
        ;;
    size)
        cache_size
        ;;
    watch)
        watch_cache
        ;;
    help|*)
        show_help
        ;;
esac
