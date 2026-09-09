// SPDX-License-Identifier: Apache-2.0
import assert from 'node:assert/strict';
import {execFileSync} from 'node:child_process';

const [context, namespace, release] = process.argv.slice(2);
if (!context?.startsWith('k3d-helmforge-') || !namespace || !release) {
  throw new Error('Explicit HelmForge lab context, namespace and release required');
}
const kubectl = args => execFileSync('kubectl', ['--context', context, '-n', namespace, ...args], {
  encoding: 'utf8', timeout: 30000, stdio: ['ignore', 'pipe', 'pipe'],
});
const pods = JSON.parse(kubectl(['get', 'pods', '-l', `app.kubernetes.io/instance=${release}`, '-o', 'json'])).items;
const pod = pods.find(p => !p.metadata.deletionTimestamp
  && p.status.conditions?.some(c => c.type === 'Ready' && c.status === 'True')
  && p.spec.containers.some(c => c.name === 'poznote'));
assert.ok(pod, 'Ready Poznote pod required');
const exec = args => kubectl(['exec', pod.metadata.name, '-c', 'poznote', '--', ...args]);
assert.equal(exec(['cat', '/var/www/html/version.txt']).trim(), '6.80.0');
const health = exec(['php', '-r', `
$context = stream_context_create(['http' => ['timeout' => 10]]);
$body = file_get_contents('http://127.0.0.1/api/health', false, $context);
if ($body === false || !preg_match('/^HTTP\\/\\S+ 200\\b/', $http_response_header[0] ?? '')) {
    fwrite(STDERR, "Poznote health endpoint failed\\n"); exit(1);
}
echo "health status 200\\n";
`]);
assert.match(health, /health status 200/);
console.log('PASS: Poznote 6.80.0 and live PHP/API health');
