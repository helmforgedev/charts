// SPDX-License-Identifier: Apache-2.0
import assert from "node:assert/strict";
import fs from "node:fs";
import { spawn } from "node:child_process";
fs.mkdirSync("/app/data/uploads", { recursive: true });
const child = spawn("/bootstrap-bin/pocket-id", [], {
  cwd: "/app/data",
  env: { ...process.env, HOST: "127.0.0.1", ACTORS_HOST: "127.0.0.1", OTEL_METRICS_EXPORTER: "none" },
  stdio: ["ignore", "pipe", "pipe"],
});
let diagnostics = "",
  spawnError;
child.on("error", (error) => {
  spawnError = error;
});
for (const stream of [child.stdout, child.stderr])
  stream.on("data", (data) => {
    diagnostics = (diagnostics + data).slice(-12000);
  });
const base = "http://127.0.0.1:" + process.env.PORT;
const api = (path, options = {}) =>
  fetch(base + path, {
    ...options,
    headers: { Origin: process.env.APP_URL, "Content-Type": "application/json", ...options.headers },
    signal: AbortSignal.timeout(10000),
  });
try {
  const deadline = Date.now() + 120000;
  let ready = false;
  while (Date.now() < deadline && child.exitCode === null && child.signalCode === null && !spawnError) {
    try {
      if ((await api("/healthz")).ok) {
        ready = true;
        break;
      }
    } catch {}
    await new Promise((r) => setTimeout(r, 200));
  }
  assert.ok(ready, "Private native bootstrap failed: " + (spawnError?.message ?? diagnostics));
  const available = await api("/api/signup/setup");
  if (available.status === 404) {
    assert.match(await available.text(), /setup_not_available/);
    console.log("Existing setup preserved; no administrator or access token reset");
  } else {
    assert.equal(available.status, 204, "Native initial setup availability");
    assert.equal(
      process.env.BOOTSTRAP_ENABLED,
      "true",
      "Initial setup remains open but bootstrap is disabled; supply an initialized database or enable bootstrap",
    );
    const response = await api("/api/signup/setup", {
      method: "POST",
      body: JSON.stringify({
        username: process.env.BOOTSTRAP_USERNAME,
        email: process.env.BOOTSTRAP_EMAIL,
        firstName: process.env.BOOTSTRAP_FIRST_NAME,
        lastName: process.env.BOOTSTRAP_LAST_NAME,
      }),
    });
    assert.equal(response.status, 200, "Native initial administrator creation");
    const user = await response.json();
    assert.equal(user.username, process.env.BOOTSTRAP_USERNAME);
    assert.equal(user.isAdmin, true);
    const closed = await api("/api/signup/setup");
    assert.equal(closed.status, 404);
    assert.match(await closed.text(), /setup_not_available/);
    console.log("Native administrator created on loopback; public initial setup is closed");
  }
} finally {
  if (child.exitCode === null && child.signalCode === null && !spawnError) {
    child.kill("SIGTERM");
    const deadline = Date.now() + 30000;
    while (child.exitCode === null && child.signalCode === null && Date.now() < deadline)
      await new Promise((r) => setTimeout(r, 100));
    if (child.exitCode === null && child.signalCode === null) {
      child.kill("SIGKILL");
      throw new Error("Private bootstrap did not stop gracefully");
    }
  }
}
