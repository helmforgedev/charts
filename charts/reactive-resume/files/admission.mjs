// SPDX-License-Identifier: Apache-2.0
import http from "node:http";
import net from "node:net";
import { createHmac, randomBytes, timingSafeEqual } from "node:crypto";
import { lookup } from "node:dns/promises";
import { networkInterfaces } from "node:os";

const ports = { native: 3010, control: 3011 };
const sleep = (ms) => new Promise((resolve) => setTimeout(resolve, ms));
const mac = (key, body) => createHmac("sha256", key).update(body).digest("hex");
function authentic(key, body, signature) {
  if (typeof signature !== "string" || !/^[a-f0-9]{64}$/.test(signature))
    return false;
  return timingSafeEqual(
    Buffer.from(signature, "hex"),
    Buffer.from(mac(key, body), "hex"),
  );
}
async function body(request) {
  const chunks = [];
  let size = 0;
  for await (const chunk of request) {
    size += chunk.length;
    if (size > 1024) throw Error("Admission request too large");
    chunks.push(chunk);
  }
  return Buffer.concat(chunks).toString("utf8");
}
function request({
  host,
  port,
  path = "/",
  method = "GET",
  payload,
  headers = {},
  localAddress,
  timeout = 2000,
}) {
  return new Promise((resolve, reject) => {
    const req = http.request(
      {
        host,
        port,
        path,
        method,
        headers,
        localAddress,
        agent: false,
        signal: AbortSignal.timeout(timeout),
      },
      async (res) => {
        try {
          resolve({
            status: res.statusCode,
            body: await body(res),
            headers: res.headers,
          });
        } catch (error) {
          reject(error);
        }
      },
    );
    req.on("error", reject);
    req.end(payload);
  });
}
function reachable(host, port) {
  return new Promise((resolve, reject) => {
    const socket = net.connect({ host, port });
    socket.setTimeout(1000);
    socket.once("connect", () => {
      socket.destroy();
      resolve(true);
    });
    socket.once("timeout", () => {
      socket.destroy();
      resolve(false);
    });
    socket.once("error", (error) => {
      socket.destroy();
      if (
        ["ECONNREFUSED", "ETIMEDOUT", "EHOSTUNREACH", "ENETUNREACH"].includes(
          error.code,
        )
      )
        resolve(false);
      else reject(error);
    });
  });
}

// The helper cannot accept a destination URL, address, port or redirect.
// Its only target is the actual TCP caller and these two fixed listener ports.
export function createHelper(key) {
  if (key.length < 32)
    throw Error("Admission key must contain at least 32 bytes");
  let active = 0;
  return http.createServer(
    { requestTimeout: 5000, headersTimeout: 5000 },
    async (req, res) => {
      if (req.url === "/health" && req.method === "GET") {
        res.writeHead(200).end("ok");
        return;
      }
      if (req.url !== "/admit" || req.method !== "POST" || active >= 4) {
        res.writeHead(404).end();
        return;
      }
      active++;
      try {
        const raw = await body(req);
        if (!authentic(key, raw, req.headers["x-admission-mac"])) {
          res.writeHead(403).end();
          return;
        }
        const data = JSON.parse(raw);
        if (
          Object.keys(data).sort().join(",") !== "challenge,timestamp" ||
          !/^[a-f0-9]{64}$/.test(data.challenge) ||
          !Number.isSafeInteger(data.timestamp) ||
          Math.abs(Date.now() - data.timestamp) > 60000
        )
          throw Error("Invalid challenge");
        const host = req.socket.remoteAddress;
        if (!net.isIP(host)) throw Error("Expected TCP caller address");
        let admitted = true;
        for (let round = 0; round < 3; round++) {
          const control = await request({
            host,
            port: ports.control,
            path: "/" + data.challenge,
          });
          if (control.status !== 200 || control.body !== data.challenge)
            throw Error("Positive control failed");
          if (await reachable(host, ports.native)) {
            admitted = false;
            break;
          }
        }
        const reply = JSON.stringify({ challenge: data.challenge, admitted });
        res
          .writeHead(200, {
            "Content-Type": "application/json",
            "X-Admission-Mac": mac(key, reply),
          })
          .end(reply);
      } catch {
        if (!res.headersSent) res.writeHead(503);
        res.end();
      } finally {
        active--;
      }
    },
  );
}

