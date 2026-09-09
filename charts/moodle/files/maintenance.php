<?php
// SPDX-License-Identifier: Apache-2.0
require '/opt/helmforge/database.php';
$action = $argv[1] ?? 'checks';
$db = moodle_connection();
moodle_acquire_lifecycle_lock($db, time() + (int)moodle_settings()['database']['connectTimeout']);
function cli(array $args): void {
    $process = proc_open(array_merge([PHP_BINARY], $args), [0 => ['file', '/dev/null', 'r'], 1 => STDOUT, 2 => STDERR], $pipes);
    if (!is_resource($process) || proc_close($process) !== 0) {
        fwrite(STDERR, "Maintenance command did not succeed. Inspect logs before resuming service.\n"); exit(1);
    }
}
$dir = '/var/www/html/admin/cli/';
switch ($action) {
    case 'upgrade':
        // Backups and draining tasks are an explicit prerequisite, never inferred.
        cli([$dir . 'maintenance.php', '--enable']);
        cli([$dir . 'upgrade.php', '--non-interactive']);
        cli([$dir . 'purge_caches.php']);
        cli(['/opt/helmforge/metrics-configure.php']);
        echo "Upgrade completed; maintenance remains enabled until explicitly disabled.\n";
        break;
    case 'checks': cli([$dir . 'checks.php']); break;
    case 'purge-caches': cli([$dir . 'purge_caches.php']); break;
    case 'enable': cli([$dir . 'maintenance.php', '--enable']); break;
    case 'disable': cli([$dir . 'maintenance.php', '--disable']); break;
    default: fwrite(STDERR, "Unknown maintenance action\n"); exit(1);
}
moodle_db_close($db);
