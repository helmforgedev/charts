<?php
// SPDX-License-Identifier: Apache-2.0
declare(strict_types=1);
// Export only daemon settings as literals: the Rust parser does not execute PHP.
// This avoids URL interpolation of Secret values containing reserved characters.
$CONFIG = [];
if (is_file('/var/www/html/config/config.php')) {
    require '/var/www/html/config/config.php';
}
$config = [
    'dbtype' => 'pgsql',
    'dbhost' => getenv('POSTGRES_HOST'),
    'dbname' => getenv('POSTGRES_DB'),
    'dbuser' => getenv('POSTGRES_USER'),
    'dbpassword' => getenv('POSTGRES_PASSWORD'),
    'dbtableprefix' => $CONFIG['dbtableprefix'] ?? 'oc_',
    'overwrite.cli.url' => 'http://127.0.0.1:8080',
    'redis' => [
        'host' => getenv('REDIS_HOST'),
        'port' => (int)getenv('REDIS_HOST_PORT'),
        'password' => getenv('REDIS_HOST_PASSWORD'),
    ],
];
umask(0077);
if (file_put_contents('/run/notify-push/config.php', "<?php\n\$CONFIG = " . var_export($config, true) . ";\n") === false) {
    throw new RuntimeException('Unable to write daemon configuration');
}
