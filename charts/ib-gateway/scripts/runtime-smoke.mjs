// SPDX-License-Identifier: Apache-2.0
import assert from 'node:assert/strict';
import {execFileSync} from 'node:child_process';

const [context, namespace, release] = process.argv.slice(2);
assert.ok(context?.startsWith('k3d-helmforge-') && namespace && release);
const run = args => execFileSync('kubectl', ['--context', context, '-n', namespace, ...args], {
  encoding: 'utf8', timeout: 60000, stdio: ['ignore', 'pipe', 'pipe'],
});

const pods = JSON.parse(run(['get', 'pods', '-l', `app.kubernetes.io/instance=${release}`, '-o', 'json'])).items;
const pod = pods.find(item => item.status.conditions?.some(
  condition => condition.type === 'Ready' && condition.status === 'True',
));
assert.ok(pod, 'one Ready IB Gateway pod is required');
assert.equal(pods.length, 1, 'IB Gateway must remain a singleton');
const container = pod.spec.containers.find(item => item.name === 'ib-gateway');
assert.ok(container?.image.includes('@sha256:'), 'IB Gateway image must use an immutable digest');
assert.equal(pod.spec.securityContext.runAsNonRoot, true);
assert.equal(pod.spec.automountServiceAccountToken, false);
assert.equal(container.securityContext.allowPrivilegeEscalation, false);
assert.deepEqual(container.securityContext.capabilities.drop, ['ALL']);

const service = JSON.parse(run(['get', 'service', release, '-o', 'json']));
assert.equal(service.spec.type, 'ClusterIP');
assert.ok(service.spec.ports.some(port => ['live-api', 'paper-api'].includes(port.name)),
  'an active API Service port is required');
const mode = container.env.find(item => item.name === 'TRADING_MODE')?.value;
assert.ok(['paper', 'live', 'both'].includes(mode), 'a supported trading mode is required');
console.log(`IB Gateway singleton, immutable image, hardened runtime and ${mode} TCP Service verified`);
