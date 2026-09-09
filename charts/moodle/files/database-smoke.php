<?php
// SPDX-License-Identifier: Apache-2.0
// Lab-only checks for native driver selection and connection-scoped lifecycle locking.
require '/opt/helmforge/database.php';
$first = moodle_connection();
$second = moodle_connection();
moodle_acquire_lifecycle_lock($first, time());
$blocked = false;
try { moodle_acquire_lifecycle_lock($second, time()); }
catch (RuntimeException $e) { $blocked = str_contains($e->getMessage(), 'installer lock'); }
if (!$blocked) { throw new RuntimeException('Concurrent lifecycle connection acquired the same lock'); }
moodle_db_close($first);
moodle_acquire_lifecycle_lock($second, time());
moodle_db_close($second);
define('CLI_SCRIPT', true);
require '/var/www/html/config.php';
$type = moodle_settings()['database']['type'];
$expected = ['postgresql' => 'pgsql', 'mysql' => 'mysqli', 'mariadb' => 'mariadb'][$type];
if ($CFG->dbtype !== $expected || get_class($DB) !== $expected . '_native_moodle_database') {
    throw new RuntimeException('Unexpected Moodle database driver');
}
if ($type !== 'postgresql' && moodle_settings()['database']['mysqlSslMode'] !== 'disable') {
    $cipher = (array)$DB->get_record_sql("SHOW SESSION STATUS LIKE 'Ssl_cipher'");
    if (empty(array_values($cipher)[1])) { throw new RuntimeException('Native Moodle connection is not encrypted'); }
}
echo "Database $type: native driver, exclusive lifecycle locking and release verified\n";
