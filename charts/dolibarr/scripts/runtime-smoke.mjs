// SPDX-License-Identifier: Apache-2.0
import assert from 'node:assert/strict';
import {execFileSync} from 'node:child_process';

const [context, namespace, release] = process.argv.slice(2);
if (!context?.startsWith('k3d-helmforge-') || !namespace || !release) {
  throw new Error('Explicit HelmForge lab context, namespace and release required');
}

const sleep = milliseconds => Atomics.wait(
  new Int32Array(new SharedArrayBuffer(4)), 0, 0, milliseconds,
);
const transientTransport = /connection was forcibly closed|connection reset|tls handshake timeout|unexpected eof/i;
const kubectl = args => {
  for (let attempt = 1; attempt <= 3; attempt += 1) {
    try {
      return execFileSync('kubectl', ['--context', context, '-n', namespace, ...args], {
        encoding: 'utf8',
        timeout: 60_000,
        stdio: ['ignore', 'pipe', 'pipe'],
      });
    } catch (error) {
      const detail = `${error.stderr ?? ''}\n${error.message ?? ''}`;
      if (attempt === 3 || !transientTransport.test(detail)) throw error;
      sleep(attempt * 2_000);
    }
  }
  throw new Error('kubectl retry loop exited unexpectedly');
};

const pods = JSON.parse(kubectl([
  'get', 'pods',
  '-l', `app.kubernetes.io/instance=${release},app.kubernetes.io/component=dolibarr`,
  '-o', 'json',
])).items;
const pod = pods.find(item => !item.metadata.deletionTimestamp
  && item.status.conditions?.some(condition => condition.type === 'Ready' && condition.status === 'True'));
assert.ok(pod, 'Ready Dolibarr pod required');

const services = JSON.parse(kubectl([
  'get', 'services',
  '-l', `app.kubernetes.io/instance=${release},app.kubernetes.io/component=dolibarr`,
  '-o', 'json',
])).items;
const service = services.find(item => item.spec.ports?.some(port => port.name === 'http'));
assert.ok(service, 'Dolibarr Service with a named HTTP port required');
const servicePort = service.spec.ports.find(port => port.name === 'http');
assert.ok(servicePort, 'Named HTTP service port required');

const container = pod.spec.containers.find(item => item.name === 'dolibarr');
const containerPort = container?.ports?.find(port => port.name === 'http')?.containerPort;
assert.ok(Number.isInteger(containerPort), 'Named HTTP container port required');

const response = kubectl([
  'get', '--raw',
  `/api/v1/namespaces/${namespace}/services/http:${service.metadata.name}:http/proxy/`,
]);
assert.match(response, /Dolibarr|Login|login/i, 'Dolibarr HTTP response required');

console.log(`Dolibarr HTTP smoke passed on Service ${service.metadata.name}:${servicePort.port} and container port ${containerPort}.`);
