# Liwan Chart Design

This chart deploys Liwan as a single-instance web analytics service using the official `ghcr.io/explodingcamera/liwan:1.5.0` image.

## Product Model

Liwan is a compact Rust service for privacy-focused web analytics. It serves the UI, receives tracking events, and
stores analytics data through an embedded DuckDB database. The runtime data directory is mounted at `/data`.

The chart does not model an external database because the upstream application is designed around local embedded storage.
The Kubernetes contract is therefore a single pod with durable storage, predictable networking, and explicit public URL
configuration.

## Default Topology

Defaults target a production-safe single instance:

- `replicas: 1`
- `strategy.type: Recreate`
- `persistence.enabled: true`
- one PVC mounted at `/data`
- Service on port `80` targeting container port `9042`
- ServiceAccount token automount disabled
- non-root UID/GID `1000`
- `RuntimeDefault` seccomp profile
- dropped Linux capabilities

`Recreate` is intentional. DuckDB is embedded and single-writer oriented, so the chart avoids overlapping pods during rollout.

## Persistence

The `/data` volume stores the DuckDB analytics database and runtime data such as GeoIP assets. The default PVC size is
`2Gi`, which is enough for small installations and test environments. Production installations should size the PVC based
on traffic volume and retention expectations.

When `persistence.enabled=false`, the chart uses `emptyDir`. That mode is only appropriate for demos and CI because analytics history is lost when the pod is replaced.

## Public URL

`liwan.baseUrl` renders `LIWAN_BASE_URL`. Set it to the external URL before installing tracking snippets. Without a
public base URL, the UI can still run, but generated tracker URLs can point at an internal or incomplete endpoint.

## Exposure

The chart supports three exposure paths:

- ClusterIP Service for internal or port-forward access
- Kubernetes Ingress with class, hosts, paths, and TLS
- Gateway API HTTPRoute for clusters using Gateway controllers

Ingress and Gateway API are independent. Operators should enable one public routing path per release unless they intentionally need both during migration.

## Security Choices

Liwan does not need Kubernetes API access, so `serviceAccount.automountServiceAccountToken` defaults to `false`.

The pod and container security contexts default to:

- non-root UID/GID `1000`
- `fsGroup: 1000`
- `fsGroupChangePolicy: OnRootMismatch`
- `seccompProfile.type: RuntimeDefault`
- `allowPrivilegeEscalation: false`
- `capabilities.drop: [ALL]`

`readOnlyRootFilesystem` is not forced by default because the upstream image behavior around temporary files is not a stable chart contract. Persistent application data remains isolated to `/data`.

## Scaling

The chart intentionally renders one replica and does not expose `replicaCount`. Horizontal scaling would require a
different storage model than embedded DuckDB. Run separate Liwan releases for isolated sites or environments.

## Validation Scope

The chart has unit tests for:

- Deployment strategy and image selection
- non-root and hardened security contexts
- ServiceAccount token automount
- PVC and `emptyDir` behavior
- base URL environment wiring
- Ingress rendering
- Gateway API HTTPRoute rendering
- dual-stack Service fields

Behavioral validation uses the default persistent single-pod topology in k3d.
