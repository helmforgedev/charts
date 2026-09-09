// SPDX-License-Identifier: Apache-2.0
import assert from 'node:assert/strict';
import {execFileSync, spawn} from 'node:child_process';
import {setTimeout as delay} from 'node:timers/promises';
const [context, namespace, release] = process.argv.slice(2);
if (!context?.startsWith('k3d-helmforge-') || !namespace || !release) {
  throw new Error('Explicit HelmForge lab context, namespace and release required');
}
const target = ['--context', context, '-n', namespace];
const kubectl = args => execFileSync('kubectl', [...target, ...args], {encoding:'utf8', timeout:30000, stdio:['ignore','pipe','pipe']});
const pods = JSON.parse(kubectl(['get','pods','-l',`app.kubernetes.io/instance=${release}`,'-o','json'])).items;
const pod = pods.find(p => !p.metadata.deletionTimestamp
  && p.status.conditions?.some(c => c.type === 'Ready' && c.status === 'True')
  && p.spec.containers.some(c => c.name === 'server'));
assert.ok(pod, 'Ready NetBird server pod required');
let logs='';
for(let i=0;i<30;i++) {
  logs=kubectl(['logs',pod.metadata.name,'-c','server']);
  if(logs.includes('running metrics server:')) break;
  await delay(1000);
}
assert.match(logs,/management server version 0\.78\.1\b/);
assert.match(logs,/running metrics server:/);
const child = spawn('kubectl', [...target,'port-forward',`pod/${pod.metadata.name}`,':80',':9090','--address=127.0.0.1'], {
  windowsHide:true, stdio:['ignore','pipe','pipe'],
});
let output='', error;
child.stdout.on('data', chunk => {output+=chunk;});
child.stderr.on('data', () => {});
child.on('error', caught => {error=caught;});
try {
  const ports = {};
  for (let i=0;i<150 && Object.keys(ports).length<2 && !error;i++) {
    for (const m of output.matchAll(/127\.0\.0\.1:(\d+) -> (\d+)/g)) ports[m[2]]=m[1];
    await delay(100);
  }
  if(error) throw error;
  assert.equal(Object.keys(ports).length,2,'All port forwards required');
  const deadline=Date.now()+90000;
  async function get(port, route, expected) {
    let last;
    for(let i=0;i<30 && Date.now()<deadline;i++) {
      try {
        const response=await fetch(`http://127.0.0.1:${ports[port]}${route}`, {redirect:'manual',signal:AbortSignal.timeout(4000)});
        const body=await response.text();
        if(response.status===expected) return body;
        last=`HTTP ${response.status}`;
      } catch(caught) {last=caught.message;}
      await delay(1000);
    }
    throw new Error(`${route}: expected ${expected}, last result ${last}`);
  }
  // The relay health endpoint validates the public URL; it is not local readiness.
  await get(80,'/api/accounts',401);
  const discovery=JSON.parse(await get(80,'/oauth2/.well-known/openid-configuration',200));
  assert.ok(discovery.issuer && discovery.jwks_uri,'OIDC issuer and signing keys required');
  assert.match(await get(9090,'/metrics',200),/# (?:HELP|TYPE) /);
  await new Promise((resolve,reject) => {
    const socket=new WebSocket(`ws://127.0.0.1:${ports[80]}/relay`);
    const timer=setTimeout(()=>{socket.close();reject(new Error('Relay WebSocket upgrade timed out'));},10000);
    socket.addEventListener('open',()=>{clearTimeout(timer);socket.close();resolve();},{once:true});
    socket.addEventListener('error',()=>{clearTimeout(timer);reject(new Error('Relay WebSocket upgrade failed'));},{once:true});
  });
  console.log('NetBird 0.78.1: unauthenticated API rejection, embedded OIDC discovery, relay WebSocket upgrade and Prometheus exposition verified.');
} finally {
  if(child.exitCode===null) {
    if(process.platform==='win32') execFileSync('taskkill',['/PID',String(child.pid),'/T','/F'],{stdio:'ignore'});
    else child.kill('SIGTERM');
  }
}
