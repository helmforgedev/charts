<!-- SPDX-License-Identifier: Apache-2.0 -->
# Automatisch Security

## Runtime controls

Web and worker containers default to UID/GID 1000, non-root execution, a
read-only root filesystem, dropped Linux capabilities, disabled privilege
escalation, and the runtime-default seccomp profile. Writable `emptyDir`
volumes are limited to `/tmp` and the application log directory. Service account
tokens are not mounted. Keep these defaults unless an upstream image change has been
validated in a disposable cluster and requires a documented exception.

The official image is pinned by tag in chart values and releases are validated
by HelmForge. Operators should still scan the resolved image digest under their
own vulnerability and admission policies.

## Secrets

The chart generates and preserves three application keys:

- `ENCRYPTION_KEY` protects stored integration credentials.
- `APP_SECRET_KEY` protects application sessions and authentication data.
- `WEBHOOK_SECRET_KEY` verifies webhook traffic.

Treat these as durable production data. Enable Kubernetes Secret encryption at
rest, limit RBAC access, exclude Secret values from logs and Git, and include
the Secret in encrypted backups. Restoring PostgreSQL with different keys can
make encrypted data unusable.

External PostgreSQL passwords should come from
`database.external.existingSecret`. Inline values are visible in Helm release
state and should be limited to disposable installations.

## Network boundary

The default NetworkPolicy limits inbound connections to the web listener. It
allows unrestricted egress because workflows integrate with operator-selected
external APIs. Environments that require destination allowlists should use an
egress proxy or CNI FQDN policy and replace `networkPolicy.egress` with explicit
rules for DNS, PostgreSQL, Redis, the proxy, and approved services.

Terminate public traffic with TLS and authentication-aware edge controls. The
NetworkPolicy does not provide TLS, user authentication, rate limiting, or web
application firewall behavior.

## Operational review

Audit access to application and datastore Secrets, alert on container security
context drift, review upstream image changes, and exercise credential recovery.
See [operations.md](operations.md) for backup and incident procedures.
