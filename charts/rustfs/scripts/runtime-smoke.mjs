// SPDX-License-Identifier: Apache-2.0
import assert from 'node:assert/strict';
import { execFileSync } from 'node:child_process';
import { randomBytes } from 'node:crypto';

const [context, namespace, release] = process.argv.slice(2);
assert.ok(context?.startsWith('k3d-helmforge-') && namespace && release,
  'Explicit local k3d-helmforge-* context, namespace, and release required');
const target = ['--context', context, '-n', namespace];
function kubectl(args, input) {
  return execFileSync('kubectl', [...target, ...args], {
    input, encoding: 'utf8', timeout: 240000, stdio: ['pipe', 'pipe', 'pipe'],
  });
}
const get = (...args) => JSON.parse(kubectl(['get', ...args, '-o', 'json']));
const sets = get('statefulsets', '-l', `app.kubernetes.io/instance=${release}`).items;
assert.equal(sets.length, 1, 'one storage StatefulSet required');
const set = sets[0];
assert.equal(set.status.readyReplicas, set.spec.replicas, 'all storage pods must be Ready');
const container = set.spec.template.spec.containers.find(c => c.name === 'rustfs');
const service = get('service', set.metadata.name);
const endpoint = `http://${service.metadata.name}:${service.spec.ports.find(p => p.name === 'api').port}`;
const configMaps = get('configmaps', '-l', `app.kubernetes.io/instance=${release}`).items;
const config = configMaps.find(c => c.data?.['config.json']);
const replication = config ? JSON.parse(config.data['config.json']) : null;
const nonce = randomBytes(6).toString('hex');
const podName = `rustfs-smoke-${nonce}`;
const q = s => `'${String(s).replaceAll("'", "'\\''")}'`;
const env = container.env.filter(e => ['RUSTFS_ACCESS_KEY', 'RUSTFS_SECRET_KEY'].includes(e.name));
assert.equal(env.length, 2, 'both S3 credential references required');
const script = [
  'set -eu', 'umask 077', 'export RC_CONFIG_DIR=/tmp/rc',
  `rc alias set local ${q(endpoint)} "$RUSTFS_ACCESS_KEY" "$RUSTFS_SECRET_KEY" --bucket-lookup path >/dev/null`,
  'rc ready local',
  `printf '%s' ${q(`HelmForge RustFS smoke ${nonce} tiếng Việt`)} > /tmp/payload`,
  // Eventual replication is bounded; errors are kept out of the normal success log.
  'verify_copy() { n=0; until rc object copy "$1" /tmp/download >/tmp/copy.log 2>&1; do n=$((n+1)); if [ "$n" -ge 45 ]; then cat /tmp/copy.log; return 1; fi; sleep 2; done; cmp /tmp/payload /tmp/download; }',
];
const peers = replication?.peers ?? [];
peers.forEach((peer, i) => {
  for (const [suffix, key] of [['ACCESS', peer.accessKeyKey ?? 'access-key'], ['SECRET', peer.secretKeyKey ?? 'secret-key']]) {
    env.push({ name: `PEER_${i}_${suffix}`, valueFrom: { secretKeyRef: { name: peer.existingSecret, key } } });
  }
  script.push(`rc alias set peer${i} ${q(peer.endpoint)} "$PEER_${i}_ACCESS" "$PEER_${i}_SECRET" --bucket-lookup path >/dev/null`);
});
if (replication?.mode === 'bucket') {
  for (const [i, rule] of replication.buckets.entries()) {
    const key = `${rule.prefix ?? ''}helmforge-smoke-${nonce}-${i}.txt`;
    const local = `local/${rule.sourceBucket}/${key}`;
    const peer = peers.findIndex(p => p.name === rule.destinationPeer);
    assert.ok(peer >= 0);
    script.push(
      `rc --json replicate list ${q(`local/${rule.sourceBucket}`)} > /tmp/rules.json`,
      `jq -e --arg id ${q(rule.id)} '[.rules[] | select(.id == $id)] | length == 1' /tmp/rules.json`,
      `rc object copy /tmp/payload ${q(local)}`,
      `verify_copy ${q(local)}`,
      `verify_copy ${q(`peer${peer}/${rule.destinationBucket}/${key}`)}`,
      `rc object remove ${q(local)}`,
    );
  }
} else {
  const bucket = `helmforge-smoke-${nonce}`;
  script.push(`rc mb local/${bucket}`, `rc object copy /tmp/payload local/${bucket}/forward.txt`,
    `verify_copy local/${bucket}/forward.txt`);
  if (replication?.mode === 'site') {
    peers.forEach((_, i) => script.push(
      `verify_copy peer${i}/${bucket}/forward.txt`,
      `rc object copy /tmp/payload peer${i}/${bucket}/reverse-${i}.txt`,
      `verify_copy local/${bucket}/reverse-${i}.txt`,
    ));
  }
  // Versioned site buckets are left to the isolated scenario namespace teardown.
  if (!replication) script.push(`rc object remove local/${bucket}/forward.txt`, `rc bucket remove local/${bucket}`);
}
script.push(`echo ${q(`PASS RustFS ${replication?.mode ?? 'S3'} content verification; storage replicas=${set.spec.replicas}`)}`);
const pod = {
  apiVersion: 'v1', kind: 'Pod', metadata: { name: podName },
  spec: {
    restartPolicy: 'Never', automountServiceAccountToken: false, activeDeadlineSeconds: 210,
    imagePullSecrets: set.spec.template.spec.imagePullSecrets,
    securityContext: set.spec.template.spec.securityContext,
    containers: [{ name: 'cli', image: 'docker.io/rustfs/rc:v0.1.36', env,
      command: ['/bin/sh', '-c', script.join('\n')], securityContext: container.securityContext,
      volumeMounts: [{ name: 'tmp', mountPath: '/tmp' }],
    }], volumes: [{ name: 'tmp', emptyDir: {} }],
  },
};
let created = false;
try {
  kubectl(['create', '-f', '-'], JSON.stringify(pod)); created = true;
  // Wait for a terminal pod phase, including image/startup failures via the deadline.
  for (let i = 0; i < 220; i++) {
    const status = get('pod', podName).status;
    if (['Succeeded', 'Failed'].includes(status.phase)) {
      process.stdout.write(kubectl(['logs', podName]));
      assert.equal(status.phase, 'Succeeded', 'native S3/replication smoke test must succeed');
      break;
    }
    if (i === 219) throw new Error('Smoke pod timed out');
    await new Promise(resolve => setTimeout(resolve, 1000));
  }
} finally {
  if (created) kubectl(['delete', 'pod', podName, '--wait=false']);
}
