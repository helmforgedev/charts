<?php
// SPDX-License-Identifier: Apache-2.0
function moodle_check_metrics($db): void {
    $enabled = moodle_settings()['metrics']['enabled'];
    $paths = [
        'tool_monitoring' => '/var/www/html/public/admin/tool/monitoring/version.php',
        'monitoringexporter_prometheus' => '/var/www/html/public/admin/tool/monitoring/exporter/prometheus/version.php',
    ];
    foreach ($paths as $component => $path) {
        $installed = moodle_scalar($db, 'SELECT value FROM ' . moodle_table('config_plugins') .
            ' WHERE plugin=? AND name=?', [$component, 'version']);
        if (!$enabled) {
            if ($installed !== null) {
                throw new RuntimeException('Monitoring plugin remains installed. Keep metrics.enabled=true; disable only its ServiceMonitor or uninstall the plugin during maintenance first.');
            }
            continue;
        }
        $plugin = new stdClass();
        require $path;
        if ($installed === null || (int)$installed !== (int)$plugin->version) {
            throw new RuntimeException('Monitoring plugin database/code version mismatch. Run the explicit maintenance upgrade before starting web workloads.');
        }
    }
}
