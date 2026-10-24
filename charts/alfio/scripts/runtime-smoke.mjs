// SPDX-License-Identifier: Apache-2.0
import assert from 'node:assert/strict';
import {execFileSync} from 'node:child_process';

const [context, namespace, release] = process.argv.slice(2);
assert.ok(context?.startsWith('k3d-helmforge-') && namespace && release);

const run = args => execFileSync(
  'kubectl',
  ['--context', context, '-n', namespace, ...args],
  {encoding: 'utf8', timeout: 120000, stdio: ['ignore', 'pipe', 'pipe']},
);

const pods = JSON.parse(run([
  'get', 'pods',
  '-l', `app.kubernetes.io/instance=${release},app.kubernetes.io/component=server`,
  '-o', 'json',
])).items;
const pod = pods.find(candidate => !candidate.metadata.deletionTimestamp
  && candidate.status.conditions?.some(condition => condition.type === 'Ready' && condition.status === 'True'));
assert.ok(pod, 'expected one Ready alf.io server pod');

const container = pod.spec.containers.find(candidate => candidate.name === 'alfio');
assert.ok(container, 'expected the alfio container');
assert.match(container.image, /docker\.io\/alfio\/alf\.io:2\.0-M5-2609$/);

const port = container.ports.find(candidate => candidate.name === 'http');
const serverPort = container.env.find(variable => variable.name === 'SERVER_PORT');
assert.ok(port && serverPort, 'expected the named HTTP port and SERVER_PORT');
assert.equal(String(port.containerPort), serverPort.value);

const service = JSON.parse(run(['get', 'service', `${release}-alfio`, '-o', 'json']));
const servicePort = service.spec.ports.find(candidate => candidate.name === 'http');
assert.ok(servicePort, 'expected the named HTTP Service port');
assert.equal(servicePort.targetPort, 'http');

const health = run([
  'get', '--raw',
  `/api/v1/namespaces/${namespace}/services/http:${release}-alfio:http/proxy/healthz`,
]);
assert.match(health, /UP|ok|healthy/i, `unexpected /healthz response: ${health}`);

console.log(`PASS alf.io ${container.image} on container port ${port.containerPort}, Service port ${servicePort.port}`);
