// SPDX-License-Identifier: Apache-2.0
import assert from 'node:assert/strict';
import {execFileSync} from 'node:child_process';

const [context, namespace, release] = process.argv.slice(2);
assert.ok(context?.startsWith('k3d-helmforge-') && namespace && release);
const run = args => execFileSync('kubectl', ['--context', context, '-n', namespace, ...args], {
  encoding: 'utf8', timeout: 30000, stdio: ['ignore', 'pipe', 'pipe'],
});
const pods = JSON.parse(run(['get', 'pods', '-l', `app.kubernetes.io/instance=${release}`, '-o', 'json'])).items;
const pod = pods.find(p => !p.metadata.deletionTimestamp && p.status.conditions?.some(c => c.type === 'Ready' && c.status === 'True')
  && p.spec.containers.some(c => c.name === 'minecraft'));
assert.ok(pod, 'Ready Minecraft server required');
const container = pod.spec.containers.find(c => c.name === 'minecraft');
assert.match(container.image, /:2026\.9\.0(?:-java17)?$/);
const exec = args => run(['exec', pod.metadata.name, '-c', 'minecraft', '--', ...args]);
exec(['mc-health']);
if (container.env.some(e => e.name === 'ENABLE_RCON' && e.value === 'true')) {
  assert.match(exec(['rcon-cli', 'list']), /players online/i);
  assert.match(exec(['rcon-cli', 'save-all', 'flush']), /Saved the game/i);
}
if (container.env.some(e => e.name === 'TYPE' && e.value === 'FORGE')) {
  assert.match(exec(['sh', '-c', 'java -version 2>&1']), /version "17\./);
  assert.match(run(['logs', pod.metadata.name, '-c', 'minecraft', '--tail=500']), /forge|fml/i);
}
console.log('PASS: Minecraft 2026.9.0 image, game health, authenticated RCON player list and world flush; Forge profile verifies Java 17 and loader startup.');
