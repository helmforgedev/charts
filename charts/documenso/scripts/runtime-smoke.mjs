// SPDX-License-Identifier: Apache-2.0
import { execFileSync } from 'node:child_process';

const [context, namespace, release] = process.argv.slice(2);
if (!context || !namespace || !release) {
  throw new Error('usage: runtime-smoke.mjs <context> <namespace> <release>');
}

const kubectl = (args) => execFileSync('kubectl', ['--context', context, '-n', namespace, ...args], {
  encoding: 'utf8',
  timeout: 120000,
}).trim();

const pod = kubectl(['get', 'pod', '-l', `app.kubernetes.io/instance=${release},app.kubernetes.io/name=documenso`, '-o', 'jsonpath={.items[0].metadata.name}']);
if (!pod) throw new Error('Documenso pod not found');

const health = kubectl(['exec', pod, '-c', 'documenso', '--', 'node', '-e',
  "fetch('http://127.0.0.1:3000/api/health').then(async r=>{const b=await r.text();if(!r.ok)throw new Error(r.status+' '+b);console.log(b)})"]);
if (!health.includes('status')) throw new Error(`unexpected health response: ${health}`);

const uid = kubectl(['exec', pod, '-c', 'documenso', '--', 'id', '-u']);
if (uid !== '1001') throw new Error(`expected UID 1001, got ${uid}`);

const deployment = kubectl(['get', 'deployment', '-l', `app.kubernetes.io/instance=${release},app.kubernetes.io/name=documenso`, '-o', 'jsonpath={.items[0].metadata.name}']);
const secretName = kubectl(['get', 'deployment', deployment, '-o', 'jsonpath={.spec.template.spec.containers[0].env[?(@.name=="NEXTAUTH_SECRET")].valueFrom.secretKeyRef.name}']);
const secret = kubectl(['get', 'secret', secretName, '-o', 'jsonpath={.data.nextauth-secret}']);
if (!secret) throw new Error('application identity secret is empty');

console.log(`health ok; uid=${uid}; identity secret retained`);
