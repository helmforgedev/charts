<?php
// SPDX-License-Identifier: Apache-2.0
[$unused, $version, $action] = $argv;
function check($condition, $message) { if (!$condition) { throw new RuntimeException($message); } }
$client = curl_init();
curl_setopt_array($client, [CURLOPT_RETURNTRANSFER => true, CURLOPT_COOKIEFILE => '', CURLOPT_TIMEOUT => 30]);
function request($route, $method = 'GET', $data = null, $expected = 200) {
    global $client;
    curl_setopt_array($client, [CURLOPT_URL => 'http://127.0.0.1/v1'.$route, CURLOPT_CUSTOMREQUEST => $method,
        CURLOPT_HTTPHEADER => ['Content-Type: application/json', 'X-Appwrite-Project: console', 'Host: '.getenv('_APP_DOMAIN')]]);
    curl_setopt($client, CURLOPT_POSTFIELDS, $data === null ? null : json_encode($data));
    $body = curl_exec($client);
    $code = curl_getinfo($client, CURLINFO_RESPONSE_CODE);
    check($code === $expected, "$method $route returned $code: $body");
    return $body === '' ? null : json_decode($body, true, flags: JSON_THROW_ON_ERROR);
}
check(request('/health/version')['version'] === $version, 'Running version mismatch');
request('/account', expected: 401);
$id = 'helmforgefixture';
$email = 'helmforge-runtime@example.invalid';
$password = 'HelmForge-runtime-fixture-2026!';
if ($action !== 'verify') {
    request('/account', 'POST', ['userId' => $id, 'email' => $email, 'password' => $password, 'name' => 'HelmForge fixture'], 201);
}
request('/account/sessions/email', 'POST', ['email' => $email, 'password' => $password], 201);
check(request('/account')['$id'] === $id, 'Persisted account missing');
$marker = '/storage/builds/helmforge-upstream-fixture.json';
if ($action !== 'verify') {
    request('/account/prefs', 'PATCH', ['prefs' => ['upgrade' => 'retained-1.9.6-to-2.0.0']]);
    $iv = random_bytes(12);
    $cipher = openssl_encrypt('retained-build-artifact', 'aes-256-gcm', getenv('_APP_OPENSSL_KEY_V1'), OPENSSL_RAW_DATA, $iv, $tag);
    file_put_contents($marker, json_encode(['iv'=>base64_encode($iv),'tag'=>base64_encode($tag),'cipher'=>base64_encode($cipher)]));
}
check(request('/account/prefs')['upgrade'] === 'retained-1.9.6-to-2.0.0', 'Account preferences not retained');
$stored = json_decode(file_get_contents($marker), true, flags: JSON_THROW_ON_ERROR);
check(openssl_decrypt(base64_decode($stored['cipher']), 'aes-256-gcm', getenv('_APP_OPENSSL_KEY_V1'), OPENSSL_RAW_DATA, base64_decode($stored['iv']), base64_decode($stored['tag'])) === 'retained-build-artifact', 'Build fixture or encryption key changed');
request('/account/sessions/current', 'DELETE', expected: 204);
if ($action === 'smoke') { unlink($marker); }
echo "PASS: Appwrite $version health, anonymous account denial, account/login/preferences, persistent builds mount and retained encryption fixture.\n";
