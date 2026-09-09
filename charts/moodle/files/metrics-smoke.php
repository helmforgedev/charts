<?php
// SPDX-License-Identifier: Apache-2.0
// Lab-only behavioral verification, including a temporary course when Prometheus is present.
$service = $argv[1];
$publicService = $argv[2];
$prometheus = $argv[3] ?? '';
$path = '/r.php/monitoringexporter_prometheus/metrics';
function http(string $url, array $headers = []): array {
    $curl = curl_init($url);
    curl_setopt_array($curl, [CURLOPT_RETURNTRANSFER => true, CURLOPT_TIMEOUT => 15,
        CURLOPT_HTTPHEADER => $headers]);
    $body = curl_exec($curl);
    $status = curl_getinfo($curl, CURLINFO_HTTP_CODE);
    if ($body === false) { throw new RuntimeException('HTTP metrics connection failed'); }
    return [$status, $body];
}
$token = trim(file_get_contents('/opt/metrics-auth/token'));
foreach (['', 'invalid-lab-token'] as $invalid) {
    [$status] = http("http://$service:9090$path", $invalid === '' ? [] : ['Authorization: Bearer ' . $invalid]);
    if ($status !== 403) { throw new RuntimeException('Metrics must reject missing and invalid tokens'); }
}
[$status, $body] = http("http://$service:9090$path", ['Authorization: Bearer ' . $token]);
if ($status !== 200 || str_contains($body, '<?php')) { throw new RuntimeException('Authenticated metrics failed'); }
$settings = json_decode(file_get_contents('/opt/helmforge/settings.json'), true, 512, JSON_THROW_ON_ERROR);
foreach ($settings['metrics']['enabledMetrics'] as $metric) {
    if (!str_contains($body, '# TYPE tool_monitoring_' . $metric . ' gauge')) {
        throw new RuntimeException('Expected metric family is missing: ' . $metric);
    }
}
[$status] = http("http://$publicService$path", ['Authorization: Bearer ' . $token]);
if ($status !== 403) { throw new RuntimeException('Metrics route must be blocked on the public listener'); }
[$status] = http("http://$service:9090/login/index.php");
if ($status !== 403) { throw new RuntimeException('Private listener must not expose login pages'); }
echo "Metrics: missing/invalid token 403, authenticated 200, expected families, listener isolation verified\n";
if ($prometheus === '') { exit(0); }
function query_value(string $prometheus, string $query): ?float {
    [$status, $body] = http("http://$prometheus:9090/api/v1/query?query=" . rawurlencode($query));
    $result = json_decode($body, true, 512, JSON_THROW_ON_ERROR);
    if ($status !== 200 || $result['status'] !== 'success') { throw new RuntimeException('Prometheus query failed'); }
    return isset($result['data']['result'][0]['value'][1]) ? (float)$result['data']['result'][0]['value'][1] : null;
}
function await_value(string $prometheus, string $query, callable $accept): float {
    for ($attempt = 0; $attempt < 24; $attempt++) {
        $value = query_value($prometheus, $query);
        if ($value !== null && $accept($value)) { return $value; }
        sleep(3);
    }
    throw new RuntimeException('Prometheus did not observe the expected value');
}
$selector = '{service="' . $service . '"}';
await_value($prometheus, 'min(up' . $selector . ')', fn($value) => $value === 1.0);
echo "Prometheus discovered the ServiceMonitor and reports up=1\n";
if (in_array('courses', $settings['metrics']['enabledMetrics'], true)) {
    $query = 'sum(max by (visible) (tool_monitoring_courses' . $selector . '))';
    $before = await_value($prometheus, $query, fn($value) => $value >= 1);
    define('CLI_SCRIPT', true);
    require '/var/www/html/config.php';
    require_once '/var/www/html/public/course/lib.php';
    $course = create_course((object)['fullname' => 'Metrics validation',
        'shortname' => 'hf-metrics-' . bin2hex(random_bytes(4)), 'category' => 1]);
    try {
        await_value($prometheus, $query, fn($value) => $value === $before + 1);
        echo "Prometheus observed a real Moodle course count increase\n";
    } finally {
        delete_course($course->id, false);
    }
    await_value($prometheus, $query, fn($value) => $value === $before);
    echo "Course cleanup and original metric value verified\n";
}
[$status, $body] = http("http://$prometheus:9090/api/v1/rules");
$rules = json_decode($body, true, 512, JSON_THROW_ON_ERROR);
$names = [];
foreach ($rules['data']['groups'] ?? [] as $group) {
    foreach ($group['rules'] as $rule) {
        if (($rule['health'] ?? '') !== 'ok') { throw new RuntimeException('Prometheus rule evaluation failed'); }
        $names[] = $rule['name'];
    }
}
if ($settings['metrics']['prometheusRule']['enabled'] && !in_array('MoodleMetricsUnavailable', $names, true)) {
    throw new RuntimeException('PrometheusRule was not loaded');
}
echo "Prometheus alert rules loaded and evaluated successfully\n";
