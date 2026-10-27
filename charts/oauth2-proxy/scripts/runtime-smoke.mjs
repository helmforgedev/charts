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
const service = services.find(item => item.spec.ports?.some(port => port.name === 'http'));
assert.ok(service, 'OAuth2 Proxy Service with named HTTP port required');

const pods = JSON.parse(kubectl([
  'get', 'pods', '-l', `app.kubernetes.io/instance=${release}`, '-o', 'json',
])).items;
const pod = pods.find(item => !item.metadata.deletionTimestamp
  && item.status.conditions?.some(condition => condition.type === 'Ready' && condition.status === 'True')
  && item.spec.containers.some(container => container.name === 'oauth2-proxy'));
assert.ok(pod, 'Ready OAuth2 Proxy pod required');
const container = pod.spec.containers.find(item => item.name === 'oauth2-proxy');
const containerPort = container.ports.find(port => port.name === 'http')?.containerPort;
assert.ok(Number.isInteger(containerPort), 'Named HTTP container port required');

const ready = kubectl([
  'get', '--raw',
  `/api/v1/namespaces/${namespace}/services/http:${service.metadata.name}:http/proxy/ready`,
]);
assert.match(ready, /OK/i, 'OAuth2 Proxy readiness response required');

console.log(`OAuth2 Proxy readiness passed on Service ${service.metadata.name} and container port ${containerPort}.`);
