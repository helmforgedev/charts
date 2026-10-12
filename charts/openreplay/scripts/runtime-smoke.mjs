// SPDX-License-Identifier: Apache-2.0
import assert from 'node:assert/strict';
import {execFileSync} from 'node:child_process';

const [context, namespace, release] = process.argv.slice(2);
assert.ok(context?.startsWith('k3d-helmforge-') && namespace && release);

const run = args => execFileSync(
  'kubectl',
  ['--context', context, '-n', namespace, ...args],
  {encoding: 'utf8', timeout: 60000, stdio: ['ignore', 'pipe', 'pipe']},
);

const deployments = JSON.parse(run([
  'get', 'deployments', '-l', `app.kubernetes.io/instance=${release}`, '-o', 'json',
])).items;
assert.ok(deployments.length >= 1, 'at least the router deployment is required');
for (const deployment of deployments) {
  assert.equal(deployment.status.availableReplicas, deployment.spec.replicas, `${deployment.metadata.name} must be available`);
  assert.equal(deployment.spec.template.spec.automountServiceAccountToken, false);
  for (const container of deployment.spec.template.spec.containers) {
    assert.ok(container.image.includes('@sha256:'), `${deployment.metadata.name}/${container.name} must use an immutable digest`);
    assert.equal(container.securityContext?.allowPrivilegeEscalation, false);
    assert.deepEqual(container.securityContext?.capabilities?.drop, ['ALL']);
  }
}

const router = deployments.find(deployment => deployment.metadata.name === `${release}-router`);
assert.ok(router, 'the internal router deployment is required');
const routerPod = JSON.parse(run([
  'get', 'pods', '-l', `app.kubernetes.io/instance=${release},app.kubernetes.io/component=router`, '-o', 'json',
])).items.find(pod => !pod.metadata.deletionTimestamp);
assert.ok(routerPod, 'the router pod is required');
const fetch = path => run([
  'exec', routerPod.metadata.name, '-c', 'router', '--', 'wget', '-qO-', `http://127.0.0.1:8080${path}`,
]);
assert.equal(fetch('/healthz').trim(), '');
const frontend = deployments.find(deployment => deployment.metadata.name === `${release}-frontend`);
if (frontend) {
  assert.match(fetch('/'), /<!doctype html|<html/i, 'the router must serve the OpenReplay frontend');
}

if (deployments.length > 2) {
  assert.equal(deployments.length, 17, 'the default profile must deploy 15 OpenReplay components, the router and RustFS');
  const migrationJobs = JSON.parse(run([
    'get', 'jobs', '-l', `app.kubernetes.io/instance=${release},app.kubernetes.io/component=migration`, '-o', 'json',
  ])).items;
  assert.equal(migrationJobs.length, 1, 'one schema migration Job is required');
  assert.equal(migrationJobs[0].status.succeeded, 1, 'the schema migration Job must complete');
}

console.log('PASS: OpenReplay workloads, migration, immutable images, hardened containers, router health and frontend verified.');
