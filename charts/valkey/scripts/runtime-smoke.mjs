// SPDX-License-Identifier: Apache-2.0
import { execFileSync } from 'node:child_process';

const [context, namespace, release] = process.argv.slice(2);
if (!context?.startsWith('k3d-helmforge-') || !namespace || !release) {
  throw new Error('Explicit HelmForge lab context, namespace and release required');
}
const output = execFileSync('helm', [
  'test', release, '--kube-context', context, '--namespace', namespace,
  '--timeout', '120s', '--logs',
], { encoding: 'utf8', timeout: 150000, stdio: ['ignore', 'pipe', 'pipe'] });
process.stdout.write(output);
