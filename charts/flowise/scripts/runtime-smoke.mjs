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
  `app.kubernetes.io/instance=${release},app.kubernetes.io/name=flowise`,
  '-o',
  'json',
])).items.find(item => item.spec?.ports?.some(port => port.name === 'http'));
assert.ok(service, 'Flowise Service was not found');

const forward = spawn(
  'kubectl',
  ['--context', context, '-n', namespace, 'port-forward', `service/${service.metadata.name}`, `:${values.service.port}`, '--address=127.0.0.1'],
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
  assert.ok(localPort, `Port-forward did not become ready: ${output}`);
  const response = await fetch(`http://127.0.0.1:${localPort}/api/v1/ping`, {
    signal: AbortSignal.timeout(15000),
    redirect: 'manual',
  });
  assert.ok(response.status >= 200 && response.status < 500, `Flowise ping returned HTTP ${response.status}`);
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

const deployment = JSON.parse(kubectl(['get', 'deployment', service.metadata.name, '-o', 'json']));
const app = deployment.spec.template.spec.containers.find(container => container.name === 'flowise');
assert.equal(app.env.find(env => env.name === 'PORT')?.value, String(values.flowise.containerPort));
assert.equal(app.ports.find(port => port.name === 'http')?.containerPort, values.flowise.containerPort);
console.log(`PASS Flowise listener ${values.flowise.containerPort} through Service port ${values.service.port}.`);
