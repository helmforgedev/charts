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

const selector = `app.kubernetes.io/instance=${release},app.kubernetes.io/name=ghostfolio`;
const pods = JSON.parse(kubectl(['get', 'pods', '-l', selector, '-o', 'json'])).items
  .filter((pod) => !pod.metadata.deletionTimestamp);
assert.equal(pods.length, 1, 'Ghostfolio must remain a singleton');

const pod = pods[0];
assert.ok(pod.status.conditions?.some((condition) => condition.type === 'Ready' && condition.status === 'True'));
const container = pod.spec.containers.find((candidate) => candidate.name === 'ghostfolio');
assert.ok(container);
assert.match(container.image, /ghostfolio\/ghostfolio:3\.82\.0@sha256:[a-f0-9]{64}$/);
assert.equal(pod.spec.automountServiceAccountToken, false);

const request = (path) => kubectl([
  'exec', pod.metadata.name, '-c', 'ghostfolio', '--',
  'curl', '--fail', '--silent', '--show-error', `http://127.0.0.1:3333${path}`,
]);

const liveness = JSON.parse(request('/api/v1/health/liveness'));
assert.equal(liveness.status, 'OK');
const readiness = JSON.parse(request('/api/v1/health'));
assert.equal(readiness.status, 'OK');

const logs = kubectl(['logs', pod.metadata.name, '-c', 'ghostfolio']);
assert.match(logs, /Running database migrations/);
assert.match(logs, /Seeding the database/);
assert.match(logs, /Starting the server/);

const accessSalt = container.env.find((entry) => entry.name === 'ACCESS_TOKEN_SALT')?.valueFrom?.secretKeyRef;
const jwtSecret = container.env.find((entry) => entry.name === 'JWT_SECRET_KEY')?.valueFrom?.secretKeyRef;
assert.ok(accessSalt?.name && accessSalt.key && jwtSecret?.name && jwtSecret.key);
assert.equal(accessSalt.name, jwtSecret.name);
const secret = JSON.parse(kubectl(['get', 'secret', accessSalt.name, '-o', 'json']));
assert.ok(Buffer.from(secret.data[accessSalt.key], 'base64').length >= 8);
assert.ok(Buffer.from(secret.data[jwtSecret.key], 'base64').length >= 8);

console.log('PASS Ghostfolio migrations, seed, official health endpoints, singleton runtime, and Secret-backed identity');
