// SPDX-License-Identifier: Apache-2.0
import assert from 'node:assert/strict';
import {execFileSync, spawn} from 'node:child_process';

const [context, namespace, release] = process.argv.slice(2);
assert.match(context ?? '', /^k3d-/);
assert.ok(namespace && release);

const kubectl = args => execFileSync(
  'kubectl',
  ['--context', context, '-n', namespace, ...args],
  {encoding: 'utf8', timeout: 60_000, stdio: ['ignore', 'pipe', 'pipe']},
);
const helm = args => execFileSync(
  'helm',
  ['--kube-context', context, '-n', namespace, ...args],
  {encoding: 'utf8', timeout: 60_000, stdio: ['ignore', 'pipe', 'pipe']},
);

const deployedValues = JSON.parse(helm(['get', 'values', release, '--all', '-o', 'json']));
const expectedHttpPort = deployedValues.containerPorts?.http;
const expectedServicePort = deployedValues.service?.port;
assert.ok(Number.isInteger(expectedHttpPort), 'Bulwark HTTP listener value is required');
assert.ok(Number.isInteger(expectedServicePort), 'Bulwark Service port value is required');

const pods = JSON.parse(kubectl([
  'get', 'pods', '-l', `app.kubernetes.io/instance=${release}`, '-o', 'json',
])).items;
const pod = pods.find(item => !item.metadata.deletionTimestamp
  && item.status.conditions?.some(condition => condition.type === 'Ready' && condition.status === 'True')
  && item.spec.containers.some(container => container.name === 'bulwark-mail'));
assert.ok(pod, 'Ready Bulwark Mail pod required');

const container = pod.spec.containers.find(item => item.name === 'bulwark-mail');
assert.equal(container.image, 'ghcr.io/bulwarkmail/webmail:1.15.0-always');
assert.equal(container.securityContext.runAsNonRoot, true);
assert.equal(container.securityContext.readOnlyRootFilesystem, true);
assert.equal(
  container.ports?.find(port => port.name === 'http')?.containerPort,
  expectedHttpPort,
  'Bulwark container port must match the deployed listener value',
);
const env = Object.fromEntries(container.env.filter(item => 'value' in item).map(item => [item.name, item.value]));
assert.equal(env.PORT, String(expectedHttpPort), 'PORT must configure the real Bulwark listener');
const expectedJmap = env.JMAP_SERVER_URL || '';
const declarative = expectedJmap.length > 0;

const program = `
const assert = require('node:assert/strict');
const base = 'http://127.0.0.1:${expectedHttpPort}';
const declarative = ${JSON.stringify(declarative)};
const expectedJmap = ${JSON.stringify(expectedJmap)};
const healthResponse = await fetch(base + '/api/health');
assert.equal(healthResponse.status, 200);
const health = await healthResponse.json();
assert.equal(health.status, 'healthy');
const rootResponse = await fetch(base + '/', {redirect: 'manual'});
if (declarative) {
  const setupResponse = await fetch(base + '/api/setup/status', {redirect: 'manual'});
  assert.equal(setupResponse.status, 404);
  const configResponse = await fetch(base + '/api/config');
  assert.equal(configResponse.status, 200);
  const config = await configResponse.json();
  assert.equal(config.appName, 'Bulwark Webmail');
  assert.equal(config.jmapServerUrl, expectedJmap);
  assert.equal(config.rememberMeEnabled, true);
  assert.equal(config.settingsSyncEnabled, true);
  assert.match(rootResponse.headers.get('location') || '', /^\\/en(?:\\/|$)/);
} else {
  const setupResponse = await fetch(base + '/api/setup/status', {redirect: 'manual'});
  assert.equal(setupResponse.status, 200);
  const setup = await setupResponse.json();
  assert.equal(setup.state, 'bootstrap');
  assert.equal(setup.authenticated, false);
  assert.equal(setup.readOnly, false);
  assert.match(rootResponse.headers.get('location') || '', /^\\/setup(?:\\/|$)/);
}
console.log('Bulwark 1.15.0 health, config, session, settings, and setup-mode contract verified');
`;

const result = kubectl([
  'exec', pod.metadata.name, '-c', 'bulwark-mail', '--',
  'node', '--input-type=commonjs', '-e',
  `(async()=>{${program}})().catch(error=>{console.error(error);process.exit(1)})`,
]);
console.log(result.trim());

const services = JSON.parse(kubectl([
  'get', 'services', '-l', `app.kubernetes.io/instance=${release}`, '-o', 'json',
])).items;
const service = services.find(item => item.spec.ports?.some(port => port.name === 'http'));
assert.ok(service, 'Bulwark HTTP Service is required');
const serviceHttp = service.spec.ports.find(port => port.name === 'http');
assert.equal(serviceHttp.port, expectedServicePort, 'Service must expose the deployed Service port value');
assert.equal(serviceHttp.targetPort, 'http');

const forward = spawn(
  'kubectl',
  [
    '--context', context, '-n', namespace,
    'port-forward', `service/${service.metadata.name}`, `:${serviceHttp.port}`,
    '--address=127.0.0.1',
  ],
  {windowsHide: true, stdio: ['ignore', 'pipe', 'pipe']},
);
let forwardOutput = '';
for (const stream of [forward.stdout, forward.stderr]) {
  stream.on('data', chunk => { forwardOutput += chunk; });
}

try {
  const deadline = Date.now() + 20_000;
  while (!/127\.0\.0\.1:(\d+) ->/.test(forwardOutput) && Date.now() < deadline && forward.exitCode === null) {
    await new Promise(resolve => setTimeout(resolve, 100));
  }
  const localPort = forwardOutput.match(/127\.0\.0\.1:(\d+) ->/)?.[1];
  assert.ok(localPort, `Bulwark Service port-forward unavailable: ${forwardOutput}`);
  const response = await fetch(`http://127.0.0.1:${localPort}/api/health`, {
    signal: AbortSignal.timeout(10_000),
  });
  assert.equal(response.status, 200, 'Bulwark health endpoint must be reachable through the Service');
} finally {
  if (process.platform === 'win32' && forward.exitCode === null) {
    try {
      execFileSync('taskkill', ['/PID', String(forward.pid), '/T', '/F'], {stdio: 'ignore'});
    } catch (error) {
      let exited = false;
      try { process.kill(forward.pid, 0); } catch (processError) {
        if (processError.code === 'ESRCH') exited = true;
        else throw processError;
      }
      if (!exited) throw error;
    }
  } else {
    forward.kill();
  }
}

console.log(`Bulwark listener ${expectedHttpPort}, independent Service port ${expectedServicePort}, official image, and hardened runtime verified`);
