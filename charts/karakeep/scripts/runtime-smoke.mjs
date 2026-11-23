// SPDX-License-Identifier: Apache-2.0

import { execFileSync } from 'node:child_process';

const [context, namespace, release] = process.argv.slice(2);

if (!context || !namespace || !release) {
  throw new Error('usage: runtime-smoke.mjs <context> <namespace> <release>');
}

function kubectl(args, options = {}) {
  return execFileSync(
    'kubectl',
    ['--context', context, '--namespace', namespace, ...args],
    { encoding: 'utf8', timeout: 120_000, ...options },
  ).trim();
}

const pods = JSON.parse(kubectl([
  'get',
  'pods',
  '-l',
  `app.kubernetes.io/instance=${release}`,
  '-o',
  'json',
]));
const pod = pods.items.find((item) =>
  item.spec.containers.some((container) => container.name === 'karakeep'),
);
const podName = pod?.metadata.name;

if (!podName) {
  throw new Error('Karakeep pod was not found');
}

const containers = new Map(
  pod.spec.containers.map((container) => [container.name, container]),
);
const karakeep = containers.get('karakeep');

if (!karakeep) {
  throw new Error('Karakeep application container was not found');
}

const applicationEnv = new Map(
  (karakeep.env ?? []).map((entry) => [entry.name, entry.value]),
);

kubectl([
  'exec',
  podName,
  '-c',
  'karakeep',
  '--',
  'node',
  '-e',
  "(async () => { for (let i = 0; i < 30; i++) { try { const r = await fetch('http://127.0.0.1:' + process.env.PORT + '/api/health'); if (r.ok) { console.log(await r.text()); return; } } catch {} await new Promise(r => setTimeout(r, 1000)); } throw new Error('Karakeep health did not respond'); })()",
]);

if (containers.has('chromium')) {
  const browserUrl = applicationEnv.get('BROWSER_WEB_URL');
  if (browserUrl !== 'http://127.0.0.1:9222') {
    throw new Error(`unexpected BROWSER_WEB_URL: ${browserUrl}`);
  }

  kubectl([
    'exec',
    podName,
    '-c',
    'karakeep',
    '--',
    'node',
    '-e',
    "(async () => { for (let i = 0; i < 30; i++) { try { const r = await fetch(process.env.BROWSER_WEB_URL + '/json/version'); if (r.ok) { const b = await r.json(); if (b.webSocketDebuggerUrl) { console.log(b.Browser); return; } } } catch {} await new Promise(r => setTimeout(r, 1000)); } throw new Error('Chromium did not respond'); })()",
  ]);
}

if (containers.has('meilisearch')) {
  const meilisearch = containers.get('meilisearch');
  const meilisearchEnv = new Map(
    (meilisearch.env ?? []).map((entry) => [entry.name, entry.value]),
  );

  if (!['development', 'production'].includes(meilisearchEnv.get('MEILI_ENV'))) {
    throw new Error(`unexpected MEILI_ENV: ${meilisearchEnv.get('MEILI_ENV')}`);
  }
  if (meilisearchEnv.get('MEILI_UPGRADE_DB') !== 'true') {
    throw new Error(
      `unexpected MEILI_UPGRADE_DB: ${meilisearchEnv.get('MEILI_UPGRADE_DB')}`,
    );
  }

  kubectl([
    'exec',
    podName,
    '-c',
    'karakeep',
    '--',
    'node',
    '-e',
    "(async () => { for (let i = 0; i < 30; i++) { try { const r = await fetch(process.env.MEILI_ADDR + '/health'); if (r.ok) { const b = await r.json(); if (b.status === 'available') { console.log(b.status); return; } } } catch {} await new Promise(r => setTimeout(r, 1000)); } throw new Error('Meilisearch did not respond'); })()",
  ]);
}

console.log('Karakeep application and enabled sidecars are reachable');
