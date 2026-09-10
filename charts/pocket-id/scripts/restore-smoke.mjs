// SPDX-License-Identifier: Apache-2.0
import assert from 'node:assert/strict';
import {execFileSync} from 'node:child_process';
export async function restoreIdentity({k,context,namespace,release,chartPath,deployment,values,pod,forward,verify,browserFixture}){
 assert.equal(values.database.type,'sqlite');assert.ok(browserFixture,'Recovery must exercise the previously enrolled passkey');
 const originalPod=pod(),claim=deployment.spec.template.spec.volumes.find(v=>v.name==='workspace').persistentVolumeClaim.claimName;
 k(['scale','deployment/'+deployment.metadata.name,'--replicas=0']);k(['wait','--for=delete','pod/'+originalPod,'--timeout=60s']);
 const original=JSON.parse(k(['get','pvc',claim,'-o','json'])),restored=deployment.metadata.name+'-recovered';
 const pvc={apiVersion:'v1',kind:'PersistentVolumeClaim',metadata:{name:restored,labels:{'helmforge.dev/runtime-fixture':'true'}},spec:{accessModes:original.spec.accessModes,resources:original.spec.resources,...(original.spec.storageClassName!==undefined?{storageClassName:original.spec.storageClassName}:{})}};
 const archive="const fs=require('node:fs'),cp=require('node:child_process'),assert=require('node:assert/strict');const entries=fs.readdirSync('/source');assert.ok(entries.includes('pocket-id.db'));cp.execFileSync('tar',['-czf','/tmp/identity.tar.gz','-C','/source','--',...entries]);cp.execFileSync('tar',['-xzf','/tmp/identity.tar.gz','-C','/recovered']);assert.ok(fs.statSync('/recovered/pocket-id.db').size>0);console.log('identity-archive-restored');";
 const copy={apiVersion:'v1',kind:'Pod',metadata:{name:'pocket-id-recovery',labels:{'helmforge.dev/runtime-fixture':'true'}},spec:{restartPolicy:'Never',automountServiceAccountToken:false,securityContext:deployment.spec.template.spec.securityContext,containers:[{name:'restore',image:values.bootstrap.helperImage.repository+':'+values.bootstrap.helperImage.tag,command:['node','-e',archive],securityContext:values.securityContext,resources:{requests:{cpu:'50m',memory:'64Mi'},limits:{cpu:'500m',memory:'256Mi'}},volumeMounts:[{name:'source',mountPath:'/source',readOnly:true},{name:'recovered',mountPath:'/recovered'},{name:'tmp',mountPath:'/tmp'}]}],volumes:[{name:'source',persistentVolumeClaim:{claimName:claim}},{name:'recovered',persistentVolumeClaim:{claimName:restored}},{name:'tmp',emptyDir:{sizeLimit:'1Gi'}}]}};
 for(const resource of [pvc,copy])execFileSync('kubectl',['--context',context,'-n',namespace,'apply','-f','-'],{encoding:'utf8',input:JSON.stringify(resource)});
 k(['wait','pod/pocket-id-recovery','--for=jsonpath={.status.phase}=Succeeded','--timeout=60s']);assert.match(k(['logs','pocket-id-recovery']),/identity-archive-restored/);k(['delete','pod/pocket-id-recovery','--wait=true','--timeout=30s']);
 execFileSync('helm',['upgrade',release,chartPath,'--kube-context',context,'-n',namespace,'--reuse-values','--set','persistence.existingClaim='+restored,'--wait','--timeout','60s'],{encoding:'utf8',timeout:75000});
 await forward(async base=>{await verify(base);await browserFixture.afterReplacement(base);});
 console.log('PASS quiesced SQLite identity restored into a fresh PVC with retained encryption Secret, user/session/JWKS and the same enrolled browser passkey');
}
