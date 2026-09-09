// SPDX-License-Identifier: Apache-2.0
import { execFileSync } from 'node:child_process';
import { readFileSync } from 'node:fs';
const [context, namespace, release, version = '2.0.0', action = 'smoke'] = process.argv.slice(2);
const k = (args, input) => execFileSync('kubectl', ['--context', context, '-n', namespace, ...args], { encoding: 'utf8', input, timeout: 180000, maxBuffer: 4 * 1024 * 1024 });
const pods = JSON.parse(k(['get', 'pods', '-l', `app.kubernetes.io/instance=${release}`, '-o', 'json'])).items;
const ready = p => !p.metadata.deletionTimestamp && p.status.conditions?.some(c => c.type === 'Ready' && c.status === 'True');
const api = pods.find(p => ready(p) && p.spec.containers.some(c => c.name === 'api'));
if (!api) throw new Error('No Ready API pod');
for (const pod of pods.filter(ready)) {
  for (const container of pod.spec.containers.filter(c => c.image.includes('appwrite/appwrite:'))) {
    if (!container.image.endsWith(`:${version}`)) throw new Error('Unexpected Appwrite image on ' + pod.metadata.name);
  }
}
console.log(k(['exec', '-i', api.metadata.name, '-c', 'api', '--', 'php', '/dev/stdin', version, action], readFileSync(new URL('./runtime-smoke.php', import.meta.url), 'utf8')).trim());
const consolePod = pods.find(p => ready(p) && p.spec.containers.some(c => c.name === 'console'));
if (!consolePod) throw new Error('No Ready console');
const port = consolePod.spec.containers.find(c => c.name === 'console').ports.find(p => p.name === 'http').containerPort;
const address = consolePod.status.podIP.includes(':') ? `[${consolePod.status.podIP}]` : consolePod.status.podIP;
const page = k(['exec', api.metadata.name, '-c', 'api', '--', 'curl', '-sfL', '--max-time', '20', `http://${address}:${port}/`]);
if (!/appwrite/i.test(page)) throw new Error('Console response does not contain Appwrite');
console.log('PASS: Console HTTP response and effective Appwrite images across all Ready components.');
