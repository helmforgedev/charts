// SPDX-License-Identifier: Apache-2.0
import assert from "node:assert/strict";
import fs from "node:fs";
import net from "node:net";
const env = process.env,
  host = env.PGHOST.replace(/^\[|\]$/g, "");
assert.ok(host && env.PGUSER && env.PGDATABASE && env.PGPASSWORD, "PostgreSQL connection components must be nonempty");
const query = new URLSearchParams({ sslmode: env.PGSSLMODE, connect_timeout: "10" });
if (env.PGSSLROOTCERT) query.set("sslrootcert", env.PGSSLROOTCERT);
const address = net.isIP(host) === 6 ? "[" + host + "]" : host;
const url = `postgres://${encodeURIComponent(env.PGUSER)}:${encodeURIComponent(env.PGPASSWORD)}@${address}:${Number(env.PGPORT)}/${encodeURIComponent(env.PGDATABASE)}?${query}`;
fs.writeFileSync("/database-runtime/url", url, { mode: 0o600 });
console.log("PostgreSQL URL prepared in a private memory volume");
const deadline = Date.now() + 300000;
let reachable = false;
while (Date.now() < deadline) {
  reachable = await new Promise(resolve => {
    const socket = net.createConnection({ host, port: Number(env.PGPORT) });
    let done = false;
    const finish = value => { if (done) return; done = true; socket.destroy(); resolve(value); };
    socket.setTimeout(3000);
    socket.once('connect', () => finish(true));
    socket.once('error', () => finish(false));
    socket.once('timeout', () => finish(false));
  });
  if (reachable) break;
  await new Promise(resolve => setTimeout(resolve, 500));
}
assert.ok(reachable, 'PostgreSQL TCP listener must become reachable before native authenticated bootstrap');
