// SPDX-License-Identifier: Apache-2.0
import assert from 'node:assert/strict';
import {execFileSync} from 'node:child_process';

const [context, namespace, release] = process.argv.slice(2);
assert.ok(context?.startsWith('k3d-helmforge-') && namespace && release);
const run = args => execFileSync('kubectl', ['--context', context, '-n', namespace, ...args], {encoding: 'utf8', timeout: 60000});
const pods = JSON.parse(run(['get', 'pods', '-l', `app.kubernetes.io/instance=${release}`, '-o', 'json'])).items
  .filter(pod => !pod.metadata.deletionTimestamp);
assert.equal(pods.length, 1, 'OpenHuman must remain a singleton');
const pod = pods[0];
assert.ok(pod.status.conditions?.some(c => c.type === 'Ready' && c.status === 'True'), 'OpenHuman must be Ready');
const container = pod.spec.containers.find(c => c.name === 'openhuman');
assert.ok(container.image.includes('@sha256:'), 'image must use an immutable digest');
assert.equal(pod.spec.securityContext.runAsUser, 10001);
assert.equal(pod.spec.automountServiceAccountToken, false);
assert.equal(container.securityContext.readOnlyRootFilesystem, true);
assert.deepEqual(container.securityContext.capabilities.drop, ['ALL']);
assert.match(run(['exec', pod.metadata.name, '-c', 'openhuman', '--', 'curl', '--fail', '--silent', 'http://127.0.0.1:7788/health']), /healthy|status/i);
const services = JSON.parse(run(['get', 'service', '-l', `app.kubernetes.io/instance=${release}`, '-o', 'json'])).items;
assert.equal(services.length, 1, 'one OpenHuman Service is required');
const service = services[0];
assert.equal(service.spec.type, 'ClusterIP');
assert.equal(service.spec.ports[0].port, 7788);
console.log('OpenHuman health, singleton state, immutable image and hardened runtime verified');
