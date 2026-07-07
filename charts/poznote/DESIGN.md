# Poznote Chart Design

Poznote is a self-hosted note-taking and documentation platform built on Nginx, Alpine Linux, and SQLite.
The chart keeps the deployment simple by treating the application as a single stateful container with one data volume.

## Runtime Model

The upstream image serves the web frontend and API from one container on port `80`.
The chart renders one Deployment with `strategy: Recreate` and `replicaCount: 1` by default.
Scaling above one pod is blocked because Poznote uses SQLite for persistence and does not support concurrent writes from multiple instances.

## Image

The chart uses the official upstream image:

```text
ghcr.io/timothepoznanski/poznote:6.30.2
```

The tag maps to the upstream `6.30.2` release and publishes Linux `amd64` and `arm64` manifests.

## Database

Poznote uses an embedded SQLite database stored in the data directory.
There is no external database requirement and no database subchart dependency.
This makes the chart simpler than typical web applications but means that scaling beyond a single replica is not supported.

## Secrets

Poznote supports OIDC/SSO authentication with `POZNOTE_OIDC_CLIENT_ID` and `POZNOTE_OIDC_CLIENT_SECRET` environment variables.
The chart creates a Kubernetes Secret when inline values are provided and `secrets.existingSecret` is empty.
Production users should use `secrets.existingSecret` or External Secrets Operator to manage OIDC credentials.

## Persistence

The upstream container writes all data (SQLite database, notes, attachments, and configuration) to `/var/www/html/data`.
A single PVC (5Gi default) covers all storage needs.
Disabling persistence is possible but means all data is lost when the pod restarts.

## Security

The upstream image starts as root to run the init script (directory creation and ownership), then supervisord runs nginx and PHP-FPM as `www-data` (UID/GID 82).
The chart sets `fsGroup: 82` so the mounted PVC is writable by the www-data group.
The container drops Linux capabilities, disallows privilege escalation, and uses the runtime default seccomp profile.

## Exposure

Poznote is an HTTP web application, so the chart supports both Ingress and the canonical HelmForge Gateway API `gatewayAPI.httpRoutes` surface.
TLS should normally terminate at the ingress controller or Gateway.

## Validation Scope

The chart includes unit tests for:

- official image tag and container port wiring
- data volume persistence behavior
- Ingress, Gateway API, Service dual-stack, NetworkPolicy, and validation failures

Full readiness is gated by:

```bash
make validate-chart CHART=poznote
```
