<?php
// SPDX-License-Identifier: Apache-2.0
declare(strict_types=1);
// Export only daemon settings as literals: the Rust parser does not execute PHP.
// This avoids URL interpolation of Secret values containing reserved characters.
$CONFIG = [];
if (is_file('/var/www/html/config/config.php')) {
    require '/var/www/html/config/config.php';
}
$dbHost = (string)getenv('POSTGRES_HOST');
$dbPort = 5432;
if (preg_match('/^(.+):(\d+)$/', $dbHost, $matches) === 1) {
    $dbHost = $matches[1];
    $dbPort = (int)$matches[2];
}
$database = null;
$lastDatabaseError = null;
for ($attempt = 1; $attempt <= 60; $attempt++) {
    try {
        $database = new PDO(
            sprintf('pgsql:host=%s;port=%d;dbname=%s;connect_timeout=3', $dbHost, $dbPort, getenv('POSTGRES_DB')),
            (string)getenv('POSTGRES_USER'),
            (string)getenv('POSTGRES_PASSWORD'),
            [PDO::ATTR_ERRMODE => PDO::ERRMODE_EXCEPTION],
        );
        $lastDatabaseError = null;
        break;
    } catch (PDOException $exception) {
        $lastDatabaseError = $exception;
        if ($attempt < 60) {
            sleep(2);
        }
    }
}
if ($lastDatabaseError !== null) {
    throw new RuntimeException('Database did not become ready for Client Push within 120 seconds', 0, $lastDatabaseError);
}
$database = null;
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
