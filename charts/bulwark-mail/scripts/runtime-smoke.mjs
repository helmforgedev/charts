// SPDX-License-Identifier: Apache-2.0
import assert from 'node:assert/strict';
import {execFileSync} from 'node:child_process';

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

const serviceChecker = `${release}-service-smoke-${process.pid}`.slice(0, 63).replace(/-+$/, '');
const serviceProgram = `
const assert = require('node:assert/strict');
const url = 'http://${service.metadata.name}:${serviceHttp.port}/api/health';
let response;
let lastError;
const deadline = Date.now() + 30000;
while (Date.now() < deadline) {
  try {
    response = await fetch(url, {signal: AbortSignal.timeout(3000)});
    if (response.status === 200) break;
    lastError = new Error('unexpected HTTP status ' + response.status);
  } catch (error) {
    lastError = error;
  }
  await new Promise(resolve => setTimeout(resolve, 500));
}
assert.ok(response, 'Bulwark Service request failed: ' + (lastError?.cause?.message || lastError?.message));
assert.equal(response.status, 200);
const health = await response.json();
assert.equal(health.status, 'healthy');
console.log('Bulwark Service DNS and ClusterIP routing verified');
`;
try {
  const serviceResult = kubectl([
    'run', serviceChecker,
    '--rm', '--attach', '--restart=Never',
    `--image=${container.image}`,
    '--image-pull-policy=IfNotPresent',
    '--labels=helmforge.dev/runtime-smoke=true',
    '--command', '--',
    'node', '--input-type=commonjs', '-e',
    `(async()=>{${serviceProgram}})().catch(error=>{console.error(error);process.exit(1)})`,
  ]);
  console.log(serviceResult.trim());
} finally {
  kubectl(['delete', 'pod', serviceChecker, '--ignore-not-found=true', '--wait=false']);
}

console.log(`Bulwark listener ${expectedHttpPort}, independent Service port ${expectedServicePort}, official image, and hardened runtime verified`);
