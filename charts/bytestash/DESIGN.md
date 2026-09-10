# ByteStash design

## Upstream boundary

The official pinned image is used unchanged. The chart imports native database and password modules in a one-shot init
container rather than inventing undocumented administrator environment variables or exposing initial registration. It
uses an explicit SQLite transaction around first-user creation and orphan ownership, then closes the database cleanly.
The main process starts only after this succeeds. Existing accounts and password hashes are preserved.

The HTTP process port is fixed at 5000. `ALLOWED_HOSTS` is not implemented in tagged server code. The chart exposes
native BASE_PATH, JWT file loading, local enrollment and OIDC settings while rejecting overrides of managed
authentication variables. Client Secrets remain in Kubernetes Secrets; the bootstrap credential is not mounted in the
server.

## Storage and availability

SQLite has one application writer and a single Recreate Deployment. A shared RWX claim does not justify replicas. No HPA
or PDB suggests availability guarantees that this topology cannot provide. The complete data directory is persistent and
generated claims are retained by default. EmptyDir is explicit and disposable.

Optional snapshot jobs use the image's better-sqlite3 backup API with a read-only source connection. They verify
integrity before atomic publication and delete only completed chart-named snapshots beyond retention. Source and backup
claims are separate. Pod affinity keeps RWO backup access on the application node; RWOP is rejected. Backup pods have a
distinct component label and cannot become HTTP Service endpoints.

A revision-named storage-check Job binds and verifies the destination PVC even with WaitForFirstConsumer. Waiting until
the first scheduled backup would deadlock Helm's PVC readiness gate. The job does not copy application data and has a
bounded deadline and TTL. CronJob suspension affects snapshots, not storage provisioning. A revision name avoids
immutable Job template updates when the image or storage settings change.

## Security and identity

Both init and server use UID/GID 1000, read-only image filesystems, restricted capabilities, RuntimeDefault seccomp and
bounded resources. Kubernetes API credentials are not mounted. Default network access is local namespace HTTP and DNS;
OIDC destinations require explicit egress. Backup pods deny ingress and egress entirely.

Native OIDC validates identity tokens but its enrollment behavior differs from local registration. Admission belongs at
the provider. Upstream's callback token query and browser token storage remain documented limitations. S256 PKCE is
verified by the runtime fixture. An additional trusted CA uses NODE_EXTRA_CA_CERTS, without disabling TLS verification.
The chart preserves local administrator recovery and does not invent claim filters or account linking.

## Validation strategy

The runtime smoke tests native HTTP authentication, enrollment rejection, Unicode snippet content, persistence after pod
replacement, JWT retention, native MCP API-key discovery and revocation. Dedicated fixtures verify trusted HTTPS OIDC,
signed identity, state replay rejection and provider admission. The backup fixture creates three snapshots, verifies
retention and restores a fresh PVC while retaining content and a preexisting JWT session. Full chart validation
exercises all CI profiles sequentially on k3d.

No native Prometheus endpoint exists in this image. Workload, volume and scheduled-job observability are documented
rather than exposing an unrelated exporter. Database subcharts are inapplicable because this application uses SQLite
only.

<!-- @AI-METADATA
type: design
title: ByteStash design
description: Native bootstrap, single-writer storage, consistent backups and honest authentication boundaries.
keywords: bytestash, sqlite, design, bootstrap, backup
purpose: Explain architecture choices and validation of production behavior.
scope: charts/bytestash
relations: [README.md, docs/operations.md]
path: charts/bytestash/DESIGN.md
version: 1.0
-->
