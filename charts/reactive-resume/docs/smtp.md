# Authenticated SMTP and account recovery

The k3d acceptance profile verified actual delivery, native password reset,
single-use tokens, rejection of the old password and subsequent login. It also
requires certificate, hostname and credential failures to be rejected distinctly.

## Native transport

Enable `smtp.enabled` and provide a certificate-matching DNS hostname, implicit
TLS port, sender, username and existing password Secret. The default port is 465.
The chart sets native `SMTP_SECURE=true` and verifies the connection, certificate
and authentication during initialization. It does not grant credentials to the
network-admission helper or proxy container.

The upstream environment contract exposes opportunistic STARTTLS but not a
`requireTLS` option. This chart therefore supports implicit TLS rather than
presenting opportunistic STARTTLS as enforced encryption. Certificate validation
cannot be disabled through the managed values contract.

`smtp.tls.caSecret` optionally supplies an additional PEM CA bundle. Native Node
loads it as additional TLS trust for the application process, including other
HTTPS clients in that process. It is not a separate SMTP-only trust store.
Certificate hostname verification remains enabled. Permit the actual SMTP
destination and port through `networkPolicy.extraEgress`.

## Delivery behavior

Native Reactive Resume catches mail-send errors, so a successful HTTP recovery
request alone does not prove delivery. The acceptance profile uses an owned,
authenticated Mailpit server with TLS. It requests a native recovery email,
retrieves the delivered message, follows the native callback and changes the
password using its token. It also checks token replay rejection and authenticates
with the recovered password before restoring the owned fixture password.

The same profile tests an untrusted CA, a mismatched TLS hostname and an incorrect
SMTP password. A successful SMTP verify only proves connection/authentication;
message arrival and native account recovery are separate assertions.

When SMTP is disabled, the proxy blocks password-reset requests, verification-email
requests and email changes. This prevents the upstream no-SMTP fallback from
publishing new token-bearing email links in application logs. Private bootstrap
diagnostics are handled separately as described in [onboarding](onboarding.md).

## Example

```yaml
server:
  publicUrl: https://resume.example.com
smtp:
  enabled: true
  host: smtp.example.com
  port: 465
  from: Reactive Resume <noreply@example.com>
  username: resume-smtp-user
  existingSecret: resume-smtp
  passwordKey: password
```

Supply the actual network egress rules and Secret before installation. These
example hostnames do not represent a configured mail service.
