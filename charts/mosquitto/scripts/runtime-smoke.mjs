// SPDX-License-Identifier: Apache-2.0
import assert from 'node:assert/strict';
import {execFileSync, spawn} from 'node:child_process';

const [context, namespace, release] = process.argv.slice(2);
if (context !== 'k3d-helmforge-tests-wsl' || !namespace?.startsWith('hf-') || !release) {
  throw new Error('Explicit owned HelmForge lab context, namespace and release required');
}

const run = (command, args, options = {}) => execFileSync(command, args, {
  encoding: 'utf8', timeout: 180000, maxBuffer: 4 * 1024 * 1024, ...options,
});
const kubectlArgs = args => ['--context', context, '-n', namespace, ...args];
const kubectl = args => run('kubectl', kubectlArgs(args));
const values = JSON.parse(run('helm', [
  'get', 'values', release, '--namespace', namespace, '--kube-context', context, '-a', '-o', 'json',
]));
const selector = `app.kubernetes.io/instance=${release},app.kubernetes.io/component=broker`;
const pods = JSON.parse(kubectl(['get', 'pods', '-l', selector, '-o', 'json'])).items
  .filter(item => !item.metadata.deletionTimestamp)
  .sort((a, b) => a.metadata.name.localeCompare(b.metadata.name));
assert.equal(pods.length, values.broker.replicaCount, 'Expected every configured broker pod');
for (const pod of pods) {
  assert.ok(pod.status.conditions?.some(condition => condition.type === 'Ready' && condition.status === 'True'));
  assert.equal(pod.spec.automountServiceAccountToken, values.serviceAccount.automountServiceAccountToken);
  assert.equal(pod.spec.securityContext.runAsUser, 1883);
  const container = pod.spec.containers.find(item => item.name === 'mosquitto');
  const init = pod.spec.initContainers.find(item => item.name === 'generate-runtime-files');
  assert.ok(container && init, 'Broker and runtime-file init containers are required');
  assert.equal(container.image, `${values.image.repository}:${values.image.tag}`);
  assert.equal(container.securityContext.readOnlyRootFilesystem, true);
  assert.deepEqual(container.securityContext.capabilities.drop, ['ALL']);
  assert.equal(init.securityContext.allowPrivilegeEscalation, false);
}

const services = JSON.parse(kubectl(['get', 'services', '-l', `app.kubernetes.io/instance=${release}`, '-o', 'json'])).items;
const service = services.find(item => item.spec.clusterIP !== 'None'
  && item.spec.selector?.['app.kubernetes.io/component'] === 'broker');
assert.ok(service, 'The broker client Service is required');
for (const port of service.spec.ports) assert.equal(typeof port.targetPort, 'string');

const authSecret = values.auth.enabled
  ? JSON.parse(kubectl(values.auth.existingSecret
    ? ['get', 'secret', values.auth.existingSecret, '-o', 'json']
    : ['get', 'secrets', '-l', `app.kubernetes.io/instance=${release}`, '-o', 'json'])).items?.[0]
      || JSON.parse(kubectl(['get', 'secret', values.auth.existingSecret, '-o', 'json']))
  : null;
if (values.auth.enabled) assert.ok(authSecret?.data, 'The effective authentication Secret is required');
const secretValue = key => Buffer.from(authSecret.data[key], 'base64').toString('utf8');
const clientFlags = () => {
  const args = [];
  if (values.broker.tls.enabled) {
    args.push('-p', String(values.broker.tls.port), '--cafile', `/mosquitto/config/tls/${values.broker.tls.caFile || values.broker.tls.certFile}`);
    if (values.broker.tls.requireCertificate) args.push('--cert', `/mosquitto/config/tls/${values.broker.tls.certFile}`, '--key', `/mosquitto/config/tls/${values.broker.tls.keyFile}`);
    args.push('--insecure');
  } else {
    args.push('-p', String(values.broker.listeners.mqtt));
  }
  if (values.auth.enabled) args.push('-u', secretValue(values.auth.existingSecretUsernameKey), '-P', secretValue(values.auth.existingSecretPasswordKey));
  return args;
};

const topic = `helmforge/smoke/${Date.now()}`;
const payload = `mosquitto-${values.image.tag}`;
const subscriberPod = values.architecture.mode === 'federated' ? pods.at(-1) : pods[0];
const publisherPod = pods[0];
const subArgs = kubectlArgs([
  'exec', subscriberPod.metadata.name, '-c', 'mosquitto', '--',
  'mosquitto_sub', '-h', 'localhost', ...clientFlags(), '-t', topic, '-C', '1', '-W', '30',
]);
const subscriber = spawn('kubectl', subArgs, {stdio: ['ignore', 'pipe', 'pipe']});
let stdout = '';
let stderr = '';
subscriber.stdout.on('data', chunk => { stdout += chunk; });
subscriber.stderr.on('data', chunk => { stderr += chunk; });
await new Promise(resolve => setTimeout(resolve, 1500));
kubectl([
  'exec', publisherPod.metadata.name, '-c', 'mosquitto', '--',
  'mosquitto_pub', '-h', 'localhost', ...clientFlags(), '-t', topic, '-m', payload,
]);
const exitCode = await new Promise((resolve, reject) => {
  const timer = setTimeout(() => {
    subscriber.kill();
    reject(new Error(`MQTT subscriber timed out: ${stderr}`));
  }, 45000);
  subscriber.once('error', reject);
  subscriber.once('close', code => {
    clearTimeout(timer);
    resolve(code);
  });
});
assert.equal(exitCode, 0, stderr);
assert.equal(stdout.trim(), payload, 'MQTT publish/subscribe payload mismatch');

if (values.mqttxWeb.enabled) {
  const mqttxPods = JSON.parse(kubectl([
    'get', 'pods', '-l', `app.kubernetes.io/instance=${release},app.kubernetes.io/component=mqttx-web`, '-o', 'json',
  ])).items;
  const mqttxPod = mqttxPods.find(item => item.status.conditions?.some(condition => condition.type === 'Ready' && condition.status === 'True'));
  assert.ok(mqttxPod, 'A Ready MQTTX Web pod is required');
  const container = mqttxPod.spec.containers.find(item => item.name === 'mqttx-web');
  assert.equal(container.image, `${values.mqttxWeb.image.repository}:${values.mqttxWeb.image.tag}`);
  assert.equal(container.ports.find(port => port.name === 'http')?.containerPort, values.mqttxWeb.containerPort);
  assert.equal(container.args.at(-1), String(values.mqttxWeb.containerPort));
  assert.equal(container.securityContext.readOnlyRootFilesystem, true);
  assert.equal(mqttxPod.spec.automountServiceAccountToken, false);
  const mqttxService = services.find(item => item.spec.selector?.['app.kubernetes.io/component'] === 'mqttx-web');
  assert.ok(mqttxService, 'The MQTTX Web Service is required');
  const page = kubectl(['get', '--raw', `/api/v1/namespaces/${namespace}/services/http:${mqttxService.metadata.name}:http/proxy/`]);
  assert.match(page, /MQTTX|<html/i, 'MQTTX Web Service must return the application');
}

console.log(`PASS Mosquitto ${values.image.tag}: MQTT publish/subscribe on ${values.architecture.mode} topology${values.mqttxWeb.enabled ? ' with MQTTX Web' : ''}.`);
