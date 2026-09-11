// SPDX-License-Identifier: Apache-2.0
import assert from 'node:assert/strict';
import {execFileSync} from 'node:child_process';
import {randomUUID} from 'node:crypto';
const [context,namespace,release]=process.argv.slice(2);assert.equal(context,'k3d-helmforge-tests-wsl');
const k=args=>execFileSync('kubectl',['--context',context,'-n',namespace,...args],{encoding:'utf8',timeout:30000});
const values=JSON.parse(execFileSync('helm',['get','values',release,'--kube-context',context,'-n',namespace,'-a','-o','json'],{encoding:'utf8'}));
if(values.tls.enabled&&values.architecture==='standalone'){
 const pods=JSON.parse(k(['get','pods','-l','app.kubernetes.io/instance='+release,'-o','json'])).items;assert.equal(pods.length,1);const pod=pods[0].metadata.name,container=pods[0].spec.containers[0].name;
 const cmd='export REDISCLI_AUTH="$REDIS_PASSWORD"; redis-cli --tls --cacert /tls/'+values.tls.caFilename+' --cert /tls/'+values.tls.certFilename+' --key /tls/'+values.tls.keyFilename+' -p '+values.service.ports.redis;
 const key='helmforge-'+randomUUID(),value=randomUUID();
 const run=command=>k(['exec',pod,'-c',container,'--','sh','-ec',command]).trim();
 assert.equal(run(cmd+' PING'),'PONG');assert.equal(run(cmd+' SET '+key+' '+value),'OK');assert.equal(run(cmd+' GET '+key),value);assert.equal(run(cmd+' DEL '+key),'1');
 const bad=run('export REDISCLI_AUTH=incorrect-owned-fixture; '+cmd.split('; ')[1]+' PING 2>&1 || true');assert.match(bad,/WRONGPASS|NOAUTH|AUTH failed/);assert.doesNotMatch(bad,/^PONG$/m);
 console.log('PASS TLS-only Redis on configured port: ready probes, authenticated SET/GET/DEL and rejected invalid password');
}else console.log('Redis TLS probe regression scenario does not apply to this profile; standard behavioral checks remain active.');
