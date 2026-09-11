// SPDX-License-Identifier: Apache-2.0
import assert from "node:assert/strict";
import { execFileSync, spawn } from "node:child_process";
import { randomUUID } from "node:crypto";
import { getDocument } from "pdfjs-dist/legacy/build/pdf.mjs";
import { verifyIsolation } from "./isolation-smoke.mjs";
import { smtpSmoke } from "./smtp-smoke.mjs";
import { uploadSmoke, verifyUpload } from "./storage-smoke.mjs";
import { databaseSmoke } from "./database-smoke.mjs";
import { browserSmoke } from "./browser-smoke.mjs";
import { restoreSmoke } from "./restore-smoke.mjs";
import { oauthSmoke } from "./oauth-smoke.mjs";
const [context, namespace, release] = process.argv.slice(2);
assert.equal(context, "k3d-helmforge-tests-wsl");
const k = (args) =>
  execFileSync("kubectl", ["--context", context, "-n", namespace, ...args], {
    encoding: "utf8",
    timeout: 90000,
  });
const values = JSON.parse(
  execFileSync(
    "helm",
    [
      "get",
      "values",
      release,
      "--kube-context",
      context,
      "-n",
      namespace,
      "-a",
      "-o",
      "json",
    ],
    { encoding: "utf8" },
  ),
);
const chartName = values.nameOverride || "reactive-resume";
const selector =
  "app.kubernetes.io/instance=" +
  release +
  ",app.kubernetes.io/name=" +
  chartName;
const deployment = JSON.parse(
  k(["get", "deployment", "-l", selector, "-o", "json"]),
).items.find(
  (item) =>
    item.spec.template.metadata.labels["app.kubernetes.io/name"] === chartName,
);
assert.ok(deployment);
const pod = () =>
  JSON.parse(k(["get", "pods", "-l", selector, "-o", "json"])).items.find(
    (item) => !item.metadata.deletionTimestamp,
  ).metadata.name;
const bootstrapSecret = deployment.spec.template.spec.volumes.find(
  (item) => item.name === "bootstrap-auth",
).secret.secretName;
const password = Buffer.from(
  JSON.parse(k(["get", "secret", bootstrapSecret, "-o", "json"])).data[
    values.bootstrap.passwordKey
  ],
  "base64",
).toString();
const identityName = deployment.spec.template.spec.containers[0].env.find(
  (item) => item.name === "AUTH_SECRET",
).valueFrom.secretKeyRef.name;
const identity = () =>
  JSON.stringify(
    Object.entries(
      JSON.parse(k(["get", "secret", identityName, "-o", "json"])).data,
    ).sort(),
  );
const originalIdentity = identity();
if (values.fullnameOverride === "reactive-resume-production") {
  const pods = JSON.parse(
    k([
      "get",
      "pods",
      "-l",
      "app.kubernetes.io/instance=" + release,
      "-o",
      "json",
    ]),
  ).items;
  assert.ok(pods.length >= 3);
  for (const item of pods) {
    assert.equal(item.spec.automountServiceAccountToken, false);
    assert.ok(
      !(item.spec.volumes ?? []).some((volume) =>
        volume.projected?.sources?.some((source) => source.serviceAccountToken),
      ),
    );
  }
  console.log(
    "PASS application, admission helper and database use tokenless Pods",
  );
}
const origin =
  values.server.publicUrl ||
  "http://" +
    deployment.metadata.name +
    "." +
    namespace +
    ".svc:" +
    values.service.port;
const sleep = (ms) => new Promise((resolve) => setTimeout(resolve, ms));
let cookies = "",
  resumeId;
