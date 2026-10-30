// SPDX-License-Identifier: Apache-2.0
import { execFileSync } from 'node:child_process';
import { readFileSync } from 'node:fs';
const [context, namespace, release, version = '2.5.0', action = 'smoke'] = process.argv.slice(2);
if (context !== 'k3d-helmforge-tests-wsl' || !namespace?.startsWith('hf-') || !release || !['smoke', 'create', 'verify'].includes(action)) {
  throw new Error('Explicit owned HelmForge lab context, namespace, release and action required');
}
const k = (args, input) => execFileSync('kubectl', ['--context', context, '-n', namespace, ...args], { encoding: 'utf8', input, timeout: 180000, maxBuffer: 4 * 1024 * 1024 });
const pods = JSON.parse(k(['get', 'pods', '-l', `app.kubernetes.io/instance=${release}`, '-o', 'json'])).items;
const ready = p => !p.metadata.deletionTimestamp && p.status.conditions?.some(c => c.type === 'Ready' && c.status === 'True');
const component = name => {
  const pod = pods.find(p => ready(p) && p.spec.containers.some(c => c.name === name));
  if (!pod) throw new Error(`No Ready ${name} pod`);
  const container = pod.spec.containers.find(c => c.name === name);
  const port = container.ports?.find(p => p.name === 'http')?.containerPort;
  const configuredPort = container.env?.find(e => e.name === 'PORT')?.value;
  if (!port || configuredPort !== String(port)) {
    throw new Error(`${name} PORT environment value does not match its http containerPort`);
  }
  return { pod, container, port };
};
const api = component('api');
const consoleComponent = component('console');
const realtime = component('realtime');
for (const pod of pods.filter(ready)) {
  for (const container of pod.spec.containers.filter(c => c.image.includes('appwrite/appwrite:'))) {
    if (!container.image.endsWith(`:${version}`)) throw new Error('Unexpected Appwrite image on ' + pod.metadata.name);
  }
}
console.log(k(['exec', '-i', api.pod.metadata.name, '-c', 'api', '--', 'php', '-d', 'display_errors=stderr', '-d', 'log_errors=0', '/dev/stdin', version, action], readFileSync(new URL('./runtime-smoke.php', import.meta.url), 'utf8')).trim());
const address = pod => pod.status.podIP.includes(':') ? `[${pod.status.podIP}]` : pod.status.podIP;
const page = k(['exec', api.pod.metadata.name, '-c', 'api', '--', 'curl', '-sfL', '--max-time', '20', `http://${address(consoleComponent.pod)}:${consoleComponent.port}/`]);
if (!/appwrite/i.test(page)) throw new Error('Console response does not contain Appwrite');
const realtimeStatus = k(['exec', api.pod.metadata.name, '-c', 'api', '--', 'curl', '-sS', '--max-time', '20', '-o', '/dev/null', '-w', '%{http_code}', `http://${address(realtime.pod)}:${realtime.port}/v1/realtime?project=console`]).trim();
if (realtimeStatus === '000') throw new Error('Realtime listener did not return an HTTP response');
console.log(`PASS: API, Console, and realtime process listeners match configured ports; realtime returned HTTP ${realtimeStatus}.`);
console.log('PASS: Console HTTP response and effective Appwrite images across all Ready components.');
