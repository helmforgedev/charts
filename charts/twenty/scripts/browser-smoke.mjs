// SPDX-License-Identifier: Apache-2.0
import assert from "node:assert/strict";
import fs from "node:fs";
import http from "node:http";
import https from "node:https";
import { createHash, X509Certificate } from "node:crypto";
import { chromium } from "playwright";

export async function browserSmoke({
  base,
  origin,
  email,
  password,
  marker,
  companyId,
}) {
  assert.equal(origin, "https://crm.example.test:18446");
  const cert = fs.readFileSync(new URL("../ci/tls/tls.crt", import.meta.url));
  const key = fs.readFileSync(new URL("../ci/tls/tls.key", import.meta.url));
  const certificate = new X509Certificate(cert);
  assert.equal(certificate.checkHost("crm.example.test"), "crm.example.test");
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
    server.listen(18446, "127.0.0.1", resolve);
  });
  let browser, page;
  try {
    browser = await chromium.launch({
      headless: true,
      args: [
        "--no-proxy-server",
        "--host-resolver-rules=MAP crm.example.test 127.0.0.1",
        "--ignore-certificate-errors-spki-list=" + pin,
      ],
    });
    const context = await browser.newContext({ locale: "en-US" });
    page = await context.newPage();
    page.setDefaultTimeout(20000);
    await page.goto(origin + "/welcome", { waitUntil: "domcontentloaded" });
    assert.equal(await page.evaluate(() => window.isSecureContext), true);
    const emailButton = page.getByRole("button", {
      name: "Continue with Email",
      exact: true,
    });
    const emailField = page.getByPlaceholder("Email", { exact: true });
    await emailButton.or(emailField).first().waitFor({ state: "visible" });
    if (await emailButton.isVisible()) await emailButton.click();
    await emailField.fill(email);
    await page.getByRole("button", { name: "Continue", exact: true }).click();
    await page.getByPlaceholder("Password", { exact: true }).fill(password);
    await page.getByRole("button", { name: "Sign in", exact: true }).click();
    const deadline = Date.now() + 25000;
    let secureSession = false;
    while (Date.now() < deadline) {
      secureSession = (await context.cookies(origin)).some(
        (cookie) =>
          cookie.name.toLowerCase().includes("session") &&
          cookie.secure &&
          cookie.httpOnly,
      );
      if (secureSession) break;
      await new Promise((resolve) => setTimeout(resolve, 300));
    }
    assert.ok(
      secureSession,
      "Native HTTPS browser session must use a secure HttpOnly cookie",
    );
    const record = page.getByText(marker, { exact: true }).first();
    const first = page.getByLabel("First Name", { exact: true });
    const noSync = page.getByText("Continue without sync", { exact: true });
    const finish = page.getByRole("button", { name: "Finish", exact: true });
    const skip = page.getByRole("button", { name: "Skip", exact: true });
    for (let step = 0; step < 8; step++) {
      await page.goto(origin + "/object/company/" + companyId, {
        waitUntil: "domcontentloaded",
      });
      await record
        .or(first)
        .or(noSync)
        .or(finish)
        .or(skip)
        .first()
        .waitFor({ state: "visible", timeout: 25000 });
      if (await record.isVisible()) break;
      const currentPath = new URL(page.url()).pathname;
      if (await first.isVisible()) {
        await first.fill("HelmForge");
        await page
          .getByLabel("Last name", { exact: true })
          .fill("Administrator");
        await page
          .getByRole("button", { name: "Continue", exact: true })
          .click();
      } else if (await noSync.isVisible()) await noSync.click();
      else if (await finish.isVisible()) await finish.click();
      else if (await skip.isVisible()) await skip.click();
      else
        assert.fail(
          "Expected native onboarding step or authenticated company record",
        );
      await page.waitForURL((url) => url.pathname !== currentPath, {
        timeout: 20000,
      });
    }
    await record.waitFor({ state: "visible", timeout: 20000 });
    await page.reload({ waitUntil: "domcontentloaded" });
    await page
      .getByText(marker, { exact: true })
      .first()
      .waitFor({ state: "visible", timeout: 20000 });
    console.log(
      "PASS actual HTTPS browser login, secure HttpOnly session and retained CRM company in the native record page",
    );
  } catch (error) {
    if (page) {
      const body = await page
        .locator("body")
        .innerText({ timeout: 3000 })
        .catch(() => "unavailable");
      console.error(
        "Browser failure:",
        new URL(page.url()).pathname,
        body.replaceAll(password, "[redacted]").slice(0, 2500),
      );
    }
    throw error;
  } finally {
    if (browser) await browser.close();
    server.closeAllConnections();
    await new Promise((resolve) => server.close(resolve));
  }
}
