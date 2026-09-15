<?php
// SPDX-License-Identifier: Apache-2.0
declare(strict_types=1);
$settings = json_decode(file_get_contents('/opt/helmforge/settings.json'), true, 512, JSON_THROW_ON_ERROR);
$base = 'http://' . $argv[1] . ':' . $argv[2];
$host = $settings['trustedDomains'][0];
$user = getenv('NEXTCLOUD_ADMIN_USER');
$password = getenv('NEXTCLOUD_ADMIN_PASSWORD');
function request(string $method, string $path, ?string $credentials = null, string $body = '', array $extra = []): array {
    global $base, $host;
    $curl = curl_init($base . $path);
    curl_setopt_array($curl, [CURLOPT_CUSTOMREQUEST => $method, CURLOPT_RETURNTRANSFER => true,
        CURLOPT_CONNECTTIMEOUT => 10, CURLOPT_TIMEOUT => 90,
        CURLOPT_HTTPHEADER => array_merge(['Host: ' . $host], $extra),
        CURLOPT_POSTFIELDS => $body]);
    if ($credentials !== null) curl_setopt($curl, CURLOPT_USERPWD, $credentials);
    $content = curl_exec($curl);
    if ($content === false) throw new RuntimeException(curl_error($curl));
    return [curl_getinfo($curl, CURLINFO_RESPONSE_CODE), $content];
}
function expect(bool $condition, string $message): void {
    if (!$condition) throw new RuntimeException($message);
    echo $message . " OK\n";
}
[$code, $body] = request('GET', '/status.php');
$status = json_decode($body, true, 512, JSON_THROW_ON_ERROR);
expect($code === 200 && $status['installed'] && !$status['maintenance'] && !$status['needsDbUpgrade'], 'Initialized application status');
[$code, $body] = request('GET', '/login');
expect($code === 200 && stripos($body, 'nextcloud') !== false && !str_contains($body, '<?php'), 'PHP-rendered login page');
[$code] = request('GET', '/config/config.php');
expect(in_array($code, [403, 404], true), 'Native configuration denied over HTTP');
$validHost = $host;
$host = 'untrusted.helmforge.invalid';
[$code] = request('GET', '/login');
expect($code === 400, 'Untrusted Host rejected');
$host = $validHost;
$auth = $user . ':' . $password;
$path = '/remote.php/dav/files/' . rawurlencode($user) . '/';
[$code] = request('PROPFIND', $path, $auth, '', ['Depth: 0']);
expect($code === 207, 'Authenticated WebDAV listing');
$name = 'helmforge-smoke-' . bin2hex(random_bytes(5));
$folder = $path . $name . '/';
$payload = "HelmForge Nextcloud\n" . random_bytes(256);
try {
    [$code] = request('MKCOL', $folder, $auth);
    expect($code === 201, 'WebDAV folder creation');
    [$code] = request('PUT', $folder . 'payload.bin', $auth, $payload, ['Content-Type: application/octet-stream']);
    expect($code === 201, 'WebDAV binary upload');
    [$code, $body] = request('GET', $folder . 'payload.bin', $auth);
    expect($code === 200 && hash_equals(hash('sha256', $payload), hash('sha256', $body)), 'WebDAV content checksum');
    [$code] = request('GET', $folder . 'payload.bin');
    expect($code === 401, 'Unauthenticated file access rejected');
    $runtime = json_decode(file_get_contents('/opt/helmforge/runtime-settings.json'), true, 512, JSON_THROW_ON_ERROR);
    if ($runtime['imaginary']['enabled']) {
        $image = imagecreatetruecolor(64, 64);
        imagefill($image, 0, 0, imagecolorallocate($image, 35, 120, 200));
        ob_start();
        imagepng($image);
        $png = ob_get_clean();
        [$code] = request('PUT', $folder . 'preview.png', $auth, $png, ['Content-Type: image/png']);
        expect($code === 201, 'Preview source uploaded');
        [$code, $body] = request('PROPFIND', $folder . 'preview.png', $auth,
            '<?xml version="1.0"?><d:propfind xmlns:d="DAV:" xmlns:oc="http://owncloud.org/ns"><d:prop><oc:fileid/></d:prop></d:propfind>',
            ['Depth: 0', 'Content-Type: application/xml']);
        $xml = simplexml_load_string($body);
        $xml->registerXPathNamespace('oc', 'http://owncloud.org/ns');
        $ids = $xml->xpath('//oc:fileid');
        expect($code === 207 && count($ids) === 1, 'Preview file identity resolved');
        [$code, $body] = request('GET', '/index.php/core/preview?fileId=' . (string)$ids[0] . '&x=32&y=32', $auth);
        $dimensions = @getimagesizefromstring($body);
        expect($code === 200 && $dimensions !== false && $dimensions[0] > 0, 'Native Imaginary preview generated');
    }
} finally {
    [$code] = request('DELETE', $folder, $auth);
    expect($code === 204, 'WebDAV folder deletion');
}
[$code] = request('PROPFIND', $path, $user . ':invalid-' . bin2hex(random_bytes(12)), '', ['Depth: 0']);
expect($code === 401, 'Incorrect password rejected');
