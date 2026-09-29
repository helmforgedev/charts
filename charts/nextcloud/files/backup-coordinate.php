<?php
// SPDX-License-Identifier: Apache-2.0
declare(strict_types=1);
$namespace = getenv('POD_NAMESPACE');
$deployment = getenv('APP_DEPLOYMENT');
$cronName = getenv('CRON_JOB');
$cronEnabled = getenv('CRON_ENABLED') === 'true';
$owner = getenv('POD_UID');
$lock = '/var/www/html/.helmforge-backup-lock';
$token = trim(file_get_contents('/var/run/secrets/kubernetes.io/serviceaccount/token'));
$scalePath = '/apis/apps/v1/namespaces/' . rawurlencode($namespace) . '/deployments/' . rawurlencode($deployment) . '/scale';
function api(string $method, string $path, ?array $body = null, string $contentType = 'application/json'): array {
    global $token;
    $curl = curl_init('https://kubernetes.default.svc' . $path);
    curl_setopt_array($curl, [CURLOPT_CUSTOMREQUEST => $method, CURLOPT_RETURNTRANSFER => true,
        CURLOPT_CONNECTTIMEOUT => 10, CURLOPT_TIMEOUT => 30,
        CURLOPT_CAINFO => '/var/run/secrets/kubernetes.io/serviceaccount/ca.crt',
        CURLOPT_HTTPHEADER => ['Authorization: Bearer ' . $token, 'Content-Type: ' . $contentType]]);
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
function setCronSuspended(bool $suspended): void {
    global $namespace, $cronName;
    $path = '/apis/batch/v1/namespaces/' . rawurlencode($namespace) . '/cronjobs/' . rawurlencode($cronName);
    api('PATCH', $path, ['spec' => ['suspend' => $suspended]], 'application/merge-patch+json');
}
function cronJobsSettled(): bool {
    global $namespace;
    $selector = rawurlencode('app.kubernetes.io/instance=' . getenv('RELEASE_NAME') . ',app.kubernetes.io/component=cron');
    $path = '/apis/batch/v1/namespaces/' . rawurlencode($namespace) . '/jobs?labelSelector=' . $selector;
    foreach (api('GET', $path)['items'] as $job) {
        $terminal = false;
        foreach ($job['status']['conditions'] ?? [] as $condition) {
            if (($condition['status'] ?? '') === 'True' && in_array($condition['type'] ?? '', ['Complete', 'Failed'], true)) {
                $terminal = true;
                break;
            }
        }
        if (!$terminal) return false;
    }
    return true;
}
if ($argv[1] === 'stop') {
    if (!mkdir($lock, 0700)) throw new RuntimeException('Another backup or failed snapshot owns the volume lock');
    file_put_contents($lock . '/owner', $owner, LOCK_EX);
    file_put_contents('/work/backup-id', gmdate('Ymd\THis\Z') . '-' . $owner);
    $deadline = time() + (int)getenv('QUIESCE_TIMEOUT');
    if ($cronEnabled) {
        $cronPath = '/apis/batch/v1/namespaces/' . rawurlencode($namespace) . '/cronjobs/' . rawurlencode($cronName);
        $cron = api('GET', $cronPath);
        $wasSuspended = (bool)($cron['spec']['suspend'] ?? false);
        file_put_contents($lock . '/cron-was-suspended', $wasSuspended ? 'true' : 'false', LOCK_EX);
        if (!$wasSuspended) setCronSuspended(true);
        while (!cronJobsSettled()) {
            if (time() >= $deadline) throw new RuntimeException('Nextcloud cron did not finish before the deadline; backup remains locked');
            sleep(2);
        }
    }
    $selector = rawurlencode('app.kubernetes.io/instance=' . getenv('RELEASE_NAME') . ',app.kubernetes.io/component=app');
    $podPath = '/api/v1/namespaces/' . rawurlencode($namespace) . '/pods?labelSelector=' . $selector;
    $writers = api('GET', $podPath)['items'];
    if (count($writers) !== 1 || isset($writers[0]['metadata']['deletionTimestamp'])) {
        throw new RuntimeException('Backup requires one stable application Pod');
    }
    $writerUid = $writers[0]['metadata']['uid'];
    scale(1, 0);
    do {
        $pods = api('GET', $podPath);
        if (count($pods['items']) === 0) {
            foreach (['web'] as $writer) {
                $proof = '/var/www/html/.helmforge-quiescence/' . $writerUid . '/' . $writer;
                if (!is_file($proof) || trim(file_get_contents($proof)) !== 'graceful') {
                    throw new RuntimeException('Missing graceful shutdown evidence for ' . $writer . '; refusing snapshot');
                }
            }
            file_put_contents($lock . '/quiesced', gmdate(DATE_ATOM));
            echo "Application stopped and cron Jobs settled; snapshot may begin\n";
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
$cronWasSuspended = is_file($lock . '/cron-was-suspended') && trim(file_get_contents($lock . '/cron-was-suspended')) === 'true';
if ($cronEnabled && !$cronWasSuspended) setCronSuspended(false);
if (is_file($lock . '/cron-was-suspended')) unlink($lock . '/cron-was-suspended');
unlink($lock . '/quiesced');
unlink($lock . '/owner');
rmdir($lock);
echo "Snapshot captured; application replicas restored\n";
