// SPDX-License-Identifier: Apache-2.0

import assert from 'node:assert/strict';
import { execFileSync } from 'node:child_process';

const [context, namespace, release] = process.argv.slice(2);
assert.ok(context?.startsWith('k3d-helmforge-') && namespace && release);

const base = ['--context', context, '-n', namespace];
const kubectl = (args) => execFileSync('kubectl', [...base, ...args], {
  encoding: 'utf8',
  timeout: 30000,
  stdio: ['ignore', 'pipe', 'pipe'],
});
const ready = (pod) => !pod.metadata.deletionTimestamp
  && pod.status.conditions?.some((condition) => condition.type === 'Ready' && condition.status === 'True');

const pods = JSON.parse(kubectl(['get', 'pods', '-l', `app.kubernetes.io/instance=${release}`, '-o', 'json'])).items;
const pod = pods.find((candidate) => ready(candidate)
  && candidate.spec.containers.some((container) => container.name === 'velero'));
assert.ok(pod, 'Ready Velero server pod required');

const container = pod.spec.containers.find((candidate) => candidate.name === 'velero');
assert.equal(container.image, 'docker.io/velero/velero:v1.18.4');
const metricsPort = container.ports?.find((port) => port.name === 'metrics')?.containerPort;
assert.ok(Number.isInteger(metricsPort), 'Named metrics container port required');
assert.ok(container.args.includes(`--metrics-address=:${metricsPort}`), 'Velero process must listen on the declared metrics port');

const version = kubectl(['exec', pod.metadata.name, '-c', 'velero', '--', '/velero', 'version', '--client-only']);
assert.match(version, /Version:\s+v1\.18\.4\b/);

const services = JSON.parse(kubectl(['get', 'services', '-l', `app.kubernetes.io/instance=${release}`, '-o', 'json'])).items;
const service = services.find((candidate) => candidate.spec.ports?.some((port) => port.name === 'metrics'));
assert.ok(service, 'Metrics Service required');
const servicePort = service.spec.ports.find((port) => port.name === 'metrics');
assert.equal(servicePort.targetPort, 'metrics');

const proxyPath = `/api/v1/namespaces/${namespace}/services/http:${service.metadata.name}:${servicePort.port}/proxy/metrics`;
const metrics = execFileSync('kubectl', ['--context', context, 'get', '--raw', proxyPath], {
  encoding: 'utf8',
  timeout: 30000,
  stdio: ['ignore', 'pipe', 'pipe'],
});
assert.match(metrics, /velero_[a-zA-Z0-9_:]+/);

console.log(`PASS: Velero v1.18.4 metrics listener ${metricsPort} through Service port ${servicePort.port}.`);
