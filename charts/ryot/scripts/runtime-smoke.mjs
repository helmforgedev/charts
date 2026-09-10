// SPDX-License-Identifier: Apache-2.0
import assert from "node:assert/strict";
import { execFileSync, spawn } from "node:child_process";
import { fileURLToPath } from "node:url";
const [context, namespace, release] = process.argv.slice(2);
assert.match(context ?? "", /^k3d-/);
assert.ok(namespace && release);
const k = (args) =>
  execFileSync("kubectl", ["--context", context, "-n", namespace, ...args], { encoding: "utf8", timeout: 100000 });
const values = JSON.parse(
  execFileSync("helm", ["get", "values", release, "-n", namespace, "--kube-context", context, "-a", "-o", "json"], {
    encoding: "utf8",
  }),
);
const selector = `app.kubernetes.io/instance=${release},app.kubernetes.io/name=ryot`;
const deployment = JSON.parse(k(["get", "deploy", "-l", selector, "-o", "json"])).items[0];
assert.ok(deployment);
const authName = deployment.spec.template.spec.containers[0].env.find((e) => e.name === "SERVER_ADMIN_ACCESS_TOKEN")
  .valueFrom.secretKeyRef.name;
const bootstrapName = deployment.spec.template.spec.volumes.find((v) => v.name === "bootstrap-auth").secret.secretName;
const secret = (name) => JSON.parse(k(["get", "secret", name, "-o", "json"])).data;
const authSecret = secret(authName),
  bootstrapSecret = secret(bootstrapName),
  adminToken = Buffer.from(authSecret[values.auth.adminAccessTokenKey], "base64").toString();
assert.ok(adminToken.length >= 32);
const password = Buffer.from(bootstrapSecret[values.bootstrap.passwordKey], "base64").toString();
const pod = () =>
  JSON.parse(k(["get", "pods", "-l", selector, "-o", "json"])).items.find((p) => !p.metadata.deletionTimestamp).metadata
    .name;
