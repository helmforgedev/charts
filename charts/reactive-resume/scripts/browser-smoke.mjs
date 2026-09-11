// SPDX-License-Identifier: Apache-2.0
import assert from "node:assert/strict";
import fs from "node:fs";
import http from "node:http";
import https from "node:https";
import { createHash, X509Certificate } from "node:crypto";
import { chromium } from "playwright";
import { getDocument } from "pdfjs-dist/legacy/build/pdf.mjs";

export async function browserSmoke({
  base,
  origin,
  email,
  password,
  resumeId,
}) {
  assert.equal(origin, "https://resume.example.test:18445");
  const cert = fs.readFileSync(new URL("../ci/tls/tls.crt", import.meta.url));
  const key = fs.readFileSync(new URL("../ci/tls/tls.key", import.meta.url));
  const certificate = new X509Certificate(cert);
  assert.equal(
    certificate.checkHost("resume.example.test"),
    "resume.example.test",
  );
  const pin = createHash("sha256")
    .update(certificate.publicKey.export({ type: "spki", format: "der" }))
    .digest("base64");
  const server = https.createServer({ cert, key }, (request, response) => {
    const upstream = http.request(
      new URL(request.url, base),
      {
        method: request.method,
        headers: {
          ...request.headers,
          host: new URL(origin).host,
          "x-forwarded-proto": "https",
        },
      },
      (reply) => {
        response.writeHead(reply.statusCode, reply.headers);
        reply.pipe(response);
      },
    );
    upstream.on("error", () => {
      if (!response.headersSent) response.writeHead(502);
      response.end();
    });
    request.pipe(upstream);
  });
  await new Promise((resolve, reject) => {
    server.once("error", reject);
    server.listen(18445, "127.0.0.1", resolve);
  });
  let browser;
  try {
    browser = await chromium.launch({
      headless: true,
      args: [
        "--no-proxy-server",
        "--host-resolver-rules=MAP resume.example.test 127.0.0.1",
        "--ignore-certificate-errors-spki-list=" + pin,
      ],
    });
    const context = await browser.newContext({ locale: "en-US" });
    const page = await context.newPage();
    page.setDefaultTimeout(20000);
    await page.goto(origin + "/auth/login", { waitUntil: "domcontentloaded" });
    assert.equal(await page.evaluate(() => window.isSecureContext), true);
    await page
      .getByRole("textbox", { name: "Email Address", exact: true })
      .fill(email);
    await page.getByLabel("Password", { exact: true }).fill(password);
    await Promise.all([
      page.waitForURL((url) => url.pathname.startsWith("/dashboard")),
      page.getByRole("button", { name: "Sign in", exact: true }).click(),
    ]);
    const cookies = await context.cookies(origin);
    assert.ok(
      cookies.some(
        (cookie) =>
          cookie.name.includes("session_token") &&
          cookie.secure &&
          cookie.httpOnly,
      ),
    );
    await page.goto(origin + "/builder/" + resumeId, {
      waitUntil: "domcontentloaded",
    });
    await page
      .getByRole("button", { name: "Export", exact: true })
      .first()
      .click();
    await page
      .getByRole("button", { name: "Choose PDF, DOCX, Markdown, or JSON" })
      .click();
    const pending = page.waitForEvent("download", { timeout: 45000 });
    await page
      .getByRole("button", { name: "Download PDF", exact: true })
      .click();
    const download = await pending;
    assert.equal(await download.failure(), null);
    const stream = await download.createReadStream();
    const chunks = [];
    for await (const chunk of stream) chunks.push(chunk);
    const bytes = Buffer.concat(chunks);
    assert.equal(bytes.subarray(0, 5).toString(), "%PDF-");
    const task = getDocument({
      data: new Uint8Array(bytes),
      isEvalSupported: false,
      useSystemFonts: true,
    });
    try {
      const doc = await task.promise;
      let text = "";
      for (let index = 1; index <= doc.numPages; index++)
        text += (await (await doc.getPage(index)).getTextContent()).items
          .map((item) => item.str ?? "")
          .join(" ");
      assert.match(text, /HELMFORGE PDF MARKER/);
    } finally {
      await task.destroy();
    }
    console.log(
      "PASS real HTTPS browser login, secure session cookie and native browser PDF download content",
    );
  } finally {
    if (browser) await browser.close();
    server.closeAllConnections();
    await new Promise((resolve) => server.close(resolve));
  }
}
