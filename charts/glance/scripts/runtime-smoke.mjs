// SPDX-License-Identifier: Apache-2.0
import assert from 'node:assert/strict';
import {execFileSync, spawn} from 'node:child_process';
import {fileURLToPath} from 'node:url';
const [context, namespace, release] = process.argv.slice(2);
assert.match(context ?? '', /^k3d-/);
assert.ok(namespace && release);
const kubectl = args => execFileSync('kubectl', ['--context', context, '-n', namespace, ...args], {encoding: 'utf8', timeout: 90000});
const values = JSON.parse(execFileSync('helm', ['get', 'values', release, '-n', namespace, '--kube-context', context, '-a', '-o', 'json'], {encoding: 'utf8'}));
const deployments = JSON.parse(kubectl(['get', 'deploy', '-l', `app.kubernetes.io/instance=${release},app.kubernetes.io/name=glance`, '-o', 'json'])).items;
assert.equal(deployments.length, 1);
const deployment = deployments[0];
const fullname = deployment.metadata.name;
if (values.externalSecrets.enabled) {
  const external = JSON.parse(kubectl(['get', 'externalsecrets', '-o', 'json'])).items;
  assert.ok(external.length > 0);
  for (const item of external) assert.ok(item.status?.conditions?.some(c => c.type === 'Ready' && c.status === 'True'), 'ExternalSecret must be Ready before authentication');
}
let credentials, cookie;
let originalAuth;
if (values.auth.enabled) {
  const volume = deployment.spec.template.spec.volumes.find(v => v.name === 'secrets');
  const name = volume.projected.sources[0].secret.name;
  const data = JSON.parse(kubectl(['get', 'secret', name, '-o', 'json'])).data;
  originalAuth = {name, data};
  const key = Buffer.from(data[values.auth.secretKeyKey], 'base64').toString();
  assert.equal(Buffer.from(key, 'base64').length, 64, 'Signing key must decode to exactly 64 bytes');
  credentials = {username: values.auth.username, password: Buffer.from(data[values.auth.passwordKey], 'base64').toString()};
}
async function withPod(pod, test) {
  const forward = spawn('kubectl', ['--context', context, '-n', namespace, 'port-forward', `pod/${pod}`, `:${values.server.port}`, '--address=127.0.0.1'], {windowsHide: true, stdio: ['ignore', 'pipe', 'pipe']});
  let output = '';
  forward.stdout.on('data', chunk => {output += chunk;});
  forward.stderr.on('data', chunk => {output += chunk;});
  try {
    const deadline = Date.now() + 20000;
    while (!output.match(/127\.0\.0\.1:(\d+) ->/) && Date.now() < deadline && forward.exitCode === null) await new Promise(r => setTimeout(r, 100));
    const port = output.match(/127\.0\.0\.1:(\d+) ->/)?.[1];
    assert.ok(port, 'Port-forward did not become ready');
    const request = (route, options = {}) => fetch(`http://127.0.0.1:${port}${route}`, {...options, signal: AbortSignal.timeout(10000), redirect: 'manual'});
    await test(request);
  } finally {
    if (process.platform === 'win32' && forward.exitCode === null) {
      try { execFileSync('taskkill', ['/PID', String(forward.pid), '/T', '/F'], {stdio: 'ignore'}); }
      catch (error) {
        let gone = false;
        try { process.kill(forward.pid, 0); }
        catch (probe) { if (probe.code === 'ESRCH') gone = true; else throw probe; }
        if (!gone) throw error;
      }
    } else forward.kill();
  }
}
const pods = () => JSON.parse(kubectl(['get', 'pods', '-l', `app.kubernetes.io/instance=${release},app.kubernetes.io/name=glance`, '-o', 'json'])).items.filter(p => !p.metadata.deletionTimestamp);
async function check(request) {
  assert.equal((await request('/api/healthz')).status, 200);
  const anonymous = await request('/');
  if (credentials) {
    assert.ok([302, 303, 307].includes(anonymous.status), 'Anonymous dashboard access must redirect to login');
    const rejected = await request('/api/authenticate', {method: 'POST', headers: {'Content-Type': 'application/json'}, body: JSON.stringify({username: '', password: ''})});
    assert.equal(rejected.status, 401);
    if (!cookie) {
      const login = await request('/api/authenticate', {method: 'POST', headers: {'Content-Type': 'application/json'}, body: JSON.stringify(credentials)});
      assert.equal(login.status, 200, 'Native Glance authentication must succeed');
      cookie = login.headers.get('set-cookie')?.split(';')[0];
      assert.match(cookie ?? '', /^session_token=/);
    }
  } else assert.equal(anonymous.status, 200);
  const page = values.config.data.pages[0];
  const slug = page.slug || page.name.toLowerCase().replaceAll(' ', '-');
  const response = await request(`/api/pages/${slug}/content/`, {headers: cookie ? {Cookie: cookie} : {}});
  assert.equal(response.status, 200, 'Dashboard content must load with the original session');
  const content = await response.text();
  assert.ok(content.length > 100, 'Dashboard must contain rendered widgets');
  if (JSON.stringify(values.config.data).includes('HelmForge')) assert.ok(content.includes('HelmForge'), 'Expected bookmark content is missing');
  if (values.assets.existingConfigMap === 'glance-assets') assert.ok(content.includes('widget-fixture-ok'), 'Custom API template or Secret interpolation did not execute');
}
for (const pod of pods()) await withPod(pod.metadata.name, check);
// Re-render against the cluster to verify lookup retains generated credentials.
execFileSync('helm', ['upgrade', release, fileURLToPath(new URL('..', import.meta.url)), '--kube-context', context, '-n', namespace, '--reuse-values', '--wait', '--timeout', '60s'], {encoding: 'utf8', timeout: 75000});
if (originalAuth) {
  const current = JSON.parse(kubectl(['get', 'secret', originalAuth.name, '-o', 'json'])).data;
  assert.deepEqual(current, originalAuth.data, 'Helm upgrade changed existing authentication material');
}
// A rollout replaces all pod processes. The original session must remain valid.
kubectl(['rollout', 'restart', `deployment/${fullname}`]);
kubectl(['rollout', 'status', `deployment/${fullname}`, '--timeout=90s']);
for (const pod of pods()) await withPod(pod.metadata.name, check);
console.log(`PASS native health, ${credentials ? 'anonymous rejection, login, shared signing key and retained session' : 'public dashboard'}, rendered widgets, Helm upgrade and pod replacement (${values.replicaCount} replica(s)).`);
