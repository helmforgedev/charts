// SPDX-License-Identifier: Apache-2.0
import assert from "node:assert/strict";
import { execFileSync, spawn } from "node:child_process";
import { fileURLToPath } from "node:url";
const [context, namespace, release] = process.argv.slice(2);
assert.equal(context, "k3d-helmforge-tests-wsl");
assert.ok(namespace && release);
const k = (args) =>
  execFileSync("kubectl", ["--context", context, "-n", namespace, ...args], { encoding: "utf8", timeout: 100000 });
const values = JSON.parse(
  execFileSync("helm", ["get", "values", release, "-n", namespace, "--kube-context", context, "-a", "-o", "json"], {
    encoding: "utf8",
  }),
);
const selector = "app.kubernetes.io/instance=" + release + ",app.kubernetes.io/name=pocket-id";
const deployment = JSON.parse(k(["get", "deploy", "-l", selector, "-o", "json"])).items[0];
assert.ok(deployment);
const pod = () =>
  JSON.parse(k(["get", "pods", "-l", selector, "-o", "json"])).items.find((p) => !p.metadata.deletionTimestamp).metadata
    .name;
const secretName = deployment.spec.template.spec.volumes.find((v) => v.name === "encryption").secret.secretName;
const secret = () => JSON.parse(k(["get", "secret", secretName, "-o", "json"])).data;
const encryption = secret();
if (values.externalSecrets.enabled) {
  const external = JSON.parse(k(["get", "externalsecrets", "-l", selector, "-o", "json"])).items;
  assert.ok(external.length);
  for (const item of external) k(["wait", "externalsecret/" + item.metadata.name, "--for=condition=Ready", "--timeout=60s"]);
  console.log("PASS External Secrets synchronized identity encryption key before native authentication");
}
async function forward(test, remote = values.server.port, resource = "pod/" + pod()) {
  const child = spawn(
    "kubectl",
    [
      "--context",
      context,
      "-n",
      namespace,
      "port-forward",
      resource,
      ":" + remote,
      "--address=127.0.0.1",
    ],
    { windowsHide: true, stdio: ["ignore", "pipe", "pipe"] },
  );
  let output = "";
  for (const stream of [child.stdout, child.stderr]) stream.on("data", (b) => (output += b));
  try {
    const deadline = Date.now() + 20000;
    while (!/127\.0\.0\.1:(\d+) ->/.test(output) && Date.now() < deadline && child.exitCode === null)
      await new Promise((r) => setTimeout(r, 100));
    const port = output.match(/127\.0\.0\.1:(\d+) ->/)?.[1];
    assert.ok(port);
    await test("http://127.0.0.1:" + port);
  } finally {
    if (process.platform === "win32" && child.exitCode === null) {
      try {
        execFileSync("taskkill", ["/PID", String(child.pid), "/T", "/F"], { stdio: "ignore" });
      } catch (error) {
        let gone = false;
        try {
          process.kill(child.pid, 0);
        } catch (e) {
          if (e.code === "ESRCH") gone = true;
          else throw e;
        }
        if (!gone) throw error;
      }
    } else child.kill();
  }
}

let cookie, userId, jwks;
const api = (base, path, { method = "GET", body, anonymous = false } = {}) =>
  fetch(base + path, {
    method,
    headers: {
      Origin: values.server.publicUrl,
      ...(!anonymous && cookie ? { Cookie: cookie } : {}),
      ...(body ? { "Content-Type": "application/json" } : {}),
    },
    ...(body ? { body: JSON.stringify(body) } : {}),
    redirect: "manual",
    signal: AbortSignal.timeout(10000),
  });
