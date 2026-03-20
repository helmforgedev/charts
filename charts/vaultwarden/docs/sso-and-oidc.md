---
title: Vaultwarden - SSO
description: SSO and OIDC integration
keywords: [vaultwarden, sso, oidc]
scope: chart-docs
audience: users
---

# SSO and OIDC Guidance

## Scope in this chart

This chart does not model SSO or OIDC as first-class values.

That is intentional.

SSO in Vaultwarden is an advanced integration topic that depends on:

- a compatible identity provider
- HTTPS and stable external URLs
- careful email and account-matching decisions
- operational understanding of what SSO does and does not replace

Use `extraEnv`, `extraVolumes`, and secret/config mounts when you intentionally need this integration.

## Important expectation

SSO does not replace Vaultwarden end-to-end encryption behavior.

Users still need their Vaultwarden master password for the cryptographic model of their vault data. Treat SSO as an authentication integration, not as a replacement for the encryption boundary.

## Operational guidance

- enable SSO only after `domain`, ingress, reverse proxy headers, and TLS are already stable
- keep rollout and rollback simple; do not combine first-time SSO enablement with unrelated storage or SMTP changes
- test account linking behavior with a non-production realm or tenant first
- document how accounts are matched and who owns that mapping logic
- keep a break-glass admin path that does not depend on the same IdP outage you are trying to survive

## Suggested chart pattern

For this repository, the safest pattern is:

1. deploy the chart with stable ingress, `domain`, and persistence
2. validate normal login and admin access
3. inject the required SSO/OIDC settings through `extraEnv` and mounted secrets
4. test the full login flow in a controlled environment before promoting it

## References

- Vaultwarden OIDC wiki: https://github.com/dani-garcia/vaultwarden/wiki/Enabling-SSO-support-using-OpenId-Connect
- Vaultwarden configuration template: https://raw.githubusercontent.com/dani-garcia/vaultwarden/main/.env.template

<!-- @AI-METADATA
type: chart-docs
title: Vaultwarden - SSO
description: SSO and OIDC integration

keywords: vaultwarden, sso, oidc

purpose: SSO and OIDC integration guidance for Vaultwarden
scope: Chart Architecture

relations:
  - charts/vaultwarden/README.md
path: charts/vaultwarden/docs/sso-and-oidc.md
version: 1.0
date: 2026-03-20
-->