async function forward(test) {
  const child = spawn(
    "kubectl",
    [
      "--context",
      context,
      "-n",
      namespace,
      "port-forward",
      "pod/" + pod(),
      ":" + values.server.port,
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
let apiKey, userId, collectionId;
const loginQuery =
  "mutation($input:AuthUserInput!){loginUser(input:$input){__typename ... on ApiKeyResponse{apiKey} ... on LoginError{error} ... on StringIdObject{id}}}";
const registerQuery =
  "mutation($input:RegisterUserInput!){registerUser(input:$input){__typename ... on StringIdObject{id} ... on RegisterError{error}}}";
const detailQuery = "query{userDetails{__typename ... on UserDetails{id name lot} ... on UserDetailsError{error}}}";
const collectionQuery = "query{userCollectionsList{response{id name description count isDefault}}}";
const changeCollection = "mutation($input:CreateOrUpdateCollectionInput!){createOrUpdateCollection(input:$input){id}}";
async function gql(base, query, variables = {}, token = apiKey, { allowErrors = false } = {}) {
  const response = await fetch(base + "/backend/graphql", {
    method: "POST",
    headers: { "Content-Type": "application/json", ...(token ? { Authorization: "Bearer " + token } : {}) },
    body: JSON.stringify({ query, variables }),
    signal: AbortSignal.timeout(20000),
  });
  assert.equal(response.status, 200);
  const result = await response.json();
  if (!allowErrors) assert.equal(result.errors, undefined, "GraphQL operation must succeed");
  return result;
}
async function login(base) {
  const result = await gql(
    base,
    loginQuery,
    { input: { password: { username: values.bootstrap.username, password } } },
    "",
  );
  assert.equal(result.data.loginUser.__typename, "ApiKeyResponse");
  apiKey = result.data.loginUser.apiKey;
  assert.ok(apiKey);
  const details = (await gql(base, detailQuery)).data.userDetails;
  assert.equal(details.lot, "ADMIN");
  if (userId) assert.equal(details.id, userId);
  else userId = details.id;
}
await forward(async (base) => {
  assert.equal((await fetch(base + "/health")).status, 200);
  const configuration = await (await fetch(base + "/backend/config")).text();
  assert.equal(configuration.includes(adminToken), false, "Public configuration must not reveal the admin override");
  assert.equal(configuration.includes(password), false);
  await login(base);
  for (const token of ["", apiKey]) {
    const flags = (await gql(base, "query{coreDetails{fileStorageEnabled oidcEnabled signupAllowed}}", {}, token)).data
      .coreDetails;
    assert.equal(flags.fileStorageEnabled, false);
    assert.equal(flags.oidcEnabled, false);
    assert.equal(flags.signupAllowed, false);
    const put = await gql(
      base,
      'mutation{presignedPutS3Url(prefix:"helmforge-disabled-fixture"){key uploadUrl}}',
      {},
      token,
      { allowErrors: true },
    );
    assert.ok(!put.data?.presignedPutS3Url?.uploadUrl, "Disabled storage must not produce a signed upload URL");
    const get = await gql(base, 'query{getPresignedS3Url(key:"helmforge-disabled-fixture/nonexistent")}', {}, token, {
      allowErrors: true,
    });
    assert.ok(!get.data?.getPresignedS3Url, "Disabled storage must not produce a signed download URL");
    const del = await gql(base, 'mutation{deleteS3Object(key:"helmforge-disabled-fixture/nonexistent")}', {}, token, {
      allowErrors: true,
    });
    assert.notEqual(del.data?.deleteS3Object, true);
  }
  const anonymous = await gql(base, detailQuery, {}, "", { allowErrors: true });
  assert.notEqual(anonymous.data?.userDetails?.__typename, "UserDetails");
  for (const token of ["", "invalid-fixture-admin-token"]) {
    const denied = await gql(
      base,
      registerQuery,
      {
        input: {
          data: { password: { username: "unapproved", password: "fixture-only-password" } },
          lot: "ADMIN",
          adminAccessToken: token,
        },
      },
      "",
      { allowErrors: true },
    );
    assert.notEqual(
      denied.data?.registerUser?.__typename,
      "StringIdObject",
      "Anonymous registration must remain closed even when requesting ADMIN",
    );
  }
  const incorrect = await gql(
    base,
    loginQuery,
    { input: { password: { username: values.bootstrap.username, password: "incorrect-fixture-password" } } },
    "",
  );
  assert.notEqual(incorrect.data.loginUser.__typename, "ApiKeyResponse");
  collectionId = (
    await gql(base, changeCollection, { input: { name: "hf-runtime-fixture", description: "initial fixture" } })
  ).data.createOrUpdateCollection.id;
  assert.ok(collectionId);
  await gql(base, changeCollection, {
    input: { updateId: collectionId, name: "hf-runtime-fixture", description: "persistent fixture ação 日本語" },
  });
  const list = (await gql(base, collectionQuery)).data.userCollectionsList.response;
  assert.equal(list.find((c) => c.id === collectionId).description, "persistent fixture ação 日本語");
  assert.equal(list.find((c) => c.id === collectionId).isDefault, false);
  const member = await gql(base, registerQuery, {
    input: { data: { password: { username: "fixture-member", password: "fixture-only-member-password" } } },
  });
  assert.equal(member.data.registerUser.__typename, "StringIdObject");
  const memberKey = (
    await gql(
      base,
      loginQuery,
      { input: { password: { username: "fixture-member", password: "fixture-only-member-password" } } },
      "",
    )
  ).data.loginUser.apiKey;
  assert.ok(memberKey);
  assert.equal((await gql(base, detailQuery, {}, memberKey)).data.userDetails.lot, "NORMAL");
  assert.equal(
    (await gql(base, collectionQuery, {}, memberKey)).data.userCollectionsList.response.some(
      (c) => c.id === collectionId,
    ),
    false,
  );
});
if (values.fullnameOverride === "ryot-restore") {
  const { recoverDatabase } = await import("./database-recovery.mjs");
  await recoverDatabase({
    k,
    context,
    namespace,
    release,
    chartPath: fileURLToPath(new URL("..", import.meta.url)),
    deployment,
  });
} else {
  k(["rollout", "restart", "deployment/" + deployment.metadata.name]);
  k(["rollout", "status", "deployment/" + deployment.metadata.name, "--timeout=100s"]);
}
await forward(async (base) => {
  assert.equal(
    (await gql(base, detailQuery)).data.userDetails.id,
    userId,
    "Native session must survive application replacement",
  );
  await login(base);
  const list = (await gql(base, collectionQuery)).data.userCollectionsList.response;
  assert.equal(list.find((c) => c.id === collectionId).description, "persistent fixture ação 日本語");
});
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
assert.deepEqual(secret(authName), authSecret);
assert.deepEqual(secret(bootstrapName), bootstrapSecret);
await forward(async (base) => {
  const deleted = (
    await gql(base, "mutation($name:String!){deleteCollection(collectionName:$name)}", { name: "hf-runtime-fixture" })
  ).data.deleteCollection;
  assert.equal(deleted, true);
  assert.equal(
    (await gql(base, collectionQuery)).data.userCollectionsList.response.some((c) => c.id === collectionId),
    false,
  );
  await gql(base, "mutation{logoutUser}");
  const revoked = await gql(base, detailQuery, {}, apiKey, { allowErrors: true });
  assert.notEqual(revoked.data?.userDetails?.__typename, "UserDetails");
});
console.log(
  "PASS protected native admin setup, closed registration and role escalation denial, local login, private collection CRUD and ownership, native session persistence and logout, retained administrator Secrets",
);
