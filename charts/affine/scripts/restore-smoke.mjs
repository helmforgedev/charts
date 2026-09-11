// SPDX-License-Identifier: Apache-2.0
import assert from 'node:assert/strict';
import {execFileSync} from 'node:child_process';
export function restore({k,context,namespace,release,chartPath,deployment,pod,values}){
 assert.equal(context,'k3d-helmforge-tests-wsl');assert.equal(namespace,'hf-validate-affine');assert.equal(deployment.metadata.name,'affine-restore');assert.equal(values.postgresql.enabled,true);
 const source=deployment.spec.template.spec.volumes.find(v=>v.name==='workspace').persistentVolumeClaim.claimName;
 const current=pod();k(['scale','deployment/'+deployment.metadata.name,'--replicas=0']);k(['wait','--for=delete','pod/'+current,'--timeout=60s']);
 const databasePod=JSON.parse(k(['get','pods','-l','app.kubernetes.io/instance='+release+',app.kubernetes.io/name=postgresql','-o','json'])).items[0];assert.ok(databasePod);
 const backup=`set -euo pipefail
umask 077
export PGPASSWORD="$APP_PASSWORD"
pg_dump -h 127.0.0.1 -U "$APP_USERNAME" -d "$APP_DATABASE" -Fc -f /tmp/affine-recovery.dump
export PGPASSWORD="$POSTGRES_PASSWORD"
psql -X -v ON_ERROR_STOP=1 -h 127.0.0.1 -U "$POSTGRES_USER" -d postgres --set=owner="$APP_USERNAME" <<'SQL'
SELECT format('CREATE DATABASE affine_recovered OWNER %I', :'owner') \\gexec
SQL
psql -X -v ON_ERROR_STOP=1 -h 127.0.0.1 -U "$POSTGRES_USER" -d affine_recovered -c 'CREATE EXTENSION vector'
pg_restore --list /tmp/affine-recovery.dump | sed '/ EXTENSION - vector/d; / COMMENT - EXTENSION vector/d' > /tmp/affine-recovery.list
pg_restore -h 127.0.0.1 -U "$POSTGRES_USER" -d affine_recovered --exit-on-error --no-owner --no-privileges --role="$APP_USERNAME" --use-list=/tmp/affine-recovery.list /tmp/affine-recovery.dump
rm /tmp/affine-recovery.dump /tmp/affine-recovery.list
echo affine-fresh-database-restored
`;
 assert.match(k(['exec',databasePod.metadata.name,'-c',databasePod.spec.containers[0].name,'--','bash','-ceu',backup]),/affine-fresh-database-restored/);
 const original=JSON.parse(k(['get','pvc',source,'-o','json'])),name='affine-restore-recovered';
 const pvc={apiVersion:'v1',kind:'PersistentVolumeClaim',metadata:{name,labels:{'helmforge.dev/runtime-fixture':'true'}},spec:{accessModes:original.spec.accessModes,resources:original.spec.resources,...(original.spec.storageClassName!==undefined?{storageClassName:original.spec.storageClassName}:{})}};
 const archive='umask 077; cd /source; find . -mindepth 1 -maxdepth 1 -print0 | tar --null -T - -czf /tmp/affine.tar.gz; tar --no-same-owner --no-overwrite-dir -xzf /tmp/affine.tar.gz -C /recovered; test -s /recovered/config/private.key; test -s /recovered/config/config.json; echo affine-private-volume-restored';
 const copy={apiVersion:'v1',kind:'Pod',metadata:{name:'affine-recovery',labels:{'helmforge.dev/runtime-fixture':'true'}},spec:{restartPolicy:'Never',automountServiceAccountToken:false,securityContext:deployment.spec.template.spec.securityContext,containers:[{name:'restore',image:'docker.io/library/postgres:18.6-trixie',command:['/bin/sh','-ceu',archive],securityContext:values.securityContext,resources:{requests:{cpu:'50m',memory:'64Mi'},limits:{cpu:'500m',memory:'256Mi'}},volumeMounts:[{name:'source',mountPath:'/source',readOnly:true},{name:'recovered',mountPath:'/recovered'},{name:'tmp',mountPath:'/tmp'}]}],volumes:[{name:'source',persistentVolumeClaim:{claimName:source}},{name:'recovered',persistentVolumeClaim:{claimName:name}},{name:'tmp',emptyDir:{sizeLimit:'1Gi'}}]}};
 for(const resource of [pvc,copy])execFileSync('kubectl',['--context',context,'-n',namespace,'apply','-f','-'],{input:JSON.stringify(resource),encoding:'utf8'});
 const deadline=Date.now()+60000;let phase;
 while(Date.now()<deadline){const status=JSON.parse(k(['get','pod','affine-recovery','-o','json'])).status;phase=status.phase;if(phase==='Succeeded')break;if(phase==='Failed')throw Error('Volume archive helper failed: '+k(['logs','affine-recovery']));Atomics.wait(new Int32Array(new SharedArrayBuffer(4)),0,0,1000);}
 assert.equal(phase,'Succeeded','Volume archive helper did not complete');assert.match(k(['logs','affine-recovery']),/affine-private-volume-restored/);k(['delete','pod/affine-recovery','--wait=true','--timeout=30s']);
 execFileSync('helm',['upgrade',release,chartPath,'--kube-context',context,'-n',namespace,'--reuse-values','--set','persistence.existingClaim='+name,'--set','postgresql.auth.database=affine_recovered','--wait','--timeout','90s'],{encoding:'utf8',timeout:100000});
 console.log('PASS quiesced pg_dump/pg_restore to a fresh database plus complete private config/storage archive to a fresh PVC');
}
