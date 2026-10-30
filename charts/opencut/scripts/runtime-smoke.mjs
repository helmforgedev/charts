// SPDX-License-Identifier: Apache-2.0
import assert from 'node:assert/strict';
import {execFileSync} from 'node:child_process';

const [context, namespace, release] = process.argv.slice(2);
if (!context?.startsWith('k3d-helmforge-') || !namespace || !release) {
  throw new Error('Explicit HelmForge lab context, namespace and release required');
}

const kubectl = args => execFileSync(
  'kubectl',
  ['--context', context, '-n', namespace, ...args],
  {encoding: 'utf8', timeout: 60_000, stdio: ['ignore', 'pipe', 'pipe']},
);

const selector = `app.kubernetes.io/instance=${release},app.kubernetes.io/name=opencut`;
const deployments = JSON.parse(kubectl(['get', 'deployments', '-l', selector, '-o', 'json'])).items;
const services = JSON.parse(kubectl(['get', 'services', '-l', selector, '-o', 'json'])).items;
const web = deployments.find(
  item => item.spec.template.metadata.labels?.['app.kubernetes.io/component'] === 'web',
);
const bridge = deployments.find(
  item => item.spec.template.metadata.labels?.['app.kubernetes.io/component'] === 'redis-http',
);
const service = services.find(
  item => item.spec.selector?.['app.kubernetes.io/component'] === 'web',
);
const bridgeService = services.find(
  item => item.spec.selector?.['app.kubernetes.io/component'] === 'redis-http',
);

assert.ok(web, 'OpenCut web Deployment required');
assert.ok(service, 'OpenCut Service required');

const webContainer = web.spec.template.spec.containers.find(item => item.name === 'opencut');
const bridgeContainer = bridge?.spec.template.spec.containers.find(item => item.name === 'redis-http');
const webPort = webContainer?.ports?.find(port => port.name === 'http')?.containerPort;
const bridgePort = bridgeContainer?.ports?.find(port => port.name === 'http')?.containerPort;
const processPort = Number(webContainer?.env?.find(item => item.name === 'PORT')?.value);
const bridgeProcessPort = Number(bridgeContainer?.env?.find(item => item.name === 'SRH_PORT')?.value);
const servicePort = service.spec.ports.find(port => port.name === 'http');

assert.ok(Number.isInteger(webPort), 'Named OpenCut HTTP container port required');
assert.equal(processPort, webPort, 'PORT must configure the rendered OpenCut container port');
assert.equal(servicePort?.targetPort, 'http', 'Service must target the named OpenCut HTTP port');
assert.equal(web.spec.template.spec.automountServiceAccountToken, false);
if (bridge) {
  assert.ok(bridgeService, 'Redis HTTP bridge Service required when the bridge is deployed');
  assert.ok(Number.isInteger(bridgePort), 'Named Redis HTTP container port required');
  assert.equal(bridgeProcessPort, bridgePort, 'SRH_PORT must configure the rendered bridge container port');
  assert.equal(bridge.spec.template.spec.automountServiceAccountToken, false);
} else {
  assert.equal(bridgeService, undefined, 'Redis HTTP bridge Service must be absent in external endpoint mode');
}

const webPod = JSON.parse(kubectl([
  'get', 'pods', '-l', `${selector},app.kubernetes.io/component=web`, '-o', 'json',
])).items.find(item => item.status.conditions?.some(
  condition => condition.type === 'Ready' && condition.status === 'True',
));
assert.ok(webPod, 'Ready OpenCut web Pod required');
kubectl([
  'exec', webPod.metadata.name, '-c', 'opencut', '--',
  'wget', '-qO-', `http://127.0.0.1:${webPort}/api/health`,
]);

const bridgeSummary = bridge ? `Redis HTTP ${bridgePort}` : 'external Redis HTTP endpoint';
console.log(`OpenCut runtime smoke passed: Service ${servicePort.port} -> container ${webPort}; ${bridgeSummary}.`);
