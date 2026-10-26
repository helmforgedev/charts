// SPDX-License-Identifier: Apache-2.0
import { execFileSync } from 'node:child_process';

const [context, namespace, release] = process.argv.slice(2);
if (!context || !namespace || !release) {
  throw new Error('usage: runtime-smoke.mjs <context> <namespace> <release>');
}

const kubectl = (args) =>
  execFileSync('kubectl', ['--context', context, '-n', namespace, ...args], {
    encoding: 'utf8',
    timeout: 120000,
  }).trim();

const podFor = (component) =>
  kubectl([
    'get',
    'pod',
    '-l',
    `app.kubernetes.io/instance=${release},app.kubernetes.io/name=opensign,app.kubernetes.io/component=${component}`,
    '-o',
    'jsonpath={.items[0].metadata.name}',
  ]);

const listenerFor = (component) => {
  const deployments = JSON.parse(kubectl([
    'get',
    'deployment',
    '-l',
    `app.kubernetes.io/instance=${release},app.kubernetes.io/name=opensign,app.kubernetes.io/component=${component}`,
    '-o',
    'json',
  ])).items;
  if (deployments.length !== 1) throw new Error(`expected one ${component} Deployment`);
  const container = deployments[0].spec.template.spec.containers.find((item) => item.name === component);
  const port = container?.ports?.find((item) => item.name === 'http')?.containerPort;
  const portEnvironment = container?.env?.find((item) => item.name === 'PORT')?.value;
  if (!Number.isInteger(port) || portEnvironment !== String(port)) {
    throw new Error(`${component} PORT must match its named HTTP container port`);
  }
  return port;
};

const backend = podFor('backend');
const frontend = podFor('frontend');
if (!backend || !frontend) throw new Error('OpenSign frontend or backend pod not found');
const backendPort = listenerFor('backend');
const frontendPort = listenerFor('frontend');

const backendHealth = kubectl([
  'exec',
  backend,
  '-c',
  'backend',
  '--',
  'node',
  '-e',
  `fetch('http://127.0.0.1:${backendPort}/').then(async r=>{const b=await r.text();if(!r.ok||!b.includes('opensign-server is running'))throw new Error(r.status+' '+b);console.log(b)})`,
]);
const frontendHealth = kubectl([
  'exec',
  frontend,
  '-c',
  'frontend',
  '--',
  'node',
  '-e',
  `fetch('http://127.0.0.1:${frontendPort}/').then(async r=>{const b=await r.text();if(!r.ok||!b.includes('<html'))throw new Error(r.status+' '+b);console.log('frontend ok')})`,
]);
if (!backendHealth.includes('opensign-server is running') || !frontendHealth.includes('frontend ok')) {
  throw new Error('unexpected OpenSign health response');
}

for (const [pod, container] of [
  [backend, 'backend'],
  [frontend, 'frontend'],
]) {
  const uid = kubectl(['exec', pod, '-c', container, '--', 'id', '-u']);
  if (uid !== '1000') throw new Error(`${container} expected UID 1000, got ${uid}`);
}

const deployment = kubectl([
  'get',
  'deployment',
  '-l',
  `app.kubernetes.io/instance=${release},app.kubernetes.io/component=backend`,
  '-o',
  'jsonpath={.items[0].metadata.name}',
]);
const secretName = kubectl([
  'get',
  'deployment',
  deployment,
  '-o',
  'jsonpath={.spec.template.spec.containers[0].env[?(@.name=="MASTER_KEY")].valueFrom.secretKeyRef.name}',
]);
const masterKey = kubectl(['get', 'secret', secretName, '-o', 'jsonpath={.data.master-key}']);
if (!masterKey) throw new Error('OpenSign master key is empty');

console.log('frontend and backend healthy; uid=1000; master key retained');
