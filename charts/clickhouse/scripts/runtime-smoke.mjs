// SPDX-License-Identifier: Apache-2.0
import assert from 'node:assert/strict';
import {execFileSync} from 'node:child_process';

const [context, namespace, release, version = '26.8.2', action = 'smoke'] = process.argv.slice(2);
assert.ok(context?.startsWith('k3d-helmforge-') && namespace && release);
const k = args => execFileSync('kubectl', ['--context', context, '-n', namespace, ...args], {
  encoding: 'utf8', timeout: 30000, stdio: ['ignore', 'pipe', 'pipe'],
});
const pods = JSON.parse(k(['get', 'pods', '-l', `app.kubernetes.io/instance=${release}`, '-o', 'json'])).items;
const pod = pods.find(p => !p.metadata.deletionTimestamp && p.status.conditions?.some(c => c.type === 'Ready' && c.status === 'True')
  && p.spec.containers.some(c => c.name === 'clickhouse'));
assert.ok(pod, 'Ready ClickHouse server required');
const exec = args => k(['exec', pod.metadata.name, '-c', 'clickhouse', '--', ...args]).trim();
const sql = query => exec(['sh', '-ec', 'clickhouse-client --host 127.0.0.1 --user "$CLICKHOUSE_USER" --password "${CLICKHOUSE_PASSWORD:-}" --database "$CLICKHOUSE_DB" --multiquery --query "$1"', 'sh', query]);
assert.ok(sql('SELECT version()').startsWith(version + '.'));
assert.equal(sql("SELECT line FROM url('http://127.0.0.1:8123/ping', 'LineAsString', 'line String')"), 'Ok.');
if (action !== 'verify') {
  sql('SET enable_full_text_index=1; CREATE TABLE helmforge_upgrade_fixture (id UInt64, body String, INDEX body_idx body TYPE text(tokenizer = splitByNonAlpha)) ENGINE=MergeTree ORDER BY id');
  sql("INSERT INTO helmforge_upgrade_fixture SELECT number, concat('HelmForge fox ', toString(number)) FROM numbers(5)");
  sql("INSERT INTO helmforge_upgrade_fixture SELECT number+5, concat('HelmForge fox ', toString(number+5)) FROM numbers(5)");
}
assert.equal(sql('SELECT count(), sum(id) FROM helmforge_upgrade_fixture'), '10\t45');
assert.equal(sql("SELECT count() FROM helmforge_upgrade_fixture WHERE hasAnyTokens(body, ['fox']) SETTINGS force_data_skipping_indices='body_idx'"), '10');
if (action === 'verify') sql('ALTER TABLE helmforge_upgrade_fixture MATERIALIZE INDEX body_idx SETTINGS mutations_sync=2');
sql('OPTIMIZE TABLE helmforge_upgrade_fixture FINAL');
assert.equal(sql("SELECT count(), sum(id) FROM helmforge_upgrade_fixture WHERE hasAnyTokens(body, ['fox']) SETTINGS force_data_skipping_indices='body_idx'"), '10\t45');
if (version === '26.8.2') assert.equal(sql("SELECT value FROM system.merge_tree_settings WHERE name='text_index_serialization_version'"), 'v2_with_positions');
const metrics = pod.spec.containers.find(c => c.name === 'clickhouse').ports.find(p => p.name === 'metrics');
if (metrics) {
  const output = sql(`SELECT line FROM url('http://127.0.0.1:${metrics.containerPort}/metrics', 'LineAsString', 'line String') WHERE startsWith(line, 'ClickHouseMetrics_') OR startsWith(line, 'ClickHouseProfileEvents_') LIMIT 2`);
  assert.match(output, /^ClickHouse(?:Metrics|ProfileEvents)_/m);
}
if (action === 'smoke') sql('DROP TABLE helmforge_upgrade_fixture');
console.log(`PASS: ClickHouse ${version}, configured SQL authentication, MergeTree writes/aggregation, text-index query before and after merge${metrics ? ', Prometheus metrics' : ''}.`);
