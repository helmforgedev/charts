// SPDX-License-Identifier: Apache-2.0
import assert from 'node:assert/strict';
import {execFileSync} from 'node:child_process';

const [context, namespace, release] = process.argv.slice(2);
assert.match(context ?? '', /^k3d-helmforge-/);
assert.ok(namespace && release);

const kubectl = (args, options = {}) => execFileSync(
  'kubectl',
  ['--context', context, '-n', namespace, ...args],
  {encoding: 'utf8', timeout: 60000, stdio: ['ignore', 'pipe', 'pipe'], ...options},
);

const selector = `app.kubernetes.io/instance=${release},app.kubernetes.io/name=stalwart`;
const pods = JSON.parse(kubectl(['get', 'pods', '-l', selector, '-o', 'json'])).items
  .filter((pod) => !pod.metadata.deletionTimestamp);
assert.equal(pods.length, 1, 'default Stalwart installation must have one pod');
const pod = pods[0];
assert.ok(pod.status.conditions?.some((condition) => condition.type === 'Ready' && condition.status === 'True'));
const container = pod.spec.containers.find((candidate) => candidate.name === 'stalwart');
assert.equal(container?.image, 'docker.io/stalwartlabs/stalwart:v0.16.27');
assert.equal(pod.spec.automountServiceAccountToken, false);

const services = JSON.parse(kubectl(['get', 'services', '-l', selector, '-o', 'json'])).items;
const httpService = services.find((service) => service.metadata.name.endsWith('-http'))?.metadata.name;
const mailService = services.find((service) => service.metadata.name.endsWith('-mail'))?.metadata.name;
assert.ok(httpService && mailService, 'HTTP and mail Services are required');
const smokeName = `${release}-protocol-smoke`;
const command = [
  `wget -qO- http://${httpService}:8080/healthz/live`,
  `wget -qO- http://${httpService}:8080/healthz/ready`,
  `printf 'EHLO smoke.local\\r\\nQUIT\\r\\n' | nc -w 10 ${mailService} 25 | grep -Eq '^(220|250)'`,
].join(' && ');

try {
  kubectl([
    'run', smokeName, '--image=docker.io/library/busybox:1.37.0',
    '--restart=Never', '--rm', '-i', '--command', '--', 'sh', '-ec', command,
  ], {timeout: 60000});
} finally {
  try { kubectl(['delete', 'pod', smokeName, '--ignore-not-found=true', '--wait=false']); } catch {}
}

console.log('PASS Stalwart image, live/ready health, and SMTP protocol behavior');
