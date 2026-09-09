<?php
// SPDX-License-Identifier: Apache-2.0
// Run with: php /opt/helmforge/smoke.php service-name service-port.
$settings = json_decode(file_get_contents('/opt/helmforge/settings.json'), true, 512, JSON_THROW_ON_ERROR);
$public = parse_url($settings['moodle']['wwwroot']);
$host = $public['host'] . (isset($public['port']) ? ':' . $public['port'] : '');
$base = 'http://' . ($argv[1] ?? '127.0.0.1') . ':' . ($argv[2] ?? '8080');
foreach (['/healthz.php' => "ok\n", '/readyz.php' => "ready\n", '/login/index.php' => null] as $path => $expected) {
    $curl = curl_init($base . $path);
    curl_setopt_array($curl, [CURLOPT_RETURNTRANSFER => true, CURLOPT_TIMEOUT => 20,
        CURLOPT_HTTPHEADER => ['Host: ' . $host]]);
    $body = curl_exec($curl);
    $status = curl_getinfo($curl, CURLINFO_HTTP_CODE);
    if ($status !== 200 || $body === false || str_contains($body, '<?php')) {
        throw new RuntimeException('HTTP execution check failed for ' . $path);
    }
    if ($expected !== null && $body !== $expected) {
        throw new RuntimeException('Unexpected health body for ' . $path);
    }
    if ($expected === null && (!str_contains($body, '<!DOCTYPE html>') || !str_contains($body, 'logintoken'))) {
        throw new RuntimeException('Login form was not rendered');
    }
    echo "$path: expected application response\n";
}
foreach (['/config.php', '/config-dist.php', '/admin/cli/install_database.php', '/settings.json'] as $path) {
    $curl = curl_init($base . $path);
    curl_setopt_array($curl, [CURLOPT_RETURNTRANSFER => true, CURLOPT_TIMEOUT => 10, CURLOPT_HTTPHEADER => ['Host: ' . $host]]);
    $body = curl_exec($curl);
    if ($body !== false && (str_contains($body, '<?php') || str_contains($body, 'DB_PASSWORD') || str_contains($body, '"existingSecret"'))) {
        throw new RuntimeException('Private configuration was exposed at ' . $path);
    }
}
if (is_writable('/var/www/html/config.php') || !is_writable('/var/moodledata')) {
    throw new RuntimeException('Filesystem immutability or data persistence mount failed');
}
echo "Private paths and filesystem permissions verified\n";
$credentials = json_decode(stream_get_contents(STDIN), true);
if (is_array($credentials) && isset($credentials['username'], $credentials['password'])) {
    $jar = tempnam('/tmp', 'moodle-smoke-');
    $request = function (string $path, ?array $form = null) use ($base, $host, $jar): array {
        $curl = curl_init($base . $path);
        curl_setopt_array($curl, [CURLOPT_RETURNTRANSFER => true, CURLOPT_TIMEOUT => 30,
            CURLOPT_HTTPHEADER => ['Host: ' . $host], CURLOPT_COOKIEJAR => $jar, CURLOPT_COOKIEFILE => $jar]);
        if ($form !== null) { curl_setopt($curl, CURLOPT_POSTFIELDS, http_build_query($form)); }
        $body = curl_exec($curl);
        $status = curl_getinfo($curl, CURLINFO_HTTP_CODE);
        curl_close($curl);
        return [$status, $body];
    };
    try {
        [$status, $login] = $request('/login/index.php');
        if ($status !== 200 || !preg_match('/name="logintoken" value="([^"]+)"/', $login, $token)) {
            throw new RuntimeException('Unable to obtain Moodle login token');
        }
        [$status] = $request('/login/index.php', ['username' => $credentials['username'],
            'password' => $credentials['password'], 'logintoken' => html_entity_decode($token[1])]);
        if (!in_array($status, [302, 303], true)) { throw new RuntimeException('Administrator login did not redirect'); }
        [$status, $dashboard] = $request('/my/');
        if ($status !== 200 || !str_contains($dashboard, 'data-userid="2"')) {
            throw new RuntimeException('Authenticated administrator dashboard not available');
        }
        echo "Administrator login and authenticated dashboard verified\n";
    } finally {
        unlink($jar);
    }
}
