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
  && p.spec.containers.some(c => c.name === 'drupal'));
assert.ok(pod, 'Ready Drupal pod required');
const php = code => kubectl(['exec', pod.metadata.name, '-c', 'drupal', '--', 'php', '-r', code]);
const runtime = JSON.parse(php('require "/var/www/html/core/lib/Drupal.php"; echo json_encode(["drupal" => Drupal::VERSION, "php" => PHP_VERSION, "drivers" => PDO::getAvailableDrivers()]);'));
assert.equal(runtime.drupal, '11.4.6');
assert.match(runtime.php, /^8\.5\./);
assert.ok(runtime.drivers.includes('mysql'), 'MySQL PDO driver required');
assert.ok(runtime.drivers.includes('sqlite'), 'SQLite PDO driver required');
const installer = php('echo file_get_contents("http://127.0.0.1/core/install.php");');
assert.match(installer, /Choose language|Select a language/);
console.log('Drupal 11.4.6 / PHP 8.5: MySQL and SQLite PDO drivers available; Apache served the fresh-site installer.');
