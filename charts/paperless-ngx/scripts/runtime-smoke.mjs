// SPDX-License-Identifier: Apache-2.0
import assert from 'node:assert/strict';
import {execFileSync} from 'node:child_process';

const [context, namespace, release] = process.argv.slice(2);
if (!context?.startsWith('k3d-helmforge-') || !namespace || !release) {
  throw new Error('Explicit HelmForge lab context, namespace and release required');
}

const retryableTransportError = /(?:connection reset|forcibly closed|i\/o timeout|unable to upgrade connection|websocket|\bEOF\b)/i;

function kubectl(args) {
  for (let attempt = 1; attempt <= 3; attempt += 1) {
    try {
      return execFileSync('kubectl', ['--context', context, '-n', namespace, ...args], {
        encoding: 'utf8',
        timeout: 60_000,
        stdio: ['ignore', 'pipe', 'pipe'],
      });
    } catch (error) {
      const message = `${error.message ?? ''}\n${error.stderr ?? ''}`;
      if (attempt === 3 || !retryableTransportError.test(message)) throw error;
      Atomics.wait(new Int32Array(new SharedArrayBuffer(4)), 0, 0, attempt * 1_000);
    }
  }
  throw new Error('kubectl retry loop exhausted');
}

const services = JSON.parse(kubectl([
  'get', 'services', '-l', `app.kubernetes.io/instance=${release}`, '-o', 'json',
])).items;
const pods = JSON.parse(kubectl([
  'get', 'pods', '-l', `app.kubernetes.io/instance=${release}`, '-o', 'json',
])).items;

function component(item) {
  return item.metadata.labels?.['app.kubernetes.io/component'];
}

function readyPod(name) {
  return pods.find(item => component(item) === name
    && !item.metadata.deletionTimestamp
    && item.status.conditions?.some(condition => condition.type === 'Ready' && condition.status === 'True'));
}

function service(name) {
  return services.find(item => component(item) === name
    && item.spec.ports?.some(port => port.name === 'http'));
}

function get(serviceName, path) {
  return kubectl([
    'get', '--raw',
    `/api/v1/namespaces/${namespace}/services/http:${serviceName}:http/proxy${path}`,
  ]);
}

const webService = service('webserver');
const webPod = readyPod('webserver');
assert.ok(webService, 'Paperless-ngx Service with named HTTP port required');
assert.ok(webPod, 'Ready Paperless-ngx pod required');
const webContainer = webPod.spec.containers.find(item => item.name === 'paperless');
const webPort = webContainer?.ports?.find(port => port.name === 'http')?.containerPort;
assert.ok(Number.isInteger(webPort), 'Named Paperless-ngx HTTP container port required');
const webServicePort = webService.spec.ports.find(port => port.name === 'http').port;
const smokePod = `${release}-runtime-smoke`.slice(0, 63).replace(/-+$/, '');
kubectl(['delete', 'pod', smokePod, '--ignore-not-found=true', '--wait=true']);
try {
  kubectl([
    'run', smokePod,
    `--image=${webContainer.image}`,
    '--restart=Never',
    `--labels=app.kubernetes.io/instance=${release},app.kubernetes.io/component=runtime-smoke`,
    '--command', '--',
    'python', '-c',
    `import urllib.request; request = urllib.request.Request("http://${webService.metadata.name}:${webServicePort}/", headers={"Host": "localhost"}); response = urllib.request.urlopen(request, timeout=15); print(response.status); response.close()`,
  ]);
  let phase = '';
  for (let attempt = 0; attempt < 60; attempt += 1) {
    phase = kubectl(['get', 'pod', smokePod, '-o', 'jsonpath={.status.phase}']).trim();
    if (phase === 'Succeeded' || phase === 'Failed') break;
    Atomics.wait(new Int32Array(new SharedArrayBuffer(4)), 0, 0, 1_000);
  }
  const webResponse = kubectl(['logs', smokePod]).trim();
  assert.equal(phase, 'Succeeded', `Paperless-ngx smoke pod failed: ${webResponse}`);
  assert.match(webResponse, /^(?:2|3)\d{2}$/, 'Paperless-ngx success response with allowed Host required');
} finally {
  kubectl(['delete', 'pod', smokePod, '--ignore-not-found=true', '--wait=true']);
}

const conversionEnabled = webContainer.env?.some(item =>
  item.name === 'PAPERLESS_TIKA_ENABLED' && item.value === 'true') ?? false;

for (const [name, path, expected] of [
  ['tika', '/tika', /tika/i],
  ['gotenberg', '/health', /(?:up|ok)/i],
]) {
  const optionalService = service(name);
  if (conversionEnabled) {
    assert.ok(optionalService, `${name} Service required when PAPERLESS_TIKA_ENABLED=true`);
  }
  if (!optionalService) continue;
  const optionalPod = readyPod(name);
  assert.ok(optionalPod, `Ready ${name} pod required`);
  const optionalContainer = optionalPod.spec.containers.find(item => item.name === name);
  const optionalPort = optionalContainer?.ports?.find(port => port.name === 'http')?.containerPort;
  assert.equal(optionalService.spec.ports.find(port => port.name === 'http').port, optionalPort,
    `${name} Service and container ports must match`);
  assert.match(get(optionalService.metadata.name, path), expected, `${name} HTTP response required`);
}

console.log(`Paperless-ngx runtime smoke passed on container port ${webPort}.`);
