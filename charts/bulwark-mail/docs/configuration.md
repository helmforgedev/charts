<!-- markdownlint-disable MD013 -->

# Configuration and authentication

## Wizard mode

Wizard mode is the default and preserves Bulwark's `/setup` workflow. Keep persistence enabled. The wizard writes `config.json`, policy, the admin password hash, plugins, themes, branding, audit state, and a setup token below `/app/data`.

```yaml
config:
  mode: wizard
persistence:
  enabled: true
```

## Declarative mode

Declarative mode requires `config.jmap.serverUrl`, exported as `JMAP_SERVER_URL`:

```yaml
config:
  mode: declarative
  jmap:
    serverUrl: https://mail.example.com
```

The URL is returned by `/api/config` and used by browsers. Do not use an internal Kubernetes DNS name unless every browser can resolve it.

Admin read-only behavior is an independent opt-in. Keep `config.admin.readOnly: false` while bootstrapping with `ADMIN_PASSWORD`, because Bulwark must write the initial `admin.json`. Set it to `true` only after the persisted admin configuration exists.

Saved admin values have higher upstream precedence than environment values. Clear obsolete admin files when converting an existing wizard installation.

## OAuth/OIDC

```yaml
config:
  oauth:
    enabled: true
    only: true
    clientId: bulwark-mail
    issuerUrl: https://idp.example.com
secrets:
  existingSecret: bulwark-mail-runtime
  generate: false
```

The Secret must contain `session-secret`. Add `oauth-client-secret` only for confidential OAuth clients; public PKCE clients do not require one. Register the public Bulwark callback URL at the identity provider. Enable private endpoints only when discovery intentionally points at trusted internal hosts.

## JWT impersonation

JWT impersonation is intended for a trusted platform that already authenticated the user. It requires a signing secret of at least 32 characters, a Stalwart master user, and its password. This grants mailbox impersonation capability and should be isolated like a root credential.

## Secret rotation

Rotating the session secret invalidates remembered sessions and makes previously encrypted settings unreadable. Coordinate rotation with a settings migration or accept the reset. OAuth, admin, and master credentials can be rotated independently by updating the Secret and recreating the pod.

## Troubleshooting

- `/api/config` returns an old URL: inspect `/app/data/admin/config.json` for a higher-precedence override.
- OAuth redirects fail: verify issuer discovery, client ID, registered callback, and proxy headers.
- Settings do not sync: confirm `SESSION_SECRET` is present and `SETTINGS_SYNC_ENABLED=true`.

<!-- @AI-METADATA
type: chart-docs
title: Bulwark Mail configuration
description: Wizard, declarative, OAuth, and JWT configuration
keywords: bulwark, configuration, oauth, jmap
purpose: Configure Bulwark Mail securely
scope: Chart
relations:
  - charts/bulwark-mail/README.md
path: charts/bulwark-mail/docs/configuration.md
version: 1.0
date: 2026-09-28
-->
