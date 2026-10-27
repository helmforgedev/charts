// SPDX-License-Identifier: Apache-2.0
import assert from 'node:assert/strict';
import {execFileSync} from 'node:child_process';

const [context, namespace, release] = process.argv.slice(2);
if (!context?.startsWith('k3d-helmforge-') || !namespace || !release) {
  throw new Error('Explicit HelmForge lab context, namespace and release required');
}

const kubectl = args => execFileSync('kubectl', ['--context', context, '-n', namespace, ...args], {
  encoding: 'utf8',
  timeout: 60_000,
  stdio: ['ignore', 'pipe', 'pipe'],
});

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
assert.match(get(webService.metadata.name, '/'), /paperless/i, 'Paperless-ngx web response required');

for (const [name, path, expected] of [
  ['tika', '/tika', /tika/i],
  ['gotenberg', '/health', /(?:up|ok)/i],
]) {
  const optionalService = service(name);
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
