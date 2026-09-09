<?php
// SPDX-License-Identifier: Apache-2.0
require '/opt/helmforge/database.php';
$settings = moodle_settings();
$deadline = time() + (int)$settings['database']['connectTimeout'];
do {
    try { $db = moodle_connection(); break; }
    catch (Throwable $e) {
        if (time() >= $deadline) { fwrite(STDERR, "Timed out waiting for authenticated PostgreSQL connectivity\n"); exit(1); }
        echo "Waiting for PostgreSQL initialization\n";
        sleep(3);
    }
} while (true);
// A session-scoped lock survives the installer child process and is released on exit.
do {
    $lock = pg_query($db, "SELECT pg_try_advisory_lock(741932, hashtext(current_database()))");
    if (pg_fetch_result($lock, 0, 0) === 't') { break; }
    if (time() >= $deadline) { fwrite(STDERR, "Timed out waiting for Moodle installer lock\n"); exit(1); }
    sleep(3);
} while (true);
$table = moodle_table('config');
$exists = pg_query_params($db, 'SELECT to_regclass($1)', [$table]);
if (pg_fetch_result($exists, 0, 0) === null) {
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
$result = pg_query_params($db, 'SELECT value FROM ' . $table . ' WHERE name=$1', ['version']);
if (!$result || pg_num_rows($result) !== 1 || (float)pg_fetch_result($result, 0, 0) !== (float)$version) {
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
pg_close($db);
