// SPDX-License-Identifier: Apache-2.0
import assert from 'node:assert/strict';
import { execFileSync } from 'node:child_process';

const [context, namespace, release] = process.argv.slice(2);
if (!context?.startsWith('k3d-helmforge-') || !namespace || !release) {
  throw new Error('Explicit HelmForge lab context, namespace and release required');
}

const kubectl = (...args) => execFileSync('kubectl', [
  '--context', context,
  '--namespace', namespace,
  '--request-timeout=30s',
  ...args,
], {
  encoding: 'utf8',
  stdio: ['ignore', 'pipe', 'pipe'],
  timeout: 120000,
  maxBuffer: 4 * 1024 * 1024,
});

const pods = JSON.parse(kubectl(
  'get', 'pods',
  '-l', `app.kubernetes.io/instance=${release},app.kubernetes.io/name=grafana`,
  '-o', 'json',
)).items;
const pod = pods.find((item) => !item.metadata.deletionTimestamp
  && item.status.conditions?.some((condition) => condition.type === 'Ready' && condition.status === 'True'));
assert.ok(pod, 'Ready Grafana Pod required');

const container = pod.spec.containers.find((item) => item.name === 'grafana');
assert.ok(container, 'Grafana container required');
assert.match(container.image, /grafana\/grafana:13\.3\.2$/, 'Grafana 13.3.2 image must be running');
const listener = container.ports?.find((port) => port.name === 'http')?.containerPort;
assert.ok(Number.isInteger(listener), 'Named Grafana HTTP container port required');

const service = JSON.parse(kubectl(
  'get', 'services',
  '-l', `app.kubernetes.io/instance=${release},app.kubernetes.io/name=grafana`,
  '-o', 'json',
)).items.find((item) => item.spec.ports?.some((port) => port.name === 'http'));
assert.ok(service, 'Grafana Service required');
const servicePort = service.spec.ports.find((port) => port.name === 'http');
assert.equal(servicePort.targetPort, 'http', 'Service must target the named HTTP port');

const execGrafana = (...args) => kubectl(
  'exec', pod.metadata.name, '-c', 'grafana', '--', ...args,
).trim();
const version = execGrafana('grafana', 'cli', '--version');
assert.match(version, /13\.3\.2/, 'Grafana CLI version must match the chart appVersion');
execGrafana('test', '-w', '/var/lib/grafana');

const health = JSON.parse(execGrafana(
  'wget', '-qO-', `http://${service.metadata.name}:${servicePort.port}/api/health`,
));
assert.equal(health.database, 'ok', 'Grafana database health must be ok');
assert.equal(health.version, '13.3.2', 'Grafana health version must match the image');

console.log(`Grafana ${health.version}: database=${health.database}, listener=${listener}, service=${servicePort.port}.`);
