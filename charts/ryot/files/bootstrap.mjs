// SPDX-License-Identifier: Apache-2.0
import assert from "node:assert/strict";
import fs from "node:fs";
import { spawn } from "node:child_process";
if (fs.readFileSync("/bootstrap-state/fresh", "utf8") !== "true") {
  console.log("Existing users preserved; bootstrap never creates or resets accounts during adoption");
  process.exit(0);
}
const url = fs.readFileSync("/database-runtime/url", "utf8");
assert.ok(process.env.SERVER_ADMIN_ACCESS_TOKEN, "A nonempty administrator override token is required");
const child = spawn("/usr/local/bin/backend", [], {
  env: {
    ...process.env,
    DATABASE_URL: url,
    SERVER_BACKEND_HOST: "127.0.0.1",
    SERVER_BACKEND_PORT: "5000",
    SERVER_DISABLE_BACKGROUND_JOBS: "true",
  },
  stdio: ["ignore", "pipe", "pipe"],
});
let output = "",
  spawnError;
child.on("error", (error) => {
  spawnError = error;
});
for (const stream of [child.stdout, child.stderr]) stream.on("data", (b) => (output = (output + b).slice(-16000)));
const base = "http://127.0.0.1:5000";
async function graphql(query, variables = {}, token) {
  const response = await fetch(base + "/graphql", {
    method: "POST",
    headers: { "Content-Type": "application/json", ...(token ? { Authorization: "Bearer " + token } : {}) },
    body: JSON.stringify({ query, variables }),
    signal: AbortSignal.timeout(20000),
  });
  assert.equal(response.status, 200);
  const result = await response.json();
  assert.equal(result.errors, undefined, "Native GraphQL operation failed");
  return result.data;
}
try {
  const deadline = Date.now() + 150000;
  let ready = false;
  while (Date.now() < deadline && child.exitCode === null && child.signalCode === null && !spawnError) {
    try {
      if ((await fetch(base + "/config", { signal: AbortSignal.timeout(3000) })).ok) {
        ready = true;
        break;
      }
    } catch {}
    await new Promise((r) => setTimeout(r, 500));
  }
  assert.ok(ready, "Native private backend did not become ready: " + (spawnError?.message ?? output));
  const username = process.env.BOOTSTRAP_USERNAME,
    password = fs.readFileSync("/bootstrap-auth/password", "utf8");
  const registered = await graphql(
    "mutation($input:RegisterUserInput!){registerUser(input:$input){__typename ... on StringIdObject{id} ... on RegisterError{error}}}",
    { input: { data: { password: { username, password } }, adminAccessToken: process.env.SERVER_ADMIN_ACCESS_TOKEN } },
  );
  const created = registered.registerUser.__typename === "StringIdObject";
  assert.ok(
    created ||
      (registered.registerUser.__typename === "RegisterError" &&
        registered.registerUser.error === "IDENTIFIER_ALREADY_EXISTS"),
    "Protected registration must create the initial account or find the same account after an interrupted bootstrap",
  );
  const login = await graphql(
    "mutation($input:AuthUserInput!){loginUser(input:$input){__typename ... on ApiKeyResponse{apiKey} ... on LoginError{error} ... on StringIdObject{id}}}",
    { input: { password: { username, password } } },
  );
  assert.equal(login.loginUser.__typename, "ApiKeyResponse");
  assert.ok(login.loginUser.apiKey);
  const details = await graphql(
    "query{userDetails{__typename ... on UserDetails{id name lot} ... on UserDetailsError{error}}}",
    {},
    login.loginUser.apiKey,
  );
  assert.equal(details.userDetails.lot, "ADMIN");
  if (created) assert.equal(details.userDetails.id, registered.registerUser.id);
  console.log("Initial administrator created with native token authorization and verified before public exposure");
} finally {
  if (child.exitCode === null && child.signalCode === null && !spawnError) {
    child.kill("SIGTERM");
    const deadline = Date.now() + 30000;
    while (child.exitCode === null && child.signalCode === null && Date.now() < deadline)
      await new Promise((r) => setTimeout(r, 100));
    if (child.exitCode === null && child.signalCode === null) {
      child.kill("SIGKILL");
      throw new Error("Private backend did not terminate");
    }
  }
}
