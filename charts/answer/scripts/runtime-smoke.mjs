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
const service = services.find(item => item.metadata.labels?.['app.kubernetes.io/name'] === 'answer');
const pod = pods.find(item => item.metadata.labels?.['app.kubernetes.io/component'] === 'server'
  && item.status.conditions?.some(condition => condition.type === 'Ready' && condition.status === 'True'));

assert.ok(service, 'Answer Service required');
assert.ok(pod, 'Ready Answer server pod required');
const servicePort = service.spec.ports.find(port => port.name === 'http');
const container = pod.spec.containers.find(item => item.name === 'answer');
const containerPort = container?.ports?.find(port => port.name === 'http')?.containerPort;
const siteAddress = container?.env?.find(item => item.name === 'SITE_ADDR')?.value;

assert.equal(servicePort?.targetPort, 'http', 'Service must target the named Answer HTTP port');
assert.ok(Number.isInteger(containerPort), 'Named Answer HTTP container port required');
assert.equal(siteAddress, `0.0.0.0:${containerPort}`, 'SITE_ADDR must configure the rendered container port');
kubectl([
  'get', '--raw',
  `/api/v1/namespaces/${namespace}/services/http:${service.metadata.name}:http/proxy/healthz`,
]);

console.log(`Answer runtime smoke passed: Service ${servicePort.port} -> container ${containerPort}.`);
