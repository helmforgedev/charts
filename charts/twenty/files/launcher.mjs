// SPDX-License-Identifier: Apache-2.0
import fs from "node:fs";
import { createHash } from "node:crypto";
import { createRequire } from "node:module";
import { spawn } from "node:child_process";
import { configure, nativeDirectory } from "./configure.mjs";
import { admit } from "./admission.mjs";

process.umask(0o077);
const mode = process.argv[2],
  require = createRequire(nativeDirectory + "/package.json");
const delay = (ms) => new Promise((resolve) => setTimeout(resolve, ms));
const log = "/tmp/helmforge-native-bootstrap.log",
  markerPath = "/app/data/.helmforge-identity.json";
let child,
  database,
  stage = "configuration";
async function stop() {
  const current = child;
  if (!current || current.exitCode !== null || current.signalCode !== null)
    return;
  const closed = new Promise((resolve) => current.once("exit", resolve));
  current.kill("SIGTERM");
  const timer = setTimeout(() => current.kill("SIGKILL"), 20000);
  try {
    await closed;
  } finally {
    clearTimeout(timer);
    child = undefined;
  }
}
function start(args, command = process.execPath) {
  const fd = mode === "bootstrap" ? fs.openSync(log, "a", 0o600) : undefined;
  child = spawn(command, args, {
    cwd: nativeDirectory,
    env: process.env,
    stdio: fd === undefined ? "inherit" : ["ignore", fd, fd],
  });
  if (fd !== undefined) fs.closeSync(fd);
  return child;
}
async function command(args) {
  const offset = fs.existsSync(log) ? fs.statSync(log).size : 0;
  const current = start(args, "yarn");
  const code = await new Promise((resolve, reject) => {
    current.once("error", reject);
    current.once("exit", (code) => resolve(code));
  });
  child = undefined;
  if (code !== 0) throw Error("Native migration command failed");
  // Native cache:flush catches exceptions without returning a failing exit code.
  // Keep diagnostics private, but do not turn that behavior into successful startup.
  const output = fs
    .readFileSync(log)
    .subarray(offset)
    .toString()
    .replace(/\x1b\[[0-9;]*m/g, "");
  if (/\bERROR\b|(?:^|\n)\s*Error[: ]/m.test(output))
    throw Error("Native command reported an error despite its exit status");
  if (args.includes("cache:flush") && !output.includes("Cache flushed"))
    throw Error("Native cache flush did not confirm completion");
}
async function health() {
  const deadline = Date.now() + 120000;
  while (Date.now() < deadline) {
    if (child.exitCode !== null || child.signalCode !== null)
      throw Error("Native server exited");
    try {
      if (
        (
          await fetch("http://127.0.0.1:3010/healthz", {
            signal: AbortSignal.timeout(2000),
          })
        ).ok
      )
        return;
    } catch {}
    await delay(500);
  }
  throw Error("Native health deadline exceeded");
}
async function graphql(query, variables = {}, token) {
  const response = await fetch("http://127.0.0.1:3010/metadata", {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
      Origin: process.env.SERVER_URL,
      ...(token ? { Authorization: "Bearer " + token } : {}),
    },
    body: JSON.stringify({ query, variables }),
    signal: AbortSignal.timeout(90000),
  });
  const result = await response.json();
  if (!response.ok || result.errors?.length) {
    fs.appendFileSync(
      log,
      "\nOwned GraphQL operation failed: " +
        JSON.stringify(
          result.errors?.map((error) => ({
            message: error.message,
            code: error.extensions?.code,
          })),
        ) +
        "\n",
      { mode: 0o600 },
    );
    throw Error("Native workspace operation failed");
  }
  return result.data;
}
const loginQuery =
  "mutation($email:String!,$password:String!){signIn(email:$email,password:$password){tokens{accessOrWorkspaceAgnosticToken{token}} availableWorkspaces{availableWorkspacesForSignIn{id loginToken}}}}";
