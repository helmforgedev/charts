// SPDX-License-Identifier: Apache-2.0
import assert from 'node:assert/strict';
import { execFileSync, spawn } from 'node:child_process';

const [context, namespace, release] = process.argv.slice(2);
assert.equal(context, 'k3d-helmforge-tests-wsl');
const kubectl = (args) =>
  execFileSync('kubectl', ['--context', context, '-n', namespace, ...args], {
    encoding: 'utf8',
    timeout: 120_000,
  });
const selector = `app.kubernetes.io/instance=${release},app.kubernetes.io/name=temporal`;
const deployments = JSON.parse(kubectl(['get', 'deployments', '-l', selector, '-o', 'json'])).items;
const statefulSets = JSON.parse(kubectl(['get', 'statefulsets', '-l', selector, '-o', 'json'])).items;
const workloads = [...deployments, ...statefulSets];
for (const component of ['frontend', 'history', 'matching', 'worker', 'web', 'admin-tools']) {
  assert.ok(workloads.some((item) => item.metadata.labels['app.kubernetes.io/component'] === component), component);
}
const admin = deployments.find((item) => item.metadata.labels['app.kubernetes.io/component'] === 'admin-tools');
const health = kubectl(['exec', `deployment/${admin.metadata.name}`, '--', 'temporal', 'operator', 'cluster', 'health']);
assert.match(health, /SERVING|healthy/i);

const webService = deployments.find((item) => item.metadata.labels['app.kubernetes.io/component'] === 'web').metadata.name;
const child = spawn(
  'kubectl',
  ['--context', context, '-n', namespace, 'port-forward', `service/${webService}`, '0:8080', '--address=127.0.0.1'],
  { windowsHide: true, stdio: ['ignore', 'pipe', 'pipe'] },
);
let output = '';
for (const stream of [child.stdout, child.stderr]) stream.on('data', (chunk) => (output += chunk));
try {
  const deadline = Date.now() + 20_000;
  while (!/Forwarding from/.test(output) && Date.now() < deadline && child.exitCode === null) {
    await new Promise((resolve) => setTimeout(resolve, 100));
  }
  const port = output.match(/127\.0\.0\.1:(\d+)/)?.[1];
  assert.ok(port, output);
  const response = await fetch(`http://127.0.0.1:${port}/healthz`, { signal: AbortSignal.timeout(15_000) });
  assert.equal(response.status, 200);
} finally {
  if (child.exitCode === null && child.signalCode === null) {
    if (process.platform === 'win32') execFileSync('taskkill', ['/PID', String(child.pid), '/T', '/F'], { stdio: 'ignore' });
    else child.kill();
  }
}
console.log('PASS Temporal cluster gRPC health, all server roles, admin tools, and Web UI /healthz');
