// SPDX-License-Identifier: Apache-2.0
import assert from 'node:assert/strict';
import { execFileSync } from 'node:child_process';
import { readFileSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
const [context, namespace, release] = process.argv.slice(2);
assert.equal(context, 'k3d-helmforge-tests-wsl', 'use the explicitly authorized validation cluster');
assert(namespace && release);
const k = (args, input) => execFileSync('kubectl', ['--context', context, '-n', namespace, ...args], {
  encoding: 'utf8', timeout: 90000, input, stdio: ['pipe', 'pipe', 'pipe'], maxBuffer: 8 * 1024 * 1024,
});
const values = JSON.parse(execFileSync('helm', ['get', 'values', release, '-n', namespace, '--kube-context', context, '-a', '-o', 'json'], { encoding: 'utf8' }));
const deployment = JSON.parse(k(['get', 'deployment', '-l', `app.kubernetes.io/instance=${release}`, '-o', 'json'])).items[0];
assert.equal(deployment.spec.replicas, 1);
const name = deployment.metadata.name;
const publicKey = container => k(['logs', `deployment/${name}`, '-c', container]).match(/Key: ([A-Za-z0-9+/=]+)/)?.[1];
const originalKey = publicKey('hbbs');
assert(originalKey && Buffer.from(originalKey, 'base64').length === 32);
assert.equal(publicKey('hbbr'), originalKey, 'both processes use the same identity');
if (values.auth.existingSecret) {
  const secret = JSON.parse(k(['get', 'secret', values.auth.existingSecret, '-o', 'json']));
  assert.equal(Buffer.from(secret.data[values.auth.publicKeyKey], 'base64').toString().trim(), originalKey, 'mounted Secret provides the server identity');
}
if (values.externalSecrets.enabled) {
  const secrets = JSON.parse(k(['get', 'externalsecret', '-o', 'json']));
  assert(secrets.items.length > 0);
  for (const secret of secrets.items) assert(secret.status?.conditions?.some(c => c.type === 'Ready' && c.status === 'True'), 'ExternalSecret must be Ready');
  console.log('PASS ExternalSecret: Ready and native identity consumed');
}
const fixture = {
  apiVersion: 'v1', kind: 'Pod',
  metadata: { name: 'rustdesk-protocol-client', labels: { 'helmforge.dev/runtime-fixture': 'true' } },
  spec: {
    restartPolicy: 'Never', automountServiceAccountToken: false, terminationGracePeriodSeconds: 1,
    securityContext: { runAsNonRoot: true, runAsUser: 1000, runAsGroup: 1000, seccompProfile: { type: 'RuntimeDefault' } },
    containers: [{
      name: 'client', image: 'docker.io/library/node:24.21.0-alpine3.23',
      command: ['node', '-e', 'setInterval(() => {}, 1000)'],
      securityContext: { allowPrivilegeEscalation: false, readOnlyRootFilesystem: true, capabilities: { drop: ['ALL'] } },
      resources: { requests: { cpu: '20m', memory: '32Mi' }, limits: { cpu: '500m', memory: '128Mi' } },
    }],
  },
};
const client = readFileSync(new URL('./protocol-client.cjs', import.meta.url), 'utf8');
const recoveryClaim = `${name.slice(0, 53)}-recovery`;
if (values.persistence.enabled) {
  const sourceClaim = deployment.spec.template.spec.volumes.find(v => v.name === 'data').persistentVolumeClaim.claimName;
  const pvc = JSON.parse(k(['get', 'pvc', sourceClaim, '-o', 'json']));
  k(['apply', '-f', '-'], JSON.stringify({apiVersion:'v1',kind:'PersistentVolumeClaim',metadata:{name:recoveryClaim},spec:{accessModes:['ReadWriteOnce'],storageClassName:pvc.spec.storageClassName,resources:{requests:{storage:pvc.spec.resources.requests.storage}}}}));
  const serverPod = JSON.parse(k(['get', 'pods', '-l', `app.kubernetes.io/instance=${release}`, '-o', 'json'])).items.find(p => p.status.phase === 'Running');
  fixture.spec.nodeSelector = {'kubernetes.io/hostname':serverPod.spec.nodeName};
  fixture.spec.securityContext.fsGroup = 1000;
  fixture.spec.volumes = [{name:'source',persistentVolumeClaim:{claimName:sourceClaim}},{name:'recovery',persistentVolumeClaim:{claimName:recoveryClaim}}];
  fixture.spec.containers[0].volumeMounts = [{name:'source',mountPath:'/source',readOnly:true},{name:'recovery',mountPath:'/recovery'}];
}
try {
  k(['apply', '-f', '-'], JSON.stringify(fixture));
  k(['wait', '--for=condition=Ready', 'pod/rustdesk-protocol-client', '--timeout=80s']);
  const check = mode => {
    const out = k(['exec', '-i', 'rustdesk-protocol-client', '--', 'node', '-', name, String(values.server.rendezvousPort), String(values.server.relayPort), originalKey, mode, ...(values.websocket.enabled ? ['--websocket'] : [])], client);
    assert(out.includes('PASS'), out); console.log(out.trim());
  };
  check('initial');
  const service = JSON.parse(k(['get', 'service', name, '-o', 'json']));
  for (const address of service.spec.clusterIPs.filter(ip => ip.includes(':'))) {
    const out = k(['exec', '-i', 'rustdesk-protocol-client', '--', 'node', '-', address, String(values.server.rendezvousPort), String(values.server.relayPort), originalKey, 'initial'], client);
    assert(out.includes('PASS'), out);
    console.log(`PASS IPv6 Service: ${out.trim()}`);
  }
  if (values.persistence.enabled) {
    k(['rollout', 'restart', `deployment/${name}`]);
    k(['rollout', 'status', `deployment/${name}`, '--timeout=80s']);
    assert.equal(publicKey('hbbs'), originalKey, 'rendezvous identity survives Pod replacement');
    assert.equal(publicKey('hbbr'), originalKey, 'relay identity survives Pod replacement');
    check('retained');
    k(['scale', `deployment/${name}`, '--replicas=0']);
    k(['wait', '--for=delete', 'pod', '-l', `app.kubernetes.io/instance=${release}`, '--timeout=60s']);
    k(['exec', 'rustdesk-protocol-client', '--', 'node', '-e', 'require("node:fs").cpSync("/source", "/recovery", {recursive:true,force:true})']);
    execFileSync('helm', ['upgrade',release,fileURLToPath(new URL('..',import.meta.url)),'--kube-context',context,'-n',namespace,'--reuse-values','--set',`persistence.existingClaim=${recoveryClaim}`,'--wait','--timeout','60s'],{encoding:'utf8',timeout:70000,stdio:['pipe','pipe','pipe']});
    assert.equal(publicKey('hbbs'), originalKey, 'restored server preserves its identity');
    assert.equal(publicKey('hbbr'), originalKey, 'restored relay preserves its identity');
    check('retained');
    console.log('PASS recovery: quiesced complete data copied to a fresh PVC; identity, SQLite association and relay verified');
  }
} finally {
  k(['delete', 'pod/rustdesk-protocol-client', '--ignore-not-found', '--wait=true', '--timeout=30s']);
}
