// SPDX-License-Identifier: Apache-2.0
import fs from "node:fs";
import { createHash } from "node:crypto";
import { createRequire } from "node:module";
import { spawn } from "node:child_process";
import { admit } from "./admission.mjs";

process.umask(0o077);
const delay = (ms) => new Promise((resolve) => setTimeout(resolve, ms));
const native = "/app/apps/server/dist/index.mjs";
const mode = process.argv[2];
const bootstrapLog = "/tmp/helmforge-native-bootstrap.log";
const require = createRequire("/app/apps/server/package.json");
let child;
let admissionDatabase;
let stage = "configuration";
function configure() {
  if (process.env.HF_INITIAL_EMAIL)
    process.env.HF_INITIAL_EMAIL =
      process.env.HF_INITIAL_EMAIL.trim().toLowerCase();
  const url = new URL("postgresql://localhost");
  url.hostname = process.env.HF_DATABASE_HOST.includes(":")
    ? "[" + process.env.HF_DATABASE_HOST + "]"
    : process.env.HF_DATABASE_HOST;
  url.port = process.env.HF_DATABASE_PORT;
  url.username = encodeURIComponent(process.env.HF_DATABASE_USERNAME);
  url.password = encodeURIComponent(process.env.HF_DATABASE_PASSWORD);
  url.pathname = "/" + encodeURIComponent(process.env.HF_DATABASE_NAME);
  url.searchParams.set(
    "sslmode",
    process.env.HF_DATABASE_TLS === "true" ? "verify-full" : "disable",
  );
  if (process.env.HF_DATABASE_CA)
    url.searchParams.set("sslrootcert", process.env.HF_DATABASE_CA);
  process.env.DATABASE_URL = url.toString();
  process.env.PORT = "3010";
  process.env.FLAG_DISABLE_SIGNUPS = "true";
  process.env.FLAG_DISABLE_EMAIL_AUTH = "false";
  process.env.FLAG_DISABLE_API_RATE_LIMIT = "false";
  process.env.FLAG_ALLOW_UNSAFE_OAUTH_REDIRECT_URI = "false";
  process.env.FLAG_ALLOW_UNSAFE_AI_BASE_URL = "false";
  process.env.LOCAL_STORAGE_PATH = "/app/data";
  const caPaths = [
    process.env.HF_SMTP_CA,
    process.env.HF_S3_CA,
    process.env.HF_OAUTH_CA,
  ].filter(Boolean);
  if (caPaths.length) {
    const bundle = "/tmp/helmforge-additional-ca.pem";
    fs.writeFileSync(
      bundle,
      caPaths.map((path) => fs.readFileSync(path, "utf8")).join("\n"),
      { mode: 0o600 },
    );
    process.env.NODE_EXTRA_CA_CERTS = bundle;
  }
}
async function verifySmtp() {
  if (!process.env.SMTP_HOST) return;
  if (!process.env.SMTP_PASS) throw Error("SMTP requires a nonempty password");
  const transport = require("nodemailer").createTransport({
    host: process.env.SMTP_HOST,
    port: Number(process.env.SMTP_PORT),
    secure: true,
    auth: { user: process.env.SMTP_USER, pass: process.env.SMTP_PASS },
    connectionTimeout: 5000,
    greetingTimeout: 5000,
    socketTimeout: 10000,
    dnsTimeout: 5000,
    tls: {
      servername: process.env.SMTP_HOST,
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
function start(signups) {
  const env = {
    ...process.env,
    FLAG_DISABLE_SIGNUPS: signups ? "false" : "true",
  };
  // Bootstrap output may contain native verification links when SMTP is absent.
  // Keep that output private; application logs remain native during normal operation.
  const logFd =
    mode === "bootstrap" ? fs.openSync(bootstrapLog, "w", 0o600) : undefined;
  child = spawn(process.execPath, [native], {
    cwd: "/app",
    env,
    stdio: mode === "bootstrap" ? ["ignore", logFd, logFd] : "inherit",
  });
  if (logFd !== undefined) fs.closeSync(logFd);
  child.once("error", () => {
    console.error("Native server could not start");
  });
  return child;
}
async function stop() {
  const current = child;
  if (!current || current.exitCode !== null || current.signalCode !== null)
    return;
  const closed = new Promise((resolve) => current.once("exit", resolve));
  current.kill("SIGTERM");
  const timer = setTimeout(() => current.kill("SIGKILL"), 10000);
  try {
    await closed;
  } finally {
    clearTimeout(timer);
    child = undefined;
  }
}
async function healthy() {
  const deadline = Date.now() + 90000;
  while (Date.now() < deadline) {
    if (child.exitCode !== null || child.signalCode !== null)
      throw Error("Native startup or migrations failed");
    try {
      const response = await fetch("http://127.0.0.1:3010/api/health", {
        signal: AbortSignal.timeout(2000),
      });
      if (response.ok) return;
    } catch {}
    await delay(500);
  }
  throw Error("Native startup deadline exceeded");
}
async function authenticate(password) {
  const origin = new URL(process.env.APP_URL).origin;
  const response = await fetch("http://127.0.0.1:3010/api/auth/sign-in/email", {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
      Origin: origin,
      Referer: origin + "/auth/login",
    },
    body: JSON.stringify({
      email: process.env.HF_INITIAL_EMAIL,
      password,
      callbackURL: "/dashboard",
    }),
    signal: AbortSignal.timeout(10000),
  });
  if (!response.ok) throw Error("Native initial user authentication failed");
  const cookies = response.headers
    .getSetCookie()
    .map((value) => value.split(";")[0])
    .join("; ");
  if (!cookies) throw Error("Native authentication returned no session cookie");
  const session = await fetch("http://127.0.0.1:3010/api/auth/get-session", {
    headers: { Cookie: cookies, Origin: origin },
    signal: AbortSignal.timeout(10000),
  });
  if (!session.ok) throw Error("Native session verification failed");
  const identity = await session.json();
  if (
    identity.user?.email !== process.env.HF_INITIAL_EMAIL ||
    identity.user.role !== "user"
  )
    throw Error("Unexpected native authenticated identity");
  return identity.user.id;
}
try {
  if (mode === "bootstrap") {
    // Repeated on every init attempt in the same Pod network namespace.
    stage = "network isolation admission";
    await admit({
      key: fs.readFileSync("/admission-key/key"),
      helperHost: process.env.HF_ADMISSION_HOST,
    });
    configure();
    stage = "authenticated SMTP TLS admission";
    await verifySmtp();
    stage = "PostgreSQL admission";
    const { Client } = require("pg");
    let database;
    const connectionDeadline = Date.now() + 90000;
    while (Date.now() < connectionDeadline) {
      const candidate = new Client({
        connectionString: process.env.DATABASE_URL,
        connectionTimeoutMillis: 5000,
        query_timeout: 15000,
        statement_timeout: 15000,
      });
      try {
        await candidate.connect();
        database = candidate;
        admissionDatabase = candidate;
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
    if (!database) throw Error("PostgreSQL connection deadline exceeded");
    stage = "retained identity verification";
    const fingerprint = createHash("sha256")
      .update(process.env.AUTH_SECRET + "\0" + process.env.ENCRYPTION_SECRET)
      .digest("hex");
    const markerPath = "/app/data/.helmforge-identity.json";
    const table = await database.query(
      "SELECT to_regclass('public.\"user\"') IS NOT NULL AS present",
    );
    const count = table.rows[0].present
      ? Number(
          (await database.query('SELECT count(*) FROM public."user"')).rows[0]
            .count,
        )
      : 0;
    if (count) {
      if (!fs.existsSync(markerPath))
        throw Error(
          "Existing users require the retained identity marker; review migration or recovery",
        );
      const marker = JSON.parse(fs.readFileSync(markerPath, "utf8"));
      if (marker.fingerprint !== fingerprint)
        throw Error(
          "Retained authentication/encryption keys do not match the local identity marker",
        );
      const user = await database.query(
        'SELECT id,banned FROM public."user" WHERE id=$1',
        [marker.userId],
      );
      if (user.rows.length !== 1 || user.rows[0].banned === true)
        throw Error("Retained initial account is missing or banned");
      await database.end();
      stage = "native migrations with signup closed";
      start(false);
      await healthy();
      await stop();
      console.log("Existing native identity retained; signup remained closed");
    } else {
      if (fs.existsSync(markerPath))
        throw Error(
          "An empty database with an identity marker requires coordinated recovery",
        );
      await database.end();
      const password = fs.readFileSync("/bootstrap-auth/password", "utf8");
      if (
        [...password].length < 16 ||
        password.length > 64 ||
        Buffer.byteLength(password, "utf8") > 72
      )
        throw Error(
          "Initial password exceeds the native character or bcrypt byte limits",
        );
      stage = "private native startup and migrations";
      start(true);
      await healthy();
      stage = "private first-user enrollment";
      const origin = new URL(process.env.APP_URL).origin;
      const signup = await fetch(
        "http://127.0.0.1:3010/api/auth/sign-up/email",
        {
          method: "POST",
          headers: {
            "Content-Type": "application/json",
            Origin: origin,
            Referer: origin + "/auth/register",
          },
          body: JSON.stringify({
            name: process.env.HF_INITIAL_NAME,
            email: process.env.HF_INITIAL_EMAIL,
            password,
            username: process.env.HF_INITIAL_USERNAME,
            displayUsername: process.env.HF_INITIAL_USERNAME,
            callbackURL: "/dashboard",
          }),
          signal: AbortSignal.timeout(10000),
        },
      );
      if (!signup.ok) throw Error("Native first-user signup failed");
      stage = "private first-user authentication";
      const userId = await authenticate(password);
      stage = "retained identity publication";
      fs.writeFileSync(markerPath, JSON.stringify({ fingerprint, userId }), {
        flag: "wx",
        mode: 0o600,
      });
      await stop();
      console.log(
        "Native initial user and authenticated session verified before public proxy startup",
      );
    }
    // Native signup can emit token-bearing email links. Remove the private
    // diagnostic file before ordinary containers may start.
    fs.rmSync(bootstrapLog, { force: true });
  } else if (mode === "server") {
    stage = "native application startup";
    configure();
    const current = start(false);
    for (const signal of ["SIGTERM", "SIGINT"])
      process.on(signal, () => {
        current.kill(signal);
      });
    const code = await new Promise((resolve) =>
      current.once("exit", (code, signal) =>
        resolve(code ?? (["SIGTERM", "SIGINT"].includes(signal) ? 0 : 1)),
      ),
    );
    process.exitCode = code;
  } else throw Error("Unsupported native launcher mode");
} catch {
  // Report only chart-owned stage names: dependency errors can contain credentials.
  console.error(
    "Reactive Resume initialization failed during " +
      stage +
      "; inspect dependency health, isolation and retained identity before retrying",
  );
  await stop();
  process.exitCode = 1;
} finally {
  await admissionDatabase?.end().catch(() => {});
}
