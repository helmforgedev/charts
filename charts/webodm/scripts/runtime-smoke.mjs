// SPDX-License-Identifier: Apache-2.0
import assert from 'node:assert/strict';
import {execFileSync} from 'node:child_process';

const [context, namespace, release] = process.argv.slice(2);
if (context !== 'k3d-helmforge-tests-wsl' || !namespace?.startsWith('hf-') || !release) {
  throw new Error('Explicit owned HelmForge lab context, namespace and release required');
}

const run = (command, args, options = {}) => execFileSync(command, args, {
  encoding: 'utf8', timeout: 180000, maxBuffer: 4 * 1024 * 1024, ...options,
});
const kubectl = args => run('kubectl', ['--context', context, '-n', namespace, ...args]);
const values = JSON.parse(run('helm', [
  'get', 'values', release, '--namespace', namespace, '--kube-context', context, '-a', '-o', 'json',
]));
const podsFor = component => JSON.parse(kubectl([
  'get', 'pods', '-l', `app.kubernetes.io/instance=${release},app.kubernetes.io/component=${component}`, '-o', 'json',
])).items.filter(item => !item.metadata.deletionTimestamp);
const onlyReadyPod = component => {
  const pods = podsFor(component);
  assert.equal(pods.length, 1, `Expected exactly one ${component} pod`);
  assert.ok(pods[0].status.conditions?.some(condition => condition.type === 'Ready' && condition.status === 'True'));
  return pods[0];
};

const webPod = onlyReadyPod('web');
const workerPods = podsFor('worker');
assert.equal(workerPods.length, values.worker.replicaCount, 'Expected every configured Celery worker pod');
for (const pod of workerPods) {
  assert.ok(pod.status.conditions?.some(condition => condition.type === 'Ready' && condition.status === 'True'));
}

for (const pod of [webPod, ...workerPods]) {
  assert.equal(pod.spec.automountServiceAccountToken, false);
  assert.equal(pod.spec.securityContext.seccompProfile.type, 'RuntimeDefault');
  const container = pod.spec.containers[0];
  assert.equal(container.securityContext.allowPrivilegeEscalation, false);
  assert.ok(container.securityContext.capabilities.drop.includes('ALL'));
}

const webContainer = webPod.spec.containers.find(container => container.name === 'webodm');
assert.ok(webContainer, 'WebODM container is required');
assert.equal(webContainer.image, `${values.image.repository}:${values.image.tag}@${values.image.digest}`);
assert.equal(webContainer.ports.find(port => port.name === 'http')?.containerPort, values.web.containerPort);
assert.equal(webContainer.env.find(item => item.name === 'WO_PORT')?.value, String(values.web.containerPort));
kubectl([
  'exec', webPod.metadata.name, '-c', 'webodm', '--', '/bin/bash', '-ec',
  'test "$WO_PORT" = "$1" && curl --fail --silent --show-error "http://127.0.0.1:${WO_PORT}/" >/dev/null',
  'runtime-smoke', String(values.web.containerPort),
]);

const services = JSON.parse(kubectl([
  'get', 'services', '-l', `app.kubernetes.io/instance=${release}`, '-o', 'json',
])).items;
const webService = services.find(item => item.spec.selector?.['app.kubernetes.io/component'] === 'web');
assert.ok(webService, 'WebODM Service is required');
assert.equal(webService.spec.ports[0].port, values.service.port);
assert.equal(webService.spec.ports[0].targetPort, 'http');

if (values.processing.enabled) {
  const processingPod = onlyReadyPod('processing');
  const container = processingPod.spec.containers.find(item => item.name === 'nodeodm');
  assert.ok(container, 'NodeODM container is required');
  const selectedImage = values.processing.gpu.enabled ? values.processing.gpu.image : values.processing.image;
  assert.equal(container.image, `${selectedImage.repository}:${selectedImage.tag}@${selectedImage.digest}`);
  assert.equal(container.ports.find(port => port.name === 'http')?.containerPort, values.processing.containerPort);
  assert.match(container.args.join(' '), new RegExp(`--port\\s+${values.processing.containerPort}(?:\\s|$)`));
  const processingService = services.find(item => item.spec.selector?.['app.kubernetes.io/component'] === 'processing');
  assert.ok(processingService, 'Private NodeODM Service is required');
  assert.equal(processingService.spec.type, 'ClusterIP');
  assert.equal(processingService.spec.ports[0].port, values.processingService.port);
  assert.equal(processingService.spec.ports[0].targetPort, 'http');
  kubectl([
    'exec', processingPod.metadata.name, '-c', 'nodeodm', '--', 'node', '-e',
    `const http=require('http');const req=http.get({host:'127.0.0.1',port:${values.processing.containerPort},path:'/info',headers:{Authorization:'Bearer '+process.env.PROCESSOR_TOKEN}},res=>{res.resume();res.on('end',()=>{if(res.statusCode<200||res.statusCode>=300)process.exit(2);});});req.on('error',()=>process.exit(3));req.setTimeout(30000,()=>{req.destroy();process.exit(4);});`,
  ]);
}

const policies = JSON.parse(kubectl([
  'get', 'networkpolicies', '-l', `app.kubernetes.io/instance=${release}`, '-o', 'json',
])).items;
assert.equal(policies.length, values.networkPolicy.enabled ? 1 : 0, 'NetworkPolicy state must match values');

console.log(`PASS WebODM ${values.image.tag}: web and authenticated NodeODM behavior verified on configured listeners.`);
