<?php
// SPDX-License-Identifier: Apache-2.0
declare(strict_types=1);
$input = json_decode(stream_get_contents(STDIN), true, 512, JSON_THROW_ON_ERROR);
$settings = json_decode(file_get_contents('/opt/helmforge/settings.json'), true, 512, JSON_THROW_ON_ERROR);
$mode = $argv[1];
$user = $input['user'];
$password = $input['password'];
$payload = base64_decode($input['payload'], true);
function occ(array $args, array $env = []): string {
    $process = proc_open(array_merge(['php', '/var/www/html/occ'], $args),
        [0 => ['pipe', 'r'], 1 => ['pipe', 'w'], 2 => ['pipe', 'w']], $pipes, null, array_merge(getenv(), $env));
    fclose($pipes[0]);
    $out = stream_get_contents($pipes[1]);
    $error = stream_get_contents($pipes[2]);
    fclose($pipes[1]); fclose($pipes[2]);
    if (proc_close($process) !== 0) throw new RuntimeException('Nextcloud CLI operation failed: ' . $error);
    return $out;
}
function request(string $method, string $path, int $expected, string $body = '', array $headers = []): string {
    global $user, $password, $settings;
    $curl = curl_init('http://127.0.0.1:8080' . $path);
    curl_setopt_array($curl, [CURLOPT_CUSTOMREQUEST => $method, CURLOPT_RETURNTRANSFER => true,
        CURLOPT_USERPWD => $user . ':' . $password, CURLOPT_TIMEOUT => 90,
        CURLOPT_HTTPHEADER => array_merge(['Host: ' . $settings['trustedDomains'][0]], $headers), CURLOPT_POSTFIELDS => $body]);
    $result = curl_exec($curl);
    $code = curl_getinfo($curl, CURLINFO_RESPONSE_CODE);
    if ($result === false || $code !== $expected) throw new RuntimeException($method . ' recovery request failed: ' . $code);
    return $result;
}
$path = '/remote.php/dav/files/' . rawurlencode($user) . '/recovery-proof.bin';
if ($mode === 'seed') {
    occ(['user:add', '--password-from-env', $user], ['OC_PASS' => $password]);
    occ(['config:app:set', 'helmforge', 'recovery-proof', '--value=' . hash('sha256', $payload)]);
    request('PUT', $path, 201, $payload, ['Content-Type: application/octet-stream']);
    $share = json_decode(request('POST', '/ocs/v2.php/apps/files_sharing/api/v1/shares?format=json', 200,
        http_build_query(['path' => '/recovery-proof.bin', 'shareType' => 3, 'permissions' => 1]),
        ['OCS-APIRequest: true', 'Content-Type: application/x-www-form-urlencoded']), true, 512, JSON_THROW_ON_ERROR);
    if (!isset($share['ocs']['data']['id'])) throw new RuntimeException('Public share was not created');
    $input['shareId'] = (string)$share['ocs']['data']['id'];
} elseif ($mode !== 'verify') {
    throw new RuntimeException('Expected seed or verify');
}
$xml = request('PROPFIND', $path, 207,
    '<?xml version="1.0"?><d:propfind xmlns:d="DAV:" xmlns:oc="http://owncloud.org/ns"><d:prop><oc:fileid/></d:prop></d:propfind>',
    ['Depth: 0', 'Content-Type: application/xml']);
if (!preg_match('/<oc:fileid>([0-9]+)<\/oc:fileid>/', $xml, $match)) throw new RuntimeException('WebDAV file ID missing');
$bytes = request('GET', $path, 200);
if (!hash_equals(hash('sha256', $payload), hash('sha256', $bytes))) throw new RuntimeException('Restored file checksum differs');
if ($mode === 'seed') {
    $input['fileId'] = $match[1];
    echo json_encode($input, JSON_THROW_ON_ERROR);
    exit(0);
}
if ($match[1] !== $input['fileId']) throw new RuntimeException('Restored file identity differs');
if (trim(occ(['config:app:get', 'helmforge', 'recovery-proof'])) !== hash('sha256', $payload)) throw new RuntimeException('Application configuration was not restored');
$share = json_decode(request('GET', '/ocs/v2.php/apps/files_sharing/api/v1/shares/' . rawurlencode($input['shareId']) . '?format=json', 200, '', ['OCS-APIRequest: true']), true, 512, JSON_THROW_ON_ERROR);
if ((string)($share['ocs']['data'][0]['id'] ?? '') !== $input['shareId']) throw new RuntimeException('Share was not restored');
request('PUT', $path . '.new', 201, 'post-restore-write');
request('DELETE', $path . '.new', 204);
echo "Restored non-admin login, file checksum, file ID, share, configuration and new writes verified\n";
