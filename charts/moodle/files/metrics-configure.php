<?php
// SPDX-License-Identifier: Apache-2.0
$settings = json_decode(file_get_contents('/opt/helmforge/settings.json'), true, 512, JSON_THROW_ON_ERROR);
if (!$settings['metrics']['enabled']) { exit(0); }
define('CLI_SCRIPT', true);
require '/var/www/html/config.php';
$manager = \core\di::get(\tool_monitoring\local\metrics_manager::class);
$manager->sync();
foreach (['courses', 'overdue_tasks', 'quiz_attempts_in_progress', 'user_accounts', 'users_online'] as $name) {
    $metric = $manager['tool_monitoring_' . $name];
    if (in_array($name, $settings['metrics']['enabledMetrics'], true)) {
        $metric->enable();
    } else {
        $metric->disable();
    }
}
echo "Monitoring metrics configured through the upstream plugin API\n";
