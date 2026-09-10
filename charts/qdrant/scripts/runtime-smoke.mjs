// SPDX-License-Identifier: Apache-2.0
import assert from 'node:assert/strict';
import {execFileSync, spawn} from 'node:child_process';
import {setTimeout as delay} from 'node:timers/promises';

const [context, namespace, release] = process.argv.slice(2);
if (!context?.startsWith('k3d-helmforge-') || !namespace || !release) {
  throw new Error('Explicit HelmForge lab context, namespace and release required');
}
const target = ['--context', context, '--namespace', namespace];
const k = (...args) => JSON.parse(execFileSync('kubectl', [...target, ...args, '-o', 'json'],
  {encoding:'utf8', timeout:30000, stdio:['ignore','pipe','pipe']}));
const pods = k('get', 'pods', '-l', `app.kubernetes.io/instance=${release}`).items
  .filter(p => p.status.phase === 'Running' && !p.metadata.deletionTimestamp);
assert.ok(pods.length, 'Qdrant pods required');
const container = pods[0].spec.containers.find(c => c.ports?.some(p => p.name === 'http'));
const env = container.env ?? [];
function credential(name) {
  const entry = env.find(e => e.name === name);
  if (!entry) return undefined;
  if (entry.value !== undefined) return entry.value;
  const ref = entry.valueFrom.secretKeyRef;
  return Buffer.from(k('get', 'secret', ref.name).data[ref.key], 'base64').toString();
}
const writeKey = credential('QDRANT__SERVICE__API_KEY');
const readKey = credential('QDRANT__SERVICE__READ_ONLY_API_KEY');
const port = container.ports.find(p => p.name === 'http').containerPort;
const forward = spawn('kubectl', [...target, 'port-forward', `pod/${pods[0].metadata.name}`, `:${port}`, '--address=127.0.0.1'],
  {windowsHide:true, stdio:['ignore','pipe','pipe']});
let output = '';
forward.stdout.on('data', chunk => { output += chunk; });
forward.stderr.on('data', () => {});
const collection = `helmforge_smoke_${Date.now()}`;
let base;
let created = false;
async function request(method, route, body, key = writeKey, expected = 200) {
  const response = await fetch(base + route, {
    method, headers:{'content-type':'application/json', ...(key ? {'api-key':key} : {})},
    body: body === undefined ? undefined : JSON.stringify(body), signal:AbortSignal.timeout(20000),
  });
  assert.equal(response.status, expected, `${method} ${route}: unexpected status`);
  if (!response.ok) { await response.text(); return null; }
  return response.json();
}
try {
  for (let i = 0; i < 150 && !/127\.0\.0\.1:(\d+) ->/.test(output); i++) {
    if (forward.exitCode !== null) throw new Error('port-forward exited before readiness');
    await delay(100);
  }
  const localPort = output.match(/127\.0\.0\.1:(\d+) ->/)?.[1];
  assert.ok(localPort, 'port-forward must become ready');
  base = `http://127.0.0.1:${localPort}`;
  const info = await request('GET', '/');
  assert.equal(info.version, '1.19.1', 'the updated server must actually run');
  if (writeKey) await request('GET', '/collections', undefined, 'invalid-key', 401);
  const distributed = env.some(e => e.name === 'QDRANT__CLUSTER__ENABLED' && e.value === 'true');
  if (distributed) {
    const cluster = await request('GET', '/cluster');
    assert.equal(cluster.result.status, 'enabled');
    assert.equal(Object.keys(cluster.result.peers).length, pods.length, 'all peers must join');
  }
  await request('PUT', `/collections/${collection}`, {
    vectors:{size:3,distance:'Cosine'}, ...(distributed ? {shard_number:3,replication_factor:2} : {}),
  });
  created = true;
  await request('PUT', `/collections/${collection}/points?wait=true`, {
    points:[{id:1,vector:[1,0,0],payload:{label:'verified'}},{id:2,vector:[0,1,0]}],
  });
  const found = await request('POST', `/collections/${collection}/points/query`, {
    query:[1,0,0],limit:1,with_payload:true,
  });
  assert.equal(found.result.points[0].id, 1);
  assert.equal(found.result.points[0].payload.label, 'verified');
  if (readKey) {
    await request('GET', `/collections/${collection}`, undefined, readKey);
    await request('PUT', `/collections/${collection}/points?wait=true`, {points:[]}, readKey, 403);
  }
  await request('DELETE', `/collections/${collection}`);
  created = false;
  console.log(`Qdrant 1.19.1: vector write/query/delete passed; ${pods.length} pod(s); authenticated=${Boolean(writeKey)}; distributed=${distributed}`);
} finally {
  if (created) await request('DELETE', `/collections/${collection}`).catch(() => {});
  if (forward.exitCode === null) {
    if (process.platform === 'win32') {
      // Package-manager shims may start a child kubectl; close the entire owned tree.
      execFileSync('taskkill', ['/PID', String(forward.pid), '/T', '/F'], {stdio:'ignore'});
    } else {
      forward.kill();
    }
  }
}
