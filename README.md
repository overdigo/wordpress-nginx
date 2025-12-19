# WordPress Nginx Multi-Site Installer

[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)

Conjunto completo de scripts para instalação e otimização de WordPress com Nginx e PHP-FPM, incluindo segurança avançada, cache em RAM e tuning de performance.

## 🚀 Características Principais

### 📦 Instalação e Multi-Sites
- **Múltiplos sites no mesmo servidor**: Cada domínio possui seu próprio diretório e configuração
- **Detecção automática de SSL** baseada na URL fornecida
- **Suporte para diferentes versões do PHP** (8.1, 8.2, 8.3, 8.4)
- **Pool PHP dedicado** para área administrativa com limites de recursos ampliados
- **Sistema de templates** Mustache para configurações dinâmicas

### ⚡ Performance
- **FastCGI Cache em RAM** (`/dev/shm`) - Cache de páginas para máxima velocidade
- **Redis Object Cache** - Cache de objetos PHP para WordPress
- **Network Performance Tuning** - Otimizações baseadas em "Extreme HTTP Performance Tuning"
- **Sysctl otimizado** - Mais de 100 parâmetros de kernel ajustados (TCP BBR, buffers, swappiness, etc.)
- **Busy Polling** - Reduz latência em ~5-10%

### 🔒 Segurança
- **WAF (Web Application Firewall)** - Regras extensivas de proteção
- **Proteção contra HTTP Smuggling, XSS, SQL Injection**
- **Hardening de headers HTTP** - Content-Type, User-Agent, Referer
- **Proteção DDoS** com rate limiting
- **NFTables Firewall** - Firewall moderno com rate limiting para SSH/ICMP
- **8G Firewall** - Regras adicionais de segurança

### 🛠️ Scripts e Ferramentas
- `server-setup.sh` - Configuração inicial do servidor
- `install-wordpress.sh` - Instalação de sites WordPress
- `nginx-cache-manager.sh` - Gerenciamento do cache FastCGI
- `network-tuning.sh` - Otimizações de rede avançadas

---

## 📁 Arquivos do Projeto

```
wordpress-nginx/
├── server-setup.sh           # Configuração inicial do servidor
├── install-wordpress.sh      # Instalação de sites WordPress
├── nginx-cache-manager.sh    # Gerenciamento do cache FastCGI
├── network-tuning.sh         # Tuning de performance de rede
├── nftables.conf             # Configuração do firewall NFTables
├── 50-perf.conf              # Configurações sysctl otimizadas
├── network-tuning.service    # Serviço systemd para tuning de rede
├── nginx-cache-dir.service   # Serviço para criar diretório de cache no boot
├── nginx/
│   ├── nginx.conf            # Configuração principal do Nginx
│   ├── nginx.mustache        # Template Nginx (sem cache)
│   ├── nginx-cache.mustache  # Template Nginx (com FastCGI cache)
│   └── snippets/
│       ├── secure.conf           # Regras de segurança
│       ├── secure-maps.conf      # Maps de segurança (WAF)
│       ├── fastcgi-cache.conf    # Configuração do cache FastCGI
│       ├── fastcgi-cache-location.conf  # Diretivas de cache para location
│       ├── fastcgi-php.conf      # Configuração FastCGI para PHP
│       └── ddos-protection.conf  # Proteção contra DDoS
├── php/
│   └── *.mustache            # Templates de configuração PHP-FPM
└── mysql/
    └── *.mustache            # Templates de configuração MySQL/MariaDB
```

---

## 📋 Como Usar

### 1. Instalar o Git e Clonar o Repositório

```bash
apt install git -y
git clone https://github.com/overdigo/wordpress-nginx
cd wordpress-nginx
```

### 2. Configuração Inicial do Servidor (apenas uma vez)

```bash
chmod +x server-setup.sh && ./server-setup.sh
```

Este script instalará e configurará:
- **Nginx** (oficial ou compilado)
- **MySQL** ou **MariaDB** (configuração otimizada por RAM)
- **PHP-FPM** (versão escolhida)
- **Redis** (para object cache)
- **Firewall NFTables** 
- **Sysctl otimizado** para performance

> ⚠️ **Importante**: Guarde a senha do MySQL root que será exibida ao final da instalação.

### 3. Instalação de Sites WordPress (para cada site)

```bash
chmod +x install-wordpress.sh && ./install-wordpress.sh
```

O script irá perguntar:
- URL do site (ex: `https://meusite.com`)
- Email do administrador
- Versão do PHP
- Senha do MySQL root
- **Habilitar FastCGI Cache** (opcional - recomendado)

Cada site terá:
- Diretório dedicado: `/var/www/dominio.com`
- Banco de dados dedicado
- Configuração Nginx específica
- SSL com certificado autoassinado (ou use Certbot depois)
- FastCGI Cache e Redis Object Cache (se habilitado)

---

## ⚡ FastCGI Cache (Page Cache em RAM)

O FastCGI Cache armazena páginas em RAM (`/dev/shm`) para máxima performance.

### Características:
- **Cache em RAM** - Latência mínima
- **Bypass inteligente** para:
  - Usuários logados
  - Carrinho/Checkout do WooCommerce
  - Páginas administrativas
  - Formulários (POST requests)
  - Preview de posts

### Gerenciamento do Cache

```bash
# Ver status do cache
./nginx-cache-manager.sh status

# Limpar todo o cache
sudo ./nginx-cache-manager.sh purge

# Ver tamanho do cache
./nginx-cache-manager.sh size

# Monitorar cache em tempo real
./nginx-cache-manager.sh watch
```

