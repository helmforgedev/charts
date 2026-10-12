// SPDX-License-Identifier: Apache-2.0
import assert from 'node:assert/strict';
import {execFileSync} from 'node:child_process';

const [context, namespace, release] = process.argv.slice(2);
assert.ok(context?.startsWith('k3d-helmforge-') && namespace && release);
const run = args => execFileSync('kubectl', ['--context', context, '-n', namespace, ...args], {
  encoding: 'utf8', timeout: 60000, stdio: ['ignore', 'pipe', 'pipe'],
});
const pods = JSON.parse(run(['get', 'pods', '-l', `app.kubernetes.io/instance=${release}`, '-o', 'json'])).items
  .filter(pod => !pod.metadata.deletionTimestamp);
assert.equal(pods.length, 1, 'QuestDB must remain a singleton');
const pod = pods[0];
assert.ok(pod.status.conditions?.some(c => c.type === 'Ready' && c.status === 'True'), 'QuestDB must be Ready');
const container = pod.spec.containers.find(c => c.name === 'questdb');
assert.ok(container.image.includes('@sha256:'), 'image must use an immutable digest');
assert.equal(pod.spec.securityContext.runAsUser, 10001);
assert.equal(pod.spec.automountServiceAccountToken, false);
assert.equal(container.securityContext.readOnlyRootFilesystem, true);
assert.deepEqual(container.securityContext.capabilities.drop, ['ALL']);
const exec = command => run(['exec', pod.metadata.name, '-c', 'questdb', '--', 'sh', '-ec', command]).trim();
assert.match(exec('curl --fail --silent http://127.0.0.1:9003/status'), /Running|OK|Status/i);
const query = exec('curl --fail --silent --user "$QDB_HTTP_USER:$(cat /run/questdb-secrets/http-password)" "http://127.0.0.1:9000/exec?query=select%201"');
assert.match(query, /dataset|columns|1/i, 'authenticated SQL-over-HTTP query must succeed');
const services = JSON.parse(run(['get', 'service', '-l', `app.kubernetes.io/instance=${release}`, '-o', 'json'])).items;
assert.ok(services.length >= 2, 'client and headless Services are required');
const client = services.find(service => service.metadata.name === `${release}-questdb`);
assert.ok(client, 'client Service is required');
assert.equal(client.spec.type, 'ClusterIP');
const clientPorts = client.spec.ports.map(port => port.port);
assert.ok(clientPorts.includes(9000) && clientPorts.includes(8812), 'HTTP and PostgreSQL ports are required');
const metrics = services.find(service => service.metadata.name === `${release}-questdb-metrics`);
if (metrics) {
  assert.match(exec('curl --fail --silent http://127.0.0.1:9003/metrics'), /questdb|jvm_|process_/i);
}
console.log('PASS: QuestDB health, authenticated SQL, singleton state, immutable image and hardened runtime verified.');
