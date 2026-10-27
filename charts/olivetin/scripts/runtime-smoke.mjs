// SPDX-License-Identifier: Apache-2.0
import assert from 'node:assert/strict';
import { execFileSync, spawn } from 'node:child_process';

const [context, namespace, release] = process.argv.slice(2);
assert.match(context ?? '', /^k3d-/);
assert.ok(namespace && release);

const kubectl = (args) =>
  execFileSync('kubectl', ['--context', context, '-n', namespace, ...args], {
    encoding: 'utf8',
    timeout: 120_000,
  });

const selector = `app.kubernetes.io/instance=${release},app.kubernetes.io/name=olivetin`;
const services = JSON.parse(kubectl(['get', 'services', '-l', selector, '-o', 'json']));
const service = services.items.find((item) => item.spec?.ports?.some((port) => port.name === 'http'));
assert.ok(service, 'OliveTin Service with named http port not found');

const pods = JSON.parse(kubectl(['get', 'pods', '-l', selector, '-o', 'json']));
const pod = pods.items.find(
  (item) =>
    !item.metadata.deletionTimestamp &&
    item.status.conditions?.some((condition) => condition.type === 'Ready' && condition.status === 'True'),
);
assert.ok(pod, 'Ready OliveTin pod not found');
const container = pod.spec.containers.find((item) => item.name === 'olivetin');
assert.ok(container, 'OliveTin container not found');
assert.match(container.image, /:3000\.20\.0$/);

const httpContainerPort = container.ports.find((port) => port.name === 'http')?.containerPort;
const portEnvironment = container.env.find((entry) => entry.name === 'PORT')?.value;
assert.equal(portEnvironment, String(httpContainerPort), 'PORT must match the named HTTP container port');

const fetchForwarded = async (remotePort, path) => {
  const child = spawn(
    'kubectl',
    [
      '--context',
      context,
      '-n',
      namespace,
      'port-forward',
      `service/${service.metadata.name}`,
      `0:${remotePort}`,
      '--address=127.0.0.1',
    ],
    { windowsHide: true, stdio: ['ignore', 'pipe', 'pipe'] },
  );

  let output = '';
  for (const stream of [child.stdout, child.stderr]) {
    stream.on('data', (chunk) => {
      output += chunk;
    });
  }

  try {
    const deadline = Date.now() + 20_000;
    while (!/Forwarding from/.test(output) && Date.now() < deadline && child.exitCode === null) {
      await new Promise((resolve) => setTimeout(resolve, 100));
    }

    const localPort = output.match(/127\.0\.0\.1:(\d+)/)?.[1];
    assert.ok(localPort, output);
    return await fetch(`http://127.0.0.1:${localPort}${path}`, {
      signal: AbortSignal.timeout(30_000),
    });
  } finally {
    if (child.exitCode === null && child.signalCode === null) {
      if (process.platform === 'win32') {
        execFileSync('taskkill', ['/PID', String(child.pid), '/T', '/F'], { stdio: 'ignore' });
      } else {
        child.kill();
      }
    }
  }
};

const httpServicePort = service.spec.ports.find((port) => port.name === 'http')?.port;
assert.ok(Number.isInteger(httpServicePort), 'OliveTin Service http port is not numeric');
const applicationResponse = await fetchForwarded(httpServicePort, '/');
assert.equal(applicationResponse.status, 200);
const applicationBody = await applicationResponse.text();
assert.match(applicationBody, /OliveTin/i);

const metricsServicePort = service.spec.ports.find((port) => port.name === 'metrics')?.port;
if (metricsServicePort !== undefined) {
  const metricsContainerPort = container.ports.find((port) => port.name === 'metrics')?.containerPort;
  assert.equal(metricsContainerPort, metricsServicePort);
  const configMap = JSON.parse(
    kubectl(['get', 'configmap', `${service.metadata.name}-config`, '-o', 'json']),
  );
  assert.match(configMap.data['config.yaml'], new RegExp(`listenAddressPrometheus: 0\\.0\\.0\\.0:${metricsServicePort}`));
  assert.match(configMap.data['config.yaml'], /prometheus:\n(?:.*\n)*?  enabled: true/);

  const metricsResponse = await fetchForwarded(metricsServicePort, '/metrics');
  assert.equal(metricsResponse.status, 200);
  assert.match(metricsResponse.headers.get('content-type') ?? '', /text\/plain|openmetrics/i);
  const metricsBody = await metricsResponse.text();
  assert.ok(metricsBody.length > 50, 'Prometheus response is unexpectedly empty');
}

console.log(
  `PASS OliveTin 3000.20.0 UI verified on ${httpContainerPort}; metrics=${metricsServicePort ?? 'disabled'}`,
);
