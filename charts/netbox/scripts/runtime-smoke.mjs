// SPDX-License-Identifier: Apache-2.0
import {execFileSync} from 'node:child_process';
const [context,namespace,release]=process.argv.slice(2);
if (!context?.startsWith('k3d-helmforge-') || !namespace || !release) {
  throw new Error('Explicit HelmForge lab context, namespace and release required');
}
const run=(bin,args)=>{
  try {
    return execFileSync(bin,args,{encoding:'utf8',timeout:150000,stdio:['ignore','pipe','pipe']});
  } catch (error) {
    console.error(String(error.stderr || error.message).slice(-1800));
    process.exit(1);
  }
};
const target=['--context',context,'-n',namespace];
const pods=JSON.parse(run('kubectl',[...target,'get','pods','-l',`app.kubernetes.io/instance=${release}`,'-o','json'])).items;
const pod=pods.find(p=>p.spec.containers.some(c=>c.name==='netbox')&&!p.metadata.deletionTimestamp);
if (!pod) throw new Error('NetBox web pod required');
const check=[
  'import os',
  'from django.conf import settings',
  'from django.db import connection',
  'from django.core.cache import cache',
  'assert settings.VERSION == "4.6.10-Docker-5.0.2", settings.VERSION',
  'cursor = connection.cursor()',
  'cursor.execute("SELECT 1")',
  'assert cursor.fetchone()[0] == 1',
  'cursor.close()',
  'expected = os.getenv("REDIS_CACHE_USERNAME")',
  'assert not expected or settings.CACHES["default"]["OPTIONS"]["USERNAME"] == expected',
  'cache.set("helmforge-upstream-smoke", "verified", 60)',
  'assert cache.get("helmforge-upstream-smoke") == "verified"',
  'cache.delete("helmforge-upstream-smoke")',
  'print("NetBox 4.6.10: database and cache roundtrip passed; configured cache username honored")',
].join('; ');
process.stdout.write(run('kubectl',[...target,'exec',pod.metadata.name,'-c','netbox','--',
  '/opt/netbox/venv/bin/python','/opt/netbox/netbox/manage.py','shell','--command',check]));
process.stdout.write(run('helm',['test',release,'--kube-context',context,'-n',namespace,'--timeout','120s','--logs']));
