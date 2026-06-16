# Liwan Architecture

Liwan runs as one HTTP application process backed by embedded DuckDB storage.

## Runtime Components

The Helm chart renders:

- a Deployment named after the release
- a ClusterIP Service
- a PersistentVolumeClaim when persistence is enabled
- optional Ingress
- optional Gateway API HTTPRoute
- optional extra manifests supplied through `extraManifests`

The container listens on `liwan.port`, which defaults to `9042`. The Service exposes port `80` and forwards to the named `http` container port.

## Storage Layout

The pod mounts a volume named `data` at `/data`.

With default values, that volume is a chart-managed PVC named `<release>-liwan-data`. If `persistence.existingClaim` is
set, the chart mounts the existing claim instead. If persistence is disabled, the chart uses `emptyDir`.

DuckDB files and runtime assets live on this mounted volume. Treat the PVC as the source of truth for backup and restore.

## Rollout Model

The Deployment uses `strategy.type: Recreate`.

This prevents old and new pods from writing to the same DuckDB-backed data directory at the same time during upgrades.
The tradeoff is a short outage during rollout, which is preferable to overlapping writers for this application model.

## Public Endpoint

`liwan.baseUrl` sets `LIWAN_BASE_URL`.

Set this value to the same URL users and tracking scripts will use, for example:

```yaml
liwan:
  baseUrl: https://analytics.example.com
```

For public deployments, keep `liwan.baseUrl`, Ingress hostnames, Gateway API hostnames, and TLS hosts aligned.

## Network Entry Points

For local or internal access, use the Service directly:

```bash
kubectl port-forward svc/liwan-liwan 9042:80
```

For public access, use either Ingress or Gateway API. Both route to the same Service backend and do not change the application runtime.

## Security Boundary

Liwan does not need Kubernetes API access. The chart disables ServiceAccount token automount and uses non-root security
defaults. Restrict network ingress at the cluster, namespace, or Ingress controller level when Liwan should only receive
traffic from trusted front doors.
