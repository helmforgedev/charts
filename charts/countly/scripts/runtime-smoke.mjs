// SPDX-License-Identifier: Apache-2.0
import assert from 'node:assert/strict';
import {execFileSync, spawn} from 'node:child_process';

const [context, namespace, release] = process.argv.slice(2);
assert.match(context ?? '', /^k3d-/);
assert.ok(namespace && release);

const kubectl = args => execFileSync(
  'kubectl',
  ['--context', context, '-n', namespace, ...args],
  {encoding: 'utf8', timeout: 90000},
);
const values = JSON.parse(execFileSync(
  'helm',
  ['get', 'values', release, '-n', namespace, '--kube-context', context, '-a', '-o', 'json'],
  {encoding: 'utf8', timeout: 30000},
));
const service = JSON.parse(kubectl([
  'get',
  'service',
  '-l',
  `app.kubernetes.io/instance=${release},app.kubernetes.io/name=countly`,
  '-o',
  'json',
])).items[0];
assert.ok(service, 'Countly Service was not found');

async function withForward(remotePort, check) {
  const forward = spawn(
    'kubectl',
    ['--context', context, '-n', namespace, 'port-forward', `service/${service.metadata.name}`, `:${remotePort}`, '--address=127.0.0.1'],
    {windowsHide: true, stdio: ['ignore', 'pipe', 'pipe']},
  );
  let output = '';
  forward.stdout.on('data', chunk => { output += chunk; });
  forward.stderr.on('data', chunk => { output += chunk; });
  try {
    const deadline = Date.now() + 20000;
    while (!output.match(/127\.0\.0\.1:(\d+) ->/) && Date.now() < deadline && forward.exitCode === null) {
      await new Promise(resolve => setTimeout(resolve, 100));
    }
    const localPort = output.match(/127\.0\.0\.1:(\d+) ->/)?.[1];
    assert.ok(localPort, `Port-forward for ${remotePort} did not become ready: ${output}`);
    await check(Number(localPort));
  } finally {
    if (process.platform === 'win32' && forward.exitCode === null) {
      try {
        execFileSync('taskkill', ['/PID', String(forward.pid), '/T', '/F'], {stdio: 'ignore'});
      } catch (error) {
        try {
          process.kill(forward.pid, 0);
          throw error;
        } catch (probe) {
          if (probe.code !== 'ESRCH') throw probe;
        }
      }
    } else {
      forward.kill();
    }
  }
}

async function withForwardRetry(remotePort, check, attempts = 3) {
  let lastError;
  for (let attempt = 1; attempt <= attempts; attempt += 1) {
    try {
      await withForward(remotePort, check);
      return;
    } catch (error) {
      lastError = error;
      if (attempt < attempts) {
        await new Promise(resolve => setTimeout(resolve, 1000));
      }
    }
  }
  throw lastError;
}

await withForwardRetry(values.service.port, async port => {
  const response = await fetch(`http://127.0.0.1:${port}/`, {signal: AbortSignal.timeout(15000), redirect: 'manual'});
  assert.ok(response.status >= 200 && response.status < 500, `Dashboard returned HTTP ${response.status}`);
});
await withForwardRetry(values.service.apiPort, async port => {
  const response = await fetch(`http://127.0.0.1:${port}/i`, {signal: AbortSignal.timeout(15000), redirect: 'manual'});
  assert.ok(response.status >= 200 && response.status < 500, `Ingestion API returned HTTP ${response.status}`);
});

const deployment = JSON.parse(kubectl(['get', 'deployment', service.metadata.name, '-o', 'json']));
const app = deployment.spec.template.spec.containers.find(container => container.name === 'countly');
assert.equal(app.env.find(env => env.name === 'COUNTLY_CONFIG_API_API_PORT')?.value, String(values.countly.apiPort));
assert.equal(app.env.find(env => env.name === 'COUNTLY_CONFIG_FRONTEND_WEB_PORT')?.value, String(values.countly.dashboardPort));
console.log(`PASS dashboard and ingestion API listeners (dashboard=${values.countly.dashboardPort}, api=${values.countly.apiPort}) through Service ports.`);
