// SPDX-License-Identifier: Apache-2.0
import fs from "node:fs";
import { createRequire } from "node:module";
import { configure, nativeDirectory } from "./configure.mjs";
let redis, queue;
try {
  const pid = Number(fs.readFileSync("/tmp/helmforge-worker.pid", "utf8"));
  if (!Number.isInteger(pid) || pid < 2) throw Error("Worker pid unavailable");
  process.kill(pid, 0);
  if (process.argv[2] !== "live") {
    configure();
    const require = createRequire(nativeDirectory + "/package.json");
    const Redis = require("ioredis"),
      { Queue } = require("bullmq");
    redis = new Redis(process.env.REDIS_URL, {
      lazyConnect: true,
      connectTimeout: 2000,
      maxRetriesPerRequest: 1,
      retryStrategy: null,
      ...(process.env.HF_REDIS_TLS === "true"
        ? {
            tls: {
              servername: process.env.HF_REDIS_HOST,
              rejectUnauthorized: true,
              ...(process.env.HF_REDIS_CA
                ? { ca: fs.readFileSync(process.env.HF_REDIS_CA) }
                : {}),
            },
          }
        : {}),
    });
    redis.on("error", () => {});
    await redis.connect();
    if ((await redis.ping()) !== "PONG") throw Error("Redis unavailable");
    queue = new Queue("workspace-queue", { connection: redis });
    const workers = await queue.getWorkers();
    if (
      !workers.some(
        (worker) =>
          worker.addr?.startsWith(process.env.HF_POD_IP + ":") ||
          worker.addr?.startsWith("[" + process.env.HF_POD_IP + "]:"),
      )
    )
      throw Error("Current Pod worker registration unavailable");
  }
} catch {
  process.exitCode = 1;
} finally {
  await queue?.close().catch(() => {});
  redis?.disconnect();
}
