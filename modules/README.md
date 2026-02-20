# Módulos do Server Setup

Esta pasta contém módulos independentes que podem ser executados separadamente para instalar/configurar componentes específicos do servidor.

## Estrutura

```
modules/
├── common.sh      # Funções utilitárias compartilhadas
├── config.sh      # Coleta interativa de configurações
├── php.sh         # Instalação e configuração do PHP
├── nginx.sh       # Instalação e configuração do Nginx
├── database.sh    # Instalação do MySQL/MariaDB
├── cache.sh       # Instalação do Redis/Valkey/DragonflyDB
├── firewall.sh    # Configuração do nftables
└── system.sh      # Configurações do sistema (sysctl, timezone)
```

## Uso

### Instalação Completa (via script principal)

```bash
sudo ./server-setup.sh
```

### Execução Individual de Módulos

Cada módulo pode ser executado de forma independente:

#### PHP

```bash
# Menu interativo
sudo ./modules/php.sh

# Instalar versão específica
sudo ./modules/php.sh --version 8.4

# Reinstalar/reconfigurar
sudo ./modules/php.sh --version 8.3 --reinstall

# Listar versões instaladas
sudo ./modules/php.sh --list
```

**Versões disponíveis:** 8.1, 8.2, 8.3, 8.4, 8.5

#### Nginx

```bash
# Menu interativo
sudo ./modules/nginx.sh

# Instalar do nginx.org (mais recente)
sudo ./modules/nginx.sh --source official

# Instalar Nginx-EE WordOps (com Brotli, ModSecurity, etc)
sudo ./modules/nginx.sh --source wordops

# Instalar do repositório Ubuntu
sudo ./modules/nginx.sh --source ubuntu
```

#### Database

```bash
# Menu interativo
sudo ./modules/database.sh

# Instalar MySQL 8.4 LTS
sudo ./modules/database.sh --type mysql --version 8.4

# Instalar MariaDB 10.11 LTS
sudo ./modules/database.sh --type mariadb --version 10.11

# Especificar senha root
sudo ./modules/database.sh --type mysql --version 8.4 --password "MinhaS3nh@"
```

**Versões MySQL:** 8.4 (LTS), 8.0  
**Versões MariaDB:** 10.11 (LTS), 10.6, 10.5

#### Cache Server

```bash
# Menu interativo
sudo ./modules/cache.sh

# Instalar DragonflyDB (25x mais rápido que Redis)
sudo ./modules/cache.sh --server dragonfly

# Instalar Valkey (fork open-source do Redis)
sudo ./modules/cache.sh --server valkey

# Instalar Redis tradicional
sudo ./modules/cache.sh --server redis

# Ver status do cache
sudo ./modules/cache.sh --status
```

#### Firewall

```bash
# Aplicar regras de firewall
sudo ./modules/firewall.sh --apply

# Ver status
sudo ./modules/firewall.sh --status

# Desabilitar firewall
sudo ./modules/firewall.sh --disable
```

#### System

```bash
# Aplicar todas as configurações
sudo ./modules/system.sh --all

# Apenas sysctl (otimizações de rede/performance)
sudo ./modules/system.sh --sysctl

# Apenas timezone
sudo ./modules/system.sh --timezone

# Apenas atualização do sistema
sudo ./modules/system.sh --update

# Apenas WP-CLI
sudo ./modules/system.sh --wpcli
```

## Opções Comuns

| Opção | Descrição |
|-------|-----------|
| `-h, --help` | Exibe ajuda do módulo |
| `-f, --force` | Executa sem pedir confirmação |

## Exemplos de Cenários

### Atualizar PHP para nova versão

```bash
# Instalar PHP 8.4 mantendo 8.3
sudo ./modules/php.sh --version 8.4

# Após testar, remover PHP 8.3
sudo apt remove php8.3-*
```

### Trocar Cache Server

```bash
# Trocar de Redis para DragonflyDB
sudo ./modules/cache.sh --server dragonfly
```

### Reconfigurar Nginx após editar templates

```bash
sudo ./modules/nginx.sh --source official
# Selecionar "reconfigurar" quando perguntado
```

### Setup mínimo (apenas PHP + Nginx)

```bash
sudo ./modules/system.sh --update
sudo ./modules/nginx.sh --source official --force
sudo ./modules/php.sh --version 8.3 --force
```

## Desenvolvendo Novos Módulos

Para criar um novo módulo, use este template:

```bash
#!/bin/bash
# =============================================================================
# MÓDULO: Nome - Descrição do módulo
# =============================================================================
# Uso standalone: sudo ./modules/nome.sh [opções]
# =============================================================================

set -e

# Carregar módulo comum
MODULES_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" &> /dev/null && pwd)
source "$MODULES_DIR/common.sh"

# Diretório base do projeto
SCRIPT_DIR=$(get_script_dir)

# Suas funções aqui...

# Executar apenas se chamado diretamente
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  check_root
  setup_environment
  main "$@"
fi
```

## Funções Utilitárias (common.sh)

| Função | Descrição |
|--------|-----------|
| `check_root` | Verifica se está executando como root |
| `command_exists cmd` | Verifica se um comando existe |
| `msg_info text` | Exibe mensagem informativa |
| `msg_success text` | Exibe mensagem de sucesso |
| `msg_warning text` | Exibe mensagem de aviso |
| `msg_error text` | Exibe mensagem de erro |
| `msg_header text` | Exibe cabeçalho formatado |
| `get_script_dir` | Retorna diretório base do projeto |
| `get_php_version` | Retorna versão do PHP configurada |
| `process_mustache in out` | Processa template mustache |