async function verify(base) {
  const closed = await api(base, "/api/signup/setup", { anonymous: true });
  assert.equal(closed.status, 404);
  assert.match(await closed.text(), /setup_not_available/);
  const me = await api(base, "/api/users/me");
  assert.equal(me.status, 200);
  const user = await me.json();
  assert.equal(user.username, values.bootstrap.username);
  assert.equal(user.isAdmin, true);
  if (userId) assert.equal(user.id, userId);
  else userId = user.id;
  const denied = await api(base, "/api/users/me", { anonymous: true });
  assert.equal(denied.status, 401);
  const discovery = await api(base, "/.well-known/openid-configuration", { anonymous: true });
  assert.equal(discovery.status, 200);
  const document = await discovery.json();
  assert.equal(document.issuer, new URL(values.server.publicUrl).origin);
  assert.ok(document.code_challenge_methods_supported.includes("S256"));
  const keys = await api(base, new URL(document.jwks_uri).pathname, { anonymous: true });
  assert.equal(keys.status, 200);
  const current = await keys.json();
  assert.ok(current.keys.length);
  for (const key of current.keys) {
    assert.ok(key.kid);
    assert.equal(key.d, undefined);
  }
  if (jwks) assert.deepEqual(current, jwks);
  else jwks = current;
}
let browserFixture;
try {
await forward(async (base) => {
  const output = k([
    "exec",
    pod(),
    "-c",
    "pocket-id",
    "--",
    "/app/pocket-id",
    "one-time-access-token",
    values.bootstrap.username,
  ]);
  const token = output.match(/\/lc\/([^\s]+)/)?.[1];
  assert.ok(token, "Native CLI must return a one-time login URL");
  const login = await api(base, "/api/one-time-access-token/" + token, { method: "POST", anonymous: true });
  assert.equal(login.status, 200);
  assert.ok(login.headers.getSetCookie().some((c) => /HttpOnly/i.test(c)));
  cookie = login.headers
    .getSetCookie()
    .map((c) => c.split(";")[0])
    .join("; ");
  assert.ok(cookie);
  const replay = await api(base, "/api/one-time-access-token/" + token, { method: "POST", anonymous: true });
  assert.equal(replay.status, 401, "Native one-time token cannot be replayed");
  await verify(base);
  if (["pocket-id-passkeys", "pocket-id-restore"].includes(deployment.metadata.name)) {
    const { createPasskeyFixture } = await import("./browser-smoke.mjs");
    browserFixture = await createPasskeyFixture({ origin: values.server.publicUrl, expectedUserId: userId });
    const response = await api(base, "/api/users/" + userId + "/one-time-access-token", { method: "POST", body: {} });
    assert.equal(response.status, 201);
    await browserFixture.enroll(base, (await response.json()).token);
  }
});
if (values.persistence.enabled) {
  k(["rollout", "restart", "deployment/" + deployment.metadata.name]);
  k(["rollout", "status", "deployment/" + deployment.metadata.name, "--timeout=90s"]);
  await forward(async base => { await verify(base); await browserFixture?.afterReplacement(base); });
}
if (deployment.metadata.name === "pocket-id-restore") {
 const {restoreIdentity}=await import("./restore-smoke.mjs");
 await restoreIdentity({k,context,namespace,release,chartPath:fileURLToPath(new URL("..",import.meta.url)),deployment,values,pod,forward,verify,browserFixture});
}
execFileSync(
  "helm",
  [
    "upgrade",
    release,
    fileURLToPath(new URL("..", import.meta.url)),
    "--kube-context",
    context,
    "-n",
    namespace,
    "--reuse-values",
    "--wait",
    "--timeout",
    "60s",
  ],
  { encoding: "utf8", timeout: 75000 },
);
assert.deepEqual(secret(), encryption);
if (values.metrics.enabled) {
  const { verifyMetrics } = await import("./metrics-smoke.mjs");
  await verifyMetrics({ k, forward, values, namespace });
}
console.log(
  "PASS private native administrator bootstrap, closed setup, one-time operator recovery and replay denial, private user API, OIDC discovery/JWKS and retained key/session across replacement",
);
} finally { await browserFixture?.close(); }
