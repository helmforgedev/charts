// SPDX-License-Identifier: Apache-2.0
import assert from "node:assert/strict";
import fs from "node:fs";
import net from "node:net";
const env = process.env,
  host = env.PGHOST.replace(/^\[|\]$/g, "");
assert.ok(
  env.SERVER_ADMIN_ACCESS_TOKEN?.length >= 32,
  "Administrator override must contain at least 32 characters before any listener starts",
);
assert.ok(host && env.PGUSER && env.PGDATABASE && env.PGPASSWORD, "PostgreSQL connection components must be nonempty");
const query = new URLSearchParams({ sslmode: env.PGSSLMODE, connect_timeout: "10" });
if (env.PGSSLROOTCERT) query.set("sslrootcert", env.PGSSLROOTCERT);
const address = net.isIP(host) === 6 ? "[" + host + "]" : host;
const url = `postgres://${encodeURIComponent(env.PGUSER)}:${encodeURIComponent(env.PGPASSWORD)}@${address}:${Number(env.PGPORT)}/${encodeURIComponent(env.PGDATABASE)}?${query}`;
fs.writeFileSync("/database-runtime/url", url, { mode: 0o600 });
console.log("PostgreSQL URL prepared in a private memory volume");