export async function admit({
  key,
  helperHost,
  helperPort = 8088,
  timeout = 45000,
}) {
  if (key.length < 32)
    throw Error("Admission key must contain at least 32 bytes");
  const challenge = randomBytes(32).toString("hex");
  const listener = () =>
    http.createServer((req, res) => {
      if (req.url !== "/" + challenge) {
        res.writeHead(404).end();
        return;
      }
      res.writeHead(200, { "Content-Type": "text/plain" }).end(challenge);
    });
  const native = listener(),
    control = listener();
  const start = (server, port) =>
    new Promise((resolve, reject) => {
      server.once("error", reject);
      server.listen(port, resolve);
    });
  try {
    await start(native, ports.native);
    await start(control, ports.control);
    const ips = Object.values(networkInterfaces())
      .flat()
      .filter((ip) => !ip.internal && !ip.address.startsWith("fe80:"));
    const deadline = Date.now() + timeout;
    let destinations;
    while (Date.now() < deadline) {
      try {
        destinations = await lookup(helperHost, { all: true });
        break;
      } catch {
        await sleep(500);
      }
    }
    if (!destinations)
      throw Error("Admission helper DNS did not become available");
    const families = [
      ...new Set(ips.map((ip) => (ip.family === "IPv6" ? 6 : 4))),
    ];
    if (!families.length) throw Error("No ordinary Pod interface found");
    for (const family of families) {
      const target = destinations.find((item) => item.family === family);
      const source = ips.find(
        (item) => (item.family === "IPv6" ? 6 : 4) === family,
      );
      if (!target)
        throw Error("Helper Service must cover every Pod address family");
      let accepted = false,
        observedReachable = false;
      while (Date.now() < deadline) {
        const before = await request({
          host: "127.0.0.1",
          port: ports.native,
          path: "/" + challenge,
        });
        if (before.status !== 200 || before.body !== challenge)
          throw Error("Native positive local control failed");
        const payload = JSON.stringify({ challenge, timestamp: Date.now() });
        let result;
        try {
          result = await request({
            host: target.address,
            port: helperPort,
            path: "/admit",
            method: "POST",
            payload,
            localAddress: source.address,
            timeout: 15000,
            headers: {
              "Content-Type": "application/json",
              "X-Admission-Mac": mac(key, payload),
            },
          });
        } catch {
          await sleep(500);
          continue;
        }
        if (result.status === 503) {
          await sleep(500);
          continue;
        }
        if (
          result.status !== 200 ||
          !authentic(key, result.body, result.headers["x-admission-mac"])
        )
          throw Error("Authenticated helper unavailable");
        const reply = JSON.parse(result.body);
        const after = await request({
          host: "127.0.0.1",
          port: ports.native,
          path: "/" + challenge,
        });
        if (after.status !== 200 || after.body !== challenge)
          throw Error("Native listener stopped during admission");
        if (reply.challenge !== challenge)
          throw Error("Stale admission response");
        if (reply.admitted === true) {
          accepted = true;
          break;
        }
        if (reply.admitted === false) observedReachable = true;
        await sleep(1000);
      }
      if (!accepted)
        throw Error(
          observedReachable
            ? "Native port remains externally reachable; enrollment is closed"
            : "Isolation admission was not established; enrollment is closed",
        );
    }
  } finally {
    // Drop every harmless connection before the sensitive native process starts.
    for (const server of [native, control]) {
      server.closeAllConnections();
      if (server.listening)
        await new Promise((resolve, reject) =>
          server.close((error) => (error ? reject(error) : resolve())),
        );
    }
  }
}
