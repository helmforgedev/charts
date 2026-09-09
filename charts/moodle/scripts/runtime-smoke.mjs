// SPDX-License-Identifier: Apache-2.0
import {execFileSync} from 'node:child_process';
const [context,namespace,release]=process.argv.slice(2);
if(!context?.startsWith('k3d-helmforge-') || !namespace || !release) throw new Error('Explicit HelmForge lab context, namespace and release required');
const k=(...args)=>execFileSync('kubectl',['--context',context,'--namespace',namespace,'--request-timeout=20s',...args],{encoding:'utf8',timeout:60000,maxBuffer:4*1024*1024});
const runWithInput=(input,...args)=>execFileSync('kubectl',['--context',context,'--namespace',namespace,'--request-timeout=20s',...args],{input,encoding:'utf8',timeout:120000,maxBuffer:4*1024*1024});
const pods=JSON.parse(k('get','pods','-l',`app.kubernetes.io/instance=${release}`,'-o','json')).items;
const web=pods.filter(p=>p.spec.containers.some(c=>c.name==='moodle') && !p.metadata.deletionTimestamp);
if(!web.length) throw new Error('No Moodle application pods found');
const services=JSON.parse(k('get','services','-l',`app.kubernetes.io/instance=${release}`,'-o','json')).items;
const service=services.find(s=>s.spec.ports.some(p=>p.name==='http'));
if(!service) throw new Error('No Moodle HTTP Service found');
for(const pod of web) {
  const name=pod.metadata.name;
  const ref=pod.spec.initContainers.find(c=>c.name==='install-database').env.find(e=>e.name==='ADMIN_PASSWORD').valueFrom.secretKeyRef;
  const secret=JSON.parse(k('get','secret',ref.name,'-o','json'));
  const config=JSON.parse(k('get','configmap',service.metadata.name,'-o','json'));
  const settings=JSON.parse(config.data['settings.json']);
  const credentials=JSON.stringify({username:settings.moodle.adminUser,password:Buffer.from(secret.data[ref.key],'base64').toString('utf8')});
  process.stdout.write(runWithInput(credentials,'exec','-i',name,'-c','moodle','--','php','/opt/helmforge/smoke.php',service.metadata.name,String(service.spec.ports.find(p=>p.name==='http').port)));
  if(settings.metrics.enabled) {
    const metricsService=services.find(s=>s.metadata.labels?.['app.kubernetes.io/component']==='metrics');
    const allServices=JSON.parse(k('get','services','-o','json')).items;
    const monitor=allServices.find(s=>s.metadata.name==='moodle-monitor');
    if(!metricsService) throw new Error('Metrics Service is missing');
    process.stdout.write(execFileSync('kubectl',['--context',context,'--namespace',namespace,
      'exec',name,'-c','moodle','--','php','/opt/helmforge/metrics-smoke.php',metricsService.metadata.name,
      `${service.metadata.name}:${service.spec.ports.find(p=>p.name==='http').port}`,...(monitor?['moodle-monitor']:[])],
      {encoding:'utf8',timeout:240000,maxBuffer:4*1024*1024}));
  }
  if(pod.spec.containers.some(c=>c.name==='cron')) {
    let completed=false;
    for(let attempt=0;attempt<15;attempt++) {
      try {k('exec',name,'-c','cron','--','test','-s','/tmp/moodle-task-last-success');completed=true;break;} catch {}
      await new Promise(resolve=>setTimeout(resolve,2000));
    }
    if(!completed) throw new Error(`${name}: no successful cron cycle`);
    console.log(`${name}: successful cron cycle verified`);
  }
}
if(web.length>1) {
  const marker=`helmforge-shared-${release}`;
  k('exec',web[0].metadata.name,'-c','moodle','--','php','-r','file_put_contents("/var/moodledata/".$argv[1], "shared-state-ok");',marker);
  for(const pod of web.slice(1)) {
    const result=k('exec',pod.metadata.name,'-c','moodle','--','php','-r','echo file_get_contents("/var/moodledata/".$argv[1]);',marker);
    if(result!=='shared-state-ok') throw new Error('Moodledata is not shared between replicas');
  }
  k('exec',web[0].metadata.name,'-c','moodle','--','php','-r','unlink("/var/moodledata/".$argv[1]);',marker);
  console.log('Concurrent replicas read the same persisted Moodledata marker');
}
const external=JSON.parse(k('get','externalsecrets','-o','json')).items;
for(const item of external) {
  if(!item.status?.conditions?.some(c=>c.type==='Ready'&&c.status==='True')) throw new Error('ExternalSecret is not Ready');
  console.log(`${item.metadata.name}: ExternalSecret Ready`);
}
