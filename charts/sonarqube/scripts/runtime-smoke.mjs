// SPDX-License-Identifier: Apache-2.0
import assert from 'node:assert/strict';
import { execFileSync } from 'node:child_process';

const [context, namespace, release] = process.argv.slice(2);
assert.match(context ?? '', /^k3d-/);
assert.ok(namespace && release);

const kubectl = (args) =>
  execFileSync('kubectl', ['--context', context, '-n', namespace, ...args], {
    encoding: 'utf8',
    timeout: 120_000,
  });

const selector = `app.kubernetes.io/instance=${release},app.kubernetes.io/component=sonarqube`;
const services = JSON.parse(kubectl(['get', 'services', '-l', selector, '-o', 'json']));
const service = services.items.find((item) => item.spec?.ports?.some((port) => port.name === 'http'));
assert.ok(service, 'SonarQube Service with named http port not found');

const pods = JSON.parse(kubectl(['get', 'pods', '-l', selector, '-o', 'json']));
const pod = pods.items.find(
  (item) =>
    !item.metadata.deletionTimestamp &&
    item.status.conditions?.some((condition) => condition.type === 'Ready' && condition.status === 'True'),
);
assert.ok(pod, 'Ready SonarQube pod not found');
const container = pod.spec.containers.find((item) => item.name === 'sonarqube');
assert.ok(container, 'SonarQube container not found');
assert.match(container.image, /:26\.8\.0\.126808-community$/);

const httpContainerPort = container.ports?.find((port) => port.name === 'http')?.containerPort;
const webPort = container.env?.find((entry) => entry.name === 'SONAR_WEB_PORT')?.value;
assert.equal(webPort, String(httpContainerPort), 'SONAR_WEB_PORT must match the named HTTP container port');
const httpServicePort = service.spec.ports.find((port) => port.name === 'http');
assert.equal(httpServicePort.targetPort, 'http');
assert.ok(Number.isInteger(httpServicePort.port), 'SonarQube Service http port is not numeric');

const configMap = JSON.parse(kubectl(['get', 'configmap', `${service.metadata.name}-config`, '-o', 'json']));
const sonarProperties = configMap.data?.['sonar.properties'] ?? '';
const contextPath = sonarProperties.match(/^sonar\.web\.context=(.+)$/m)?.[1]?.replace(/\/$/, '') ?? '';
const statusUrl = `http://${service.metadata.name}.${namespace}.svc:${httpServicePort.port}${contextPath}/api/system/status`;
let statusOutput;
let lastError;
for (let attempt = 1; attempt <= 5; attempt += 1) {
  try {
    statusOutput = kubectl([
      'exec',
      pod.metadata.name,
      '-c',
      'sonarqube',
      '--',
      'curl',
      '-fsS',
      '--max-time',
      '20',
      statusUrl,
    ]);
    break;
  } catch (error) {
    lastError = error;
    if (attempt < 5) await new Promise((resolve) => setTimeout(resolve, 500));
  }
}
if (statusOutput === undefined) throw lastError;
const status = JSON.parse(statusOutput);
assert.equal(status.status, 'UP');
assert.equal(status.version, '26.8.0.126808');

let jdbcUrl;
try {
  jdbcUrl = kubectl(['exec', pod.metadata.name, '-c', 'sonarqube', '--', 'printenv', 'SONAR_JDBC_URL']).trim();
} catch {
  jdbcUrl = '';
}
if (jdbcUrl) assert.match(jdbcUrl, /^jdbc:postgresql:\/\//);
console.log(
  `PASS SonarQube ${status.version} status=${status.status} listener=${httpContainerPort} service=${httpServicePort.port} database=${jdbcUrl ? 'postgresql' : 'embedded'}`,
);
