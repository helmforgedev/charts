// SPDX-License-Identifier: Apache-2.0
import assert from 'node:assert/strict';
import {execFileSync} from 'node:child_process';

const [context, namespace, release] = process.argv.slice(2);
if (context !== 'k3d-helmforge-tests-wsl' || !namespace?.startsWith('hf-') || !release) {
  throw new Error('Explicit owned HelmForge lab context, namespace and release required');
}

const run = (command, args, options = {}) => execFileSync(command, args, {
  encoding: 'utf8',
  timeout: 180000,
  maxBuffer: 4 * 1024 * 1024,
  ...options,
});
const kubectl = args => run('kubectl', ['--context', context, '-n', namespace, ...args]);
const values = JSON.parse(run('helm', [
  'get', 'values', release, '--namespace', namespace, '--kube-context', context, '-a', '-o', 'json',
]));
const selector = `app.kubernetes.io/instance=${release},app.kubernetes.io/component=server`;
const pods = JSON.parse(kubectl(['get', 'pods', '-l', selector, '-o', 'json'])).items;
const pod = pods.find(item => !item.metadata.deletionTimestamp
  && item.status.conditions?.some(condition => condition.type === 'Ready' && condition.status === 'True'));
assert.ok(pod, 'A Ready Heimdall server pod is required');

const container = pod.spec.containers.find(item => item.name === 'heimdall');
assert.ok(container, 'The Heimdall container is missing');
assert.equal(container.image, `${values.image.repository}:${values.image.tag}`, 'The effective image must match values');
assert.equal(container.ports.find(port => port.name === 'http')?.containerPort, values.heimdall.containerPort);
assert.equal(container.env.find(variable => variable.name === 'HELMFORGE_HTTP_PORT')?.value, String(values.heimdall.containerPort));
assert.equal(pod.spec.automountServiceAccountToken, values.serviceAccount.automountServiceAccountToken);

const services = JSON.parse(kubectl(['get', 'services', '-l', `app.kubernetes.io/instance=${release}`, '-o', 'json'])).items;
const service = services.find(item => item.spec.ports.some(port => port.name === 'http'));
assert.ok(service, 'The Heimdall HTTP Service is missing');
const http = service.spec.ports.find(port => port.name === 'http');
assert.equal(http.port, values.service.port);
assert.equal(http.targetPort, 'http');

const config = kubectl([
  'exec', pod.metadata.name, '-c', 'heimdall', '--',
  'sh', '-ec', 'grep -E "^[[:space:]]*listen[[:space:]]+' + values.heimdall.containerPort + '[[:space:]]+default_server;" /config/nginx/site-confs/default.conf',
]);
assert.ok(config.includes(String(values.heimdall.containerPort)), 'NGINX must use the configured listener');

const proxyPath = `/api/v1/namespaces/${namespace}/services/http:${service.metadata.name}:http/proxy/`;
const page = kubectl(['get', '--raw', proxyPath]);
assert.match(page, /heimdall/i, 'Service proxy must return the Heimdall application');

const buildVersion = kubectl(['exec', pod.metadata.name, '-c', 'heimdall', '--', 'cat', '/build_version']).trim();
assert.match(buildVersion, /Linuxserver\.io version: v\d+\.\d+\.\d+-ls\d+/, 'The running image must report valid LinuxServer build metadata');

if (values.persistence.enabled) {
  const marker = `helmforge-${Date.now()}`;
  const result = kubectl([
    'exec', pod.metadata.name, '-c', 'heimdall', '--', 's6-setuidgid', 'abc', 'sh', '-ec',
    `test "$(id -u)" = '${values.heimdall.puid}' && test "$(id -g)" = '${values.heimdall.pgid}' && printf '%s' '${marker}' > /config/.helmforge-smoke && cat /config/.helmforge-smoke && rm /config/.helmforge-smoke`,
  ]).trim();
  assert.equal(result, marker, 'The configured PUID/PGID path must remain writable');
}

console.log(`PASS Heimdall ${values.image.tag}, HTTP listener ${values.heimdall.containerPort}, Service port ${values.service.port}, application response, and /config write.`);
