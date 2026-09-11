// SPDX-License-Identifier: Apache-2.0
import assert from 'node:assert/strict';
import {execFileSync} from 'node:child_process';
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import {validateRecovery} from './runtime-recovery.mjs';

const [context, namespace, release] = process.argv.slice(2);
assert.equal(context, 'k3d-helmforge-tests-wsl');
assert.equal(namespace, 'hf-validate-hermes-agent');
const chart = path.resolve(import.meta.dirname, '..');
const base = ['--context', context, '-n', namespace];
const k = (args, input, timeout=65000) => execFileSync('kubectl', [...base, ...args], {encoding:'utf8',input,timeout,maxBuffer:8*1024*1024,stdio:['pipe','pipe','pipe']});
const json = args => JSON.parse(k(args));
const apply = object => k(['apply','-f','-'],JSON.stringify(object));
const helm = args => execFileSync('helm',[...args,'--kube-context',context,'-n',namespace],{encoding:'utf8',stdio:'pipe',timeout:80000,maxBuffer:8*1024*1024});
const delay = ms => new Promise(resolve=>setTimeout(resolve,ms));
let values = JSON.parse(helm(['get','values',release,'--all','-o','json']));
// The default installation deliberately requires real provider credentials. The
// acceptance harness replaces inference only with a controlled local provider.
if(values.agent.provider!=='custom:fixture') {
  k(['apply','-f',path.join(chart,'ci','fixtures','agent-values.yaml')]);
  k(['rollout','status','deployment/hermes-provider','--timeout=60s']);
  const temporary=fs.mkdtempSync(path.join(os.tmpdir(),'hf-hermes-'));
  const file=path.join(temporary,'values.json');
  try {
    fs.writeFileSync(file,JSON.stringify({agent:{model:'helmforge-fixture',provider:'custom:fixture',baseUrl:'http://hermes-provider:8080/v1',apiKeyEnv:'OPENAI_API_KEY',allowInsecureHTTP:true},credentials:{existingSecret:'hermes-provider-credentials'},networkPolicy:{allowInternet:false,extraEgress:[{to:[{podSelector:{matchLabels:{app:'hermes-provider'}}}],ports:[{protocol:'TCP',port:8080}]}]},config:{values:{model:{api_mode:'chat_completions'},auxiliary:{free_only:true}}}}));
    helm(['upgrade',release,chart,'--reuse-values','-f',file,'--wait','--timeout','60s']);
  } finally {fs.rmSync(file,{force:true});fs.rmdirSync(temporary);}
  values = JSON.parse(helm(['get','values',release,'--all','-o','json']));
}
const statefulSet=json(['get','sts','-l',`app.kubernetes.io/instance=${release}`,'-o','json']).items[0];
const name=statefulSet.metadata.name;
const pod=`${name}-0`;
const python=(script,container='hermes',target=pod,env=[])=>k(['exec','-i',target,'-c',container,'--','env',...env,'/opt/hermes/.venv/bin/python','-'],script);
const accept=prompt=>python(fs.readFileSync(path.join(chart,'scripts','agent-accept.py'),'utf8'),'hermes',pod,[`TEST_PROMPT=${prompt}`]);
const credentials=statefulSet.spec.template.spec.containers[0].env.find(item=>item.name==='API_SERVER_KEY').valueFrom.secretKeyRef.name;
const beforeSecret=json(['get','secret',credentials,'-o','json']).data;
python(`import os, pathlib, sqlite3
assert os.getuid()==10000
assert not pathlib.Path('/var/run/secrets/kubernetes.io/serviceaccount/token').exists()
try:
 pathlib.Path('/etc/helmforge-write-test').write_text('fail')
 raise AssertionError('Root filesystem is writable')
except PermissionError: pass
except OSError as error: assert error.errno==30
assert pathlib.Path('/proc/1/comm').read_text().strip()=='pause'
assert sqlite3.connect('/opt/data/state.db').execute('pragma integrity_check').fetchone()[0]=='ok'
assert any(pathlib.Path('/opt/data/skills').rglob('SKILL.md'))
print('PASS restricted runtime, sandbox reaper, bundled skills and SQLite integrity')
`);
console.log(accept('HF_MEMORY_STORE').trim());
const peer=json(['get','pods','-l','app=hermes-provider','-o','json']).items[0].metadata.name;
const peerGet=url=>python(`import urllib.request\nprint(urllib.request.urlopen(${JSON.stringify(url)},timeout=3).status)`,'provider',peer);
if(values.networkPolicy.enabled && values.networkPolicy.ingressFrom.length===0) {
  assert.throws(()=>peerGet(`http://${name}:${values.service.port}/health`),'Untrusted client must be denied by NetworkPolicy');
}
const policy='hermes-acceptance-network';
apply({apiVersion:'networking.k8s.io/v1',kind:'NetworkPolicy',metadata:{name:policy},spec:{podSelector:{matchLabels:{'app.kubernetes.io/instance':release,'app.kubernetes.io/component':'gateway'}},policyTypes:['Ingress'],ingress:[{from:[{podSelector:{matchLabels:{app:'hermes-provider'}}}],ports:[{protocol:'TCP',port:8642},...(values.dashboard.enabled?[{protocol:'TCP',port:9119}]:[])]}]}});
try {
  let reached=false;
  for(let attempt=0;attempt<8;attempt++) {
    try {reached=peerGet(`http://${name}:${values.service.port}/health`).trim()==='200';if(reached)break;}catch{}
    await delay(500);
  }
  assert(reached,'Explicitly admitted client must reach the API Service');
  if(values.service.ipFamilyPolicy==='RequireDualStack') {
    const service=json(['get','service',name,'-o','json']);
    assert.equal(service.spec.clusterIPs.length,2);
    for(const ip of service.spec.clusterIPs) assert.equal(peerGet(`http://${ip.includes(':')?`[${ip}]`:ip}:${values.service.port}/health`).trim(),'200');
    if(values.dashboard.enabled) {
      const dashboard=json(['get','service',`${name}-dashboard`,'-o','json']);
      assert.equal(dashboard.spec.clusterIPs.length,2);
      for(const ip of dashboard.spec.clusterIPs) assert.equal(peerGet(`http://${ip.includes(':')?`[${ip}]`:ip}:${values.dashboard.service.port}/api/health`).trim(),'200');
      console.log('PASS IPv4 and IPv6 dashboard Service access');
    }
  }
} finally {k(['delete','networkpolicy',policy]);}
console.log('PASS default-deny and explicitly allowed API network access');
if(values.dashboard.enabled) {
  console.log(python(fs.readFileSync(path.join(chart,'scripts','dashboard-accept.py'),'utf8'),'dashboard').trim());
}
if(values.metrics.enabled && values.metrics.collector.enabled) {
  let metrics='';
  for(let attempt=0;attempt<12;attempt++) {
    metrics=python("import urllib.request; print(urllib.request.urlopen('http://127.0.0.1:8889/metrics',timeout=5).read().decode())");
    if(/^hermes_gateway_up\{[^\n]*\} 1(?:\.0)?$/m.test(metrics)) break;
    await delay(2000);
  }
  assert.match(metrics,/^hermes_gateway_up\{[^\n]*\} 1(?:\.0)?$/m);
  assert.match(metrics,/^hermes_gateway_active_agents\{/m);
  const metricsUrl=`http://${name}-metrics:8889/metrics`;
  if(values.networkPolicy.enabled && values.metrics.ingressFrom.length===0) assert.throws(()=>peerGet(metricsUrl),'Metrics must deny untrusted peers');
  const metricsPolicy='hermes-acceptance-metrics';
  apply({apiVersion:'networking.k8s.io/v1',kind:'NetworkPolicy',metadata:{name:metricsPolicy},spec:{podSelector:{matchLabels:{'app.kubernetes.io/instance':release,'app.kubernetes.io/component':'gateway'}},policyTypes:['Ingress'],ingress:[{from:[{podSelector:{matchLabels:{app:'hermes-provider'}}}],ports:[{protocol:'TCP',port:8889}]}]}});
  try {
    await delay(1000);
    const exposed=python(`import urllib.request\nprint(urllib.request.urlopen(${JSON.stringify(metricsUrl)},timeout=5).read().decode())`,'provider',peer);
    assert.match(exposed,/^hermes_gateway_up\{[^\n]*\} 1(?:\.0)?$/m);
  } finally {k(['delete','networkpolicy',metricsPolicy]);}
  if(values.metrics.serviceMonitor.enabled) assert.equal(json(['get','servicemonitor',name,'-o','json']).spec.endpoints[0].port,'metrics');
  if(values.metrics.prometheusRule.enabled) assert.equal(json(['get','prometheusrule',name,'-o','json']).spec.groups[0].rules[0].alert,'HermesGatewayUnavailable');
  const metricsContainer=statefulSet.spec.template.spec.containers.find(item=>item.name==='metrics');
  assert.equal(metricsContainer.securityContext.runAsUser,10001);
  const boundaryName=`metrics-boundary-${Date.now()}`;
  const boundaryScript=`import os,pathlib
assert os.getuid()==10001 and os.getgid()==10001
found=0
for process in pathlib.Path('/proc').iterdir():
 if not process.name.isdigit(): continue
 try:
  command=(process/'cmdline').read_bytes()
  status=(process/'status').read_text()
 except (FileNotFoundError,PermissionError,ProcessLookupError): continue
 if b'gateway\\x00run' not in command or 'Uid:\\t10000\\t' not in status: continue
 found+=1
 try:
  (process/'environ').read_bytes()
  raise AssertionError('Collector identity can read gateway credentials')
 except PermissionError: pass
 try:
  os.kill(int(process.name),0)
  raise AssertionError('Collector identity can signal gateway')
 except PermissionError: pass
assert found>0,'Gateway process must be visible for a meaningful permission check'
print('PASS collector identity cannot read gateway environment or signal gateway')
`;
  const currentPod=json(['get','pod',pod,'-o','json']);
  currentPod.spec.ephemeralContainers=[...(currentPod.spec.ephemeralContainers||[]),{name:boundaryName,image:statefulSet.spec.template.spec.containers[0].image,command:['/opt/hermes/.venv/bin/python','-c',boundaryScript],securityContext:{...metricsContainer.securityContext,runAsNonRoot:true}}];
  k(['replace','--raw',`/api/v1/namespaces/${namespace}/pods/${pod}/ephemeralcontainers`,'-f','-'],JSON.stringify(currentPod));
  let finished;
  for(let attempt=0;attempt<40;attempt++) {
    finished=json(['get','pod',pod,'-o','json']).status.ephemeralContainerStatuses?.find(item=>item.name===boundaryName)?.state?.terminated;
    if(finished)break;
    await delay(500);
  }
  assert.equal(finished?.exitCode,0,'Collector permission boundary test must complete successfully');
  console.log(k(['logs',pod,'-c',boundaryName]).trim());
  console.log('PASS native gateway telemetry exported as Prometheus metrics');
}
if(values.externalSecrets.enabled) {
  for(const item of json(['get','externalsecrets','-l',`app.kubernetes.io/instance=${release}`,'-o','json']).items) {
    k(['wait','--for=condition=Ready',`externalsecret/${item.metadata.name}`,'--timeout=60s']);
    assert(json(['get','secret',item.spec.target.name,'-o','json']).data);
  }
  console.log('PASS ESO reconciled Secrets consumed by authenticated gateway');
}
if(values.persistence.enabled) {
  python("from pathlib import Path\np=Path('/opt/data/config.yaml')\np.write_text(p.read_text()+'\\n# helmforge-ci-user-edit\\n')");
  const oldUid=json(['get','pod',pod,'-o','json']).metadata.uid;
  k(['delete','pod',pod,'--wait=true','--timeout=60s']);
  k(['wait','--for=condition=Ready',`pod/${pod}`,'--timeout=60s']);
  assert.notEqual(json(['get','pod',pod,'-o','json']).metadata.uid,oldUid);
  assert.deepEqual(json(['get','secret',credentials,'-o','json']).data,beforeSecret);
  console.log(accept('HF_HISTORY_CHECK').trim());
  console.log(accept('HF_MEMORY_CHECK').trim());
  const configEdited=python("from pathlib import Path\nprint('helmforge-ci-user-edit' in Path('/opt/data/config.yaml').read_text())").trim();
  assert.equal(configEdited,values.config.policy==='seed'?'True':'False','Configuration ownership must survive Pod replacement as declared');
}
if(release.endsWith('-ci-agent-values')) {
  const claim=statefulSet.spec.template.spec.volumes.find(volume=>volume.name==='data').persistentVolumeClaim.claimName;
  const claimUid=json(['get','pvc',claim,'-o','json']).metadata.uid;
  const temporary=fs.mkdtempSync(path.join(os.tmpdir(),'hf-hermes-retain-'));
  const file=path.join(temporary,'values.json');
  try {
    fs.writeFileSync(file,JSON.stringify(values));
    helm(['uninstall',release,'--wait','--timeout','60s']);
    assert.equal(json(['get','pvc',claim,'-o','json']).metadata.uid,claimUid);
    assert.deepEqual(json(['get','secret',credentials,'-o','json']).data,beforeSecret);
    helm(['install',release,chart,'-f',file,'--wait','--timeout','60s']);
    assert.equal(json(['get','pvc',claim,'-o','json']).metadata.uid,claimUid);
    assert.deepEqual(json(['get','secret',credentials,'-o','json']).data,beforeSecret);
    console.log(accept('HF_HISTORY_CHECK').trim());
    console.log('PASS Helm uninstall/reinstall retains the same PVC, API identity and real conversation');
  } finally {fs.rmSync(file,{force:true});fs.rmdirSync(temporary);}
}
await validateRecovery({k,json,helm,values,name,pod,python,chart,namespace,release});
console.log('PASS Hermes authentication, inference, tool dispatch and persistent state');
