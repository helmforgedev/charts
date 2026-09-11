// SPDX-License-Identifier: Apache-2.0
import assert from "node:assert/strict";
import { spawn, execFileSync } from "node:child_process";
import { randomBytes } from "node:crypto";

const sleep = (ms) => new Promise((resolve) => setTimeout(resolve, ms));
async function mailbox(context, namespace, action) {
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
  graphql,
  base,
  origin,
  password,
}) {
  if (!values.smtp.enabled) return password;
  const script = `
 const assert=require('node:assert/strict'),fs=require('node:fs'),tls=require('node:tls');
 const nodemailer=require('node:module').createRequire('/app/packages/twenty-server/package.json')('nodemailer');
 const base={host:process.env.HF_SMTP_HOST,port:465,secure:true,auth:{user:process.env.EMAIL_SMTP_USER,pass:process.env.EMAIL_SMTP_PASSWORD},connectionTimeout:20000,greetingTimeout:20000,socketTimeout:20000,tls:{ca:fs.readFileSync(process.env.HF_SMTP_CA),servername:process.env.HF_SMTP_HOST,rejectUnauthorized:true}};
 const verify=async options=>{const client=nodemailer.createTransport(options);try{await client.verify()}finally{client.close()}};
 (async()=>{await verify(base);await assert.rejects(()=>verify({...base,tls:{...base.tls,ca:tls.rootCertificates}}),/certificate|issuer|self.signed/i);
 await assert.rejects(()=>verify({...base,host:process.env.HF_SMTP_HOST+'.${namespace}.svc',tls:{...base.tls,servername:process.env.HF_SMTP_HOST+'.${namespace}.svc'}}),/hostname|altnames|certificate/i);
 await assert.rejects(()=>verify({...base,auth:{...base.auth,pass:'wrong-owned-fixture'}}),error=>error.code==='EAUTH');await verify(base);console.log('PASS SMTP strict TLS and authentication');})().catch(error=>{console.error('SMTP fixture acceptance failed',JSON.stringify({name:error.name,code:error.code,actualCode:error.actual?.code,responseCode:error.responseCode}));process.exitCode=1});
 `;
  assert.match(
    k(["exec", pod(), "-c", "twenty", "--", "node", "-e", script]),
    /PASS SMTP strict TLS/,
  );
  const nextPassword = "Recovered-" + randomBytes(16).toString("hex"),
    email = values.bootstrap.email.trim().toLowerCase();
  await mailbox(context, namespace, async (mail) => {
    const seen = new Set(
      (await mail("/api/v1/messages")).messages.map((item) => item.ID),
    );
    const submitted = await graphql(
      base,
      "mutation($email:String!){emailPasswordResetLink(email:$email){success}}",
      { email },
      null,
    );
    assert.equal(submitted.emailPasswordResetLink.success, true);
    let message;
    const deadline = Date.now() + 20000;
    while (Date.now() < deadline) {
      const item = (await mail("/api/v1/messages")).messages.find(
        (item) =>
          !seen.has(item.ID) &&
          item.Subject === "Action Needed to Reset Password" &&
          item.To.some((address) => address.Address.toLowerCase() === email),
      );
      if (item) {
        message = await mail("/api/v1/message/" + item.ID);
        break;
      }
      await sleep(300);
    }
    assert.ok(
      message,
      "Native recovery email must arrive through the configured SMTP server",
    );
    assert.equal(message.Username, values.smtp.username);
    assert.equal(message.From.Address, values.smtp.from);
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
          url?.origin === origin && url.pathname.includes("reset-password"),
      );
    assert.ok(link, "Delivered native password recovery link is required");
    const resetToken =
      link.searchParams.get("passwordResetToken") ??
      link.pathname.match(/[a-f0-9]{64}/)?.[0];
    assert.match(resetToken ?? "", /^[a-f0-9]{64}$/);
    const query =
      "mutation($token:String!,$password:String!){updatePasswordViaResetToken(passwordResetToken:$token,newPassword:$password){success}}";
    assert.equal(
      (
        await graphql(
          base,
          query,
          { token: resetToken, password: nextPassword },
          null,
        )
      ).updatePasswordViaResetToken.success,
      true,
    );
    const replay = await graphql(
      base,
      query,
      { token: resetToken, password: nextPassword },
      null,
      "/metadata",
      true,
    );
    assert.ok(replay.errors?.length, "Recovery tokens must be single-use");
    const login =
      "mutation($email:String!,$password:String!){signIn(email:$email,password:$password){availableWorkspaces{availableWorkspacesForSignIn{id}}}}";
    const old = await graphql(
      base,
      login,
      { email, password },
      null,
      "/metadata",
      true,
    );
    assert.ok(old.errors?.length, "Old password must stop authenticating");
    const fresh = await graphql(
      base,
      login,
      { email, password: nextPassword },
      null,
    );
    assert.equal(
      fresh.signIn.availableWorkspaces.availableWorkspacesForSignIn.length,
      1,
    );
  });
  console.log(
    "PASS delivered native recovery email, one-use reset token, old-password rejection and recovered-password login",
  );
  return nextPassword;
}