let retainedUpload;
async function forward(action) {
  const process = spawn(
    "kubectl",
    [
      "--context",
      context,
      "-n",
      namespace,
      "port-forward",
      "pod/" + pod(),
      "0:3000",
      "--address=127.0.0.1",
    ],
    { windowsHide: true, stdio: ["ignore", "pipe", "pipe"] },
  );
  let output = "";
  for (const stream of [process.stdout, process.stderr])
    stream.on("data", (chunk) => (output += chunk));
  try {
    const deadline = Date.now() + 15000;
    while (
      !/Forwarding from/.test(output) &&
      Date.now() < deadline &&
      process.exitCode === null
    )
      await sleep(100);
    const port = output.match(/127\.0\.0\.1:(\d+)/)?.[1];
    assert.ok(port, "Application port-forward failed");
    await action("http://127.0.0.1:" + port);
  } finally {
    if (process.exitCode === null && process.signalCode === null) {
      if (globalThis.process.platform === "win32")
        execFileSync("taskkill", ["/PID", String(process.pid), "/T", "/F"], {
          stdio: "ignore",
        });
      else process.kill();
    }
  }
}
function client(base) {
  return (path, { method = "GET", json, body, anonymous = false } = {}) =>
    fetch(base + path, {
      method,
      headers: {
        Origin: origin,
        ...(json ? { "Content-Type": "application/json" } : {}),
        ...(!anonymous && cookies ? { Cookie: cookies } : {}),
      },
      body: json ? JSON.stringify(json) : body,
      redirect: "manual",
      signal: AbortSignal.timeout(30000),
    });
}
async function login(request) {
  const result = await request("/api/auth/sign-in/email", {
    method: "POST",
    anonymous: true,
    json: {
      email: values.bootstrap.email,
      password,
      callbackURL: "/dashboard",
    },
  });
  assert.equal(result.status, 200, "Native initial-user login failed");
  cookies = result.headers
    .getSetCookie()
    .map((value) => value.split(";")[0])
    .join("; ");
  assert.ok(cookies);
  const session = await request("/api/auth/get-session");
  assert.equal(session.status, 200);
  const user = (await session.json()).user;
  assert.equal(user.email, values.bootstrap.email.trim().toLowerCase());
  assert.equal(user.role, "user");
}
async function pdf(request) {
  const response = await request("/api/openapi/resumes/" + resumeId + "/pdf");
  assert.equal(response.status, 200, "Native server-side PDF export failed");
  assert.match(response.headers.get("content-type"), /application\/pdf/);
  const bytes = new Uint8Array(await response.arrayBuffer());
  assert.equal(Buffer.from(bytes.subarray(0, 5)).toString(), "%PDF-");
  const task = getDocument({
    data: bytes,
    isEvalSupported: false,
    useSystemFonts: true,
  });
  try {
    const doc = await task.promise;
    assert.ok(doc.numPages >= 1);
    let text = "";
    for (let index = 1; index <= doc.numPages; index++)
      text += (await (await doc.getPage(index)).getTextContent()).items
        .map((item) => item.str ?? "")
        .join(" ");
    assert.match(
      text,
      /HELMFORGE PDF MARKER/,
      "Rendered PDF must contain the edited resume content",
    );
  } finally {
    await task.destroy();
  }
}
try {
  verifyIsolation({ context, namespace, release, k, deployment, pod, values });
  await forward(async (base) => {
    const request = client(base);
    assert.equal(
      (await request("/api/health", { anonymous: true })).status,
      200,
    );
    assert.equal(
      (
        await request("/api/auth/sign-up/email", {
          method: "POST",
          anonymous: true,
          json: {},
        })
      ).status,
      403,
    );
    for (const endpoint of values.smtp.enabled
      ? []
      : ["request-password-reset", "send-verification-email", "change-email"]) {
      assert.equal(
        (
          await request("/api/auth/" + endpoint, {
            method: "POST",
            anonymous: true,
            json: { email: values.bootstrap.email },
          })
        ).status,
        403,
        "Mail-dependent routes must not expose native log-only token delivery",
      );
    }
    assert.equal(
      (
        await request("/api/auth/sign-in/email", {
          method: "POST",
          anonymous: true,
          json: {
            email: values.bootstrap.email,
            password: "incorrect-owned-fixture",
          },
        })
      ).status,
      401,
    );
    await login(request);
    databaseSmoke({ values, k, pod });
    await oauthSmoke({
      context,
      namespace,
      values,
      k,
      pod,
      base,
      origin,
      password,
    });
    if (!values.oauth.enabled)
      await smtpSmoke({
        context,
        namespace,
        values,
        k,
        pod,
        request,
        login,
        password,
        origin,
      });
    retainedUpload = await uploadSmoke({ values, k, pod, request, origin });
    const create = await request("/api/openapi/resumes", {
      method: "POST",
      json: {
        name: "Owned HelmForge fixture",
        slug: "helmforge-" + randomUUID(),
        tags: [],
        withSampleData: false,
      },
    });
    assert.equal(create.status, 200);
    resumeId = await create.json();
    assert.equal(typeof resumeId, "string");
    assert.ok(
      [401, 403].includes(
        (await request("/api/openapi/resumes/" + resumeId, { anonymous: true }))
          .status,
      ),
    );
    const operations = [
      { op: "replace", path: "/basics/name", value: "HELMFORGE PDF MARKER" },
      {
        op: "replace",
        path: "/basics/headline",
        value: "Retained private resume",
      },
      {
        op: "replace",
        path: "/metadata/typography/body/fontFamily",
        value: "Helvetica",
      },
      {
        op: "replace",
        path: "/metadata/typography/heading/fontFamily",
        value: "Helvetica",
      },
      {
        op: "replace",
        path: "/metadata/typography/body/fontWeights",
        value: ["400", "700"],
      },
      {
        op: "replace",
        path: "/metadata/typography/heading/fontWeights",
        value: ["400", "700"],
      },
      { op: "replace", path: "/picture/hidden", value: true },
    ];
    const edit = await request("/api/openapi/resumes/" + resumeId, {
      method: "PATCH",
      json: { operations },
    });
    assert.equal(edit.status, 200);
    const updated = await request("/api/openapi/resumes/" + resumeId);
    assert.equal(updated.status, 200);
    assert.equal(
      (await updated.json()).data.basics.name,
      "HELMFORGE PDF MARKER",
    );
    await pdf(request);
    if (values.fullnameOverride === "reactive-resume-browser") {
      await browserSmoke({
        base,
        origin,
        email: values.bootstrap.email,
        password,
        resumeId,
      });
    }
    console.log(
      "PASS native ordinary-user authentication, closed signup, private resume CRUD and real PDF content",
    );
  });
  if (values.fullnameOverride === "reactive-resume-restore") {
    restoreSmoke({ context, namespace, release, k, values, deployment, pod });
  } else k(["rollout", "restart", "deployment/" + deployment.metadata.name]);
  k([
    "rollout",
    "status",
    "deployment/" + deployment.metadata.name,
    "--timeout=120s",
  ]);
  await forward(async (base) => {
    const request = client(base);
    const session = await request("/api/auth/get-session");
    assert.equal(session.status, 200);
    assert.equal(
      (await session.json())?.user?.email,
      values.bootstrap.email.trim().toLowerCase(),
      "Original native session must survive recovery or replacement",
    );
    await login(request);
    const retained = await request("/api/openapi/resumes/" + resumeId);
    assert.equal(retained.status, 200);
    assert.equal(
      (await retained.json()).data.basics.name,
      "HELMFORGE PDF MARKER",
    );
    await pdf(request);
  });
  await forward(async (base) => {
    await verifyUpload({ request: client(base), upload: retainedUpload });
  });
  assert.equal(
    identity(),
    originalIdentity,
    "Native signing and encryption keys changed",
  );
  assert.match(
    k(["logs", pod(), "-c", "bootstrap"]),
    /Existing native identity retained; signup remained closed/,
  );
  console.log(
    "PASS retained user, signing/encryption keys, private resume and PDF after Pod replacement",
  );
} catch (error) {
  console.error(
    String(error.stack ?? error)
      .replaceAll(password, "[REDACTED]")
      .replaceAll(cookies || "no-session-value", "[REDACTED]"),
  );
  throw Error("Reactive Resume behavioral validation failed");
}
