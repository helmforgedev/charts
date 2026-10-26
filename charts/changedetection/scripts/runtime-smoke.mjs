// SPDX-License-Identifier: Apache-2.0
import { execFileSync } from 'node:child_process';
import { readFileSync } from 'node:fs';
const [context, namespace, release, version = '0.60.9', action = 'smoke'] = process.argv.slice(2);
const run = (args, input) => execFileSync('kubectl', ['--context', context, '-n', namespace, ...args], { encoding: 'utf8', input, timeout: 360000, maxBuffer: 4 * 1024 * 1024 });
const pods = JSON.parse(run(['get', 'pods', '-l', `app.kubernetes.io/instance=${release}`, '-o', 'json']));
const pod = pods.items.find(p => !p.metadata.deletionTimestamp && p.status.conditions?.some(c => c.type === 'Ready' && c.status === 'True'));
if (!pod) throw new Error('No Ready changedetection pod');
const app = pod.spec.containers.find(c => c.name === 'changedetection');
if (!app?.image.endsWith(`:${version}`)) throw new Error('Unexpected application image');
const browserContainer = pod.spec.containers.find(c => c.name === 'browser');
const browser = Boolean(browserContainer);
if (browserContainer) {
  const browserPort = browserContainer.ports?.find(port => port.name === 'browser')?.containerPort;
  if (!browserPort) throw new Error('Browser listener port required');
  if (JSON.stringify(browserContainer.command) !== JSON.stringify(['/usr/local/bin/entrypoint.sh'])) {
    throw new Error('Browser entrypoint command does not match the pinned upstream image contract');
  }
  if (JSON.stringify(browserContainer.args) !== JSON.stringify(['--port', String(browserPort)])) {
    throw new Error('Browser process arguments do not match its declared listener port');
  }
  const driverUrl = app.env?.find(variable => variable.name === 'PLAYWRIGHT_DRIVER_URL')?.value;
  if (driverUrl !== `ws://127.0.0.1:${browserPort}`) {
    throw new Error('PLAYWRIGHT_DRIVER_URL does not match the browser listener port');
  }
}
console.log(run(['exec', '-i', pod.metadata.name, '-c', 'changedetection', '--', 'python', '-', action, String(browser), version], readFileSync(new URL('./runtime-smoke.py', import.meta.url), 'utf8')).trim());
