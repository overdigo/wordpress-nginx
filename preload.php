<?php
/**
 * OPcache Preload Script for WordPress
 * 
 * Este arquivo é usado pelo opcache.preload para pré-carregar
 * classes e funções do WordPress na memória compartilhada.
 * 
 * Benefícios:
 * - Reduz tempo de execução ao eliminar compilação repetida
 * - Melhora performance em sites de alto tráfego
 * - Classes ficam sempre em memória compartilhada
 * 
 * IMPORTANTE:
 * - Este arquivo é executado UMA VEZ quando o PHP-FPM inicia
 * - Alterações requerem reinício do PHP-FPM
 * - Use apenas em produção com opcache.validate_timestamps=0
 * 
 * Configuração necessária no php.ini:
 * opcache.preload=/var/www/DOMAIN/preload.php
 * opcache.preload_user=www-data
 */

// Define o caminho base do WordPress
define('PRELOAD_BASE_PATH', __DIR__);

// Habilita error reporting para debug durante desenvolvimento
// Descomente para ver erros durante testes
// ini_set('display_errors', 1);
// error_reporting(E_ALL);

/**
 * Lista de arquivos core do WordPress para pré-carregar
 * Adicione aqui os arquivos mais usados do seu site
 */
$preload_files = [
    // Core WordPress files
    '/wp-load.php',
    '/wp-includes/version.php',
    '/wp-includes/compat.php',
    '/wp-includes/functions.php',
    '/wp-includes/class-wp.php',
    '/wp-includes/class-wp-error.php',
    '/wp-includes/plugin.php',
    '/wp-includes/pomo/mo.php',
    '/wp-includes/l10n.php',
    '/wp-includes/formatting.php',
    '/wp-includes/meta.php',
    '/wp-includes/post.php',
    '/wp-includes/user.php',
    '/wp-includes/link-template.php',
    '/wp-includes/general-template.php',
    '/wp-includes/class-wp-query.php',
    '/wp-includes/query.php',
    '/wp-includes/theme.php',
    '/wp-includes/class-wp-theme.php',
    '/wp-includes/class-wp-widget.php',
    '/wp-includes/class-wp-widget-factory.php',
    '/wp-includes/widgets.php',
    
    // WordPress Database
    '/wp-includes/wp-db.php',
    '/wp-includes/class-wpdb.php',
    
    // WordPress Options
    '/wp-includes/option.php',
    
    // WordPress Caching
    '/wp-includes/cache.php',
    '/wp-includes/class-wp-object-cache.php',
    
    // Adicione aqui plugins críticos que são sempre carregados
    // Exemplo:
    // '/wp-content/plugins/seu-plugin/seu-plugin.php',
    
    // Adicione aqui classes do seu tema (se aplicável)
    // Exemplo:
    // '/wp-content/themes/seu-tema/functions.php',
];

/**
 * Função para pré-carregar arquivo com tratamento de erros
 */
function preload_file($file) {
    $full_path = PRELOAD_BASE_PATH . $file;
    
    if (!file_exists($full_path)) {
        // Log para syslog em caso de arquivo não encontrado
        error_log("OPcache Preload: Arquivo não encontrado: {$full_path}");
        return false;
    }
    
    try {
        // Tenta incluir o arquivo
        opcache_compile_file($full_path);
        return true;
    } catch (Throwable $e) {
        // Log de erro caso haja problema ao compilar
        error_log("OPcache Preload: Erro ao compilar {$full_path}: " . $e->getMessage());
        return false;
    }
}

/**
 * Pré-carrega todos os arquivos da lista
 */
$loaded = 0;
$failed = 0;

foreach ($preload_files as $file) {
    if (preload_file($file)) {
        $loaded++;
    } else {
        $failed++;
    }
}

// Log de estatísticas para syslog
error_log(sprintf(
    "OPcache Preload: Concluído - %d arquivos carregados, %d falharam",
    $loaded,
    $failed
));

/**
 * AVANÇADO: Pré-carrega classes automaticamente via reflection
 * 
 * Descomente o bloco abaixo se quiser pré-carregar todas as classes
 * de um namespace específico ou diretório
 */

/*
// Exemplo: Pré-carregar todas as classes de um plugin
$plugin_dir = PRELOAD_BASE_PATH . '/wp-content/plugins/woocommerce/includes';
$iterator = new RecursiveIteratorIterator(
    new RecursiveDirectoryIterator($plugin_dir),
    RecursiveIteratorIterator::SELF_FIRST
);

foreach ($iterator as $file) {
    if ($file->isFile() && $file->getExtension() === 'php') {
        try {
            opcache_compile_file($file->getPathname());
        } catch (Throwable $e) {
            error_log("OPcache Preload: Erro ao compilar {$file->getPathname()}: " . $e->getMessage());
        }
    }
}
*/

/**
 * DICAS:
 * 
 * 1. Comece com poucos arquivos e adicione gradualmente
 * 2. Monitore o uso de memória com opcache_get_status()
 * 3. Arquivos pré-carregados NÃO podem ser modificados sem reiniciar PHP-FPM
 * 4. Use apenas para arquivos que raramente mudam (core, plugins estáveis)
 * 5. NÃO pré-carregue wp-config.php ou arquivos com side-effects
 * 
 * Para testar:
 * 1. sudo systemctl restart php8.x-fpm
 * 2. Verifique logs: tail -f /var/log/syslog | grep "OPcache Preload"
 * 3. Verifique status: curl https://seusite.com/SECURE_DIR/opcache.php
 */
