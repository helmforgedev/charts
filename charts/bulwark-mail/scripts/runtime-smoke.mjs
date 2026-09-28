// SPDX-License-Identifier: Apache-2.0
import assert from 'node:assert/strict';
import {execFileSync} from 'node:child_process';

const [context, namespace, release] = process.argv.slice(2);
assert.ok(context?.startsWith('k3d-helmforge-') && namespace && release);

const run = args => execFileSync('kubectl', ['--context', context, '-n', namespace, ...args], {
  encoding: 'utf8', timeout: 60000, stdio: ['ignore', 'pipe', 'pipe'],
});

const pods = JSON.parse(run(['get', 'pods', '-l', `app.kubernetes.io/instance=${release}`, '-o', 'json'])).items;
const pod = pods.find(item => !item.metadata.deletionTimestamp
  && item.status.conditions?.some(condition => condition.type === 'Ready' && condition.status === 'True')
  && item.spec.containers.some(container => container.name === 'bulwark-mail'));
assert.ok(pod, 'Ready Bulwark Mail pod required');

const container = pod.spec.containers.find(item => item.name === 'bulwark-mail');
assert.equal(container.image, 'ghcr.io/bulwarkmail/webmail:1.11.2-always');
const env = Object.fromEntries(container.env.filter(item => 'value' in item).map(item => [item.name, item.value]));
const expectedJmap = env.JMAP_SERVER_URL || '';
const declarative = expectedJmap.length > 0;

const program = `
const assert = require('node:assert/strict');
const base = 'http://127.0.0.1:3000';
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
console.log('Bulwark 1.11.2 health, config, session, settings, and setup-mode contract verified');
`;

const result = run(['exec', pod.metadata.name, '-c', 'bulwark-mail', '--', 'node', '--input-type=commonjs', '-e', `(async()=>{${program}})().catch(error=>{console.error(error);process.exit(1)})`]);
console.log(result.trim());
