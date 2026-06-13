<!-- SPDX-License-Identifier: Apache-2.0 -->

# Gophish Chart Design

This chart packages the official Gophish image for authorized security awareness
training workflows. It keeps the default install private and single-replica,
because upstream Gophish stores state locally by default and does not document a
Kubernetes-native HA mode.

## Differentiators

- Separate admin and phishing Services, Ingresses, and Gateway API HTTPRoutes.
- Safe SQLite defaults with explicit persistence boundaries.
- External MySQL and HelmForge MySQL dependency paths for production database
  lifecycle ownership.
- Generated `config.json` stored as a Secret, with `existingSecret` support for
  operator-managed configuration.
- NetworkPolicy, dual-stack Service fields, ServiceAccount token control, and
  backup support for SQLite mode.
- CI scenarios covering default, ingress, Gateway API, backup, dual-stack,
  NetworkPolicy, embedded MySQL, and external database render paths.

## Architecture

The detailed architecture record lives in [docs/architecture.md](docs/architecture.md).
That document captures upstream image behavior, database mode decisions, network
surface separation, TLS choices, persistence, and site sync notes.

## Runtime Boundaries

- Admin UI is privileged and should stay private behind port-forward, VPN, SSO,
  reverse proxy auth, or an internal Gateway/Ingress.
- The phishing listener is intentionally separate so campaign traffic can use a
  different hostname, policy, and network path.
- SQLite mode remains single-replica. Multi-replica experiments require
  `database.mode=external` or `database.mode=mysql` and separate validation of
  shared database behavior.
- Chart-managed backup covers SQLite mode only. MySQL backup is delegated to the
  MySQL dependency or external database tooling.

## Validation Focus

Use `make validate-chart CHART=gophish` as the required gate. It exercises Helm
lint, template rendering, unit tests, kubeconform with real schemas, Artifact Hub
lint, and k3d behavioral validation for every CI values file.
