# Umami Chart Design

This chart packages Umami as a single web Deployment backed by PostgreSQL. The chart keeps the default install small for local use while exposing the controls needed for production deployments.

## Goals

- Keep a working default install for development and demos.
- Support production deployments without raw template overrides.
- Prefer structured values for common Umami runtime settings.
- Support both bundled and external PostgreSQL.
- Allow platform-owned secrets through External Secrets Operator.
- Support modern Kubernetes exposure through Gateway API while keeping Ingress.
- Make network, availability, and backup controls explicit.

## Default Architecture

```text
┌──────────────┐       ┌──────────────────────┐
│ kubectl port │       │ Service ClusterIP    │
│ forward      ├──────►│ <release>-umami:80   │
└──────────────┘       └──────────┬───────────┘
                                  │
                         ┌────────▼─────────┐
                         │ Umami Deployment │
                         │ 1 replica        │
                         └────────┬─────────┘
                                  │ DATABASE_URL
                         ┌────────▼─────────┐
                         │ PostgreSQL       │
                         │ HelmForge chart  │
                         └──────────────────┘
```

Default installs generate the application and database secrets and do not expose Umami publicly.

## Production Architecture

```text
┌───────────────┐
│ Internet      │
└───────┬───────┘
        │ HTTPS
┌───────▼────────┐       ┌───────────────────────┐
│ Gateway        │       │ HTTPRoute             │
│ or Ingress     ├──────►│ analytics.example.com │
└────────────────┘       └───────────┬───────────┘
                                      │
                             ┌────────▼─────────┐
                             │ Service          │
                             │ ClusterIP/dual   │
                             └────────┬─────────┘
                                      │
                       ┌──────────────▼──────────────┐
                       │ Umami Deployment             │
                       │ 2+ replicas, PDB, resources  │
                       └──────────────┬──────────────┘
                                      │
                    ┌─────────────────▼─────────────────┐
                    │ Managed PostgreSQL / DB operator   │
                    └───────────────────────────────────┘
```

Recommended production values use a stable APP_SECRET, external PostgreSQL, explicit resource requests, Gateway API or Ingress TLS, a PDB, and egress-aware NetworkPolicy.

## External Database Preparation

Umami's first migration creates `pgcrypto`. Some PostgreSQL services allow the application owner to create extensions,
while others require an administrative user. The chart supports an optional `prepare-external-db` init container for the
second case.

```text
┌──────────────────────┐
│ Admin Secret          │
│ postgres-password     │
└──────────┬───────────┘
           │ valueFrom
┌──────────▼───────────┐       CREATE EXTENSION       ┌──────────────────┐
│ prepare-external-db  ├─────────────────────────────►│ External Postgres │
│ postgres client      │                              │ umami database    │
└──────────┬───────────┘                              └──────────────────┘
           │ success
┌──────────▼───────────┐
│ wait-for-db          │
└──────────┬───────────┘
           │
┌──────────▼───────────┐
│ Umami container      │
└──────────────────────┘
```

This is opt-in and only active when `postgresql.enabled=false`. It lets operators keep the runtime Umami user least-privileged while still preparing required extensions during installation.

## External Secrets Architecture

```text
┌────────────────────┐      sync       ┌──────────────────────┐
│ Secret backend     ├────────────────►│ ExternalSecret       │
│ Vault / AWS / GCP  │                 │ external-secrets.io  │
└────────────────────┘                 └──────────┬───────────┘
                                                   │ creates
                                      ┌────────────▼────────────┐
                                      │ Kubernetes Secret        │
                                      │ app, db, backup creds    │
                                      └────────────┬────────────┘
                                                   │ envFrom/valueFrom
                                      ┌────────────▼────────────┐
                                      │ Umami / backup CronJob   │
                                      └─────────────────────────┘
```

The chart renders `external-secrets.io/v1` resources only when enabled. It never requires External Secrets Operator for default installs.

## Backup Architecture

```text
┌────────────────────┐       pg_dump       ┌──────────────────┐
│ Backup CronJob     ├────────────────────►│ PostgreSQL       │
│ postgres tools     │                     │ bundled/external │
└──────────┬─────────┘                     └──────────────────┘
           │ upload
┌──────────▼─────────┐
│ S3-compatible      │
│ object storage     │
└────────────────────┘
```

The backup job is optional and designed for smaller self-hosted installations.
Production teams should still validate restores and may prefer database-native backups from their PostgreSQL operator
or managed database service.

## Runtime Configuration

The chart maps common Umami environment variables to structured values. This makes production values easier to review than large `extraEnv` blocks:

- `APP_SECRET` from generated, existing, or external-managed Secret.
- `DATABASE_URL` composed by chart helpers.
- `DISABLE_TELEMETRY` and `DISABLE_UPDATES` default to true.
- `FORCE_SSL`, `CLIENT_IP_HEADER`, `COLLECT_API_ENDPOINT`, `TRACKER_SCRIPT_NAME`, `ALLOWED_FRAME_URLS`, and related settings are optional structured values.

`extraEnv` remains available for upstream settings that are not modeled yet.
`BASE_PATH` is intentionally not modeled because Umami v3 treats it as a build-time setting for the stock image.

## Security Posture

- The service account token is not mounted by default.
- Secrets can be user-provided or managed by External Secrets Operator.
- The container runs with the chart-defined security context.
- NetworkPolicy is opt-in because clusters and CNIs vary.
- Public exposure is opt-in through Ingress or Gateway API.
- Production examples avoid embedding secret values in Helm values.

## Availability

Umami is stateless at the pod layer. Horizontal scaling depends on a shared PostgreSQL database and a stable APP_SECRET. Enable:

- `replicaCount: 2` or higher
- `pdb.enabled: true`
- production resources
- external PostgreSQL or a highly available PostgreSQL operator
- `database.external.init.enabled` when the application user cannot create required extensions

## Dual Stack

The Service supports `ipFamilyPolicy` and `ipFamilies`. The chart does not force dual-stack by default because the Kubernetes cluster and CNI must provide IPv6 support.

## Gateway API

Gateway API support renders an `HTTPRoute` using `gateway.networking.k8s.io/v1`.
The chart expects the cluster to already provide Gateway API CRDs and a Gateway implementation.
Ingress remains available for clusters that have not adopted Gateway API.

## Validation Strategy

Chart changes should be validated with:

- `helm lint`
- `helm lint --strict`
- `helm unittest`
- render of every `ci/*.yaml`
- `kubeconform -strict`
- `ah lint`
- K3D install with bundled PostgreSQL
- K3D install with external PostgreSQL
- pod logs and namespace events inspection

Generated dependency artifacts such as `Chart.lock` and `charts/` are not committed in this repository workflow.
