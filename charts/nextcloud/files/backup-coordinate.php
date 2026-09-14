<?php
// SPDX-License-Identifier: Apache-2.0
declare(strict_types=1);
$namespace = getenv('POD_NAMESPACE');
$deployment = getenv('APP_DEPLOYMENT');
$owner = getenv('POD_UID');
$lock = '/var/www/html/.helmforge-backup-lock';
$token = trim(file_get_contents('/var/run/secrets/kubernetes.io/serviceaccount/token'));
$scalePath = '/apis/apps/v1/namespaces/' . rawurlencode($namespace) . '/deployments/' . rawurlencode($deployment) . '/scale';
function api(string $method, string $path, ?array $body = null): array {
    global $token;
    $curl = curl_init('https://kubernetes.default.svc' . $path);
    curl_setopt_array($curl, [CURLOPT_CUSTOMREQUEST => $method, CURLOPT_RETURNTRANSFER => true,
        CURLOPT_CONNECTTIMEOUT => 10, CURLOPT_TIMEOUT => 30,
        CURLOPT_CAINFO => '/var/run/secrets/kubernetes.io/serviceaccount/ca.crt',
        CURLOPT_HTTPHEADER => ['Authorization: Bearer ' . $token, 'Content-Type: application/json']]);
    if ($body !== null) curl_setopt($curl, CURLOPT_POSTFIELDS, json_encode($body, JSON_THROW_ON_ERROR));
    $response = curl_exec($curl);
    $status = curl_getinfo($curl, CURLINFO_RESPONSE_CODE);
    if ($response === false || $status < 200 || $status >= 300) {
        throw new RuntimeException('Kubernetes ' . $method . ' failed with HTTP ' . $status . '; backup remains locked for recovery');
    }
    return json_decode($response, true, 512, JSON_THROW_ON_ERROR);
}
function scale(int $from, int $to): void {
    global $scalePath;
    $state = api('GET', $scalePath);
    // The scale API omits the zero-valued replicas field in its JSON response.
    if (($state['spec']['replicas'] ?? 0) !== $from) throw new RuntimeException('Unexpected application replica count; refusing to change it');
    $state['spec']['replicas'] = $to;
    // resourceVersion guards against a concurrent operator/GitOps update.
    api('PUT', $scalePath, $state);
}
if ($argv[1] === 'stop') {
    if (!mkdir($lock, 0700)) throw new RuntimeException('Another backup or failed snapshot owns the volume lock');
    file_put_contents($lock . '/owner', $owner, LOCK_EX);
    file_put_contents('/work/backup-id', gmdate('Ymd\THis\Z') . '-' . $owner);
    $selector = rawurlencode('app.kubernetes.io/instance=' . getenv('RELEASE_NAME') . ',app.kubernetes.io/component=app');
    $podPath = '/api/v1/namespaces/' . rawurlencode($namespace) . '/pods?labelSelector=' . $selector;
    $writers = api('GET', $podPath)['items'];
    if (count($writers) !== 1 || isset($writers[0]['metadata']['deletionTimestamp'])) {
        throw new RuntimeException('Backup requires one stable application Pod');
    }
    $writerUid = $writers[0]['metadata']['uid'];
    $needsCron = in_array('cron', array_column($writers[0]['spec']['containers'], 'name'), true);
    scale(1, 0);
    $deadline = time() + (int)getenv('QUIESCE_TIMEOUT');
    do {
        $pods = api('GET', $podPath);
        if (count($pods['items']) === 0) {
            foreach ($needsCron ? ['web', 'cron'] : ['web'] as $writer) {
                $proof = '/var/www/html/.helmforge-quiescence/' . $writerUid . '/' . $writer;
                if (!is_file($proof) || trim(file_get_contents($proof)) !== 'graceful') {
                    throw new RuntimeException('Missing graceful shutdown evidence for ' . $writer . '; refusing snapshot');
                }
            }
            file_put_contents($lock . '/quiesced', gmdate(DATE_ATOM));
            echo "Application and cron terminated; snapshot may begin\n";
            exit(0);
        }
        sleep(2);
    } while (time() < $deadline);
    throw new RuntimeException('Application did not stop before the deadline; fail closed and inspect the backup Job');
}
if ($argv[1] !== 'resume') throw new RuntimeException('Expected stop or resume');
if (!is_file($lock . '/quiesced') || trim(file_get_contents($lock . '/owner')) !== $owner) {
    throw new RuntimeException('Backup ownership mismatch; refusing to resume');
}
scale(0, 1);
unlink($lock . '/quiesced');
unlink($lock . '/owner');
rmdir($lock);
echo "Snapshot captured; application replicas restored\n";
