<!-- SPDX-License-Identifier: Apache-2.0 -->

# Documenso implementation plan

## P1 release contract

- Pin the official v2.21.0 image by immutable manifest digest.
- Keep the upstream Prisma migration entrypoint.
- Provide HelmForge PostgreSQL and optional BullMQ Redis dependencies.
- Model application identity, external database, SMTP, signing certificate,
  S3, Gotenberg, and External Secrets without plaintext production credentials.
- Add non-root security contexts, read-only root filesystem, NetworkPolicy,
  dual-stack Service, Ingress, and Gateway API.
- Test the values schema, validation invariants, secret lifecycle, routes,
  dependency wiring, and behavioral health in k3d.
- Document backup, restore, scale-out prerequisites, and upgrade behavior.

## Production extensions included

- External PostgreSQL URLs support pooler and direct migration endpoints.
- Multiple replicas are allowed only with BullMQ and shared S3 storage.
- Public egress excludes private networks; operators enumerate private peers.
- Custom environment and volume extensions cover less common upstream
  providers without weakening the typed core contract.

## Deliberate omissions

- No application PVC: upstream stores state in PostgreSQL or object storage.
- No fake metrics endpoint or ServiceMonitor.
- No migration hook: a pre-install hook cannot reach a PostgreSQL subchart
  created by the same release, while the official entrypoint is supported.
- No embedded Gotenberg, SMTP, or object-storage chart because HelmForge has no
  maintained dependencies for them.
