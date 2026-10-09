// SPDX-License-Identifier: Apache-2.0
import assert from 'node:assert/strict';
import {execFileSync} from 'node:child_process';

const [context, namespace, release] = process.argv.slice(2);
assert.ok(context?.startsWith('k3d-helmforge-') && namespace && release);
const run = args => execFileSync('kubectl', ['--context', context, '-n', namespace, ...args], {
  encoding: 'utf8', timeout: 90000, stdio: ['ignore', 'pipe', 'pipe'],
});

const pods = JSON.parse(run(['get', 'pods', '-l', `app.kubernetes.io/instance=${release}`, '-o', 'json'])).items;
const pod = pods.find(item => item.metadata.labels?.['app.kubernetes.io/component'] !== 'backtest'
  && item.status.conditions?.some(condition => condition.type === 'Ready' && condition.status === 'True'));
if (pod) {
  const container = pod.spec.containers.find(item => item.name === 'nautilus-trader');
  assert.ok(container?.image.includes('@sha256:'), 'NautilusTrader image must use an immutable digest');
  const runnerPort = container.ports.find(port => port.name === 'runner')?.containerPort;
  assert.ok(runnerPort, 'Named runner container port required');
  assert.equal(pod.spec.securityContext.runAsNonRoot, true);
  assert.equal(container.securityContext.readOnlyRootFilesystem, true);
  const check = path => run(['exec', pod.metadata.name, '-c', 'nautilus-trader', '--', 'python', '-c',
    `import urllib.request; print(urllib.request.urlopen('http://127.0.0.1:${runnerPort}${path}').read().decode())`]);
  assert.match(check('/healthz'), /ok/);
  assert.match(check('/readyz'), /ready/);
  assert.match(check('/metrics'), /nautilus_runner_up 1/);
  const version = run(['exec', pod.metadata.name, '-c', 'nautilus-trader', '--', 'python', '-c',
    'import nautilus_trader; print(nautilus_trader.__version__)']);
  assert.ok(version.trim(), 'NautilusTrader import must expose a version');
}

const jobs = JSON.parse(run(['get', 'jobs', '-l', `app.kubernetes.io/instance=${release}`, '-o', 'json'])).items;
for (const job of jobs) {
  run(['wait', '--for=condition=complete', `job/${job.metadata.name}`, '--timeout=180s']);
}
assert.ok(pod || jobs.length, 'Ready live pod or completed backtest Job required');
console.log('NautilusTrader import, immutable image, hardened runtime, runner endpoints and batch completion verified');
