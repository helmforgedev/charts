<?php
// SPDX-License-Identifier: Apache-2.0
require '/opt/helmforge/database.php';
$settings = moodle_settings();
$deadline = time() + (int)$settings['database']['connectTimeout'];
do {
    try { $db = moodle_connection(); break; }
    catch (Throwable $e) {
        if (time() >= $deadline) { fwrite(STDERR, "Timed out waiting for authenticated database connectivity\n"); exit(1); }
        echo "Waiting for database initialization\n";
        sleep(3);
    }
} while (true);
// A session-scoped lock survives the installer child process and is released on exit.
moodle_acquire_lifecycle_lock($db, $deadline);
$table = moodle_table('config');
if (!moodle_has_config_table($db)) {
    if (!$settings['moodle']['autoInstall']) { fwrite(STDERR, "Database is empty and moodle.autoInstall is disabled\n"); exit(1); }
    $app = $settings['moodle'];
    $args = [PHP_BINARY, '/var/www/html/admin/cli/install_database.php', '--agree-license',
        '--adminuser=' . $app['adminUser'], '--adminpass=' . getenv('ADMIN_PASSWORD'),
        '--adminemail=' . $app['adminEmail'], '--fullname=' . $app['siteName'],
        '--shortname=' . $app['shortName'], '--lang=' . $app['language']];
    $process = proc_open($args, [0 => ['file', '/dev/null', 'r'], 1 => STDOUT, 2 => STDERR], $pipes);
    if (!is_resource($process) || proc_close($process) !== 0) {
        fwrite(STDERR, "Installation did not complete. Inspect the database before retrying; no data will be erased.\n"); exit(1);
    }
}
define('MOODLE_INTERNAL', true);
define('MATURITY_STABLE', 200);
require '/var/www/html/public/version.php';
$installed = moodle_scalar($db, 'SELECT value FROM ' . $table . ' WHERE name=?', ['version']);
if ($installed === null || (float)$installed !== (float)$version) {
    fwrite(STDERR, "Moodle database/code version mismatch. Follow the documented maintenance upgrade or restore procedure; automatic upgrades are disabled.\n"); exit(1);
}
echo "Moodle database is installed and matches the immutable code version\n";
require '/opt/helmforge/metrics-check.php';
moodle_check_metrics($db);
if ($settings['metrics']['enabled']) {
    $process = proc_open([PHP_BINARY, '/opt/helmforge/metrics-configure.php'],
        [0 => ['file', '/dev/null', 'r'], 1 => STDOUT, 2 => STDERR], $pipes);
    if (!is_resource($process) || proc_close($process) !== 0) { exit(1); }
}
moodle_db_close($db);
