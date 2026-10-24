// SPDX-License-Identifier: Apache-2.0
import assert from 'node:assert/strict';
import {execFileSync} from 'node:child_process';
import path from 'node:path';
import {fileURLToPath} from 'node:url';

const [context, namespace, release] = process.argv.slice(2);
if (!context?.startsWith('k3d-helmforge-') || !namespace || !release) {
  throw new Error('Explicit HelmForge lab context, namespace and release required');
}

const run = (command, args, options = {}) => execFileSync(command, args, {
  encoding: 'utf8',
  timeout: 240000,
  stdio: ['ignore', 'pipe', 'pipe'],
  ...options,
});
const kubectl = args => run('kubectl', ['--context', context, '-n', namespace, ...args]);
const podList = JSON.parse(kubectl([
  'get', 'pods', '-l', `app.kubernetes.io/instance=${release}`, '-o', 'json',
]));
const wordpressPod = podList.items.find(pod => !pod.metadata.deletionTimestamp
  && pod.status.conditions?.some(condition => condition.type === 'Ready' && condition.status === 'True')
  && pod.spec.containers.some(container => container.name === 'wordpress'));
assert.ok(wordpressPod, 'Ready WordPress pod required');

const fixtureExists = (() => {
  try {
    kubectl(['get', 'service', 'wordpress-plugin-fixture', '-o', 'name']);
    return true;
  } catch {
    return false;
  }
})();

if (!fixtureExists) {
  console.log('WordPress pod is Ready; no custom plugin runtime fixture is active.');
  process.exit(0);
}

const execWordPress = command => kubectl([
  'exec', wordpressPod.metadata.name, '-c', 'wordpress', '--', ...command,
]);
execWordPress(['test', '-f', '/var/www/html/wp-content/plugins/company-plugin/company-plugin.php']);
const active = execWordPress([
  'php', '-r',
  'require "/var/www/html/wp-load.php"; echo in_array("company-plugin/company-plugin.php", get_option("active_plugins", []), true) ? "active" : "inactive";',
]).trim();
assert.equal(active, 'active', 'Custom plugin must be active after bootstrap');

const fixturePod = JSON.parse(kubectl([
  'get', 'pods', '-l', 'app.kubernetes.io/name=wordpress-plugin-fixture', '-o', 'json',
])).items.find(pod => !pod.metadata.deletionTimestamp);
assert.ok(fixturePod, 'Plugin fixture pod required');
const downloadCount = () => {
  try {
    return Number(kubectl([
      'exec', fixturePod.metadata.name, '-c', 'server', '--',
      'cat', '/tmp/download-count',
    ]).trim());
  } catch {
    return 0;
  }
};
assert.equal(downloadCount(), 1, 'Initial install must download the custom plugin exactly once');

const chartPath = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
run('helm', [
  'upgrade', release, chartPath,
  '--namespace', namespace,
  '--kube-context', context,
  '--reuse-values',
  '--wait',
  '--wait-for-jobs',
  '--timeout', '180s',
]);
assert.equal(downloadCount(), 1, 'Upgrade must not download an installed custom plugin again');

console.log('Verified custom plugin installed, activated, and skipped without a second download during upgrade.');
