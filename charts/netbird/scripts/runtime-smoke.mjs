// SPDX-License-Identifier: Apache-2.0
import assert from 'node:assert/strict';
import { execFileSync, spawn } from 'node:child_process';
import { setTimeout as delay } from 'node:timers/promises';

if (Number(process.versions.node.split('.')[0]) < 22) {
  throw new Error('Node.js >= 22 is required for the relay WebSocket smoke test');
}

const [context, namespace, release] = process.argv.slice(2);
if (!context?.startsWith('k3d-helmforge-') || !namespace || !release) {
  throw new Error('Explicit HelmForge lab context, namespace and release required');
}

const target = ['--context', context, '-n', namespace];
const kubectl = (args) =>
  execFileSync('kubectl', [...target, ...args], {
    encoding: 'utf8',
    timeout: 30000,
    stdio: ['ignore', 'pipe', 'pipe'],
  });
const pods = JSON.parse(
  kubectl(['get', 'pods', '-l', `app.kubernetes.io/instance=${release}`, '-o', 'json']),
).items;
const readyPod = (containerName) =>
  pods.find(
    (pod) =>
      !pod.metadata.deletionTimestamp &&
      pod.status.conditions?.some((condition) => condition.type === 'Ready' && condition.status === 'True') &&
      pod.spec.containers.some((container) => container.name === containerName),
  );
const containerPort = (pod, containerName, portName) => {
  const container = pod.spec.containers.find((candidate) => candidate.name === containerName);
  const port = container?.ports?.find((candidate) => candidate.name === portName)?.containerPort;
  assert.ok(port, `${containerName} named port ${portName} required`);
  return port;
};

const serverPod = readyPod('server');
const dashboardPod = readyPod('dashboard');
assert.ok(serverPod, 'Ready NetBird server pod required');
assert.ok(dashboardPod, 'Ready NetBird dashboard pod required');

const serverHttpPort = containerPort(serverPod, 'server', 'http');
const metricsPort = containerPort(serverPod, 'server', 'metrics');
const dashboardHttpPort = containerPort(dashboardPod, 'dashboard', 'http');

let logs = '';
for (let index = 0; index < 360; index += 1) {
  logs = kubectl(['logs', serverPod.metadata.name, '-c', 'server']);
  if (logs.includes('running metrics server:')) break;
  await delay(1000);
}
assert.match(logs, /management server version 0\.81\.5\b/);
assert.match(logs, /running metrics server:/);

function forward(podName, remotePorts) {
  const child = spawn(
    'kubectl',
    [...target, 'port-forward', `pod/${podName}`, ...remotePorts.map((port) => `:${port}`), '--address=127.0.0.1'],
    { windowsHide: true, stdio: ['ignore', 'pipe', 'pipe'] },
  );
  const state = { child, output: '', error: null };
  child.stdout.on('data', (chunk) => {
    state.output += chunk;
  });
  child.stderr.on('data', () => {});
  child.on('error', (caught) => {
    state.error = caught;
  });
  return state;
}

async function forwardedPorts(state, expected) {
  const ports = {};
  for (let index = 0; index < 150 && Object.keys(ports).length < expected && !state.error; index += 1) {
    for (const match of state.output.matchAll(/127\.0\.0\.1:(\d+) -> (\d+)/g)) {
      ports[match[2]] = match[1];
    }
    await delay(100);
  }
  if (state.error) throw state.error;
  assert.equal(Object.keys(ports).length, expected, 'All port forwards required');
  return ports;
}

function stopForward(state) {
  if (state.child.exitCode !== null) return;
  if (process.platform === 'win32') {
    execFileSync('taskkill', ['/PID', String(state.child.pid), '/T', '/F'], { stdio: 'ignore' });
  } else {
    state.child.kill('SIGTERM');
  }
}

const serverForward = forward(serverPod.metadata.name, [serverHttpPort, metricsPort]);
const dashboardForward = forward(dashboardPod.metadata.name, [dashboardHttpPort]);
try {
  const serverPorts = await forwardedPorts(serverForward, 2);
  const dashboardPorts = await forwardedPorts(dashboardForward, 1);
  const deadline = Date.now() + 90000;

  async function get(ports, remotePort, route, expected) {
    let last;
    for (let index = 0; index < 30 && Date.now() < deadline; index += 1) {
      try {
        const response = await fetch(`http://127.0.0.1:${ports[remotePort]}${route}`, {
          redirect: 'manual',
          signal: AbortSignal.timeout(4000),
        });
        const body = await response.text();
        if (response.status === expected) return body;
        last = `HTTP ${response.status}`;
      } catch (caught) {
        last = caught.message;
      }
      await delay(1000);
    }
    throw new Error(`${route}: expected ${expected}, last result ${last}`);
  }

  // The relay health endpoint validates the public URL; it is not local readiness.
  await get(serverPorts, serverHttpPort, '/api/accounts', 401);
  const discovery = JSON.parse(
    await get(serverPorts, serverHttpPort, '/oauth2/.well-known/openid-configuration', 200),
  );
  assert.ok(discovery.issuer && discovery.jwks_uri, 'OIDC issuer and signing keys required');
  assert.match(await get(serverPorts, metricsPort, '/metrics', 200), /# (?:HELP|TYPE) /);
  assert.match(await get(dashboardPorts, dashboardHttpPort, '/', 200), /<html/i);
  await new Promise((resolve, reject) => {
    const socket = new WebSocket(`ws://127.0.0.1:${serverPorts[serverHttpPort]}/relay`);
    const timer = setTimeout(() => {
      socket.close();
      reject(new Error('Relay WebSocket upgrade timed out'));
    }, 10000);
    socket.addEventListener(
      'open',
      () => {
        clearTimeout(timer);
        socket.close();
        resolve();
      },
      { once: true },
    );
    socket.addEventListener(
      'error',
      () => {
        clearTimeout(timer);
        reject(new Error('Relay WebSocket upgrade failed'));
      },
      { once: true },
    );
  });
  console.log(
    `NetBird 0.81.5: server HTTP ${serverHttpPort}, metrics ${metricsPort}, dashboard HTTP ${dashboardHttpPort}, embedded OIDC, relay WebSocket, and Prometheus exposition verified.`,
  );
} finally {
  stopForward(serverForward);
  stopForward(dashboardForward);
}
