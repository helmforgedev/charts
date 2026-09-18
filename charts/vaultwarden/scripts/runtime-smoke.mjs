// SPDX-License-Identifier: Apache-2.0
import { execFileSync } from 'node:child_process';

const [context, namespace, release] = process.argv.slice(2);
if (!context || !namespace || !release) throw new Error('usage: runtime-smoke.mjs <context> <namespace> <release>');

const kubectl = (...args) => execFileSync('kubectl', ['--context', context, '-n', namespace, ...args], {
  encoding: 'utf8',
  timeout: 360000,
  maxBuffer: 4 * 1024 * 1024,
});

const cronJobs = JSON.parse(kubectl('get', 'cronjob', '-l', `app.kubernetes.io/instance=${release}`, '-o', 'json')).items;
const backup = cronJobs.find(item => item.metadata.name.endsWith('-backup'));
if (!backup) {
  console.log('Vaultwarden runtime smoke: no backup CronJob enabled');
  process.exit(0);
}

const caVolume = backup.spec.jobTemplate.spec.template.spec.volumes?.find(volume => volume.name === 's3-ca');
if (!caVolume) {
  console.log('Vaultwarden runtime smoke: backup enabled without the private-CA acceptance profile');
  process.exit(0);
}

const insecure = backup.spec.jobTemplate.spec.template.spec.containers[0].env
  .find(variable => variable.name === 'S3_INSECURE_SKIP_VERIFY')?.value;
if (insecure !== 'false') throw new Error('Private-CA acceptance must keep TLS verification enabled');

const suffix = Date.now().toString(36).slice(-8);
const jobName = `${release.slice(0, 42)}-ca-smoke-${suffix}`;
try {
  kubectl('create', 'job', `--from=cronjob/${backup.metadata.name}`, jobName);
  kubectl('wait', '--for=condition=complete', `job/${jobName}`, '--timeout=300s');
  const logs = kubectl('logs', `job/${jobName}`, '-c', 'upload');
  process.stdout.write(logs);
  console.log('Vaultwarden backup uploaded to HTTPS S3 with private-CA verification enabled');
} catch (error) {
  try {
    process.stderr.write(kubectl('logs', `job/${jobName}`, '--all-containers', '--prefix=true'));
  } catch {}
  throw error;
} finally {
  try {
    kubectl('delete', 'job', jobName, '--wait=true');
  } catch {}
}

