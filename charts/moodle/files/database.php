<?php
// SPDX-License-Identifier: Apache-2.0
function moodle_settings(): array {
    return json_decode(file_get_contents('/opt/helmforge/settings.json'), true, 512, JSON_THROW_ON_ERROR);
}
function moodle_connection() {
    $settings = moodle_settings()['database'];
    if ($settings['type'] !== 'postgresql') {
        mysqli_report(MYSQLI_REPORT_ERROR | MYSQLI_REPORT_STRICT);
        $db = mysqli_init();
        $db->options(MYSQLI_OPT_CONNECT_TIMEOUT, 5);
        $db->options(MYSQLI_OPT_READ_TIMEOUT, 5);
        $mode = $settings['mysqlSslMode'];
        $flags = 0;
        if ($mode !== 'disable') {
            $ca = $settings['tlsSecret'] !== '' ? '/opt/database-tls/ca.crt' : null;
            $db->ssl_set(null, null, $ca, null, null);
            $db->options(MYSQLI_OPT_SSL_VERIFY_SERVER_CERT, $mode === 'verify-full');
            $flags = MYSQLI_CLIENT_SSL | ($mode === 'verify-full'
                ? MYSQLI_CLIENT_SSL_VERIFY_SERVER_CERT : MYSQLI_CLIENT_SSL_DONT_VERIFY_SERVER_CERT);
        }
        try {
            $db->real_connect(getenv('DB_HOST'), getenv('DB_USER'), getenv('DB_PASSWORD'),
                getenv('DB_NAME'), (int)getenv('DB_PORT'), null, $flags);
            $db->set_charset('utf8mb4');
            if ($mode !== 'disable') {
                $cipher = $db->query("SHOW SESSION STATUS LIKE 'Ssl_cipher'")->fetch_row();
                if (empty($cipher[1])) { throw new RuntimeException('Database connection is not encrypted'); }
            }
        } catch (Throwable $e) {
            throw new RuntimeException('MySQL/MariaDB connection or TLS verification unavailable');
        }
        return $db;
    }
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
    if (!preg_match('/^[a-z_]+$/D', $suffix)) { throw new RuntimeException('Invalid table suffix'); }
    $quote = moodle_settings()['database']['type'] === 'postgresql' ? '"' : '`';
    return $quote . $prefix . $suffix . $quote;
}
function moodle_scalar($db, string $sql, array $params = []) {
    if ($db instanceof mysqli) {
        $statement = $db->prepare($sql);
        $statement->execute($params);
        $row = $statement->get_result()->fetch_row();
        $statement->close();
        return $row[0] ?? null;
    }
    $index = 0;
    $sql = preg_replace_callback('/\?/', function () use (&$index) { return '$' . ++$index; }, $sql);
    $result = pg_query_params($db, $sql, $params);
    if (!$result) { throw new RuntimeException('Database query failed'); }
    return pg_num_rows($result) > 0 ? pg_fetch_result($result, 0, 0) : null;
}
function moodle_has_config_table($db): bool {
    if ($db instanceof mysqli) {
        return (int)moodle_scalar($db,
            'SELECT COUNT(*) FROM information_schema.tables WHERE table_schema=DATABASE() AND table_name=?',
            [moodle_settings()['database']['prefix'] . 'config']) === 1;
    }
    return moodle_scalar($db, 'SELECT to_regclass(?)', [moodle_table('config')]) !== null;
}
function moodle_acquire_lifecycle_lock($db, int $deadline): void {
    do {
        // Same namespace for installation and maintenance; held on this connection until close.
        $locked = $db instanceof mysqli
            ? moodle_scalar($db, 'SELECT GET_LOCK(?, 0)', ['helmforge-moodle:' . substr(hash('sha256', getenv('DB_NAME')), 0, 40)])
            : moodle_scalar($db, 'SELECT pg_try_advisory_lock(741932, hashtext(current_database()))');
        if ($locked === 't' || (string)$locked === '1') { return; }
        if (time() >= $deadline) { throw new RuntimeException('Timed out waiting for Moodle installer lock'); }
        sleep(3);
    } while (true);
}
function moodle_db_close($db): void {
    if ($db instanceof mysqli) { $db->close(); } else { pg_close($db); }
}
