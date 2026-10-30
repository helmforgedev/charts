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

const podName = kubectl([
  'get',
  'pods',
  '-l',
  `app.kubernetes.io/instance=${release},app.kubernetes.io/name=karakeep`,
  '-o',
  'jsonpath={.items[0].metadata.name}',
]);

if (!podName) {
  throw new Error('Karakeep pod was not found');
}

const pod = JSON.parse(kubectl(['get', 'pod', podName, '-o', 'json']));
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
  "fetch('http://127.0.0.1:' + process.env.PORT + '/api/health').then(async response => { if (!response.ok) throw new Error('Karakeep health returned ' + response.status); console.log(await response.text()); })",
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
    "fetch(process.env.BROWSER_WEB_URL + '/json/version').then(async response => { if (!response.ok) throw new Error('Chromium returned ' + response.status); const body = await response.json(); if (!body.webSocketDebuggerUrl) throw new Error('Chromium debugger URL is missing'); console.log(body.Browser); })",
  ]);
}

if (containers.has('meilisearch')) {
  const meilisearch = containers.get('meilisearch');
  const meilisearchEnv = new Map(
    (meilisearch.env ?? []).map((entry) => [entry.name, entry.value]),
  );

  if (meilisearchEnv.get('MEILI_ENV') !== 'production') {
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
    "fetch(process.env.MEILI_ADDR + '/health').then(async response => { if (!response.ok) throw new Error('Meilisearch returned ' + response.status); const body = await response.json(); if (body.status !== 'available') throw new Error('Meilisearch is not available'); console.log(body.status); })",
  ]);
}

console.log('Karakeep application and enabled sidecars are reachable');
