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

const selector = `app.kubernetes.io/instance=${release},app.kubernetes.io/name=discount-bandit`;
const services = JSON.parse(kubectl(['get', 'services', '-l', selector, '-o', 'json']));
const service = services.items.find((item) => item.spec?.ports?.some((port) => port.name === 'http'));
assert.ok(service, 'Discount Bandit Service with named http port not found');
const servicePort = service.spec.ports.find((port) => port.name === 'http')?.port;
assert.ok(Number.isInteger(servicePort), 'Discount Bandit Service http port is not numeric');

const child = spawn(
  'kubectl',
  [
    '--context',
    context,
    '-n',
    namespace,
    'port-forward',
    `service/${service.metadata.name}`,
    `0:${servicePort}`,
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
  const response = await fetch(`http://127.0.0.1:${localPort}/`, {
    signal: AbortSignal.timeout(30_000),
  });
  assert.equal(response.status, 200);
  assert.match(response.headers.get('content-type') ?? '', /text\/html/i);
  const body = await response.text();
  assert.match(body, /Discount Bandit|<!doctype html/i);
} finally {
  if (child.exitCode === null && child.signalCode === null) {
    if (process.platform === 'win32') {
      execFileSync('taskkill', ['/PID', String(child.pid), '/T', '/F'], { stdio: 'ignore' });
    } else {
      child.kill();
    }
  }
}

console.log('PASS Discount Bandit Service returned the HTML application');
