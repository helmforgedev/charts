// SPDX-License-Identifier: Apache-2.0
import { execFileSync } from 'node:child_process';
import { verifyBackupRecovery } from './backup-recovery.mjs';

const [context, namespace, release] = process.argv.slice(2);
if (context !== 'k3d-helmforge-tests-wsl' || !namespace || !release) {
  throw new Error('Explicit local HelmForge context, namespace and release are required');
}
const kubectl = (...args) => execFileSync('kubectl', [
  '--context', context, '--namespace', namespace, '--request-timeout=120s', ...args,
], { encoding: 'utf8', timeout: 240000, maxBuffer: 4 * 1024 * 1024 });
const selector = `app.kubernetes.io/instance=${release},app.kubernetes.io/component=app`;
const pods = JSON.parse(kubectl('get', 'pods', '-l', selector, '-o', 'json')).items;
const pod = pods.find(item => !item.metadata.deletionTimestamp && item.spec.containers.some(c => c.name === 'nextcloud'));
if (!pod) throw new Error('Nextcloud Pod not found');
const services = JSON.parse(kubectl('get', 'services', '-l', `app.kubernetes.io/instance=${release}`, '-o', 'json')).items;
const service = services.find(item => item.spec.ports.some(p => p.name === 'http'));
if (!service) throw new Error('Nextcloud HTTP service not found');
process.stdout.write(kubectl('exec', pod.metadata.name, '-c', 'nextcloud', '--',
  'php', '/opt/helmforge/smoke.php', service.metadata.name, String(service.spec.ports.find(p => p.name === 'http').port)));
const status = JSON.parse(kubectl('exec', pod.metadata.name, '-c', 'nextcloud', '--', 'php', '/var/www/html/occ', 'status', '--output=json'));
if (!status.installed || status.maintenance || status.needsDbUpgrade) throw new Error('Nextcloud CLI state is unhealthy');
console.log(`Nextcloud ${status.versionstring}: application and CLI checks passed`);
const config = JSON.parse(kubectl('get', 'configmap', service.metadata.name, '-o', 'json'));
const runtime = JSON.parse(config.data['runtime-settings.json']);
if (runtime.cron.enabled && runtime.cron.initialDelay === 0) {
  let success = false;
  for (let attempt = 0; attempt < 150; attempt++) {
    try {
      kubectl('exec', pod.metadata.name, '-c', 'cron', '--', 'test', '-s', '/tmp/nextcloud-cron-last-success');
      success = true;
      break;
    } catch { await new Promise(resolve => setTimeout(resolve, 5000)); }
  }
  if (!success) throw new Error('Cron did not complete a native background job cycle');
  console.log('Native cron cycle completed successfully');
}
const external = JSON.parse(kubectl('get', 'externalsecrets', '-o', 'json')).items;
for (const item of external) {
  if (!item.status?.conditions?.some(c => c.type === 'Ready' && c.status === 'True')) throw new Error('ExternalSecret is not Ready');
}
const cronjobs = JSON.parse(kubectl('get', 'cronjobs', '-l', `app.kubernetes.io/instance=${release}`, '-o', 'json')).items;
if (cronjobs.length > 0) {
  const secret = pod.spec.containers.find(c => c.name === 'nextcloud').env.find(e => e.name === 'NEXTCLOUD_ADMIN_PASSWORD').valueFrom.secretKeyRef.name;
  verifyBackupRecovery(context, namespace, release, service.metadata.name, secret, cronjobs[0].metadata.name);
}
