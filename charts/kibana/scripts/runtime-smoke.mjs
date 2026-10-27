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
const values = JSON.parse(
  execFileSync('helm', ['get', 'values', release, '-n', namespace, '--kube-context', context, '-a', '-o', 'json'], {
    encoding: 'utf8',
    timeout: 120_000,
  }),
);
const selector = `app.kubernetes.io/instance=${release},app.kubernetes.io/name=kibana`;
const service = JSON.parse(kubectl(['get', 'services', '-l', selector, '-o', 'json'])).items[0];
assert.ok(service, 'Kibana Service not found');
const servicePort = service.spec.ports.find((port) => port.name === 'http')?.port;
assert.ok(Number.isInteger(servicePort), 'Kibana Service does not expose the named http port');

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
for (const stream of [child.stdout, child.stderr]) stream.on('data', (chunk) => (output += chunk));

try {
  const deadline = Date.now() + 20_000;
  while (!/Forwarding from/.test(output) && Date.now() < deadline && child.exitCode === null) {
    await new Promise((resolve) => setTimeout(resolve, 100));
  }
  const port = output.match(/127\.0\.0\.1:(\d+)/)?.[1];
  assert.ok(port, output);
  const basePath = String(values.server.basePath || '').replace(/\/$/, '');
  const response = await fetch(`http://127.0.0.1:${port}${basePath}/api/status`, {
    signal: AbortSignal.timeout(20_000),
  });
  assert.equal(response.status, 200);
  assert.match(response.headers.get('content-type') ?? '', /application\/json/i);
  const status = await response.json();
  // Kibana 9.5 redacts version/build details for callers without the
  // Elasticsearch cluster:monitor privilege. Kubernetes probes and this
  // unauthenticated smoke still receive the authoritative overall level.
  assert.match(status.status?.overall?.level ?? status.status?.overall?.state ?? '', /available|green/i);
} finally {
  if (child.exitCode === null && child.signalCode === null) {
    if (process.platform === 'win32') {
      execFileSync('taskkill', ['/PID', String(child.pid), '/T', '/F'], { stdio: 'ignore' });
    } else {
      child.kill();
    }
  }
}

console.log('PASS Kibana Service /api/status and overall availability');
