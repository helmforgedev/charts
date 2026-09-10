// SPDX-License-Identifier: Apache-2.0
import assert from 'node:assert/strict';
import {execFileSync, spawn} from 'node:child_process';
import {setTimeout as delay} from 'node:timers/promises';
const [context, namespace, release] = process.argv.slice(2);
if (!context?.startsWith('k3d-helmforge-') || !namespace || !release) {
  throw new Error('Explicit HelmForge lab context, namespace and release required');
}
const run = (bin, args) => execFileSync(bin, args, {encoding:'utf8', timeout:30000, stdio:['ignore','pipe','pipe']});
const target = ['--context',context,'-n',namespace];
const pods = JSON.parse(run('kubectl',[...target,'get','pods','-l',`app.kubernetes.io/instance=${release}`,'-o','json'])).items;
const pod = pods.find(p => !p.metadata.deletionTimestamp && p.spec.containers.some(c => c.name === 'jenkins'));
assert.ok(pod, 'Jenkins controller pod required');
const container = pod.spec.containers.find(c => c.name === 'jenkins');
function env(name) {
  const entry = container.env?.find(e => e.name === name);
  if (entry?.value !== undefined) return entry.value;
  const ref = entry?.valueFrom?.secretKeyRef;
  if (!ref) return undefined;
  const secret = JSON.parse(run('kubectl',[...target,'get','secret',ref.name,'-o','json']));
  assert.ok(secret.data?.[ref.key], `Missing credential key ${ref.key}`);
  return Buffer.from(secret.data[ref.key],'base64').toString();
}
const user = env('JENKINS_ADMIN_USER'), password = env('JENKINS_ADMIN_PASSWORD');
const port = container.ports.find(p => p.name === 'http').containerPort;
const child = spawn('kubectl',[...target,'port-forward',`pod/${pod.metadata.name}`,`:${port}`,'--address=127.0.0.1'],{windowsHide:true,stdio:['ignore','pipe','pipe']});
let output = '';
child.stdout.on('data',c => {output += c;});
child.stderr.on('data',() => {});
let childError;
child.on('error',error => {childError = error;});
try {
  for (let i=0; i<150 && !/127\.0\.0\.1:(\d+) ->/.test(output) && !childError; i++) await delay(100);
  if (childError) throw childError;
  const localPort = output.match(/127\.0\.0\.1:(\d+) ->/)?.[1];
  assert.ok(localPort,'Jenkins port-forward did not become ready');
  const base = `http://127.0.0.1:${localPort}`;
  const request = (route, options={}) => fetch(base+route,{...options,redirect:'manual',signal:AbortSignal.timeout(20000)});
  const login = await request('/login');
  assert.equal(login.status,200,'Login page');
  assert.equal(login.headers.get('x-jenkins'),'2.568.3','Actual Jenkins version');
  await login.arrayBuffer();
  if (user && password) {
    const anonymous = await request('/api/json');
    assert.equal(anonymous.status,403,'Anonymous controller access must be denied');
    await anonymous.arrayBuffer();
    const headers = {Authorization:`Basic ${Buffer.from(`${user}:${password}`).toString('base64')}`};
    const crumbResponse = await request('/crumbIssuer/api/json',{headers});
    assert.equal(crumbResponse.status,200,'Authenticated crumb request');
    const cookie = crumbResponse.headers.getSetCookie().map(c => c.split(';')[0]).join('; ');
    const crumb = await crumbResponse.json();
    assert.ok(cookie && crumb.crumb && crumb.crumbRequestField,'Session-bound CSRF protection');
    Object.assign(headers,{Cookie:cookie,[crumb.crumbRequestField]:crumb.crumb,'Content-Type':'application/xml'});
    const name = 'helmforge-upstream-smoke';
    const created = await request(`/createItem?name=${name}`,{method:'POST',headers,body:'<project><description>helmforge-configuration-roundtrip</description><disabled>true</disabled></project>'});
    assert.equal(created.status,200,'Create disabled test job with CSRF crumb');
    await created.arrayBuffer();
    const config = await request(`/job/${name}/config.xml`,{headers});
    assert.equal(config.status,200,'Read persisted job configuration');
    assert.match(await config.text(),/helmforge-configuration-roundtrip/);
    const deleted = await request(`/job/${name}/doDelete`,{method:'POST',headers});
    assert.ok([200,302,303].includes(deleted.status),'Delete test job');
    await deleted.arrayBuffer();
    console.log('Jenkins 2.568.3: anonymous denial, admin authentication, session CSRF and job configuration roundtrip passed.');
  } else {
    console.log('Jenkins 2.568.3: login/version passed; bootstrap credentials are not configured in this scenario.');
  }
} finally {
  if (child.exitCode === null && child.pid) {
    if (process.platform === 'win32') run('taskkill',['/PID',String(child.pid),'/T','/F']);
    else child.kill('SIGTERM');
  }
}
