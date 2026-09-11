// SPDX-License-Identifier: Apache-2.0
import assert from 'node:assert/strict';
import {execFileSync} from 'node:child_process';

export function restore({k,context,namespace,release,chartPath,deployment,pod,values}){
 assert.equal(context,'k3d-helmforge-tests-wsl');assert.equal(namespace,'hf-validate-dawarich');assert.equal(deployment.metadata.name,'dawarich-restore');assert.equal(values.postgresql.enabled,true);
 const source=deployment.spec.template.spec.volumes.find(volume=>volume.name==='workspace').persistentVolumeClaim.claimName;
 const current=pod();k(['scale','deployment/'+deployment.metadata.name,'--replicas=0']);k(['wait','--for=delete','pod/'+current,'--timeout=60s']);
 const databasePod=JSON.parse(k(['get','pods','-l','app.kubernetes.io/instance='+release+',app.kubernetes.io/name=postgresql','-o','json'])).items[0];assert.ok(databasePod);
 const backup=`set -euo pipefail
umask 077
export PGPASSWORD="$POSTGRES_PASSWORD"
psql -X -v ON_ERROR_STOP=1 -h 127.0.0.1 -U "$POSTGRES_USER" -d "$APP_DATABASE" -c "INSERT INTO spatial_ref_sys (srid,auth_name,auth_srid,srtext,proj4text) SELECT 910001,'HelmForge',910001,srtext,proj4text FROM spatial_ref_sys WHERE srid=4326"
export PGPASSWORD="$APP_PASSWORD"
pg_dump -h 127.0.0.1 -U "$APP_USERNAME" -d "$APP_DATABASE" -Fc -f /tmp/dawarich.dump
export PGPASSWORD="$POSTGRES_PASSWORD"
psql -X -v ON_ERROR_STOP=1 -h 127.0.0.1 -U "$POSTGRES_USER" -d postgres --set=owner="$APP_USERNAME" <<'SQL'
SELECT format('CREATE DATABASE dawarich_recovered OWNER %I', :'owner') \\gexec
SQL
psql -X -v ON_ERROR_STOP=1 -h 127.0.0.1 -U "$POSTGRES_USER" -d dawarich_recovered -c 'CREATE EXTENSION postgis; CREATE EXTENSION pgcrypto'
pg_restore --list /tmp/dawarich.dump > /tmp/dawarich.list
sed '/ EXTENSION - postgis/d; / COMMENT - EXTENSION postgis/d; / EXTENSION - pgcrypto/d; / COMMENT - EXTENSION pgcrypto/d; / TABLE DATA public spatial_ref_sys /d' /tmp/dawarich.list > /tmp/dawarich-application.list
pg_restore -h 127.0.0.1 -U "$POSTGRES_USER" -d dawarich_recovered --exit-on-error --no-owner --no-privileges --role="$APP_USERNAME" --use-list=/tmp/dawarich-application.list /tmp/dawarich.dump
sed -n '/ TABLE DATA public spatial_ref_sys /p' /tmp/dawarich.list > /tmp/dawarich-spatial.list
test -s /tmp/dawarich-spatial.list
pg_restore -h 127.0.0.1 -U "$POSTGRES_USER" -d dawarich_recovered --exit-on-error --no-owner --no-privileges --use-list=/tmp/dawarich-spatial.list /tmp/dawarich.dump
test "$(psql -X -At -h 127.0.0.1 -U "$POSTGRES_USER" -d dawarich_recovered -c "SELECT count(*) FROM spatial_ref_sys WHERE srid=910001 AND auth_name='HelmForge'")" = 1
rm /tmp/dawarich.dump /tmp/dawarich.list /tmp/dawarich-application.list /tmp/dawarich-spatial.list
echo dawarich-postgis-and-custom-srid-restored
`;
 assert.match(k(['exec',databasePod.metadata.name,'-c',databasePod.spec.containers[0].name,'--','bash','-ceu',backup]),/dawarich-postgis-and-custom-srid-restored/);
 const original=JSON.parse(k(['get','pvc',source,'-o','json'])),name='dawarich-restore-recovered';
 const pvc={apiVersion:'v1',kind:'PersistentVolumeClaim',metadata:{name,labels:{'helmforge.dev/runtime-fixture':'true'}},spec:{accessModes:original.spec.accessModes,resources:original.spec.resources,...(original.spec.storageClassName!==undefined?{storageClassName:original.spec.storageClassName}:{})}};
 const archive='umask 077; cd /source; find . -mindepth 1 -maxdepth 1 -print0 | tar --null -T - -czf /tmp/dawarich.tar.gz; tar --no-same-owner --no-overwrite-dir -xzf /tmp/dawarich.tar.gz -C /recovered; test -s /recovered/.identity-fingerprint; test -d /recovered/storage; echo dawarich-private-volume-restored';
 const copy={apiVersion:'v1',kind:'Pod',metadata:{name:'dawarich-recovery',labels:{'helmforge.dev/runtime-fixture':'true'}},spec:{restartPolicy:'Never',automountServiceAccountToken:false,securityContext:deployment.spec.template.spec.securityContext,containers:[{name:'restore',image:'docker.io/library/postgres:18.6-trixie',command:['/bin/sh','-ceu',archive],securityContext:values.securityContext,resources:{requests:{cpu:'50m',memory:'64Mi'},limits:{cpu:'500m',memory:'256Mi'}},volumeMounts:[{name:'source',mountPath:'/source',readOnly:true},{name:'recovered',mountPath:'/recovered'},{name:'tmp',mountPath:'/tmp'}]}],volumes:[{name:'source',persistentVolumeClaim:{claimName:source}},{name:'recovered',persistentVolumeClaim:{claimName:name}},{name:'tmp',emptyDir:{sizeLimit:'1Gi'}}]}};
 for(const resource of [pvc,copy])execFileSync('kubectl',['--context',context,'-n',namespace,'apply','-f','-'],{input:JSON.stringify(resource),encoding:'utf8'});
 const deadline=Date.now()+60000;let phase;
 while(Date.now()<deadline){phase=JSON.parse(k(['get','pod','dawarich-recovery','-o','json'])).status.phase;if(phase==='Succeeded')break;if(phase==='Failed')throw Error('Volume archive failed: '+k(['logs','dawarich-recovery']));Atomics.wait(new Int32Array(new SharedArrayBuffer(4)),0,0,1000);}
 assert.equal(phase,'Succeeded');assert.match(k(['logs','dawarich-recovery']),/dawarich-private-volume-restored/);k(['delete','pod/dawarich-recovery','--wait=true','--timeout=30s']);
 execFileSync('helm',['upgrade',release,chartPath,'--kube-context',context,'-n',namespace,'--reuse-values','--set','persistence.existingClaim='+name,'--set','postgresql.auth.database=dawarich_recovered','--wait','--timeout','90s'],{encoding:'utf8',timeout:100000});
 console.log('PASS quiesced PostGIS dump/restore with custom SRID plus complete local storage into a fresh database and PVC');
}
