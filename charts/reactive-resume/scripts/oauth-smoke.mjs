// SPDX-License-Identifier: Apache-2.0
import assert from "node:assert/strict";
import { mailbox } from "./smtp-smoke.mjs";

export async function oauthSmoke({
  context,
  namespace,
  values,
  k,
  pod,
  base,
  origin,
  password,
}) {
  if (!values.oauth.enabled) return;
  const providerPod = JSON.parse(
    k(["get", "pods", "-l", "app=fixture-oauth", "-o", "json"]),
  ).items[0].metadata.name;
  const select = (subject) =>
    k([
      "exec",
      providerPod,
      "--",
      "node",
      "-e",
      "fetch('http://127.0.0.1:8081/subject?sub=" +
        subject +
        "').then(r=>{if(!r.ok)process.exitCode=1});",
    ]);
  const jar = new Map();
  const call = async (path, json) => {
    const response = await fetch(base + path, {
      method: json ? "POST" : "GET",
      redirect: "manual",
      signal: AbortSignal.timeout(10000),
      headers: {
        Origin: origin,
        Referer: origin + "/auth/login",
        Cookie: [...jar].map(([key, value]) => key + "=" + value).join("; "),
        ...(json ? { "Content-Type": "application/json" } : {}),
      },
      body: json ? JSON.stringify(json) : undefined,
    });
    for (const cookie of response.headers.getSetCookie()) {
      const pair = cookie.split(";")[0],
        separator = pair.indexOf("=");
      jar.set(pair.slice(0, separator), pair.slice(separator + 1));
    }
    return response;
  };
  const authorize = (url) => {
    const parsed = new URL(url);
    assert.equal(parsed.origin, "https://fixture-oauth:8443");
    assert.equal(parsed.searchParams.get("code_challenge_method"), "S256");
    assert.ok(parsed.searchParams.get("state"));
    const script = `const https=require('node:https'),fs=require('node:fs');const req=https.get(${JSON.stringify(url)},{ca:fs.readFileSync('/oauth-ca/ca.crt'),rejectUnauthorized:true,timeout:5000},r=>{r.resume();if(r.statusCode!==302){process.exitCode=1;return;}console.log(r.headers.location)});req.on('error',()=>{process.exitCode=1});req.on('timeout',()=>req.destroy());`;
    const callback = new URL(
      k([
        "exec",
        pod(),
        "-c",
        "reactive-resume",
        "--",
        "node",
        "-e",
        script,
      ]).trim(),
    );
    assert.equal(callback.origin, origin);
    assert.equal(callback.pathname, "/api/auth/callback/custom");
    return callback;
  };
  const begin = async (link = false) => {
    const response = await call(
      link ? "/api/auth/link-social" : "/api/auth/sign-in/social",
      {
        provider: "custom",
        callbackURL: origin + "/dashboard",
        disableRedirect: true,
      },
    );
    assert.equal(response.status, 200, "Native OAuth authorization must start");
    return authorize((await response.json()).url);
  };
  const finish = (callback) => call(callback.pathname + callback.search);
  const identity = async () => {
    const response = await call("/api/auth/get-session");
    assert.equal(response.status, 200);
    return (await response.json())?.user;
  };
  const succeeded = (response) => {
    assert.ok([302, 303].includes(response.status));
    const url = new URL(response.headers.get("location"), origin);
    assert.equal(url.origin, origin);
    assert.equal(
      url.pathname,
      "/dashboard",
      "Native OAuth callback failed with code " +
        (url.searchParams.get("error") ?? "unspecified").replace(
          /[^a-zA-Z0-9_-]/g,
          "",
        ),
    );
    assert.equal(url.searchParams.has("error"), false);
  };
  select("hf-admin");
  const login = await call("/api/auth/sign-in/email", {
    email: values.bootstrap.email,
    password,
  });
  assert.equal(login.status, 200);
  const original = await identity();
  assert.ok(original?.id);
  if (!original.emailVerified) {
    assert.equal(
      values.smtp.enabled,
      true,
      "Native custom-provider linking requires a verified local email; configure SMTP to complete verification",
    );
    await mailbox(context, namespace, async (mail) => {
      const seen = new Set(
        (await mail("/api/v1/messages")).messages.map((item) => item.ID),
      );
      const sent = await call("/api/auth/send-verification-email", {
        email: original.email,
        callbackURL: origin + "/dashboard",
      });
      assert.equal(sent.status, 200);
      let message;
      const deadline = Date.now() + 20000;
      while (Date.now() < deadline) {
        const item = (await mail("/api/v1/messages")).messages.find(
          (item) =>
            !seen.has(item.ID) &&
            item.Subject === "Verify your email" &&
            item.To.some(
              (address) => address.Address.toLowerCase() === original.email,
            ),
        );
        if (item) {
          message = await mail("/api/v1/message/" + item.ID);
          break;
        }
        await new Promise((resolve) => setTimeout(resolve, 300));
      }
      assert.ok(
        message,
        "Native verification email must be delivered before linking",
      );
      assert.equal(message.Username, values.smtp.username);
      const link = [...message.HTML.matchAll(/href=["']([^"']+)["']/g)]
        .map((match) => {
          try {
            return new URL(match[1].replaceAll("&amp;", "&"));
          } catch {
            return null;
          }
        })
        .find(
          (url) =>
            url?.origin === origin && url.pathname === "/api/auth/verify-email",
        );
      assert.ok(
        link,
        "Delivered native email-verification callback is required",
      );
      const confirmed = await call(link.pathname + link.search);
      assert.ok([200, 302, 303].includes(confirmed.status));
      assert.equal((await identity()).emailVerified, true);
      console.log(
        "PASS native email verification through delivered authenticated SMTP before OAuth linking",
      );
    });
  }
  succeeded(await finish(await begin(true)));
  jar.clear();
  const tampered = await begin();
  tampered.searchParams.set("state", "invalid-owned-state");
  await finish(tampered);
  assert.equal(
    await identity(),
    undefined,
    "Incorrect OAuth state must not create a session",
  );
  jar.clear();
  const valid = await begin();
  const stateCookies = new Map(jar);
  succeeded(await finish(valid));
  assert.equal((await identity()).id, original.id);
  jar.clear();
  for (const [key, value] of stateCookies) jar.set(key, value);
  await finish(valid);
  assert.equal(
    await identity(),
    undefined,
    "Replayed callback must not create a session",
  );
  select("hf-new");
  jar.clear();
  const rejectedSignup = await finish(await begin());
  assert.ok([302, 303].includes(rejectedSignup.status));
  const rejectionCode = new URL(
    rejectedSignup.headers.get("location"),
    origin,
  ).searchParams.get("error");
  assert.match(
    rejectionCode ?? "",
    /signup.*disabled|sign_up.*disabled/i,
    "Native signup policy must cause the new-provider-identity rejection",
  );
  assert.equal(
    await identity(),
    undefined,
    "OAuth signup must stay closed for a new subject",
  );
  select("hf-admin");
  jar.clear();
  const tls = `const assert=require('node:assert/strict'),https=require('node:https'),fs=require('node:fs');const ca=fs.readFileSync('/oauth-ca/ca.crt');const get=options=>new Promise((resolve,reject)=>{const req=https.get('https://fixture-oauth:8443/health',{rejectUnauthorized:true,timeout:4000,...options},r=>{r.resume();resolve(r.statusCode)});req.on('error',reject);req.on('timeout',()=>req.destroy(Error('timeout')));});(async()=>{assert.equal(await get({ca}),200);await assert.rejects(()=>get({}),/certificate|issuer|self.signed/i);await assert.rejects(()=>get({ca,servername:'wrong-host.example.test'}),/hostname|altnames|certificate/i);assert.equal(await get({ca}),200);console.log('PASS OAuth strict TLS')})().catch(()=>{console.error('OAuth TLS acceptance failed');process.exitCode=1});`;
  assert.match(
    k(["exec", pod(), "-c", "reactive-resume", "--", "node", "-e", tls]),
    /PASS OAuth strict TLS/,
  );
  console.log(
    "PASS native OAuth linking and stable subject login with S256, state/replay/new-user rejection and strict TLS",
  );
}
