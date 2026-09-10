// SPDX-License-Identifier: Apache-2.0
import assert from 'node:assert/strict';
import {execFileSync, spawn} from 'node:child_process';
import {randomBytes} from 'node:crypto';
import {setTimeout as delay} from 'node:timers/promises';

const [context, namespace, release] = process.argv.slice(2);
if (!context?.startsWith('k3d-helmforge-') || !namespace || !release) {
  throw new Error('Explicit HelmForge lab context, namespace and release required');
}
const deadline = Date.now() + 140000;
const target = ['--context', context, '-n', namespace];
const kubectl = args => execFileSync('kubectl', [...target, ...args], {
  encoding: 'utf8', timeout: 15000, stdio: ['ignore', 'pipe', 'pipe'],
});
const pods = JSON.parse(kubectl(['get', 'pods', '-l', `app.kubernetes.io/instance=${release}`, '-o', 'json'])).items;
const pod = pods.find(p => !p.metadata.deletionTimestamp
  && p.status.conditions?.some(c => c.type === 'Ready' && c.status === 'True')
  && p.spec.containers.some(c => c.name === 'n8n'));
assert.ok(pod, 'Ready n8n main pod required');
assert.equal(kubectl(['exec', pod.metadata.name, '-c', 'n8n', '--', 'n8n', '--version']).trim(), '2.38.4');
const main = pod.spec.containers.find(c => c.name === 'n8n');
const python = main.env.some(e => e.name === 'N8N_PYTHON_ENABLED' && e.value === 'true');
const queue = main.env.some(e => e.name === 'EXECUTIONS_MODE' && e.value === 'queue');
const child = spawn('kubectl', [...target, 'port-forward', `pod/${pod.metadata.name}`, ':5678', '--address=127.0.0.1'], {
  windowsHide: true, stdio: ['ignore', 'pipe', 'pipe'],
});
let output = '', error;
child.stdout.on('data', chunk => { output += chunk; });
child.stderr.on('data', () => {});
child.on('error', caught => { error = caught; });
try {
  for (let i = 0; i < 150 && !/127\.0\.0\.1:(\d+) ->/.test(output) && !error; i++) await delay(100);
  if (error) throw error;
  const port = output.match(/127\.0\.0\.1:(\d+) ->/)?.[1];
  assert.ok(port);
  const base = `http://127.0.0.1:${port}`, cookies = new Map();
  async function request(route, method = 'GET', body) {
    const remaining = deadline - Date.now();
    assert.ok(remaining > 0, 'Runtime deadline reached');
    const response = await fetch(base + route, {
      method, headers: {'Content-Type': 'application/json', Cookie: [...cookies].map(([a, b]) => `${a}=${b}`).join('; ')},
      ...(body ? {body: JSON.stringify(body)} : {}), signal: AbortSignal.timeout(Math.min(60000, remaining)),
    });
    for (const cookie of response.headers.getSetCookie()) {
      const pair = cookie.split(';')[0], equals = pair.indexOf('=');
      cookies.set(pair.slice(0, equals), pair.slice(equals + 1));
    }
    assert.ok(response.ok, `${method} ${route}: HTTP ${response.status}`);
    return response.json();
  }
  await request('/healthz/readiness');
  await request('/rest/owner/setup', 'POST', {
    email: 'runtime@example.invalid', firstName: 'Runtime', lastName: 'Fixture',
    password: `Fixture-${randomBytes(18).toString('hex')}!`,
  });
  for (const language of python ? ['javaScript', 'pythonNative'] : ['javaScript']) {
    const route = `helmforge-${randomBytes(8).toString('hex')}`;
    const workflow = {name: `Runtime ${language}`, nodes: [
      {id: 'webhook', name: 'Webhook', type: 'n8n-nodes-base.webhook', typeVersion: 2, position: [0, 0], webhookId: route,
        parameters: {httpMethod: 'GET', path: route, responseMode: 'lastNode', options: {}}},
      {id: 'code', name: 'Code', type: 'n8n-nodes-base.code', typeVersion: 2, position: [240, 0], parameters: {
        language, mode: 'runOnceForAllItems', ...(language === 'javaScript'
          ? {jsCode: 'return [{json: {answer: 6 * 7}}];'} : {pythonCode: 'return [{"json": {"answer": 6 * 7}}]'}),
      }},
    ], connections: {Webhook: {main: [[{node: 'Code', type: 'main', index: 0}]]}}, settings: {executionOrder: 'v1'}};
    const created = (await request('/rest/workflows', 'POST', workflow)).data;
    assert.ok(created.id && created.versionId);
    await request(`/rest/workflows/${created.id}/activate`, 'POST', {versionId: created.versionId});
    const response = await request(`/webhook/${route}`);
    const result = Array.isArray(response) ? response[0] : response;
    assert.equal(result.answer, 42, `${language} runner result`);
  }
  console.log(`PASS: n8n 2.38.4, readiness, owner authentication and published ${python ? 'JavaScript/Python' : 'JavaScript'} workflow execution${queue ? ' through Redis queue workers' : ''}`);
} finally {
  if (child.exitCode === null) {
    if (process.platform === 'win32') {
      try { execFileSync('taskkill', ['/PID', String(child.pid), '/T', '/F'], {stdio: 'ignore'}); }
      catch (cleanupError) {
        let exists = true;
        try { process.kill(child.pid, 0); }
        catch (error) { if (error.code === 'ESRCH') exists = false; else throw error; }
        if (exists) throw cleanupError;
      }
    } else child.kill('SIGTERM');
  }
}
