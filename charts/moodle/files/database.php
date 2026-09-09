<?php
// SPDX-License-Identifier: Apache-2.0
function moodle_settings(): array {
    return json_decode(file_get_contents('/opt/helmforge/settings.json'), true, 512, JSON_THROW_ON_ERROR);
}
function moodle_connection() {
    $settings = moodle_settings()['database'];
    $params = [
        'host' => getenv('DB_HOST'), 'port' => getenv('DB_PORT'),
        'dbname' => getenv('DB_NAME'), 'user' => getenv('DB_USER'),
        'password' => getenv('DB_PASSWORD'), 'connect_timeout' => '5',
        'sslmode' => $settings['sslMode'],
    ];
    if ($settings['tlsSecret'] !== '') {
        $params['sslrootcert'] = '/opt/database-tls/ca.crt';
    }
    $parts = [];
    foreach ($params as $key => $value) {
        $parts[] = $key . "='" . str_replace(['\\', "'"], ['\\\\', "\\'"], (string)$value) . "'";
    }
    $db = @pg_connect(implode(' ', $parts), PGSQL_CONNECT_FORCE_NEW);
    if (!$db) {
        throw new RuntimeException('PostgreSQL connection unavailable');
    }
    return $db;
}
function moodle_table(string $suffix): string {
    $prefix = moodle_settings()['database']['prefix'];
    if (!preg_match('/^[a-zA-Z][a-zA-Z0-9_]{0,9}$/D', $prefix)) {
        throw new RuntimeException('Invalid database prefix');
    }
    return '"' . $prefix . $suffix . '"';
}
