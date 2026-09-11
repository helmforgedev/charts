// SPDX-License-Identifier: Apache-2.0
import assert from "node:assert/strict";
import { spawn, execFileSync } from "node:child_process";
import { randomBytes } from "node:crypto";

const sleep = (ms) => new Promise((resolve) => setTimeout(resolve, ms));
export async function mailbox(context, namespace, action) {
  const pf = spawn(
    "kubectl",
    [
      "--context",
      context,
      "-n",
      namespace,
      "port-forward",
      "service/fixture-integrations",
      "0:8025",
      "--address=127.0.0.1",
    ],
    { windowsHide: true, stdio: ["ignore", "pipe", "pipe"] },
  );
  let output = "";
  for (const stream of [pf.stdout, pf.stderr])
    stream.on("data", (chunk) => (output += chunk));
  try {
    const deadline = Date.now() + 15000;
    while (
      !/Forwarding from/.test(output) &&
      Date.now() < deadline &&
      pf.exitCode === null
    )
      await sleep(100);
    const port = output.match(/127\.0\.0\.1:(\d+)/)?.[1];
    assert.ok(port, "Owned mailbox port-forward did not start");
    await action(async (path) => {
      const response = await fetch("http://127.0.0.1:" + port + path, {
        signal: AbortSignal.timeout(5000),
      });
      assert.equal(response.status, 200, "Owned Mailpit API unavailable");
      return response.json();
    });
  } finally {
    if (pf.exitCode === null && pf.signalCode === null) {
      if (process.platform === "win32")
        execFileSync("taskkill", ["/PID", String(pf.pid), "/T", "/F"], {
          stdio: "ignore",
        });
      else pf.kill();
    }
  }
}

export async function smtpSmoke({
  context,
  namespace,
  values,
  k,
  pod,
  request,
  login,
  password,
  origin,
}) {
  assert.equal(context, "k3d-helmforge-tests-wsl");
  if (!values.smtp.enabled) return;
  const nativeCheck = `
  const assert=require('node:assert/strict'),fs=require('node:fs'),tls=require('node:tls');
  const nodemailer=require('node:module').createRequire('/app/apps/server/package.json')('nodemailer');
  const base={host:process.env.SMTP_HOST,port:Number(process.env.SMTP_PORT),secure:true,
   auth:{user:process.env.SMTP_USER,pass:process.env.SMTP_PASS},connectionTimeout:20000,greetingTimeout:20000,socketTimeout:20000,
   tls:{ca:fs.readFileSync(process.env.HF_SMTP_CA),servername:process.env.SMTP_HOST,rejectUnauthorized:true}};
  const verify=async options=>{const transport=nodemailer.createTransport(options);try{await transport.verify()}finally{transport.close()}};
  (async()=>{
   await verify(base);
   await assert.rejects(()=>verify({...base,tls:{...base.tls,ca:tls.rootCertificates.join(String.fromCharCode(10))}}),e=>/certificate|self.signed|CERT_|unable to verify/i.test(e.message+' '+e.code));
   await assert.rejects(()=>verify({...base,tls:{...base.tls,servername:'wrong.fixture.invalid'}}),e=>/hostname|altname|CERT_ALTNAME/i.test(e.message+' '+e.code));
   await assert.rejects(()=>verify({...base,auth:{...base.auth,pass:'wrong-owned-fixture'}}),e=>e.code==='EAUTH');
   await verify(base);
   console.log('PASS authenticated SMTP TLS and rejection of unknown CA, incorrect hostname and incorrect password');
  })().catch(error=>{console.error('Native SMTP certificate/authentication acceptance failed: '+String(error.message).replaceAll(process.env.SMTP_PASS||'unused-secret','[REDACTED]'));process.exitCode=1});
 `;
  assert.match(
    k([
      "exec",
      pod(),
      "-c",
      "reactive-resume",
      "--",
      "node",
      "-e",
      nativeCheck,
    ]),
    /PASS authenticated SMTP TLS/,
  );
  const email = values.bootstrap.email.trim().toLowerCase();
  await mailbox(context, namespace, async (mail) => {
    const consumed = new Set(
      (await mail("/api/v1/messages")).messages.map((item) => item.ID),
    );
    async function reset(nextPassword) {
      const submitted = await request("/api/auth/request-password-reset", {
        method: "POST",
        anonymous: true,
        json: { email, redirectTo: origin + "/auth/reset-password" },
      });
      assert.equal(
        submitted.status,
        200,
        "Native password recovery request failed",
      );
      let message;
      const deadline = Date.now() + 20000;
      while (Date.now() < deadline) {
        const listing = await mail("/api/v1/messages");
        const item = listing.messages.find(
          (item) =>
            !consumed.has(item.ID) &&
            item.Subject === "Reset your password" &&
            item.To.some((address) => address.Address.toLowerCase() === email),
        );
        if (item) {
          message = await mail("/api/v1/message/" + item.ID);
          consumed.add(item.ID);
          break;
        }
        await sleep(300);
      }
      assert.ok(
        message,
        "Native recovery email must actually arrive through authenticated SMTP",
      );
      assert.equal(
        message.Username,
        values.smtp.username,
        "Message must use the configured SMTP identity",
      );
      assert.equal(message.From.Address, "noreply@example.test");
      const links = [...message.HTML.matchAll(/href=["']([^"']+)["']/g)].map(
        (match) => match[1].replaceAll("&amp;", "&"),
      );
      const link = links
        .map((value) => {
          try {
            return new URL(value);
          } catch {
            return null;
          }
        })
        .find(
          (url) =>
            url?.origin === origin &&
            url.pathname.startsWith("/api/auth/reset-password/"),
        );
      assert.ok(
        link,
        "Delivered email must contain the native recovery callback",
      );
      const callback = await request(link.pathname + link.search, {
        anonymous: true,
      });
      assert.ok(
        [302, 303, 307].includes(callback.status),
        "Native recovery callback must redirect",
      );
      const target = new URL(callback.headers.get("location"), origin);
      assert.equal(target.origin, origin);
      assert.equal(target.pathname, "/auth/reset-password");
      const token = target.searchParams.get("token");
      assert.ok(token, "Native callback must validate its recovery token");
      const changed = await request("/api/auth/reset-password", {
        method: "POST",
        anonymous: true,
        json: { token, newPassword: nextPassword },
      });
      assert.equal(
        changed.status,
        200,
        "Delivered native recovery token must change the password",
      );
      const replay = await request("/api/auth/reset-password", {
        method: "POST",
        anonymous: true,
        json: { token, newPassword: nextPassword },
      });
      assert.equal(
        replay.status,
        400,
        "A consumed recovery token must not be reusable",
      );
    }
    const temporary = "Changed-" + randomBytes(12).toString("hex");
    await reset(temporary);
    assert.equal(
      (
        await request("/api/auth/sign-in/email", {
          method: "POST",
          anonymous: true,
          json: { email, password },
        })
      ).status,
      401,
      "Previous password must stop authenticating",
    );
    const newLogin = await request("/api/auth/sign-in/email", {
      method: "POST",
      anonymous: true,
      json: { email, password: temporary },
    });
    assert.equal(
      newLogin.status,
      200,
      "Recovered password must authenticate natively",
    );
    await reset(password);
    await login(request);
  });
  console.log(
    "PASS native delivered recovery email, consumed-token replay denial and password recovery through verified SMTP TLS",
  );
}
