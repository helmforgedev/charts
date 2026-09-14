// SPDX-License-Identifier: Apache-2.0
import { execFileSync } from 'node:child_process';
import { randomBytes } from 'node:crypto';
import { mkdtempSync, writeFileSync, rmSync, rmdirSync } from 'node:fs';
import { tmpdir } from 'node:os';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

export function verifyBackupRecovery(context, namespace, release, deployment, adminSecret, cronName) {
  if (context !== 'k3d-helmforge-tests-wsl') throw new Error('Recovery acceptance is restricted to the local HelmForge lab');
  const k = (args, input) => execFileSync('kubectl', ['--context', context, '-n', namespace, ...args], {
    input, encoding: 'utf8', timeout: 900000, maxBuffer: 4 * 1024 * 1024,
  });
  const helm = args => execFileSync('helm', args, { encoding: 'utf8', timeout: 960000, maxBuffer: 4 * 1024 * 1024 });
  const chart = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
  const source = JSON.parse(helm(['get', 'values', release, '--kube-context', context, '-n', namespace, '--all', '-o', 'json']));
  const proofInput = { user: `hf-recovery-${randomBytes(4).toString('hex')}`, password: randomBytes(24).toString('base64url'), payload: randomBytes(1024 * 1024).toString('base64') };
  const proof = k(['exec', '-i', `deployment/${deployment}`, '-c', 'nextcloud', '--', 'php', '/opt/helmforge/recovery-smoke.php', 'seed'], JSON.stringify(proofInput));
  JSON.parse(proof);
  console.log('Recovery seed: non-admin user, one MiB binary file, file identity, share and configuration');
  const job = `nc-backup-${Date.now()}`;
  k(['create', 'job', job, `--from=cronjob/${cronName}`]);
  k(['wait', '--for=condition=complete', `job/${job}`, '--timeout=600s']);
  const log = k(['logs', `job/${job}`, '-c', 'upload']);
  const prefix = log.match(/Completed backup: s3:\/\/[^/]+\/(\S+)/)?.[1];
  if (!prefix) throw new Error('Backup did not publish a completion marker');
  k(['rollout', 'status', `deployment/${deployment}`, '--timeout=180s']);
  console.log('SQL/files backup completed and source application resumed');

  const restored = `${release.slice(0, 35)}-recovery`;
  const values = {
    image: source.image,
    nextcloud: { ...source.nextcloud, existingSecret: adminSecret, adminPassword: '' },
    backup: { ...source.backup, enabled: false },
    restore: { enabled: true, backupPath: prefix },
    postgresql: { enabled: true, image: source.postgresql.image, auth: { database: source.postgresql.auth.database, username: source.postgresql.auth.username } },
  };
  const temporary = mkdtempSync(path.join(tmpdir(), 'nextcloud-recovery-'));
  const file = path.join(temporary, 'values.json');
  try {
    writeFileSync(file, JSON.stringify(values));
    helm(['upgrade', '--install', restored, chart, '--kube-context', context, '-n', namespace, '-f', file, '--wait', '--wait-for-jobs', '--timeout', '15m']);
    values.restore.enabled = false;
    writeFileSync(file, JSON.stringify(values));
    helm(['upgrade', restored, chart, '--kube-context', context, '-n', namespace, '-f', file, '--wait', '--timeout', '5m']);
    const pods = JSON.parse(k(['get', 'pods', '-l', `app.kubernetes.io/instance=${restored},app.kubernetes.io/component=app`, '-o', 'json'])).items;
    const app = pods.find(p => !p.metadata.deletionTimestamp);
    if (!app) throw new Error('Restored application Pod was not created');
    const restoredClaim = app.spec.volumes.find(v => v.name === 'data').persistentVolumeClaim.claimName;
    const originalPods = JSON.parse(k(['get', 'pods', '-l', `app.kubernetes.io/instance=${release},app.kubernetes.io/component=app`, '-o', 'json'])).items;
    const originalClaim = originalPods.find(p => !p.metadata.deletionTimestamp).spec.volumes.find(v => v.name === 'data').persistentVolumeClaim.claimName;
    if (restoredClaim === originalClaim) throw new Error('Recovery reused the source PVC');
    process.stdout.write(k(['exec', '-i', app.metadata.name, '-c', 'nextcloud', '--', 'php', '/opt/helmforge/recovery-smoke.php', 'verify'], proof));
    const recoveredPods = JSON.parse(k(['get', 'pods', '-l', `app.kubernetes.io/instance=${restored}`, '-o', 'json'])).items;
    for (const recovered of recoveredPods) {
      for (const container of [...(recovered.status.initContainerStatuses ?? []), ...(recovered.status.containerStatuses ?? [])]) {
        if (container.restartCount !== 0 || (container.lastState?.terminated?.exitCode ?? 0) !== 0) {
          throw new Error(`Restored workload ${recovered.metadata.name}/${container.name} restarted or crashed`);
        }
      }
    }
    console.log(`Fresh PVC ${restoredClaim} and independent PostgreSQL recovery verified`);
    helm(['uninstall', restored, '--kube-context', context, '-n', namespace, '--wait']);
    // StatefulSet deletion can return before its Pods finish graceful shutdown.
    // Finish cleanup before the parent gate scans the remaining live workloads.
    const remaining = JSON.parse(k(['get', 'pods', '-l', `app.kubernetes.io/instance=${restored}`, '-o', 'json'])).items;
    if (remaining.length) k(['wait', '--for=delete', 'pods', '-l', `app.kubernetes.io/instance=${restored}`, '--timeout=180s']);
  } finally {
    rmSync(file, { force: true });
    rmdirSync(temporary);
  }
}
