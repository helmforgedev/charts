// SPDX-License-Identifier: Apache-2.0
import assert from 'node:assert/strict';
import {execFileSync} from 'node:child_process';
import {setTimeout as delay} from 'node:timers/promises';
const [context,namespace,release] = process.argv.slice(2);
if (!context?.startsWith('k3d-helmforge-') || !namespace || !release) {
  throw new Error('Explicit HelmForge lab context, namespace and release required');
}
const target = ['--context',context,'-n',namespace];
const kubectl = args => execFileSync('kubectl',[...target,...args],{encoding:'utf8',timeout:30000,stdio:['ignore','pipe','pipe']});
const pods = JSON.parse(kubectl(['get','pods','-l',`app.kubernetes.io/instance=${release}`,'-o','json'])).items;
const pod = pods.find(p => !p.metadata.deletionTimestamp && p.spec.containers.some(c => c.name === 'cloudflared'));
assert.ok(pod,'cloudflared pod required');
const version = kubectl(['exec',pod.metadata.name,'-c','cloudflared','--','cloudflared','version']);
assert.match(version,/cloudflared version 2026\.8\.3\b/);
const container = pod.spec.containers.find(c => c.name === 'cloudflared');
if (container.command?.includes('--hello-world')) {
  const logs = kubectl(['logs',pod.metadata.name,'-c','cloudflared']);
  const url = logs.match(/https:\/\/[a-z0-9-]+\.trycloudflare\.com\b/)?.[0];
  assert.ok(url,'Quick tunnel hostname required');
  let status, error;
  for (let i=0; i<6; i++) {
    try {
      const response = await fetch(url,{redirect:'manual',signal:AbortSignal.timeout(15000)});
      status = response.status;
      await response.arrayBuffer();
      if (status === 200) break;
    } catch (caught) { error = caught.message; }
    await delay(3000);
  }
  assert.equal(status,200,`Quick tunnel HTTPS origin request failed: ${error || status}`);
  console.log('cloudflared 2026.8.3: HTTPS request through the live quick tunnel reached the built-in origin.');
} else {
  console.log('cloudflared 2026.8.3: binary version verified; custom/managed origin is not requested by this smoke test.');
}
