// SPDX-License-Identifier: Apache-2.0
import { execFileSync } from 'node:child_process';
import { readFileSync } from 'node:fs';
import { verifyBackupRecovery } from './backup-recovery.mjs';

const [context, namespace, release] = process.argv.slice(2);
if (context !== 'k3d-helmforge-tests-wsl' || !namespace || !release) {
  throw new Error('Explicit local HelmForge context, namespace and release are required');
}
const kubectl = (...args) => execFileSync('kubectl', [
  '--context', context, '--namespace', namespace, '--request-timeout=120s', ...args,
], { encoding: 'utf8', timeout: 660000, maxBuffer: 4 * 1024 * 1024 });
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
if (runtime.notifyPush?.enabled) {
  const occ = (...args) => kubectl('exec', pod.metadata.name, '-c', 'nextcloud', '--', 'php', '/var/www/html/occ', ...args);
  const apps = JSON.parse(occ('app:list', '--output=json'));
  // Verify the replacement before changing any retained app in this local test release.
  process.stdout.write(kubectl('exec', pod.metadata.name, '-c', 'nextcloud', '--', 'sh', '-ec',
      'curl --fail --silent --show-error --location --retry 2 --max-time 120 --output /tmp/notify-push-fixture.tar.gz https://github.com/nextcloud-releases/notify_push/releases/download/v1.4.1/notify_push-v1.4.1.tar.gz; ' +
      'echo "0bfda35cba6e21bc6358ede431bde790b039efadae54bbb393560fcff6127e36 /tmp/notify-push-fixture.tar.gz" | sha256sum -c -'));
  if (apps.enabled.notify_push) process.stdout.write(occ('app:disable', 'notify_push'));
  if (apps.enabled.notify_push || apps.disabled.notify_push) process.stdout.write(occ('app:remove', 'notify_push'));
  process.stdout.write(kubectl('exec', pod.metadata.name, '-c', 'nextcloud', '--', 'sh', '-ec',
    'tar -xzf /tmp/notify-push-fixture.tar.gz -C /var/www/html/custom_apps; rm /tmp/notify-push-fixture.tar.gz'));
  process.stdout.write(occ('app:enable', 'notify_push'));
  process.stdout.write(occ('integrity:check-app', 'notify_push'));
  process.stdout.write(occ('notify_push:setup', 'http://127.0.0.1:8080/push'));
  process.stdout.write(execFileSync('kubectl', ['--context', context, '-n', namespace,
    'exec', '-i', pod.metadata.name, '-c', 'nextcloud', '--', 'php'], {
    input: readFileSync(new URL('./push-smoke.php', import.meta.url)),
    encoding: 'utf8', timeout: 120000,
  }));
}
if (runtime.cron.enabled) {
  const cronjobs = JSON.parse(kubectl('get', 'cronjobs', '-l', `app.kubernetes.io/instance=${release},app.kubernetes.io/component=cron`, '-o', 'json')).items;
  if (cronjobs.length !== 1) throw new Error(`Expected one Nextcloud CronJob, found ${cronjobs.length}`);
  const cronjob = cronjobs[0];
  if (!cronjob.spec.suspend) {
    kubectl('patch', 'cronjob', cronjob.metadata.name, '--type=merge', '-p', '{"spec":{"suspend":true}}');
  }
  const job = `${cronjob.metadata.name.slice(0, 39)}-smoke-${Date.now()}`;
  kubectl('create', 'job', job, `--from=cronjob/${cronjob.metadata.name}`);
  kubectl('wait', '--for=condition=complete', `job/${job}`, '--timeout=600s');
  const log = kubectl('logs', `job/${job}`, '-c', 'cron');
  if (!log.includes('Nextcloud background jobs completed successfully')) {
    throw new Error(`CronJob did not report a completed background-job cycle: ${log}`);
  }
  kubectl('delete', 'job', job, '--wait=true');
  if (!cronjob.spec.suspend) {
    kubectl('patch', 'cronjob', cronjob.metadata.name, '--type=merge', '-p', '{"spec":{"suspend":false}}');
  }
  console.log('Kubernetes CronJob background cycle completed successfully');
}
const external = JSON.parse(kubectl('get', 'externalsecrets', '-o', 'json')).items;
for (const item of external) {
  if (!item.status?.conditions?.some(c => c.type === 'Ready' && c.status === 'True')) throw new Error('ExternalSecret is not Ready');
}
const backupCronjobs = JSON.parse(kubectl('get', 'cronjobs', '-l', `app.kubernetes.io/instance=${release},app.kubernetes.io/component=backup`, '-o', 'json')).items;
if (backupCronjobs.length > 0) {
  const secret = pod.spec.containers.find(c => c.name === 'nextcloud').env.find(e => e.name === 'NEXTCLOUD_ADMIN_PASSWORD').valueFrom.secretKeyRef.name;
  verifyBackupRecovery(context, namespace, release, service.metadata.name, secret, backupCronjobs[0].metadata.name);
}
