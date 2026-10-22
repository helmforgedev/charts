// SPDX-License-Identifier: Apache-2.0
import assert from 'node:assert/strict';
import {execFileSync} from 'node:child_process';

const [context, namespace, release, version = '9.5.5', action = 'smoke'] = process.argv.slice(2);
assert.ok(context?.startsWith('k3d-helmforge-') && namespace && release);
const k = args => execFileSync('kubectl', ['--context', context, '-n', namespace, ...args], {
  encoding: 'utf8', timeout: 25000, stdio: ['ignore', 'pipe', 'pipe'],
});
const pods = JSON.parse(k(['get', 'pods', '-l', `app.kubernetes.io/instance=${release}`, '-o', 'json'])).items;
const ready = p => !p.metadata.deletionTimestamp && p.status.conditions?.some(c => c.type === 'Ready' && c.status === 'True');
const server = pods.find(p => ready(p) && p.spec.containers.some(c => c.image.includes('/elasticsearch:')));
assert.ok(server);
const container = server.spec.containers.find(c => c.image.includes('/elasticsearch:'));
const passwordEnv = container.env.find(e => e.name === 'ELASTIC_PASSWORD');
const secure = passwordEnv?.valueFrom?.secretKeyRef?.optional === false;
const httpPort = container.ports.find(p => p.name === 'http')?.containerPort;
assert.ok(Number.isInteger(httpPort), 'Elasticsearch container must expose a named http port');
const curl = 'if [ "$1" = true ]; then curl -skf --max-time 20 -u "elastic:$ELASTIC_PASSWORD" -H "Content-Type: application/json" -X "$2" "$3://localhost:$4$5" -d "$6"; else curl -sf --max-time 20 -H "Content-Type: application/json" -X "$2" "$3://localhost:$4$5" -d "$6"; fi';
const request = (route, method = 'GET', body) => JSON.parse(k(['exec', server.metadata.name, '-c', container.name, '--', 'sh', '-ec', curl, 'sh', String(secure), method, secure ? 'https' : 'http', String(httpPort), route, body ? JSON.stringify(body) : '']));
assert.equal(request('/').version.number, version);
if (secure) {
  const code = k(['exec', server.metadata.name, '-c', container.name, '--', 'curl', '-sk', '--max-time', '10', '-o', '/dev/null', '-w', '%{http_code}', `https://localhost:${httpPort}/`]);
  assert.equal(code, '401', 'Anonymous Elasticsearch access must be denied');
}
const health = request('/_cluster/health?wait_for_status=yellow&timeout=15s');
assert.equal(health.timed_out, false);
assert.ok(['green', 'yellow'].includes(health.status));
const nodes = Object.values(request('/_nodes?filter_path=nodes.*.version').nodes);
assert.ok(nodes.length > 0);
for (const node of nodes) assert.equal(node.version, version);
const index = '/helmforge-upstream-fixture';
if (action !== 'verify') {
  request(index, 'PUT', {settings: {number_of_shards: 1, number_of_replicas: 0}, mappings: {properties: {
    message: {type: 'keyword'}, vector: {type: 'dense_vector', dims: 4, index: true, similarity: 'l2_norm', index_options: {type: 'hnsw'}},
  }}});
  request(index + '/_doc/fixture?refresh=wait_for', 'PUT', {message: 'HelmForge retained document', vector: [1, 0, 0, 0]});
}
assert.equal(request(index + '/_doc/fixture')._source.message, 'HelmForge retained document');
const search = request(index + '/_search', 'POST', {knn: {field: 'vector', query_vector: [1, 0, 0, 0], k: 1, num_candidates: 10, filter: {exists: {field: 'message'}}}});
assert.equal(search.hits.hits[0]._id, 'fixture');
request(index + '/_flush', 'POST');
const kibana = pods.find(p => ready(p) && p.spec.containers.some(c => c.name === 'kibana'));
if (kibana) {
  const address = kibana.status.podIP.includes(':') ? `[${kibana.status.podIP}]` : kibana.status.podIP;
  const kibanaContainer = kibana.spec.containers.find(c => c.name === 'kibana');
  const kibanaPort = kibanaContainer.ports.find(p => p.name === 'http')?.containerPort;
  assert.ok(Number.isInteger(kibanaPort), 'Kibana container must expose a named http port');
  const status = JSON.parse(k(['exec', server.metadata.name, '-c', container.name, '--', 'curl', '-sf', '--max-time', '15', `http://${address}:${kibanaPort}/api/status`]));
  // Unauthenticated status deliberately redacts version metadata.
  const packageInfo = JSON.parse(k(['exec', kibana.metadata.name, '-c', 'kibana', '--', 'cat', '/usr/share/kibana/package.json']));
  assert.equal(packageInfo.version, version);
  assert.equal(status.status.overall.level, 'available');
}
if (action === 'smoke') request(index, 'DELETE');
console.log(`PASS: Elasticsearch ${version}, ${nodes.length} healthy node(s), ${secure ? 'TLS and authenticated access with anonymous denial, ' : ''}document read/write, filtered vector search and flush${kibana ? '; bundled Kibana available at matching version' : ''}.`);
