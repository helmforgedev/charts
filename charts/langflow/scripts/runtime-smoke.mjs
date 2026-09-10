// SPDX-License-Identifier: Apache-2.0
import assert from 'node:assert/strict';
import {execFileSync} from 'node:child_process';
import {readFileSync} from 'node:fs';

const [context, namespace, release] = process.argv.slice(2);
assert.ok(context?.startsWith('k3d-helmforge-') && namespace && release);
const target = ['--context', context, '-n', namespace];
const pods = JSON.parse(execFileSync('kubectl', [...target, 'get', 'pods', '-l', `app.kubernetes.io/instance=${release}`, '-o', 'json'], {
  encoding: 'utf8', timeout: 15000,
})).items;
const pod = pods.find(p => !p.metadata.deletionTimestamp && p.status.conditions?.some(c => c.type === 'Ready' && c.status === 'True')
  && p.spec.containers.some(c => c.name === 'langflow'));
assert.ok(pod, 'Ready Langflow pod required');
const output = execFileSync('kubectl', [...target, 'exec', '-i', pod.metadata.name, '-c', 'langflow', '--', 'python', '-', '1.12.0', 'create'], {
  input: readFileSync(new URL('./runtime-smoke.py', import.meta.url)), encoding: 'utf8', timeout: 160000, stdio: ['pipe', 'pipe', 'pipe'],
});
console.log(output.trim());
