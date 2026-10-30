// SPDX-License-Identifier: Apache-2.0
import assert from 'node:assert/strict';
import { execFileSync } from 'node:child_process';

const [context, namespace, release] = process.argv.slice(2);
if (!context?.startsWith('k3d-helmforge-') || !namespace || !release) {
  throw new Error('Explicit HelmForge lab context, namespace and release required');
}

const kubectl = (...args) => execFileSync('kubectl', [
  '--context', context,
  '--namespace', namespace,
  '--request-timeout=30s',
  ...args,
], {
  encoding: 'utf8',
  stdio: ['ignore', 'pipe', 'pipe'],
  timeout: 120000,
  maxBuffer: 4 * 1024 * 1024,
});

const pods = JSON.parse(kubectl(
  'get', 'pods',
  '-l', `app.kubernetes.io/instance=${release},app.kubernetes.io/component=web`,
  '-o', 'json',
)).items;
const pod = pods.find((item) => !item.metadata.deletionTimestamp
  && item.status.conditions?.some((condition) => condition.type === 'Ready' && condition.status === 'True')
  && item.spec.containers.some((container) => container.name === 'matomo'));
assert.ok(pod, 'Ready Matomo web Pod required');

const matomoContainer = pod.spec.containers.find((container) => container.name === 'matomo');
assert.match(matomoContainer.image, /:5\.14\.2-/, 'Matomo 5.14.2 image must be running');
const httpPort = matomoContainer.ports?.find((port) => port.name === 'http')?.containerPort;
assert.ok(Number.isInteger(httpPort), 'Named Matomo HTTP container port required');

const services = JSON.parse(kubectl(
  'get', 'services',
  '-l', `app.kubernetes.io/instance=${release}`,
  '-o', 'json',
)).items;
const service = services.find((item) => item.spec.ports?.some((port) => port.name === 'http'));
assert.ok(service, 'Matomo HTTP Service required');
const servicePort = service.spec.ports.find((port) => port.name === 'http');
assert.equal(servicePort.targetPort, 'http', 'Service must target the named HTTP port');

const execMatomo = (...args) => kubectl(
  'exec', pod.metadata.name, '-c', 'matomo', '--', ...args,
).trim();
const appVersion = execMatomo(
  'php', '-r',
  'require "/var/www/html/core/Version.php"; echo Piwik\\Version::VERSION;',
);
assert.equal(appVersion, '5.14.2', 'Persisted application code must match the image version');

const phpVersion = execMatomo('php', '-r', 'echo PHP_VERSION;');
const phpVersionId = Number(execMatomo('php', '-r', 'echo PHP_VERSION_ID;'));
const patchedPhp = (phpVersionId >= 80235 && phpVersionId < 80300)
  || (phpVersionId >= 80336 && phpVersionId < 80400)
  || (phpVersionId >= 80427 && phpVersionId < 80500)
  || phpVersionId >= 80512;
assert.ok(patchedPhp, `PHP ${phpVersion} does not include the required security fixes`);

const httpStatus = execMatomo(
  'php', '-r',
  [
    '$context=stream_context_create(["http"=>["timeout"=>20,"ignore_errors"=>true,"follow_location"=>false]]);',
    '$body=@file_get_contents($argv[1],false,$context);',
    'if($body===false){fwrite(STDERR,"HTTP request failed\\n");exit(1);}',
    '$status=0;',
    'foreach(($http_response_header??[]) as $line){',
    'if(preg_match("~^HTTP/\\S+\\s+(\\d{3})~",$line,$match)){$status=(int)$match[1];break;}}',
    'if($status<200||$status>=400){fwrite(STDERR,"Unexpected HTTP status ".$status."\\n");exit(2);}',
    'echo $status;',
  ].join(''),
  `http://${service.metadata.name}:${servicePort.port}/matomo.php`,
);

console.log(
  `Matomo ${appVersion}: PHP ${phpVersion}, listener=${httpPort}, service=${servicePort.port}, HTTP ${httpStatus}.`,
);
