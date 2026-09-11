// SPDX-License-Identifier: Apache-2.0
import test from "node:test";
import assert from "node:assert/strict";
import http from "node:http";
import { createHmac, randomBytes } from "node:crypto";
import { createHelper } from "../files/admission.mjs";
const key = randomBytes(32),
  challenge = randomBytes(32).toString("hex");
const sign = (body) => createHmac("sha256", key).update(body).digest("hex");
const listen = (server, port = 0) =>
  new Promise((resolve, reject) => {
    server.once("error", reject);
    server.listen(port, "127.0.0.1", resolve);
  });
const close = (server) =>
  new Promise((resolve) => {
    server.closeAllConnections();
    server.close(resolve);
  });
test("admission helper requires authenticated fixed-target requests and rejects a reachable native listener", async () => {
  const helper = createHelper(key);
  const control = http.createServer((req, res) => res.end(req.url.slice(1)));
  const native = http.createServer((req, res) => res.end("harmless"));
  await listen(helper);
  await listen(control, 3011);
  await listen(native, 3010);
  const url = "http://127.0.0.1:" + helper.address().port + "/admit";
  const post = (data, signature) =>
    fetch(url, {
      method: "POST",
      body: data,
      headers: { "X-Admission-Mac": signature ?? sign(data) },
      signal: AbortSignal.timeout(10000),
    });
  try {
    const data = JSON.stringify({ challenge, timestamp: Date.now() });
    assert.equal((await post(data, "0".repeat(64))).status, 403);
    assert.equal(
      (
        await post(
          JSON.stringify({
            challenge,
            timestamp: Date.now(),
            url: "http://example.invalid/",
          }),
        )
      ).status,
      503,
    );
    assert.equal(
      (
        await post(
          JSON.stringify({ challenge, timestamp: Date.now() - 120000 }),
        )
      ).status,
      503,
    );
    const result = await post(data);
    assert.equal(result.status, 200);
    const raw = await result.text();
    assert.equal(result.headers.get("x-admission-mac"), sign(raw));
    assert.deepEqual(JSON.parse(raw), { challenge, admitted: false });
  } finally {
    await close(native);
    await close(control);
    await close(helper);
  }
});
test("a missing positive control cannot authorize admission", async () => {
  const helper = createHelper(key);
  await listen(helper);
  try {
    const data = JSON.stringify({ challenge, timestamp: Date.now() });
    const result = await fetch(
      "http://127.0.0.1:" + helper.address().port + "/admit",
      {
        method: "POST",
        body: data,
        headers: { "X-Admission-Mac": sign(data) },
        signal: AbortSignal.timeout(10000),
      },
    );
    assert.equal(result.status, 503);
  } finally {
    await close(helper);
  }
});
