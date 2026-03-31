# SMTP and Email

## Why it matters

Vaultwarden relies on email for:

- invitations
- signup verification
- password hints and account flows
- emergency access notifications

If SMTP is enabled, document the chosen behavior clearly instead of relying on provider defaults.

## Recommended pattern

- use a valid `domain` so generated links point to the correct external URL
- use explicit `smtp.security`
- keep certificate validation enabled whenever possible
- prefer `smtp.existingSecret` for the SMTP password
- set `smtp.timeout` explicitly for production

## Example

```yaml
domain: https://vaultwarden.example.com

smtp:
  enabled: true
  host: smtp.example.com
  port: 587
  from: vaultwarden@example.com
  fromName: Vaultwarden
  security: starttls
  timeout: 15
  username: vaultwarden
  authMechanism: Plain,Login
  heloName: vaultwarden.example.com
  embedImages: true
  existingSecret: vaultwarden-smtp
```

## Risky troubleshooting flags

These options should stay disabled unless you are handling a specific diagnostic case:

- `smtp.debug`
- `smtp.acceptInvalidCerts`
- `smtp.acceptInvalidHostnames`

If any of them are enabled temporarily, treat that as an explicit risk acceptance and remove it after troubleshooting.

## References

- Vaultwarden configuration template: https://raw.githubusercontent.com/dani-garcia/vaultwarden/main/.env.template

<!-- @AI-METADATA
type: chart-docs
title: Vaultwarden - SMTP
description: SMTP configuration

keywords: vaultwarden, smtp, email

purpose: SMTP and email configuration guide for Vaultwarden
scope: Chart Architecture

relations:
  - charts/vaultwarden/README.md
path: charts/vaultwarden/docs/smtp-and-email.md
version: 1.0
date: 2026-03-20
-->
