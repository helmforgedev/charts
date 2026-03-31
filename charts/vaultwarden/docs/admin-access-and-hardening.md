# Admin Access and Hardening

## Admin panel basics

Vaultwarden can expose an admin panel controlled by `ADMIN_TOKEN`.

In this chart:

- `admin.token` accepts the value directly
- `admin.existingSecret` is the preferred production path

## Recommended pattern

- prefer `admin.existingSecret`
- prefer an Argon2 PHC string instead of plain text
- expose the admin panel only behind trusted access controls
- do not rely on obscurity alone

## Generate a secure admin token

Using the Vaultwarden image:

```bash
docker run --rm -it vaultwarden/server:1.35.4 /vaultwarden hash
```

Using the `argon2` CLI:

```bash
echo -n 'change-me' | argon2 "$(openssl rand -base64 32)" -e -id -k 65540 -t 3 -p 4
```

## Ingress recommendations

- terminate TLS at ingress or reverse proxy
- keep `domain` aligned with the external HTTPS URL
- keep the admin page behind network or identity controls when possible
- keep `vaultwarden.proxy.ipHeader` aligned with the actual reverse proxy behavior

## Operational notes

- rotating `ADMIN_TOKEN` requires an explicit rollout
- admin-interface changes can persist runtime configuration to `/data/config.json`
- document who is allowed to use the admin panel before enabling it

## Admin token rotation

Recommended sequence:

1. generate a new Argon2 PHC string
2. update the referenced Kubernetes secret or the Helm value
3. run a controlled rollout of the Deployment
4. validate access to the admin page with the new token
5. invalidate any operational runbook or secret copy that still references the old token

When `admin.existingSecret` is used, rotating the secret alone is not enough. Vaultwarden must restart to consume the new value.

## Pod and network hardening

This chart keeps hardening focused on defaults that match the current Vaultwarden container model:

- `runAsNonRoot=true`
- dropped Linux capabilities
- `seccompProfile: RuntimeDefault`
- `allowPrivilegeEscalation=false`

`readOnlyRootFilesystem` remains disabled by default because operators often need a more explicit runtime validation before enabling it in web workloads that still write temporary files.

If your cluster requires strict east-west traffic controls, enable `networkPolicy` and explicitly allow ingress from your ingress controller namespace and egress to DNS and the selected database path.

## References

- Vaultwarden configuration template: https://raw.githubusercontent.com/dani-garcia/vaultwarden/main/.env.template
- Admin token guidance: https://github.com/dani-garcia/vaultwarden/wiki/Enabling-admin-page#secure-the-admin_token

<!-- @AI-METADATA
type: chart-docs
title: Vaultwarden - Admin Access
description: Admin panel and hardening

keywords: vaultwarden, admin, hardening, argon2

purpose: Admin panel configuration and Argon2 hardening guide for Vaultwarden
scope: Chart Architecture

relations:
  - charts/vaultwarden/README.md
  - charts/vaultwarden/docs/scope-and-automation-boundaries.md
path: charts/vaultwarden/docs/admin-access-and-hardening.md
version: 1.0
date: 2026-03-20
-->