try {
  if (mode === "bootstrap") {
    stage = "network isolation admission";
    await admit({
      key: fs.readFileSync("/admission-key/key"),
      helperHost: process.env.HF_ADMISSION_HOST,
    });
  }
  configure();
  if (mode === "bootstrap") {
    if (process.env.HF_SMTP_ENABLED === "true") {
      stage = "authenticated SMTP TLS admission";
      const transport = require("nodemailer").createTransport({
        host: process.env.HF_SMTP_HOST,
        port: 465,
        secure: true,
        auth: {
          user: process.env.EMAIL_SMTP_USER,
          pass: process.env.EMAIL_SMTP_PASSWORD,
        },
        connectionTimeout: 5000,
        greetingTimeout: 5000,
        socketTimeout: 10000,
        tls: {
          servername: process.env.HF_SMTP_HOST,
          rejectUnauthorized: true,
          minVersion: "TLSv1.2",
          ...(process.env.HF_SMTP_CA
            ? { ca: fs.readFileSync(process.env.HF_SMTP_CA) }
            : {}),
        },
      });
      try {
        await transport.verify();
      } finally {
        transport.close();
      }
    }
    stage = "database admission";
    const { Client } = require("pg");
    const deadline = Date.now() + 90000;
    while (Date.now() < deadline) {
      const candidate = new Client({
        connectionString: process.env.PG_DATABASE_URL,
        connectionTimeoutMillis: 5000,
        query_timeout: 15000,
      });
      try {
        await candidate.connect();
        database = candidate;
        break;
      } catch (error) {
        await candidate.end().catch(() => {});
        if (
          ![
            "ECONNREFUSED",
            "ECONNRESET",
            "ETIMEDOUT",
            "EAI_AGAIN",
            "57P03",
          ].includes(error.code)
        )
          throw error;
        await delay(1000);
      }
    }
    if (!database) throw Error("Database connection deadline exceeded");
    stage = "retained identity admission";
    const fingerprint = createHash("sha256")
      .update(process.env.ENCRYPTION_KEY + "\0" + process.env.SERVER_ID)
      .digest("hex");
    const email = process.env.HF_INITIAL_EMAIL.trim().toLowerCase();
    let marker = fs.existsSync(markerPath)
      ? JSON.parse(fs.readFileSync(markerPath, "utf8"))
      : undefined;
    if (
      marker &&
      (marker.fingerprint !== fingerprint ||
        (!marker.userId && marker.email !== email))
    )
      throw Error("Retained identity mismatch before native migrations");
    const userTableExists = (
      await database.query(
        "SELECT to_regclass('core.\"user\"') IS NOT NULL AS present",
      )
    ).rows[0].present;
    if (
      !marker &&
      userTableExists &&
      (
        await database.query(
          'SELECT EXISTS(SELECT 1 FROM core."user") AS present',
        )
      ).rows[0].present
    )
      throw Error(
        "Existing users require the retained identity marker before native migrations",
      );
    stage = "native instance migrations";
    const exists = (
      await database.query(
        "SELECT EXISTS(SELECT 1 FROM pg_namespace WHERE nspname='core') AS present",
      )
    ).rows[0].present;
    if (!exists) await command(["database:init:prod"]);
    await command(["command:prod", "cache:flush"]);
    await command(["command:prod", "upgrade"]);
    await command(["command:prod", "cache:flush"]);
    await command(["command:prod", "cron:register:all"]);
    const prerequisites = (
      await database.query(
        "SELECT to_regclass('core.\"user\"') IS NOT NULL AS users,to_regclass('core.workspace') IS NOT NULL AS workspaces,to_regprocedure('public.unaccent_immutable(text)') IS NOT NULL AS unaccent,(SELECT count(*)=3 FROM pg_extension WHERE extname IN ('uuid-ossp','unaccent','citext')) AS extensions",
      )
    ).rows[0];
    if (!Object.values(prerequisites).every(Boolean))
      throw Error("Native database prerequisites are incomplete");
    stage = "retained identity verification";
    const users = (
      await database.query(
        'SELECT id,email,"canAccessFullAdminPanel","canImpersonate" FROM core."user"',
      )
    ).rows;
    if (users.length && !marker)
      throw Error("Existing users require the retained identity marker");
    if (
      marker?.userId &&
      !users.some(
        (user) => user.id === marker.userId && user.canAccessFullAdminPanel,
      )
    )
      throw Error(
        "Retained administrator is missing or has changed privileges",
      );
    if (!marker) {
      marker = { fingerprint, email };
      fs.writeFileSync(markerPath, JSON.stringify(marker), {
        flag: "wx",
        mode: 0o600,
      });
    }
    // Completed ownership follows the native user ID. Ordinary password/email
    // changes must not require replaying the initial enrollment credential.
    if (!marker.userId) {
      const password = fs.readFileSync("/bootstrap-auth/password", "utf8");
      if (password.length < 16 || Buffer.byteLength(password) > 72)
        throw Error("Initial password must satisfy native bcrypt limits");
      stage = "private native server startup";
      start(["dist/main.js"]);
      await health();
      let token, login;
      if (!users.length) {
        stage = "native first administrator enrollment";
        const data = await graphql(
          "mutation($email:String!,$password:String!){signUp(email:$email,password:$password){tokens{accessOrWorkspaceAgnosticToken{token}}}}",
          { email, password },
        );
        token = data.signUp.tokens.accessOrWorkspaceAgnosticToken.token;
      } else {
        login = (await graphql(loginQuery, { email, password })).signIn;
        token = login.tokens.accessOrWorkspaceAgnosticToken.token;
      }
      stage = "native workspace creation";
      let loginToken;
      const available =
        login?.availableWorkspaces.availableWorkspacesForSignIn ?? [];
      if (available.length) {
        const chosen =
          available.find((w) => w.id === marker.workspaceId) ??
          (available.length === 1 ? available[0] : undefined);
        if (!chosen) throw Error("Ambiguous existing workspaces");
        marker.workspaceId = chosen.id;
        loginToken = chosen.loginToken;
      } else {
        const data = await graphql(
          "mutation($input:SignUpInNewWorkspaceInput){signUpInNewWorkspace(input:$input){loginToken{token} workspace{id}}}",
          { input: { displayName: process.env.HF_WORKSPACE_NAME } },
          token,
        );
        marker.workspaceId = data.signUpInNewWorkspace.workspace.id;
        loginToken = data.signUpInNewWorkspace.loginToken.token;
      }
      const exchanged = await graphql(
        "mutation($loginToken:String!,$origin:String!){getAuthTokensFromLoginToken(loginToken:$loginToken,origin:$origin){tokens{accessOrWorkspaceAgnosticToken{token}}}}",
        { loginToken, origin: process.env.SERVER_URL },
      );
      token =
        exchanged.getAuthTokensFromLoginToken.tokens
          .accessOrWorkspaceAgnosticToken.token;
      stage = "native workspace activation";
      const activated = await graphql(
        "mutation{activateWorkspace(data:{}){id activationStatus}}",
        {},
        token,
      );
      if (
        !["ACTIVE", "CREATED"].includes(
          activated.activateWorkspace.activationStatus,
        )
      )
        throw Error("Workspace activation did not finish");
      if (!marker.userId) {
        await graphql(
          "mutation($input:UpdateWorkspaceInput!){updateWorkspace(data:$input){id isPublicInviteLinkEnabled}}",
          { input: { isPublicInviteLinkEnabled: false } },
          token,
        );
        const user = (
          await database.query(
            'SELECT id,"canAccessFullAdminPanel","canImpersonate" FROM core."user" WHERE email=$1',
            [email],
          )
        ).rows[0];
        if (!user?.canAccessFullAdminPanel || !user.canImpersonate)
          throw Error(
            "Native initial administrator privileges not established",
          );
        marker.userId = user.id;
      }
    }
    const workspace = (
      await database.query(
        'SELECT "isPublicInviteLinkEnabled","activationStatus" FROM core.workspace WHERE id=$1',
        [marker.workspaceId],
      )
    ).rows[0];
    const membership = (
      await database.query(
        'SELECT EXISTS(SELECT 1 FROM core."userWorkspace" WHERE "userId"=$1 AND "workspaceId"=$2) AS present',
        [marker.userId, marker.workspaceId],
      )
    ).rows[0].present;
    if (
      !workspace ||
      !membership ||
      workspace.isPublicInviteLinkEnabled ||
      !["ACTIVE", "CREATED"].includes(workspace.activationStatus)
    )
      throw Error("Retained workspace access policy or activation changed");
    fs.writeFileSync(markerPath, JSON.stringify(marker), { mode: 0o600 });
    await stop();
    fs.rmSync(log, { force: true });
    console.log(
      "Native administrator and active private workspace verified before public startup",
    );
  } else if (["server", "worker"].includes(mode)) {
    stage = "native " + mode + " startup";
    const current = start([
      mode === "server" ? "dist/main.js" : "dist/queue-worker/queue-worker.js",
    ]);
    if (mode === "worker")
      fs.writeFileSync("/tmp/helmforge-worker.pid", String(current.pid), {
        mode: 0o600,
      });
    for (const signal of ["SIGTERM", "SIGINT"])
      process.on(signal, () => {
        void stop();
      });
    process.exitCode = await new Promise((resolve, reject) => {
      current.once("error", reject);
      current.once("exit", (code, signal) =>
        resolve(code ?? (["SIGTERM", "SIGINT"].includes(signal) ? 0 : 1)),
      );
    });
  } else throw Error("Unsupported native launcher mode");
} catch (error) {
  if (mode === "bootstrap") {
    try {
      fs.appendFileSync(
        log,
        "\nInitializer failure: " + String(error.stack ?? error) + "\n",
        { mode: 0o600 },
      );
    } catch {}
  }
  console.error(
    "Twenty initialization failed during " +
      stage +
      "; inspect private diagnostics and retained dependency state",
  );
  await stop();
  process.exitCode = 1;
} finally {
  await database?.end().catch(() => {});
}
