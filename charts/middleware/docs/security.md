<!-- SPDX-License-Identifier: Apache-2.0 -->
# Middleware security model

## Protected assets

The PostgreSQL database stores DORA data, integration metadata, and encrypted
provider credentials. The key PVC stores the RSA key pair that decrypts those
credentials. Database passwords reside in Kubernetes Secrets or an external
secret manager.

## Default controls

- Dedicated ServiceAccount with token automount disabled.
- RuntimeDefault seccomp at pod level.
- Privilege escalation disabled and all Linux capabilities dropped.
- NetworkPolicy ingress limited to the named frontend port.
- Database passwords referenced from Secrets in both migration and application
  containers.
- Immutable application image tag.
- Single-replica Recreate deployment to avoid concurrent key-volume access.

These are defaults, not guarantees. Operators can override several security
contexts and can disable the NetworkPolicy or token protection.

## Upstream image constraints

The official image runs as root, extracts packaged dependencies at startup,
writes under `/opt` and `/app`, starts supervisor and cron, and does not support
a read-only root filesystem. The chart therefore cannot set `runAsNonRoot` or
`readOnlyRootFilesystem` safely.

Middleware 0.3.1 also lacks authenticated remote Redis support. The chart keeps
the embedded Redis listener on loopback rather than deploying an unauthenticated
network service.

## Network boundary

Only the frontend Service is exposed. Analytics and sync listeners are not
Service ports. Application egress remains unrestricted because provider URLs
depend on operator-selected Git, issue tracking, and CI systems.

Clusters with strict egress requirements should inventory DNS, PostgreSQL,
provider API, webhook, package, and certificate endpoints before replacing the
open egress rule.

## Secret guidance

Prefer `externalDatabase.existingSecret`. If `externalDatabase.password` is
used, the chart places it in a Secret rather than directly in the Deployment,
but the value may still be present in Helm release storage and Git history.

Encrypt backups of `config.ini`. Anyone holding that key pair and the database
can decrypt stored integration credentials.

## Image and vulnerability management

The chart pins the official upstream tag. Kubernetes manifest scanning does not
scan operating system or application packages inside the image. Run an image
vulnerability scanner and evaluate upstream releases before changing
`image.tag`.
