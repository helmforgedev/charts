// SPDX-License-Identifier: Apache-2.0
import assert from 'node:assert/strict';
import {execFileSync} from 'node:child_process';

const [context, namespace, release] = process.argv.slice(2);
if (!context?.startsWith('k3d-helmforge-') || !namespace || !release) {
  throw new Error('Explicit HelmForge lab context, namespace and release required');
}
const kubectl = args => execFileSync('kubectl', ['--context', context, '-n', namespace, ...args], {
  encoding: 'utf8', timeout: 30000, stdio: ['ignore', 'pipe', 'pipe'],
});
const pods = JSON.parse(kubectl(['get', 'pods', '-l', `app.kubernetes.io/instance=${release}`, '-o', 'json'])).items;
const pod = pods.find(p => !p.metadata.deletionTimestamp
  && p.status.conditions?.some(c => c.type === 'Ready' && c.status === 'True')
  && p.spec.containers.some(c => c.name === 'poznote'));
assert.ok(pod, 'Ready Poznote pod required');
const container = pod.spec.containers.find(c => c.name === 'poznote');
const listenerPort = Number(container.env.find(e => e.name === 'POZNOTE_LISTEN_PORT')?.value);
assert.ok(Number.isInteger(listenerPort) && listenerPort >= 1 && listenerPort <= 65535,
  'POZNOTE_LISTEN_PORT must contain a valid port');
assert.equal(container.ports.find(p => p.name === 'http')?.containerPort, listenerPort,
  'Named HTTP container port must match the Poznote listener');
const services = JSON.parse(kubectl([
  'get', 'services', '-l', `app.kubernetes.io/instance=${release}`, '-o', 'json',
])).items;
const service = services.find(item => item.spec.selector?.['app.kubernetes.io/name']
  === pod.metadata.labels['app.kubernetes.io/name']);
assert.ok(service, 'Poznote Service required');
const servicePort = service.spec.ports.find(port => port.name === 'http');
assert.equal(servicePort?.targetPort, 'http', 'Service must target the named HTTP port');
const exec = args => kubectl(['exec', pod.metadata.name, '-c', 'poznote', '--', ...args]);
assert.equal(exec(['cat', '/var/www/html/version.txt']).trim(), '6.121.0');
const health = exec(['php', '-r', `
$context = stream_context_create(['http' => ['timeout' => 10]]);
$body = file_get_contents('http://127.0.0.1:${listenerPort}/api/health', false, $context);
if ($body === false || !preg_match('/^HTTP\\/\\S+ 200\\b/', $http_response_header[0] ?? '')) {
    fwrite(STDERR, "Poznote health endpoint failed\\n"); exit(1);
}
echo "health status 200\\n";
`]);
assert.match(health, /health status 200/);
console.log(`PASS: Poznote 6.121.0 listener=${listenerPort} service=${servicePort.port} and live PHP/API health`);
