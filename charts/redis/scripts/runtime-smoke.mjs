// SPDX-License-Identifier: Apache-2.0
import assert from 'node:assert/strict';
import { execFileSync } from 'node:child_process';
import { randomUUID } from 'node:crypto';

const [context, namespace, release] = process.argv.slice(2);
assert.equal(context, 'k3d-helmforge-tests-wsl');

const kubectl = (args) =>
  execFileSync('kubectl', ['--context', context, '-n', namespace, ...args], {
    encoding: 'utf8',
    timeout: 30000,
  });
const values = JSON.parse(
  execFileSync(
    'helm',
    ['get', 'values', release, '--kube-context', context, '-n', namespace, '-a', '-o', 'json'],
    { encoding: 'utf8' },
  ),
);
const pods = JSON.parse(
  kubectl([
    'get',
    'pods',
    '-l',
    `app.kubernetes.io/instance=${release},app.kubernetes.io/component=redis`,
    '-o',
    'json',
  ]),
).items;
assert.ok(pods.length > 0, 'at least one Redis data pod must exist');

const pod = pods[0].metadata.name;
const redisContainer = pods[0].spec.containers.find((container) => container.name === 'redis');
assert.ok(redisContainer, 'Redis container must exist');
assert.equal(
  redisContainer.ports.find((port) => port.name === 'redis')?.containerPort,
  values.containerPorts.redis,
  'the declared Redis container port must match the configured process listener',
);

const tlsArgs = values.tls.enabled
  ? ` --tls --cacert /tls/${values.tls.caFilename} --cert /tls/${values.tls.certFilename} --key /tls/${values.tls.keyFilename}`
  : '';
const cli = `redis-cli${tlsArgs} -p ${values.containerPorts.redis}`;
const authenticatedCli = values.auth.enabled ? `REDISCLI_AUTH="$REDIS_PASSWORD" ${cli}` : cli;
const run = (command) =>
  kubectl(['exec', pod, '-c', 'redis', '--', 'sh', '-ec', command]).trim();

assert.equal(run(`${authenticatedCli} PING`), 'PONG');

if (values.architecture === 'standalone') {
  const key = `helmforge-${randomUUID()}`;
  const value = randomUUID();
  assert.equal(run(`${authenticatedCli} SET ${key} ${value}`), 'OK');
  assert.equal(run(`${authenticatedCli} GET ${key}`), value);
  assert.equal(run(`${authenticatedCli} DEL ${key}`), '1');
}

if (values.tls.enabled && values.auth.enabled && values.architecture === 'standalone') {
  const bad = run(`REDISCLI_AUTH=incorrect-owned-fixture ${cli} PING 2>&1 || true`);
  assert.match(bad, /WRONGPASS|NOAUTH|AUTH failed/);
  assert.doesNotMatch(bad, /^PONG$/m);
}

console.log(
  `PASS Redis ${values.architecture} listener on ${values.containerPorts.redis}: declared port and authenticated PING verified`,
);
