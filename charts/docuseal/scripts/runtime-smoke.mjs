import { execFileSync } from 'node:child_process';

const [context, namespace, release] = process.argv.slice(2);
if (!context || !namespace || !release) {
  throw new Error('usage: runtime-smoke.mjs <context> <namespace> <release>');
}

const kubectl = (args) => execFileSync('kubectl', ['--context', context, '-n', namespace, ...args], {
  encoding: 'utf8',
  timeout: 120000,
}).trim();

const pod = kubectl(['get', 'pod', '-l', `app.kubernetes.io/instance=${release},app.kubernetes.io/name=docuseal`, '-o', 'jsonpath={.items[0].metadata.name}']);
if (!pod) throw new Error('DocuSeal pod not found');

const deployment = kubectl(['get', 'deployment', '-l', `app.kubernetes.io/instance=${release},app.kubernetes.io/name=docuseal`, '-o', 'jsonpath={.items[0].metadata.name}']);
const port = kubectl(['get', 'deployment', deployment, '-o', 'jsonpath={.spec.template.spec.containers[0].env[?(@.name=="PORT")].value}']);
if (!/^\d+$/.test(port)) throw new Error(`invalid DocuSeal listener port: ${port}`);

const health = kubectl(['exec', pod, '-c', 'docuseal', '--', 'ruby', '-rnet/http', '-e',
  `response=Net::HTTP.get_response(URI('http://127.0.0.1:${port}/up')); abort(\"#{response.code} #{response.body}\") unless response.is_a?(Net::HTTPSuccess); puts response.body`]);
if (!health) throw new Error('empty health response');

const uid = kubectl(['exec', pod, '-c', 'docuseal', '--', 'id', '-u']);
if (uid !== '2000') throw new Error(`expected UID 2000, got ${uid}`);

const secretName = kubectl(['get', 'deployment', deployment, '-o', 'jsonpath={.spec.template.spec.containers[0].env[?(@.name=="SECRET_KEY_BASE")].valueFrom.secretKeyRef.name}']);
const secret = kubectl(['get', 'secret', secretName, '-o', 'jsonpath={.data.secret-key-base}']);
if (!secret) throw new Error('application identity secret is empty');

console.log(`health ok on port ${port}; uid=${uid}; identity secret retained`);
