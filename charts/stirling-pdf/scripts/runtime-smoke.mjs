// SPDX-License-Identifier: Apache-2.0
import assert from 'node:assert/strict';
import {execFileSync,spawn} from 'node:child_process';
import {fileURLToPath} from 'node:url';
import {inflateRawSync} from 'node:zlib';
import {PDFDocument,StandardFonts,rgb} from 'pdf-lib';
const [context,namespace,release]=process.argv.slice(2);assert.match(context??'',/^k3d-/);assert.ok(namespace&&release);
const k=args=>execFileSync('kubectl',['--context',context,'-n',namespace,...args],{encoding:'utf8',timeout:120000});
const values=JSON.parse(execFileSync('helm',['get','values',release,'-n',namespace,'--kube-context',context,'-a','-o','json'],{encoding:'utf8'}));
const selector=`app.kubernetes.io/instance=${release},app.kubernetes.io/name=stirling-pdf`;
const deployment=JSON.parse(k(['get','deploy','-l',selector,'-o','json'])).items[0];assert.ok(deployment);
const secretName=deployment.spec.template.spec.containers[0].env.find(e=>e.name==='SECURITY_INITIALLOGIN_PASSWORD').valueFrom.secretKeyRef.name;
const secret=JSON.parse(k(['get','secret',secretName,'-o','json'])).data;const password=Buffer.from(secret[values.auth.passwordKey],'base64').toString();
const pod=()=>JSON.parse(k(['get','pods','-l',selector,'-o','json'])).items.find(p=>!p.metadata.deletionTimestamp).metadata.name;
async function forward(test,remote='pod/'+pod(),remotePort=values.server.port,basePath=values.server.basePath){
 const child=spawn('kubectl',['--context',context,'-n',namespace,'port-forward',remote,':'+remotePort,'--address=127.0.0.1'],{windowsHide:true,stdio:['ignore','pipe','pipe']});let output='';for(const stream of [child.stdout,child.stderr])stream.on('data',b=>output+=b);
 try{const deadline=Date.now()+20000;while(!/127\.0\.0\.1:(\d+) ->/.test(output)&&Date.now()<deadline&&child.exitCode===null)await new Promise(r=>setTimeout(r,100));const port=output.match(/127\.0\.0\.1:(\d+) ->/)?.[1];assert.ok(port);await test('http://127.0.0.1:'+port+basePath);}
 finally{if(process.platform==='win32'&&child.exitCode===null){try{execFileSync('taskkill',['/PID',String(child.pid),'/T','/F'],{stdio:'ignore'});}catch(error){let gone=false;try{process.kill(child.pid,0);}catch(e){if(e.code==='ESRCH')gone=true;else throw e;}if(!gone)throw error;}}else child.kill();}
}
async function pdf(text,width=612){const doc=await PDFDocument.create();const font=await doc.embedFont(StandardFonts.Helvetica);const page=doc.addPage([width,792]);page.drawText(text,{x:40,y:500,size:22,font,color:rgb(0,0,0)});return await doc.save();}
const first=await pdf('HELMFORGE MERGE FIRST',612),second=await pdf('HELMFORGE MERGE SECOND',620);
const pdfText=bytes=>execFileSync('kubectl',['--context',context,'-n',namespace,'exec','-i',pod(),'-c','stirling-pdf','--','pdftotext','-','-'],{input:Buffer.from(bytes),encoding:'utf8',timeout:20000});
let apiKey;
if(values.externalSecrets.enabled){const items=JSON.parse(k(['get','externalsecrets','-o','json'])).items;assert.ok(items.length);assert.ok(items.every(e=>e.status?.conditions?.some(c=>c.type==='Ready'&&c.status==='True')));}
async function authenticate(base){const response=await fetch(base+'/api/v1/auth/login',{method:'POST',headers:{'Content-Type':'application/json'},body:JSON.stringify({username:values.auth.username,password}),signal:AbortSignal.timeout(15000)});assert.equal(response.status,200,'native administrator login');const body=await response.json();assert.ok(body.session?.access_token);const headers={Authorization:'Bearer '+body.session.access_token};const keyResponse=await fetch(base+'/api/v1/user/get-api-key',{method:'POST',headers,signal:AbortSignal.timeout(15000)});assert.equal(keyResponse.status,200);const current=(await keyResponse.json()).apiKey;assert.ok(current);if(apiKey)assert.equal(current,apiKey,'API key persisted in H2');else apiKey=current;}
function multipart(){const form=new FormData();form.append('fileInput',new Blob([first],{type:'application/pdf'}),'first.pdf');form.append('fileInput',new Blob([second],{type:'application/pdf'}),'second.pdf');return form;}
async function merge(base){const response=await fetch(base+'/api/v1/general/merge-pdfs?async=false',{method:'POST',headers:{'X-API-KEY':apiKey},body:multipart(),signal:AbortSignal.timeout(60000)});assert.equal(response.status,200,'authenticated PDF merge');const bytes=new Uint8Array(await response.arrayBuffer());const output=await PDFDocument.load(bytes);assert.equal(output.getPageCount(),2);assert.equal(output.getPage(0).getWidth(),612);assert.equal(output.getPage(1).getWidth(),620);const text=pdfText(bytes);assert.ok(text.indexOf('HELMFORGE MERGE FIRST')>=0);assert.ok(text.indexOf('HELMFORGE MERGE SECOND')>text.indexOf('HELMFORGE MERGE FIRST'));}
await forward(async base=>{const anonymous=await fetch(base+'/api/v1/general/merge-pdfs?async=false',{method:'POST',body:multipart(),redirect:'manual',signal:AbortSignal.timeout(15000)});assert.equal(anonymous.status,401);await authenticate(base);await merge(base);});
const verifyReplacement=values.persistence.enabled && /-(default|test)-/.test(deployment.metadata.name);
if(verifyReplacement){k(['rollout','restart','deployment/'+deployment.metadata.name]);k(['rollout','status','deployment/'+deployment.metadata.name,'--timeout=120s']);await forward(async base=>{await authenticate(base);await merge(base);});}
execFileSync('helm',['upgrade',release,fileURLToPath(new URL('..',import.meta.url)),'--kube-context',context,'-n',namespace,'--reuse-values','--wait','--timeout','60s'],{encoding:'utf8',timeout:75000});assert.deepEqual(JSON.parse(k(['get','secret',secretName,'-o','json'])).data,secret);
// ZIP entries are parsed in memory; no archive path is written to disk.
function unzip(bytes){const buffer=Buffer.from(bytes);let end=buffer.length-22;while(end>=0&&buffer.readUInt32LE(end)!==0x06054b50)end--;assert.ok(end>=0);const count=buffer.readUInt16LE(end+10);let offset=buffer.readUInt32LE(end+16);const files=new Map();for(let i=0;i<count;i++){assert.equal(buffer.readUInt32LE(offset),0x02014b50);const method=buffer.readUInt16LE(offset+10),size=buffer.readUInt32LE(offset+20),nameLength=buffer.readUInt16LE(offset+28),extraLength=buffer.readUInt16LE(offset+30),commentLength=buffer.readUInt16LE(offset+32),local=buffer.readUInt32LE(offset+42);const name=buffer.subarray(offset+46,offset+46+nameLength).toString();const start=local+30+buffer.readUInt16LE(local+26)+buffer.readUInt16LE(local+28);const compressed=buffer.subarray(start,start+size);assert.ok(method===0||method===8);files.set(name,method===8?inflateRawSync(compressed):compressed);offset+=46+nameLength+extraLength+commentLength;}return files;}
if(deployment.metadata.name==='stirling-pdf-ocr')await forward(async base=>{const form=new FormData();form.append('fileInput',new Blob([await pdf('HELMFORGE DOCUMENT CHECK')],{type:'application/pdf'}),'fixture.pdf');for(const[key,value]of Object.entries({languages:'eng',ocrType:'force-ocr',ocrRenderType:'hocr',sidecar:'true'}))form.append(key,value);const response=await fetch(base+'/api/v1/misc/ocr-pdf?async=false',{method:'POST',headers:{'X-API-KEY':apiKey},body:form,signal:AbortSignal.timeout(90000)});assert.equal(response.status,200,'full-image OCR');const files=unzip(await response.arrayBuffer());const text=[...files].find(([name])=>name.endsWith('.txt'))?.[1]?.toString().replace(/\s+/g,' ').toUpperCase();assert.ok(text?.includes('HELMFORGE DOCUMENT CHECK'));const bytes=[...files].find(([name])=>name.endsWith('.pdf'))?.[1];assert.ok(bytes);assert.equal((await PDFDocument.load(bytes)).getPageCount(),1);assert.ok(pdfText(bytes).replace(/\s+/g,' ').toUpperCase().includes('HELMFORGE DOCUMENT CHECK'));console.log('PASS forced rasterization and Tesseract OCR, sidecar text and searchable one-page output');});
if(deployment.metadata.name==='stirling-pdf-office')await forward(async base=>{
 const rtf=String.raw`{\rtf1\ansi\deff0{\fonttbl{\f0 Arial;}}\paperw11906\paperh16838\margl1440\margr1440\margt1440\margb1440\f0\fs28 HELMFORGE OFFICE FIRST\par Deterministic office conversion fixture.\par\page HELMFORGE OFFICE SECOND\par LibreOffice conversion is working.\par}`;
 const form=new FormData();form.append('fileInput',new Blob([rtf],{type:'application/rtf'}),'helmforge-office.rtf');
 const response=await fetch(base+'/api/v1/convert/file/pdf?async=false',{method:'POST',headers:{'X-API-KEY':apiKey},body:form,signal:AbortSignal.timeout(90000)});assert.equal(response.status,200,'native LibreOffice RTF conversion');
 const bytes=new Uint8Array(await response.arrayBuffer());assert.equal((await PDFDocument.load(bytes)).getPageCount(),2);
 const pages=pdfText(bytes).split('\f');assert.ok(pages[0].includes('HELMFORGE OFFICE FIRST'));assert.ok(pages[0].includes('Deterministic office conversion fixture.'));assert.ok(pages[1].includes('HELMFORGE OFFICE SECOND'));assert.ok(pages[1].includes('LibreOffice conversion is working.'));
 console.log('PASS real LibreOffice RTF conversion, two pages and independently extracted page-specific text');
});
if(values.metrics.enabled){
 await forward(async base=>{const denied=await fetch(base+'/actuator/prometheus');assert.equal(denied.status,401);const response=await fetch(base+'/actuator/prometheus',{headers:{'X-API-KEY':apiKey}});assert.equal(response.status,200);assert.match(response.headers.get('content-type'),/text\/plain|openmetrics/);const body=await response.text();assert.match(body,/# TYPE http_requests_total counter/);assert.match(body,/uri="\/api\/v1\/general\/merge-pdfs"/);},'pod/'+pod(),values.metrics.port,'');
 if(deployment.metadata.name==='stirling-pdf-metrics'){
  const credential={apiVersion:'v1',kind:'Secret',metadata:{name:values.metrics.scrapeConfig.apiKeySecret},type:'Opaque',data:{[values.metrics.scrapeConfig.apiKeyKey]:Buffer.from(apiKey).toString('base64')}};
  execFileSync('kubectl',['--context',context,'-n',namespace,'apply','-f','-'],{input:JSON.stringify(credential),encoding:'utf8'});
  await forward(async base=>{const deadline=Date.now()+100000;let healthy=false;while(Date.now()<deadline){const response=await fetch(base+'/api/v1/query?query='+encodeURIComponent('up{job="'+namespace+'/'+deployment.metadata.name+'"}'),{signal:AbortSignal.timeout(5000)});const data=await response.json();if(data.data?.result?.some(r=>r.value[1]==='1')){healthy=true;break;}await new Promise(r=>setTimeout(r,2000));}assert.ok(healthy,'Prometheus must scrape the authenticated native endpoint');const counter=await (await fetch(base+'/api/v1/query?query='+encodeURIComponent('http_requests_total{uri="/api/v1/general/merge-pdfs"}'))).json();assert.ok(counter.data.result.some(r=>Number(r.value[1])>=1));},'service/stirling-pdf-monitor',9090,'');
  console.log('PASS real Prometheus Operator additionalScrapeConfigs with mounted X-API-KEY Secret and native conversion request counter');
 }
}
if(deployment.metadata.name==='stirling-pdf-restore'){
 assert.ok(values.persistence.enabled);
 k(['exec',pod(),'-c','stirling-pdf','--','/bin/sh','-ceu','printf custom-files-preserved > /customFiles/helmforge-recovery.txt; printf pipeline-preserved > /pipeline/helmforge-recovery.txt']);
 const originalPod=pod();
 k(['scale','deployment/'+deployment.metadata.name,'--replicas=0']);
 k(['wait','--for=delete','pod/'+originalPod,'--timeout=60s']);
 const claim=deployment.spec.template.spec.volumes.find(v=>v.name==='workspace').persistentVolumeClaim.claimName;
 const original=JSON.parse(k(['get','pvc',claim,'-o','json']));
 const restoreName=deployment.metadata.name+'-recovered';
 const pvc={apiVersion:'v1',kind:'PersistentVolumeClaim',metadata:{name:restoreName,labels:{'helmforge.dev/runtime-fixture':'true'}},spec:{accessModes:original.spec.accessModes,resources:original.spec.resources,...(original.spec.storageClassName!==undefined?{storageClassName:original.spec.storageClassName}:{})}};
 const copy={apiVersion:'v1',kind:'Pod',metadata:{name:'workspace-recovery',labels:{'helmforge.dev/runtime-fixture':'true'}},spec:{restartPolicy:'Never',automountServiceAccountToken:false,securityContext:deployment.spec.template.spec.securityContext,containers:[{name:'restore',image:deployment.spec.template.spec.containers[0].image,command:['/bin/sh','-ceu','tar -czf /tmp/workspace.tar.gz -C /source configs customFiles pipeline; tar --no-same-owner --no-overwrite-dir -xzf /tmp/workspace.tar.gz -C /recovered; test -d /recovered/configs; test -d /recovered/customFiles; test -d /recovered/pipeline; echo workspace-archive-restored'],securityContext:values.securityContext,resources:{requests:{cpu:'50m',memory:'64Mi'},limits:{cpu:'500m',memory:'256Mi'}},volumeMounts:[{name:'source',mountPath:'/source',readOnly:true},{name:'recovered',mountPath:'/recovered'},{name:'tmp',mountPath:'/tmp'}]}],volumes:[{name:'source',persistentVolumeClaim:{claimName:claim}},{name:'recovered',persistentVolumeClaim:{claimName:restoreName}},{name:'tmp',emptyDir:{sizeLimit:'1Gi'}}]}};
 for(const object of [pvc,copy])execFileSync('kubectl',['--context',context,'-n',namespace,'apply','-f','-'],{input:JSON.stringify(object),encoding:'utf8',timeout:30000});
 const recoveryDeadline=Date.now()+60000;let recoveryPhase;
 while(Date.now()<recoveryDeadline){recoveryPhase=JSON.parse(k(['get','pod','workspace-recovery','-o','json'])).status.phase;if(recoveryPhase==='Succeeded'||recoveryPhase==='Failed')break;await new Promise(r=>setTimeout(r,1000));}
 assert.equal(recoveryPhase,'Succeeded',k(['logs','workspace-recovery']));
 assert.ok(k(['logs','workspace-recovery']).includes('workspace-archive-restored'));
 k(['delete','pod/workspace-recovery','--wait=true','--timeout=30s']);
 execFileSync('helm',['upgrade',release,fileURLToPath(new URL('..',import.meta.url)),'--kube-context',context,'-n',namespace,'--reuse-values','--set','persistence.existingClaim='+restoreName,'--wait','--timeout','60s'],{encoding:'utf8',timeout:75000});
 await forward(async base=>{await authenticate(base);await merge(base);});
 assert.equal(k(['exec',pod(),'-c','stirling-pdf','--','cat','/customFiles/helmforge-recovery.txt']), 'custom-files-preserved');
 assert.equal(k(['exec',pod(),'-c','stirling-pdf','--','cat','/pipeline/helmforge-recovery.txt']), 'pipeline-preserved');
 console.log('PASS quiesced full-workspace archive restored into a fresh PVC, native login, retained H2 API key, authenticated merge and preserved custom/pipeline files');
}

console.log('PASS native administrator login, anonymous conversion denial, authenticated two-page merge with ordered text, retained bootstrap Secret'+(verifyReplacement?', persisted API key and conversion across pod replacement':''));
