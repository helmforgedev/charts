// SPDX-License-Identifier: Apache-2.0
import assert from 'node:assert/strict';
import {execFileSync} from 'node:child_process';
export function restore({k,context,namespace,release,chartPath,deployment,pod,values}){
 const source=deployment.spec.template.spec.volumes.find(v=>v.name==='workspace').persistentVolumeClaim.claimName;
 const current=pod();k(['scale','deployment/'+deployment.metadata.name,'--replicas=0']);k(['wait','--for=delete','pod/'+current,'--timeout=60s']);
 const original=JSON.parse(k(['get','pvc',source,'-o','json'])),name=deployment.metadata.name+'-recovered';
 const pvc={apiVersion:'v1',kind:'PersistentVolumeClaim',metadata:{name,labels:{'helmforge.dev/runtime-fixture':'true'}},spec:{accessModes:original.spec.accessModes,resources:original.spec.resources,...(original.spec.storageClassName!==undefined?{storageClassName:original.spec.storageClassName}:{})}};
 const archive='tar --xattrs --acls -czf /tmp/opencloud.tar.gz -C /source config data; tar --xattrs --acls --no-same-owner --no-overwrite-dir -xzf /tmp/opencloud.tar.gz -C /recovered; test -s /recovered/config/opencloud.yaml; test -s /recovered/data/idp/private-key.pem; echo opencloud-xattr-archive-restored';
 const copy={apiVersion:'v1',kind:'Pod',metadata:{name:'opencloud-recovery',labels:{'helmforge.dev/runtime-fixture':'true'}},spec:{restartPolicy:'Never',automountServiceAccountToken:false,securityContext:deployment.spec.template.spec.securityContext,containers:[{name:'restore',image:'docker.io/library/postgres:18.6-trixie',command:['/bin/sh','-ceu',archive],securityContext:values.securityContext,resources:{requests:{cpu:'50m',memory:'64Mi'},limits:{cpu:'500m',memory:'256Mi'}},volumeMounts:[{name:'source',mountPath:'/source',readOnly:true},{name:'recovered',mountPath:'/recovered'},{name:'tmp',mountPath:'/tmp'}]}],volumes:[{name:'source',persistentVolumeClaim:{claimName:source}},{name:'recovered',persistentVolumeClaim:{claimName:name}},{name:'tmp',emptyDir:{sizeLimit:'1Gi'}}]}};
 for(const resource of [pvc,copy])execFileSync('kubectl',['--context',context,'-n',namespace,'apply','-f','-'],{input:JSON.stringify(resource),encoding:'utf8'});
 k(['wait','pod/opencloud-recovery','--for=jsonpath={.status.phase}=Succeeded','--timeout=60s']);assert.match(k(['logs','opencloud-recovery']),/opencloud-xattr-archive-restored/);k(['delete','pod/opencloud-recovery','--wait=true','--timeout=30s']);
 execFileSync('helm',['upgrade',release,chartPath,'--kube-context',context,'-n',namespace,'--reuse-values','--set','persistence.existingClaim='+name,'--wait','--timeout','60s'],{encoding:'utf8',timeout:75000});
}
