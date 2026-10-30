// SPDX-License-Identifier: Apache-2.0
import assert from 'node:assert/strict';
import { execFileSync } from 'node:child_process';

const [context, namespace, release] = process.argv.slice(2);
assert.ok(context?.startsWith('k3d-helmforge-') && namespace && release,
  'Explicit HelmForge lab context, namespace, and release are required');

const kubectl = (args) => execFileSync(
  'kubectl',
  ['--context', context, '-n', namespace, ...args],
  { encoding: 'utf8', timeout: 60_000, stdio: ['ignore', 'pipe', 'pipe'] },
);

const pods = JSON.parse(kubectl([
  'get', 'pods', '-l', `app.kubernetes.io/instance=${release}`, '-o', 'json',
])).items;
const pod = pods.find((candidate) => !candidate.metadata.deletionTimestamp
  && candidate.status.conditions?.some((condition) => condition.type === 'Ready' && condition.status === 'True')
  && candidate.spec.containers.some((container) => container.name === 'pihole'));
assert.ok(pod, 'A Ready Pi-hole pod is required');

const container = pod.spec.containers.find((candidate) => candidate.name === 'pihole');
const dnsPort = container.ports.find((port) => port.name === 'dns-tcp')?.containerPort;
const dnsUdpPort = container.ports.find((port) => port.name === 'dns-udp')?.containerPort;
const httpPort = container.ports.find((port) => port.name === 'http')?.containerPort;
const environment = Object.fromEntries(container.env.filter((entry) => 'value' in entry)
  .map((entry) => [entry.name, entry.value]));

assert.equal(dnsPort, dnsUdpPort, 'DNS TCP and UDP listeners must use the same port');
assert.equal(environment.FTLCONF_dns_port, String(dnsPort));
const primaryHttpListener = new RegExp(`^(?:\\+|0\\.0\\.0\\.0:)?${httpPort}o?$`);
assert.ok(
  environment.FTLCONF_webserver_port.split(',').some((listener) => primaryHttpListener.test(listener.trim())),
  `FTLCONF_webserver_port must include pod-reachable primary HTTP listener ${httpPort}`,
);

const check = [
  'set -eu',
  `curl -fsSL --max-time 10 http://127.0.0.1:${httpPort}/admin/ >/dev/null`,
  `dig +notcp +time=5 +tries=1 @127.0.0.1 -p ${dnsPort} pi.hole A | grep -Eq 'status: (NOERROR|NXDOMAIN)'`,
  `dig +tcp +time=5 +tries=1 @127.0.0.1 -p ${dnsPort} pi.hole A | grep -Eq 'status: (NOERROR|NXDOMAIN)'`,
].join('; ');
kubectl(['exec', pod.metadata.name, '-c', 'pihole', '--', 'sh', '-ec', check]);

console.log(`PASS: live Pi-hole HTTP ${httpPort} and DNS TCP/UDP ${dnsPort} listener contracts verified.`);
