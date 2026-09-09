// SPDX-License-Identifier: Apache-2.0
import { execFileSync } from 'node:child_process';
import { readFileSync } from 'node:fs';
const [context, namespace, release, version = '0.60.3', action = 'smoke'] = process.argv.slice(2);
const run = (args, input) => execFileSync('kubectl', ['--context', context, '-n', namespace, ...args], { encoding: 'utf8', input, timeout: 360000, maxBuffer: 4 * 1024 * 1024 });
const pods = JSON.parse(run(['get', 'pods', '-l', `app.kubernetes.io/instance=${release}`, '-o', 'json']));
const pod = pods.items.find(p => !p.metadata.deletionTimestamp && p.status.conditions?.some(c => c.type === 'Ready' && c.status === 'True'));
if (!pod) throw new Error('No Ready changedetection pod');
const app = pod.spec.containers.find(c => c.name === 'changedetection');
if (!app?.image.endsWith(`:${version}`)) throw new Error('Unexpected application image');
const browser = pod.spec.containers.some(c => c.name === 'browser');
console.log(run(['exec', '-i', pod.metadata.name, '-c', 'changedetection', '--', 'python', '-', action, String(browser), version], readFileSync(new URL('./runtime-smoke.py', import.meta.url), 'utf8')).trim());
