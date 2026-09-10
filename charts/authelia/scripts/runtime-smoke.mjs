// SPDX-License-Identifier: Apache-2.0
import assert from 'node:assert/strict';
import {execFileSync, spawn} from 'node:child_process';
import {setTimeout as delay} from 'node:timers/promises';

const [context, namespace, release] = process.argv.slice(2);
if (!context?.startsWith('k3d-helmforge-') || !namespace || !release) {
  throw new Error('Explicit HelmForge lab context, namespace and release required');
}
const target = ['--context', context, '-n', namespace];
const kubectl = args => execFileSync('kubectl', [...target, ...args], {
  encoding: 'utf8', timeout: 30000, stdio: ['ignore', 'pipe', 'pipe'],
});
const pods = JSON.parse(kubectl(['get', 'pods', '-l', `app.kubernetes.io/instance=${release}`, '-o', 'json'])).items;
const pod = pods.find(p => !p.metadata.deletionTimestamp
  && p.status.conditions?.some(c => c.type === 'Ready' && c.status === 'True')
  && p.spec.containers.some(c => c.name === 'authelia'));
assert.ok(pod, 'Ready Authelia pod required');
const exec = args => kubectl(['exec', pod.metadata.name, '-c', 'authelia', '--', 'authelia', ...args]);
assert.match(exec(['--version']), /v4\.39\.22\b/);
assert.match(exec(['storage', 'encryption', 'check', '--config', '/config/configuration.yml']), /SUCCESS/);
const metrics = pod.spec.containers.find(c => c.name === 'authelia').ports.some(p => p.name === 'metrics');
const ports = metrics ? [9091, 9959] : [9091];
const child = spawn('kubectl', [...target, 'port-forward', `pod/${pod.metadata.name}`,
  ...ports.map(p => `:${p}`), '--address=127.0.0.1'], {windowsHide: true, stdio: ['ignore', 'pipe', 'pipe']});
let output = '', error;
child.stdout.on('data', chunk => { output += chunk; });
child.stderr.on('data', () => {});
child.on('error', caught => { error = caught; });
try {
  const forwarded = {};
  for (let i = 0; i < 150 && Object.keys(forwarded).length < ports.length && !error; i++) {
    for (const m of output.matchAll(/127\.0\.0\.1:(\d+) -> (\d+)/g)) forwarded[m[2]] = m[1];
    await delay(100);
  }
  if (error) throw error;
  assert.equal(Object.keys(forwarded).length, ports.length);
  const health = await fetch(`http://127.0.0.1:${forwarded[9091]}/api/health`, {signal: AbortSignal.timeout(10000)});
  assert.equal(health.status, 200);
  await health.arrayBuffer();
  if (metrics) {
    const response = await fetch(`http://127.0.0.1:${forwarded[9959]}/metrics`, {signal: AbortSignal.timeout(10000)});
    assert.equal(response.status, 200);
    const body = await response.text();
    assert.match(body, /^# HELP /m);
    assert.match(body, /^# TYPE /m);
  }
  console.log(`PASS: Authelia 4.39.22, storage encryption and API health${metrics ? ', Prometheus scrape' : ''}`);
} finally {
  if (child.exitCode === null) {
    if (process.platform === 'win32') {
      try {
        execFileSync('taskkill', ['/PID', String(child.pid), '/T', '/F'], {stdio: 'ignore'});
      } catch (cleanupError) {
        // The forwarder can exit before taskkill observes it. Suppress only
        // that race; retain failures when the process still exists.
        let exists = true;
        try { process.kill(child.pid, 0); }
        catch (error) { if (error.code === 'ESRCH') exists = false; else throw error; }
        if (exists) throw cleanupError;
      }
    } else child.kill('SIGTERM');
  }
}
