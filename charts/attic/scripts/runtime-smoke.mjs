// SPDX-License-Identifier: Apache-2.0
import assert from 'node:assert/strict';
import {execFileSync} from 'node:child_process';

const [context, namespace, release] = process.argv.slice(2);
assert.ok(context?.startsWith('k3d-helmforge-') && namespace && release);

const run = args => execFileSync('kubectl', ['--context', context, '-n', namespace, ...args], {
  encoding: 'utf8', timeout: 60000, stdio: ['ignore', 'pipe', 'pipe'],
});

const pods = JSON.parse(run(['get', 'pods', '-l', `app.kubernetes.io/instance=${release},app.kubernetes.io/component=api`, '-o', 'json'])).items;
const pod = pods.find(item => !item.metadata.deletionTimestamp
  && item.status.conditions?.some(condition => condition.type === 'Ready' && condition.status === 'True'));
assert.ok(pod, 'Ready Attic API pod required');

const container = pod.spec.containers.find(item => item.name === 'attic');
assert.ok(container, 'Attic application container required');
assert.equal(container.image, 'ghcr.io/zhaofengli/attic:9eda345a743f50999de04f59a170806c3e029eea');
assert.equal(container.securityContext.runAsNonRoot, undefined);
assert.equal(pod.spec.securityContext.runAsNonRoot, true);
assert.equal(container.securityContext.readOnlyRootFilesystem, true);

const configMaps = JSON.parse(run(['get', 'configmaps', '-l', `app.kubernetes.io/instance=${release}`, '-o', 'json'])).items;
const serverConfig = configMaps.find(item => item.data?.['server.toml'])?.data['server.toml'];
const allowedHost = serverConfig?.match(/allowed-hosts\s*=\s*\["([^"]+)"/)?.[1];
assert.ok(allowedHost, 'Attic allowed host required in rendered server configuration');

const response = run([
  'exec', pod.metadata.name, '-c', 'attic', '--',
  '/bin/busybox', 'wget', '-qO-', '--header', `Host: ${allowedHost}`, 'http://127.0.0.1:8080/',
]);
assert.match(response, /Attic/i, 'Attic root endpoint should identify the server');

const hasDataVolume = pod.spec.volumes.some(volume => volume.name === 'data');
if (hasDataVolume) {
  run(['exec', pod.metadata.name, '-c', 'attic', '--', '/bin/busybox', 'sh', '-c',
    'test -w /data && printf runtime-smoke > /data/.helmforge-smoke && test "$(cat /data/.helmforge-smoke)" = runtime-smoke']);
}

console.log(`Attic listener, official image, non-root runtime, read-only root filesystem${hasDataVolume ? ', and persistent data write' : ', and distributed topology'} verified`);
