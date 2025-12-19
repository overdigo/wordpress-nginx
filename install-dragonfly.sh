#!/bin/bash
# =============================================================================
# INSTALADOR STANDALONE DO DRAGONFLYDB
# =============================================================================
# Instala DragonflyDB para uso com WordPress (redis-cache plugin)
# DragonflyDB: 25x mais rápido que Redis, 30% menos memória, multi-threaded
# =============================================================================

set -e

# Cores
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

echo -e "${CYAN}"
echo "============================================="
echo "  DragonflyDB Installer"
echo "  High-Performance Redis Alternative"
echo "============================================="
echo -e "${NC}"

# Verificar se está rodando como root
if [ "$EUID" -ne 0 ]; then
    echo -e "${RED}Este script deve ser executado como root${NC}"
    exit 1
fi

# Verificar se DragonflyDB já está instalado
if command -v dragonfly &> /dev/null; then
    echo -e "${YELLOW}DragonflyDB já está instalado!${NC}"
    dragonfly --version
    exit 0
fi

# Instalar dependências
echo -e "\n${CYAN}Instalando dependências...${NC}"
apt-get update
apt-get install -y wget redis-tools curl

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
        echo -e "${RED}Arquitetura não suportada: $ARCH${NC}"
        echo "DragonflyDB suporta apenas x86_64 e aarch64"
        exit 1
        ;;
esac

# Obter versão mais recente
echo -e "\n${CYAN}Baixando DragonflyDB para $DRAGONFLY_ARCH...${NC}"
DRAGONFLY_VERSION=$(curl -s https://api.github.com/repos/dragonflydb/dragonfly/releases/latest | grep '"tag_name":' | sed -E 's/.*"v([^"]+)".*/\1/')

if [ -z "$DRAGONFLY_VERSION" ]; then
    DRAGONFLY_VERSION="1.14.0"  # Fallback to known stable version
    echo "Usando versão padrão: v$DRAGONFLY_VERSION"
else
    echo "Versão detectada: v$DRAGONFLY_VERSION"
fi

# Download e instalação do DragonflyDB
DOWNLOAD_URL="https://github.com/dragonflydb/dragonfly/releases/download/v${DRAGONFLY_VERSION}/dragonfly-${DRAGONFLY_ARCH}.tar.gz"

echo "Baixando de: $DOWNLOAD_URL"
wget --show-progress "$DOWNLOAD_URL" -O /tmp/dragonfly.tar.gz || {
    echo -e "${RED}Erro ao baixar DragonflyDB${NC}"
    echo "URL tentada: $DOWNLOAD_URL"
    exit 1
}

# Extrair e instalar
echo "Extraindo binário..."
tar -xzf /tmp/dragonfly.tar.gz -C /tmp/
mv /tmp/dragonfly-${DRAGONFLY_ARCH} /usr/local/bin/dragonfly
chmod +x /usr/local/bin/dragonfly
rm /tmp/dragonfly.tar.gz

echo "DragonflyDB instalado em: /usr/local/bin/dragonfly"
/usr/local/bin/dragonfly --version

# Criar usuário dragonfly se não existir
if ! id -u dragonfly &>/dev/null; then
    echo "Criando usuário dragonfly..."
    useradd -r -s /bin/false dragonfly
fi

# Criar diretório de dados
mkdir -p /var/lib/dragonfly
chown dragonfly:dragonfly /var/lib/dragonfly

# Criar serviço systemd
echo -e "\n${CYAN}Criando serviço systemd...${NC}"
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

# Performance optimizations
Nice=-5
CPUSchedulingPolicy=fifo
CPUSchedulingPriority=99
IOSchedulingClass=realtime
IOSchedulingPriority=0

[Install]
WantedBy=multi-user.target
EOF

# Recarregar systemd e iniciar serviço
echo -e "\n${CYAN}Iniciando DragonflyDB...${NC}"
systemctl daemon-reload
systemctl enable dragonfly
systemctl start dragonfly

# Aguardar serviço iniciar
sleep 3

# Testar conexão
echo -e "\n${CYAN}Testando conexão...${NC}"
if redis-cli -p 6379 PING 2>/dev/null | grep -q "PONG"; then
    echo -e "${GREEN}"
    echo "============================================="
    echo "  ✓ DragonflyDB instalado com sucesso!"
    echo "============================================="
    echo -e "${NC}"
    echo ""
    echo "Informações:"
    echo "  Porta: 6379 (compatível com Redis)"
    echo "  Status: systemctl status dragonfly"
    echo "  Logs: journalctl -u dragonfly -f"
    echo ""
    echo "Performance:"
    echo "  ✓ 25x mais rápido que Redis"
    echo "  ✓ 30% menos uso de memória"
    echo "  ✓ Multi-threaded (usa todos os cores)"
    echo "  ✓ Compatível com plugin redis-cache do WordPress"
    echo ""
    echo "Comandos úteis:"
    echo "  redis-cli --stat          # Estatísticas em tempo real"
    echo "  redis-cli INFO memory     # Informações de memória"
    echo "  redis-cli MONITOR         # Monitorar comandos"
    echo ""
else
    echo -e "${YELLOW}"
    echo "⚠ DragonflyDB instalado mas não está respondendo"
    echo "Verifique o status: systemctl status dragonfly"
    echo "Verifique os logs: journalctl -u dragonfly -n 50"
    echo -e "${NC}"
    exit 1
fi
