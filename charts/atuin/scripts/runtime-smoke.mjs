// SPDX-License-Identifier: Apache-2.0
import assert from 'node:assert/strict';
import {execFileSync} from 'node:child_process';

const [context, namespace, release] = process.argv.slice(2);
assert.ok(context?.startsWith('k3d-helmforge-') && namespace && release);

const run = args => execFileSync('kubectl', ['--context', context, '-n', namespace, ...args], {
  encoding: 'utf8', timeout: 60000, stdio: ['ignore', 'pipe', 'pipe'],
});

const pods = JSON.parse(run(['get', 'pods', '-l', `app.kubernetes.io/instance=${release}`, '-o', 'json'])).items;
const pod = pods.find(item => item.status.conditions?.some(condition => condition.type === 'Ready' && condition.status === 'True'));
assert.ok(pod, 'Ready Atuin pod required');

const container = pod.spec.containers.find(item => item.name === 'atuin');
assert.ok(container, 'Atuin application container required');
assert.equal(container.image, 'ghcr.io/atuinsh/atuin:18.23.0');
assert.equal(pod.spec.securityContext.runAsNonRoot, true);
assert.equal(container.securityContext.readOnlyRootFilesystem, true);

const health = run(['exec', pod.metadata.name, '-c', 'atuin', '--', 'curl', '--fail', '--silent', 'http://127.0.0.1:8888/healthz']);
assert.match(health, /healthy/, 'Atuin health endpoint must respond');
const configVolume = pod.spec.volumes.find(volume => volume.name === 'config');
assert.ok(configVolume, 'Atuin config volume required');
if (configVolume.persistentVolumeClaim) {
  run(['exec', pod.metadata.name, '-c', 'atuin', '--', '/bin/sh', '-ec', 'test -s /config/atuin.db && test -w /config']);
} else {
  run(['exec', pod.metadata.name, '-c', 'atuin', '--', '/bin/sh', '-ec', 'test -w /config && test -s /runtime/db-uri']);
  const databasePods = JSON.parse(run(['get', 'pods', '-l', `app.kubernetes.io/instance=${release},app.kubernetes.io/name=postgresql`, '-o', 'json'])).items;
  const databasePod = databasePods.find(item => item.status.conditions?.some(condition => condition.type === 'Ready' && condition.status === 'True'));
  assert.ok(databasePod, 'Ready bundled PostgreSQL pod required');
  const migrations = run(['exec', databasePod.metadata.name, '-c', 'postgresql', '--', '/bin/sh', '-ec',
    'PGPASSWORD="$POSTGRES_PASSWORD" psql -U "$POSTGRES_USER" -d "$POSTGRES_DB" -tAc "select count(*) from _sqlx_migrations"']);
  assert.ok(Number.parseInt(migrations.trim(), 10) > 0, 'Atuin PostgreSQL migrations must exist');
}

console.log(`Atuin HTTP health, ${configVolume.persistentVolumeClaim ? 'SQLite initialization' : 'PostgreSQL migrations'}, writable config, official image and hardened runtime verified`);
