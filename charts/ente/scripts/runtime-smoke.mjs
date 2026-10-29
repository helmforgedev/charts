// SPDX-License-Identifier: Apache-2.0
import assert from 'node:assert/strict';
import { execFileSync, spawn } from 'node:child_process';

const [context, namespace, release] = process.argv.slice(2);
assert.match(context ?? '', /^k3d-/);
assert.ok(namespace && release);

const kubectl = args => execFileSync(
  'kubectl',
  ['--context', context, '-n', namespace, ...args],
  { encoding: 'utf8', timeout: 60_000, stdio: ['ignore', 'pipe', 'pipe'] },
);

const pods = JSON.parse(kubectl([
  'get', 'pods',
  '-l', `app.kubernetes.io/instance=${release},app.kubernetes.io/name=ente`,
  '-o', 'json',
])).items.filter(pod => !pod.metadata.deletionTimestamp);
const museumPods = pods.filter(pod => ['museum-api', 'museum-worker'].includes(
  pod.metadata.labels?.['app.kubernetes.io/component'],
));
assert.ok(museumPods.length >= 1, 'At least one Museum pod is required');

let httpPort;
for (const pod of museumPods) {
  assert.ok(
    pod.status.conditions?.some(condition => condition.type === 'Ready' && condition.status === 'True'),
    `Museum pod ${pod.metadata.name} must be Ready`,
  );
  const museum = pod.spec.containers.find(container => container.name === 'museum');
  assert.ok(museum, `Museum container missing from ${pod.metadata.name}`);
  const podHttpPort = museum.ports?.find(port => port.name === 'http')?.containerPort;
  assert.ok(Number.isInteger(podHttpPort), 'Named Museum HTTP container port is required');
  httpPort ??= podHttpPort;
  assert.equal(podHttpPort, httpPort, 'All Museum processes must use the same HTTP listener');
  assert.equal(museum.ports?.find(port => port.name === 'metrics')?.containerPort, 2112);
  assert.equal(museum.image, 'ghcr.io/ente/server:0472c929b6070e61fecaf2013d47efce2dcda462');
  assert.equal(museum.securityContext.runAsNonRoot, true);
  assert.equal(museum.securityContext.readOnlyRootFilesystem, true);
}

const configMaps = JSON.parse(kubectl([
  'get', 'configmaps',
  '-l', `app.kubernetes.io/instance=${release},app.kubernetes.io/name=ente`,
  '-o', 'json',
])).items;
const config = configMaps.find(item => item.data?.['museum-api.yaml'] && item.data?.['museum-worker.yaml']);
assert.ok(config, 'Ente runtime ConfigMap is required');
for (const key of ['museum-api.yaml', 'museum-worker.yaml']) {
  assert.match(config.data?.[key] ?? '', new RegExp(`http:\\s*\\n\\s*port:\\s*${httpPort}(?:\\s|$)`));
}

const services = JSON.parse(kubectl([
  'get', 'services',
  '-l', `app.kubernetes.io/instance=${release},app.kubernetes.io/name=ente,app.kubernetes.io/component=museum-api`,
  '-o', 'json',
])).items;
const service = services.find(item => item.spec.ports?.some(port => port.name === 'http'));
assert.ok(service, 'Museum HTTP Service is required');
const serviceHttp = service.spec.ports.find(port => port.name === 'http');
assert.ok(serviceHttp, 'Museum HTTP Service port is required');
assert.equal(serviceHttp.targetPort, 'http');

const forward = spawn(
  'kubectl',
  [
    '--context', context, '-n', namespace,
    'port-forward', `service/${service.metadata.name}`, `:${serviceHttp.port}`,
    '--address=127.0.0.1',
  ],
  { windowsHide: true, stdio: ['ignore', 'pipe', 'pipe'] },
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
  assert.ok(localPort, `Museum Service port-forward unavailable: ${forwardOutput}`);
  const response = await fetch(`http://127.0.0.1:${localPort}/ping`, {
    signal: AbortSignal.timeout(10_000),
  });
  assert.equal(response.status, 200, 'Museum /ping must be reachable through the Service');
} finally {
  if (process.platform === 'win32' && forward.exitCode === null) {
    try {
      execFileSync('taskkill', ['/PID', String(forward.pid), '/T', '/F'], { stdio: 'ignore' });
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

console.log(`Museum listener ${httpPort}, independent Service port ${serviceHttp.port}, fixed metrics port, official image, and hardened runtime verified`);
