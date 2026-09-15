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
if ($action !== 'verify') {
    request('/teams', 'POST', ['teamId' => 'helmforgeteam', 'name' => 'HelmForge team'], 201);
    request('/projects', 'POST', ['projectId' => 'helmforgeproject', 'name' => 'HelmForge project', 'teamId' => 'helmforgeteam'], 201);
}
check(request('/projects/helmforgeproject')['name'] === 'HelmForge project', 'Persisted project missing');
$marker = '/storage/builds/helmforge-upstream-fixture.json';
if ($action !== 'verify') {
    request('/account/prefs', 'PATCH', ['prefs' => ['upgrade' => 'retained-1.9.6-to-2.2.0']]);
    $iv = random_bytes(12);
    $cipher = openssl_encrypt('retained-build-artifact', 'aes-256-gcm', getenv('_APP_OPENSSL_KEY_V1'), OPENSSL_RAW_DATA, $iv, $tag);
    file_put_contents($marker, json_encode(['iv'=>base64_encode($iv),'tag'=>base64_encode($tag),'cipher'=>base64_encode($cipher)]));
}
check(request('/account/prefs')['upgrade'] === 'retained-1.9.6-to-2.2.0', 'Account preferences not retained');
$stored = json_decode(file_get_contents($marker), true, flags: JSON_THROW_ON_ERROR);
check(openssl_decrypt(base64_decode($stored['cipher']), 'aes-256-gcm', getenv('_APP_OPENSSL_KEY_V1'), OPENSSL_RAW_DATA, base64_decode($stored['iv']), base64_decode($stored['tag'])) === 'retained-build-artifact', 'Build fixture or encryption key changed');
if (version_compare($version, '2.1.0', '>=')) {
    $key = request('/projects/helmforgeproject/keys', 'POST', [
        'keyId' => 'unique()', 'name' => 'HelmForge S3 fixture',
        'scopes' => array_merge(['buckets.read', 'buckets.write', 'files.read', 'files.write'], version_compare($version, '2.2.0', '>=') ? ['project.policies.read', 'project.policies.write'] : []),
    ], 201);
    if (version_compare($version, '2.2.0', '>=')) {
        $projectRequest = function ($route, $method = 'GET', $data = null) use ($key) {
            $curl = curl_init('http://127.0.0.1/v1'.$route);
            curl_setopt_array($curl, [CURLOPT_RETURNTRANSFER => true, CURLOPT_TIMEOUT => 30,
                CURLOPT_CUSTOMREQUEST => $method,
                CURLOPT_HTTPHEADER => ['Content-Type: application/json', 'Host: '.getenv('_APP_DOMAIN'),
                    'X-Appwrite-Project: helmforgeproject', 'X-Appwrite-Key: '.$key['secret']],
            ]);
            if ($data !== null) { curl_setopt($curl, CURLOPT_POSTFIELDS, json_encode($data)); }
            $response = curl_exec($curl);
            $status = curl_getinfo($curl, CURLINFO_RESPONSE_CODE);
            curl_close($curl);
            check($status === 200, "Project policy $method $route returned $status: $response");
            return json_decode($response, true, flags: JSON_THROW_ON_ERROR);
        };
        $projectRequest('/project/policies/deny-free-email', 'PATCH', ['enabled' => true]);
        $policies = $projectRequest('/project/policies');
        $matching = array_values(array_filter($policies['policies'], fn ($policy) => $policy['$id'] === 'deny-free-email'));
        check(count($matching) === 1 && $matching[0]['enabled'] === true, 'Self-hosted email policy was not retained');
        $projectRequest('/project/policies/deny-free-email', 'PATCH', ['enabled' => false]);
        echo "PASS: Self-hosted email policy update and persisted policy list.\n";
    }
    $signed = function ($path, $method, $body = '', $expected = 200) use ($key) {
        $curl = curl_init('http://127.0.0.1/v1/s3'.$path);
        curl_setopt_array($curl, [CURLOPT_RETURNTRANSFER => true, CURLOPT_TIMEOUT => 30,
            CURLOPT_CUSTOMREQUEST => $method, CURLOPT_AWS_SIGV4 => 'aws:amz:us-east-1:s3',
            CURLOPT_USERPWD => 'helmforgeproject:'.$key['secret'],
            CURLOPT_HTTPHEADER => ['Host: '.getenv('_APP_DOMAIN'), 'x-amz-content-sha256: '.hash('sha256', $body)],
        ]);
        if ($method === 'PUT') { curl_setopt($curl, CURLOPT_POSTFIELDS, $body); }
        $response = curl_exec($curl);
        $status = curl_getinfo($curl, CURLINFO_RESPONSE_CODE);
        curl_close($curl);
        check($status === $expected, "Signed S3 $method $path returned $status: $response");
        return $response;
    };
    $bucket = '/helmforge-s3-fixture';
    $signed($bucket, 'PUT');
    $signed($bucket.'/retained.txt', 'PUT', 'Appwrite S3 exact fixture bytes');
    check($signed($bucket.'/retained.txt', 'GET') === 'Appwrite S3 exact fixture bytes', 'S3 payload mismatch');
    $signed($bucket.'/retained.txt', 'DELETE', expected: 204);
    $signed($bucket, 'DELETE', expected: 204);
    request('/projects/helmforgeproject/keys/'.$key['$id'], 'DELETE', expected: 204);
    echo "PASS: Signed S3 bucket/object creation, exact download and deletion.\n";
}
// The old 1.9.6 queue publisher has a known NOAUTH logout bug; creation retains
// the upgrade fixture, while every new-version smoke and verify checks logout.
if ($action !== 'create') { request('/account/sessions/current', 'DELETE', expected: 204); }
if ($action === 'smoke') { unlink($marker); }
echo "PASS: Appwrite $version health, anonymous account denial, account/login/project/preferences, persistent builds mount and retained encryption fixture.\n";
