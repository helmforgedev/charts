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
  && p.spec.containers.some(c => c.name === 'matterbridge'));
assert.ok(pod, 'Ready Matterbridge pod required');
const container = pod.spec.containers.find(c => c.name === 'matterbridge');
const port = container.ports.find(p => p.name === 'http').containerPort;
const code = `
const fs=require('node:fs'),path=require('node:path');
let dir=path.dirname(fs.realpathSync('/usr/local/bin/matterbridge')), version;
while(dir!==path.dirname(dir)) {
  const file=path.join(dir,'package.json');
  if(fs.existsSync(file)){const pkg=JSON.parse(fs.readFileSync(file));if(pkg.name==='matterbridge'){version=pkg.version;break;}}
  dir=path.dirname(dir);
}
fetch('http://127.0.0.1:${port}/health').then(async r=>{
 if(r.status!==200)throw new Error('Health status '+r.status);
 console.log(JSON.stringify({version,health:await r.json()}));
}).catch(e=>{console.error(e.message);process.exitCode=1;});`;
const result = JSON.parse(kubectl(['exec', pod.metadata.name, '-c', 'matterbridge', '--', 'node', '-e', code]));
assert.equal(result.version, '3.10.8');
assert.equal(result.health.status, 'ok');
console.log('Matterbridge standalone 3.10.8: installed package version and live HTTP health verified.');
