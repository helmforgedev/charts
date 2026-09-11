// SPDX-License-Identifier: Apache-2.0
import fs from "node:fs";
export const nativeDirectory = "/app/packages/twenty-server";
export function configure() {
  const database = new URL("postgresql://localhost");
  database.hostname = process.env.HF_DATABASE_HOST.includes(":")
    ? "[" + process.env.HF_DATABASE_HOST + "]"
    : process.env.HF_DATABASE_HOST;
  database.port = process.env.HF_DATABASE_PORT;
  database.username = encodeURIComponent(process.env.HF_DATABASE_USERNAME);
  database.password = encodeURIComponent(process.env.HF_DATABASE_PASSWORD);
  database.pathname = "/" + encodeURIComponent(process.env.HF_DATABASE_NAME);
  database.searchParams.set(
    "sslmode",
    process.env.HF_DATABASE_TLS === "true" ? "verify-full" : "disable",
  );
  if (process.env.HF_DATABASE_CA)
    database.searchParams.set("sslrootcert", process.env.HF_DATABASE_CA);
  process.env.PG_DATABASE_URL = database.toString();
  const redis = new URL(
    process.env.HF_REDIS_TLS === "true"
      ? "rediss://localhost"
      : "redis://localhost",
  );
  redis.hostname = process.env.HF_REDIS_HOST.includes(":")
    ? "[" + process.env.HF_REDIS_HOST + "]"
    : process.env.HF_REDIS_HOST;
  redis.port = process.env.HF_REDIS_PORT;
  redis.username = encodeURIComponent(
    process.env.HF_REDIS_USERNAME || "default",
  );
  redis.password = encodeURIComponent(process.env.HF_REDIS_PASSWORD);
  redis.pathname = "/" + process.env.HF_REDIS_DATABASE;
  process.env.REDIS_URL = redis.toString();
  Object.assign(process.env, {
    NODE_PORT: "3010",
    IS_CONFIG_VARIABLES_IN_DB_ENABLED: "false",
    IS_MULTIWORKSPACE_ENABLED: "false",
    IS_WORKSPACE_CREATION_LIMITED_TO_SERVER_ADMINS: "true",
    AUTH_PASSWORD_ENABLED: "true",
    SIGN_IN_PREFILLED: "false",
    IS_EMAIL_VERIFICATION_REQUIRED: "false",
    IS_FDW_ENABLED: "false",
    TELEMETRY_ENABLED: "false",
    STORAGE_TYPE: process.env.HF_STORAGE_DRIVER || "local",
    STORAGE_LOCAL_PATH: "/app/data/storage",
    STORAGE_S3_PRESIGNED_URL_ENABLED: "false",
    // LOGGER includes recovery links in logs. Disabled email uses a refused
    // loopback SMTP transport; operators must enable verified SMTP for recovery.
    EMAIL_DRIVER: "SMTP",
    EMAIL_SMTP_HOST:
      process.env.HF_SMTP_ENABLED === "true"
        ? process.env.HF_SMTP_HOST
        : "127.0.0.1",
    EMAIL_SMTP_PORT: "465",
    EMAIL_SMTP_NO_TLS: "false",
    METER_DRIVER:
      process.argv[2] === "server" && process.env.HF_METRICS_ENABLED === "true"
        ? "prometheus"
        : "",
    OTEL_SERVICE_NAME:
      process.argv[2] === "worker" ? "twenty-worker" : "twenty-server",
    DISABLE_DB_MIGRATIONS: "true",
    DISABLE_CRON_JOBS_REGISTRATION: "true",
  });
  const caPaths = [
    process.env.HF_REDIS_CA,
    process.env.HF_S3_CA,
    process.env.HF_SMTP_CA,
  ].filter(Boolean);
  if (caPaths.length) {
    const bundle = "/tmp/helmforge-additional-ca.pem";
    const content = caPaths
      .map((path) => fs.readFileSync(path, "utf8"))
      .join("\n");
    if (!fs.existsSync(bundle) || fs.readFileSync(bundle, "utf8") !== content) {
      const temporary = bundle + "." + process.pid;
      fs.writeFileSync(temporary, content, { mode: 0o600 });
      fs.renameSync(temporary, bundle);
    }
    process.env.NODE_EXTRA_CA_CERTS = bundle;
  }
  if (Buffer.from(process.env.ENCRYPTION_KEY || "", "base64").length !== 32)
    throw Error("Retained encryption key must encode 32 bytes");
  if (
    !/^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i.test(
      process.env.SERVER_ID || "",
    )
  )
    throw Error("Retained server ID must be a UUID v4");
}
