<?php
// SPDX-License-Identifier: Apache-2.0
declare(strict_types=1);
// Executed only by the chart's local-lab runtime acceptance script.
$user = getenv('NEXTCLOUD_ADMIN_USER');
$password = getenv('NEXTCLOUD_ADMIN_PASSWORD');
function http(string $method, string $path, string $body = ''): array {
    global $user, $password;
    $curl = curl_init('http://127.0.0.1:8080' . $path);
    curl_setopt_array($curl, [CURLOPT_CUSTOMREQUEST => $method, CURLOPT_RETURNTRANSFER => true,
        CURLOPT_USERPWD => $user . ':' . $password, CURLOPT_POSTFIELDS => $body,
        CURLOPT_HTTPHEADER => ['OCS-APIRequest: true', 'Accept: application/json'],
        CURLOPT_TIMEOUT => 30]);
    $response = curl_exec($curl);
    if ($response === false) throw new RuntimeException(curl_error($curl));
    return [curl_getinfo($curl, CURLINFO_RESPONSE_CODE), $response];
}
function readBytes($socket, int $size): string {
    $data = '';
    while (strlen($data) < $size) {
        $chunk = fread($socket, $size - strlen($data));
        if ($chunk === false || $chunk === '') throw new RuntimeException('WebSocket closed or timed out');
        $data .= $chunk;
    }
    return $data;
}
function sendFrame($socket, string $data, int $opcode = 1): void {
    $length = strlen($data);
    if ($length > 65535) throw new RuntimeException('Acceptance frame too large');
    $mask = random_bytes(4);
    $header = chr(128 | $opcode) . ($length < 126 ? chr(128 | $length) : chr(254) . pack('n', $length));
    $masked = '';
    for ($i = 0; $i < $length; $i++) $masked .= $data[$i] ^ $mask[$i % 4];
    if (fwrite($socket, $header . $mask . $masked) !== strlen($header . $mask . $masked)) {
        throw new RuntimeException('Incomplete WebSocket write');
    }
}
function receiveFrame($socket): string {
    while (true) {
        $header = readBytes($socket, 2);
        $opcode = ord($header[0]) & 15;
        $length = ord($header[1]) & 127;
        if ($length === 126) $length = unpack('n', readBytes($socket, 2))[1];
        if ($length === 127) throw new RuntimeException('Unexpected large WebSocket frame');
        $body = readBytes($socket, $length);
        if ($opcode === 9) { sendFrame($socket, $body, 10); continue; }
        if ($opcode !== 1) throw new RuntimeException('Unexpected WebSocket opcode');
        return $body;
    }
}
// Apache workers may briefly retain capabilities from before the app was enabled.
$discovered = false;
for ($attempt = 0; $attempt < 20; $attempt++) {
    [$code, $body] = http('GET', '/ocs/v2.php/cloud/capabilities?format=json');
    $endpoint = json_decode($body, true, 512, JSON_THROW_ON_ERROR)['ocs']['data']['capabilities']['notify_push']['endpoints']['websocket'] ?? '';
    if ($code === 200 && str_ends_with($endpoint, '/push/ws')) { $discovered = true; break; }
    sleep(2);
}
if (!$discovered) throw new RuntimeException('Push capability missing after app setup');
$socket = null;
$authenticationResponse = '';
for ($attempt = 0; $attempt < 10; $attempt++) {
    $candidate = fsockopen('127.0.0.1', 8080, $errno, $error, 10);
    if ($candidate === false) throw new RuntimeException('Unable to connect to Apache');
    stream_set_timeout($candidate, 30);
    fwrite($candidate, "GET /push/ws HTTP/1.1\r\nHost: 127.0.0.1\r\nUpgrade: websocket\r\nConnection: Upgrade\r\nSec-WebSocket-Version: 13\r\nSec-WebSocket-Key: dGhlIHNhbXBsZSBub25jZQ==\r\n\r\n");
    if (!str_contains(fgets($candidate), '101')) throw new RuntimeException('Apache WebSocket upgrade failed');
    while (($line = fgets($candidate)) !== "\r\n") {
        if ($line === false) throw new RuntimeException('Incomplete upgrade headers');
    }
    sendFrame($candidate, $user);
    sendFrame($candidate, $password);
    $authenticationResponse = receiveFrame($candidate);
    if ($authenticationResponse === 'authenticated') {
        $socket = $candidate;
        break;
    }
    fclose($candidate);
    if ($attempt < 9) sleep(2);
}
if ($socket === null) throw new RuntimeException('Push authentication failed after bounded retries: ' . $authenticationResponse);
$path = '/remote.php/dav/files/' . rawurlencode($user) . '/push-smoke-' . bin2hex(random_bytes(6)) . '.txt';
try {
    [$code] = http('PUT', $path, 'Client Push acceptance');
    if ($code !== 201) throw new RuntimeException('Push test upload failed');
    $received = false;
    for ($attempt = 0; $attempt < 8; $attempt++) {
        if (receiveFrame($socket) === 'notify_file') { $received = true; break; }
    }
    if (!$received) throw new RuntimeException('No file-change notification received');
    echo "Authenticated WebSocket received notify_file after a real WebDAV upload\n";
} finally {
    http('DELETE', $path);
    fclose($socket);
}
