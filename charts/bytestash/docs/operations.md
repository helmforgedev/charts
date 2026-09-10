# ByteStash operations

## Initial access and credential ownership

The chart creates a local administrator in an init container before the application opens HTTP. It uses the pinned
application's database schema, password validation and bcrypt implementation in an explicit transaction. A nonempty
database is never reset. The configured administrator must already exist when reusing a populated database with
bootstrap enabled; set the correct username or explicitly disable bootstrap when adopting an existing claim.

The bootstrap password is an initial credential, not a password reconciler. Changing its Secret does not change the
database password. Use the application's password-management flow for rotation and update your password manager. The
main container cannot mount the bootstrap password Secret. The separately retained JWT key is passed through the
upstream `JWT_SECRET_FILE` feature. Rotate that key deliberately: existing sessions will become invalid. Generated
Secrets are retained across upgrades by Kubernetes lookup; GitOps rendering without live lookup should use existing
Secrets or ESO.

## SQLite snapshots and recovery

Enable `backup.enabled` to create consistent online database snapshots through `better-sqlite3`'s backup API. Each
completed copy passes SQLite `integrity_check` before atomic publication. Incomplete copies are not counted as valid
snapshots. The retention policy deletes only chart-named completed snapshots, never unrelated destination files. Cron
jobs cannot overlap.

The backup pod is placed on the application node for ReadWriteOnce volume compatibility. ReadWriteOncePod is
incompatible with a separate online backup pod and is rejected. A short Job binds and verifies the backup PVC during
each Helm revision, including with WaitForFirstConsumer storage. This prevents `helm install --wait` from waiting until
the scheduled backup. The storage check does not create a snapshot. Suspending the CronJob does not disable this
installation check.

```bash
kubectl -n snippets create job bytestash-manual-backup --from=cronjob/bytestash-bytestash-backup
kubectl -n snippets wait --for=condition=Complete job/bytestash-manual-backup --timeout=600s
kubectl -n snippets logs job/bytestash-manual-backup
```

Size the destination for complete copies of the database plus one temporary snapshot. The default 10Gi is a starting
point, not enough to guarantee seven copies of a full 5Gi source. Monitor free bytes, failed jobs and snapshot age.
Snapshots contain accounts, password hashes and API keys. Protect them and copy them to a separate failure domain using
your storage backup system. A second PVC in the same cluster is not disaster recovery by itself.

To recover:

1. Stop the application and wait until its pod has terminated.
2. Provision a fresh claim accessible to UID/GID 1000. Copy a verified snapshot as `snippets.db` at the claim root.
3. Preserve the corresponding JWT Secret if sessions must remain valid. Preserve the bootstrap username and current
   database password in your password manager.
4. Set `persistence.existingClaim` to the recovered claim and upgrade the release. Never attach the same writable SQLite
   claim to two running applications.
5. Log in, verify snippets and API access, and perform a new backup. Keep the old claim until recovery is accepted.

The chart's runtime validation exercises three online snapshots, retention of two copies and recovery into a fresh PVC,
including verification of Unicode snippet content and a previously issued JWT. Do not copy a live `snippets.db` file
without the SQLite backup API; WAL content may not be present in the main file. Helm rollback does not reverse data
migrations. Snapshot before upstream upgrades and restore data separately when required.

## OIDC and reverse proxy

Register a confidential client with callback `https://snippets.example.test/api/auth/oidc/callback`. Include the
configured `server.basePath` before `/api` when serving under a subpath. Use an HTTPS issuer and client Secret. Optional
`oidc.caConfigMap` adds a trusted PEM CA through native Node TLS verification; it does not disable certificate checks.

Restrict assigned users at the identity provider. Upstream 1.5.12 does not apply `ALLOW_NEW_ACCOUNTS=false` as an OIDC
allowlist once the database has users. Identities are keyed by subject and issuer, not automatically linked by email.
Mapped username collisions receive a numeric suffix. Administrator access is based on the final username in
`auth.adminUsernames`; verify that mapping and control provider enrollment. Local administrator login stays available.

The runtime fixture verifies S256 PKCE against standard provider discovery metadata. Upstream stores its application
token in the callback query and browser storage; the JavaScript-created cookie is not HttpOnly. Avoid callback query
logging at the proxy and treat XSS protection as part of the application boundary. The chart does not advertise HttpOnly
sessions that upstream does not implement.

ByteStash always trusts reverse-proxy headers. Terminate HTTPS at an edge that overwrites forwarded headers and accepts
only the configured hostname; restrict `networkPolicy.ingressFrom` to that edge. The upstream `ALLOWED_HOSTS` setting is
not consumed by this tagged server and is intentionally absent from the chart. The process port is fixed at 5000.

## MCP and observability

The native Streamable HTTP MCP endpoint is `/mcp`, prefixed by `server.basePath`. Authenticate using an application API
key in `x-api-key` or `Authorization: Bearer ...`; an application login JWT is not the MCP API key. Keys are scoped to
their owner's snippets. Revoke unused keys in the application. The runtime gate verifies MCP tool discovery and denial
after key revocation.

There is no native Prometheus endpoint in the pinned application. Use Kubernetes workload, PVC and Job metrics plus
ingress monitoring. No invented exporter, ServiceMonitor, database subchart, HPA or PDB is included. SQLite remains a
single-writer deployment with intentional downtime during Recreate upgrades.

<!-- @AI-METADATA
type: guide
title: ByteStash operations
description: Authentication, consistent SQLite snapshots, recovery, OIDC limitations and native MCP operations.
keywords: bytestash, sqlite, backup, oidc, mcp
purpose: Operate the chart against verified upstream behavior.
scope: charts/bytestash
relations: [../README.md, ../DESIGN.md]
path: charts/bytestash/docs/operations.md
version: 1.0
-->
