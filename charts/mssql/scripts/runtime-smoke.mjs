// SPDX-License-Identifier: Apache-2.0
import assert from 'node:assert/strict';
import {execFileSync} from 'node:child_process';
import path from 'node:path';
import {validateBackup} from './runtime-backup.mjs';
import {validateExternalSecrets,validateObservability} from './runtime-observability.mjs';
import {validateInitialization,validateAgent} from './runtime-initialization.mjs';
const [context,ns,release]=process.argv.slice(2);
assert.equal(context,'k3d-helmforge-tests-wsl');assert.equal(ns,'hf-validate-mssql');
const base=['--context',context,'-n',ns];
function k(args,input,timeout=90000){return execFileSync('kubectl',[...base,...args],{encoding:'utf8',input,timeout,maxBuffer:8*1024*1024,stdio:['pipe','pipe','pipe']});}
const json=args=>JSON.parse(k(args));
const apply=value=>k(['apply','-f','-'],JSON.stringify(value));
const wait=ms=>new Promise(r=>setTimeout(r,ms));
let values=JSON.parse(execFileSync('helm',['get','values',release,'--all','-n',ns,'--kube-context',context,'-o','json'],{encoding:'utf8'}));
if(!values.license.acceptEULA){
  assert.equal(json(['get','statefulsets,pvc,secret,service','-o','json']).items.filter(x=>x.kind!=='Secret'||x.type!=='helm.sh/release.v1').length,0,'No SQL resources before consent');
  execFileSync('helm',['upgrade',release,path.resolve(import.meta.dirname,'..'),'-n',ns,'--kube-context',context,'--reuse-values','--set','license.acceptEULA=true','--set','initdb.databases[0].name=acceptance','--wait','--timeout','120s'],{stdio:'pipe',timeout:140000});
  values.license.acceptEULA=true;
  console.log('PASS explicit EULA gate: no server or storage until opt-in');
}
let sts=json(['get','sts','-o','json']).items.find(x=>x.metadata.labels['app.kubernetes.io/instance']===release);
await validateExternalSecrets({k,json,values,release});
assert(sts);const name=sts.metadata.name;let pod=`${name}-0`;
const exec=(script)=>k(['exec',pod,'-c','mssql','--','/bin/bash','-ec',script]);
function sql(query,user='sa',key='sa-password'){
  // Input over stdin avoids shell interpretation; password is read inside the container.
  return k(['exec','-i',pod,'-c','mssql','--','/bin/bash','-ec',`export SQLCMDPASSWORD="$(cat /auth/${key})"; exec /opt/mssql-tools18/bin/sqlcmd -S localhost -U ${user} -C -b -x -h -1 -W`],`SET NOCOUNT ON;\n${query}\nGO\n`).trim();
}
const edition=sql("SELECT CAST(SERVERPROPERTY('Edition') AS nvarchar(100))");
assert.match(edition,values.sql.edition==='Express'?/Express/i:/Developer|Standard|Enterprise|Evaluation/i);
const version=sql("SELECT CAST(SERVERPROPERTY('ProductVersion') AS nvarchar(100))");
assert.match(version,values.image.tag.startsWith('2022-')?/^16\./:/^17\./);
assert.equal(sql('SELECT 1','hf_probe','probe-password'),'1');
assert.equal(sql("SELECT IS_SRVROLEMEMBER('sysadmin')",'hf_probe','probe-password'),'0');
assert.equal(sql('SELECT encrypt_option FROM sys.dm_exec_connections WHERE session_id=@@SPID'),'TRUE');
assert.equal(exec('id -u').trim(),'10001');
assert.equal(exec('if touch /etc/hf-should-fail 2>/dev/null; then echo writable; else echo readonly; fi').trim(),'readonly');
assert.equal(exec('test ! -e /var/run/secrets/kubernetes.io/serviceaccount/token && echo absent').trim(),'absent');
assert.equal(exec('stat -c %a /run/mssql/tls.key').trim(),'600');
console.log(`PASS native SQL ${version} ${edition}; authenticated queries, encryption and restricted runtime`);
validateInitialization({k,json,sql,values,pod,phase:'before restart'});
sql("IF DB_ID(N'acceptance') IS NULL CREATE DATABASE [acceptance];");
sql("USE [acceptance]; IF OBJECT_ID(N'dbo.verification') IS NULL CREATE TABLE dbo.verification(id int PRIMARY KEY,value nvarchar(60)); IF NOT EXISTS(SELECT 1 FROM dbo.verification WHERE id=1) INSERT dbo.verification VALUES(1,N'persistent SQL data');");
assert.equal(sql('SELECT value FROM acceptance.dbo.verification WHERE id=1'),'persistent SQL data');
await validateAgent({sql,values});
const auth=sts.spec.template.spec.volumes.find(v=>v.name==='auth').secret.secretName;
const tls=sts.spec.template.spec.volumes.find(v=>v.name==='tls').secret.secretName;
const before=json(['get','secret',auth,'-o','json']).data;
// A real client starts outside the SQL selector, first denied, then explicitly admitted.
const peer='mssql-validation-client';
apply({apiVersion:'v1',kind:'Pod',metadata:{name:peer,labels:{'helmforge.dev/runtime-fixture':'true','helmforge.dev/sql-client':'test'}},spec:{restartPolicy:'Never',automountServiceAccountToken:false,terminationGracePeriodSeconds:1,securityContext:{runAsUser:10001,runAsGroup:10001,fsGroup:10001,runAsNonRoot:true,seccompProfile:{type:'RuntimeDefault'}},containers:[{name:'client',image:`${values.image.repository}:${values.image.tag}`,command:['/bin/bash','-c','sleep 600'],env:[{name:'SQLCMDPASSWORD',valueFrom:{secretKeyRef:{name:auth,key:'probe-password'}}},{name:'SSL_CERT_FILE',value:'/tls/ca.crt'}],securityContext:{readOnlyRootFilesystem:true,allowPrivilegeEscalation:false,capabilities:{drop:['ALL']}},resources:{requests:{cpu:'50m',memory:'128Mi'},limits:{cpu:'500m',memory:'512Mi'}},volumeMounts:[{name:'tls',mountPath:'/tls',readOnly:true},{name:'tmp',mountPath:'/tmp'}]}],volumes:[{name:'tls',secret:{secretName:tls,items:[{key:'ca.crt',path:'ca.crt'}]}},{name:'tmp',emptyDir:{sizeLimit:'64Mi'}}]}});
k(['wait','--for=condition=Ready',`pod/${peer}`,'--timeout=45s']);
function peerSql(host=name){return k(['exec',peer,'--','/opt/mssql-tools18/bin/sqlcmd','-S',`${host},${values.service.port}`,'-U','hf_probe','-N','-b','-l','3','-t','3','-h','-1','-W','-Q','SET NOCOUNT ON; SELECT 1;'],undefined,12000).trim();}
if(values.networkPolicy.enabled){assert.throws(()=>peerSql(),'untrusted network peer must be denied');}
apply({apiVersion:'networking.k8s.io/v1',kind:'NetworkPolicy',metadata:{name:'mssql-validation-client'},spec:{podSelector:{matchLabels:{'app.kubernetes.io/instance':release,'app.kubernetes.io/component':'server'}},policyTypes:['Ingress'],ingress:[{from:[{podSelector:{matchLabels:{'helmforge.dev/sql-client':'test'}}}],ports:[{port:1433,protocol:'TCP'}]}]}});
let connected=false;for(let i=0;i<10;i++){try{connected=peerSql()==='1';if(connected)break;}catch{}await wait(1000);}assert(connected,'trusted client connects through Service with CA and hostname validation');
apply({apiVersion:'v1',kind:'Service',metadata:{name:'mssql-unlisted-name'},spec:{selector:{'app.kubernetes.io/instance':release,'app.kubernetes.io/component':'server'},ports:[{port:values.service.port,targetPort:1433}]}});
assert.throws(()=>peerSql('mssql-unlisted-name'),'Service DNS name absent from certificate SANs must fail');
assert.throws(()=>k(['exec',peer,'--','/bin/bash','-ec',`export SSL_CERT_FILE=/missing/ca.crt; /opt/mssql-tools18/bin/sqlcmd -S ${name},${values.service.port} -U hf_probe -N -b -l 3 -Q "SELECT 1"`]),'untrusted CA must fail');
if(values.service.ipFamilyPolicy==='RequireDualStack'){
  const service=json(['get','service',name,'-o','json']);
  assert.equal(service.spec.clusterIPs.length,2);
  for(const address of service.spec.clusterIPs){
    const target=address.includes(':')?`tcp:[${address}],${values.service.port}`:`tcp:${address},${values.service.port}`;
    // Certificate identity is tested through DNS above; raw IPs prove both Service routes.
    assert.equal(k(['exec',peer,'--','/opt/mssql-tools18/bin/sqlcmd','-S',target,'-U','hf_probe','-N','-C','-b','-l','5','-h','-1','-W','-Q','SET NOCOUNT ON; SELECT 1;']).trim(),'1');
  }
  console.log('PASS authenticated SQL through both IPv4 and IPv6 ClusterIPs');
}
k(['delete','service','mssql-unlisted-name']);
console.log('PASS SQL Service connectivity, valid CA/hostname, invalid hostname rejection and network isolation');
k(['delete','pod',peer,'--wait=true','--timeout=30s']);k(['delete','networkpolicy','mssql-validation-client']);
await validateObservability({k,json,apply,sql,values,name,pod,ns,release,context});
if(values.backup.enabled){
  sql('USE [acceptance]; IF USER_ID(N\'hf_backup\') IS NULL CREATE USER hf_backup FOR LOGIN hf_backup; ALTER ROLE db_backupoperator ADD MEMBER hf_backup;');
  assert.equal(sql("SELECT IS_SRVROLEMEMBER('sysadmin')",'hf_backup','backup-password'),'0');
  const job='mssql-backup-acceptance';k(['create','job',job,`--from=cronjob/${name}-backup`]);
  k(['wait','--for=condition=complete',`job/${job}`,'--timeout=120s'],undefined,130000);
  assert(Number(exec('cat /backup/.last-success').trim())>Math.floor(Date.now()/1000)-300);
  await validateBackup({k,json,apply,sql,values,name,pod,ns,context});
}
// Actual live Helm lookup upgrade must retain credentials, not only render defaults.
execFileSync('helm',['upgrade',release,path.resolve(import.meta.dirname,'..'),'-n',ns,'--kube-context',context,'--reuse-values','--wait','--timeout','90s'],{stdio:'pipe',timeout:100000});
assert(JSON.stringify(json(['get','secret',auth,'-o','json']).data)===JSON.stringify(before),'authentication Secret must remain unchanged');
const uid=json(['get','pod',pod,'-o','json']).metadata.uid;
k(['rollout','restart',`statefulset/${name}`]);k(['rollout','status',`statefulset/${name}`,'--timeout=90s'],undefined,100000);
assert.notEqual(json(['get','pod',pod,'-o','json']).metadata.uid,uid);
assert.equal(sql('SELECT value FROM acceptance.dbo.verification WHERE id=1'),'persistent SQL data');
assert.equal(sql('SELECT 1','hf_probe','probe-password'),'1');
console.log('PASS data and authentication retained across real Helm upgrade and Pod replacement');
validateInitialization({k,json,sql,values,pod,phase:'after restart'});