### Plugin Nginx Helper
O script instala automaticamente o plugin **Nginx Helper** configurado para:
- Purge automático ao atualizar posts/páginas
- Purge ao atualizar menus/widgets
- Cache path: `/dev/shm/nginx-cache`

---

## 🔒 Segurança

### Firewall NFTables

```bash
# Aplicar firewall
sudo nft -f nftables.conf

# Ver regras ativas
sudo nft list ruleset
```

**Recursos:**
- Policy DROP para input/forward
- Rate limiting para SSH (10/minuto)
- Rate limiting para ICMP (1/segundo)
- Suporte a HTTP/3 (QUIC - porta 443/UDP)

### WAF (Web Application Firewall)

Proteções incluídas em `nginx/snippets/secure.conf` e `secure-maps.conf`:

| Categoria | Proteção |
|-----------|----------|
| **Headers** | User-Agent malicioso, Referer spam, Content-Type attacks |
| **URL** | Path traversal, SQL injection, XSS |
| **Arquivos** | Backup files, config files, PHP em uploads |
| **WordPress** | wp-config, xmlrpc, install.php, upgrade.php |
| **HTTP** | HTTP Smuggling, H2C Smuggling, Method tampering |
| **Overflow** | Cookie size, URI length, query parameters |

---

## 🚀 Performance Tuning

### Network Tuning

```bash
# Aplicar todas as otimizações de rede
sudo ./network-tuning.sh all

# Ou individualmente:
sudo ./network-tuning.sh irq       # IRQ affinity
sudo ./network-tuning.sh xps       # Transmit Packet Steering
sudo ./network-tuning.sh ring      # Ring buffers
sudo ./network-tuning.sh status    # Ver status atual
```

### Sysctl Otimizado

O arquivo `50-perf.conf` contém mais de 100 otimizações:

```bash
# Aplicar configurações
sudo cp 50-perf.conf /etc/sysctl.d/
sudo sysctl --system
```

**Principais otimizações:**
- TCP BBR congestion control
- Busy polling (reduz latência 5-10%)
- Buffers otimizados (rmem, wmem)
- SYN cookies e proteção contra floods
- TCP FastOpen
- Swappiness reduzido

### Serviços Systemd

```bash
# Tuning de rede no boot
sudo cp network-tuning.service /etc/systemd/system/
sudo systemctl enable network-tuning

# Criar diretório de cache no boot
sudo cp nginx-cache-dir.service /etc/systemd/system/
sudo systemctl enable nginx-cache-dir
```

---

## 📝 Sistema de Templates

O projeto usa arquivos `.mustache` como templates. Variáveis disponíveis:

| Variável | Descrição | Exemplo |
|----------|-----------|---------|
| `{{DOMAIN}}` | Domínio do site | `meusite.com` |
| `{{PHP_VERSION}}` | Versão do PHP | `8.4` |
| `{{PHP_VERSION_NO_DOT}}` | Versão sem ponto | `84` |
| `{{SITE_ROOT}}` | Caminho do site | `/var/www/meusite.com` |

---

## 🔧 Comandos Úteis

### MySQL Tuner (otimização do MySQL)
```bash
bash <(wget -O - https://raw.githubusercontent.com/overdigo/wordpress-nginx/master/mysqltuner.sh)
```

### Benchmark do Servidor
```bash
wget https://freevps.us/downloads/bench.sh -O - -o /dev/null|bash
```

### Verificar Configuração Nginx
```bash
sudo nginx -t
```

### Reiniciar Serviços
```bash
sudo systemctl restart nginx
sudo systemctl restart php8.4-fpm
sudo systemctl restart redis-server
```

### Logs
```bash
# Nginx error log
tail -f /var/log/nginx/error.log

# PHP-FPM log
tail -f /var/log/php8.4-fpm.log
```

---

## 📊 Arquitetura

```
┌─────────────────────────────────────────────────────────────┐
│                         CLIENTE                              │
└─────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────┐
│                     NFTables Firewall                        │
│            (Rate limiting SSH/ICMP, Drop policy)             │
└─────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────┐
│                          NGINX                               │
│  ┌─────────────────┐  ┌──────────────┐  ┌────────────────┐  │
│  │   WAF Rules     │  │ FastCGI     │  │    Static      │  │
│  │   (secure.conf) │  │ Cache (RAM) │  │    Files       │  │
│  └─────────────────┘  └──────────────┘  └────────────────┘  │
└─────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌──────────────────────────────┐    ┌─────────────────────────┐
│         PHP-FPM              │    │         Redis           │
│  ┌──────────┐ ┌──────────┐   │    │    (Object Cache)       │
│  │  www     │ │  admin   │   │◄──►│                         │
│  │  pool    │ │  pool    │   │    │                         │
│  └──────────┘ └──────────┘   │    └─────────────────────────┘
└──────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────┐
│                    MySQL / MariaDB                           │
│              (Configuração otimizada por RAM)                │
└─────────────────────────────────────────────────────────────┘
```

---

## 📄 Licença

Este projeto está sob a licença MIT. Veja o arquivo [LICENSE](LICENSE) para mais detalhes.

---

## 🤝 Contribuindo

Contribuições são bem-vindas! Por favor, abra uma issue ou pull request.

---

## ⚠️ Aviso

Este projeto é voltado para **servidores de produção**. Antes de usar:
- Faça backup dos seus dados
- Teste em ambiente de desenvolvimento primeiro
- Revise as configurações de segurança para seu caso de uso específico
