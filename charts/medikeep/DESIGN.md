# MediKeep Chart Design

MediKeep is a single web application container backed by PostgreSQL and writable filesystem paths for uploads, backups, and logs.
The chart keeps those concerns explicit instead of hiding them behind a generic application scaffold.

## Runtime Model

The upstream image serves the React frontend and FastAPI backend from one container on port `8000`.
The chart renders one Deployment with `strategy: Recreate` and `replicaCount: 1` by default.
Scaling above one pod is blocked because MediKeep writes uploads and generated backups to local mounted paths.

## Image

The chart uses the official upstream image:

```text
ghcr.io/afairgiant/medikeep:v0.68.0
```

The tag maps to the upstream `v0.68.0` release and publishes Linux `amd64` and `arm64` manifests.

## Database

PostgreSQL is required.
The default install uses the HelmForge PostgreSQL dependency so local validation and small self-hosted installs work without an external database.
Production users can disable the subchart and point MediKeep at an external PostgreSQL service with an existing Secret for the password.

## Secrets

MediKeep requires `SECRET_KEY` for persistent JWT/session behavior.
The chart creates a Kubernetes Secret when `secrets.existingSecret` is empty, generating the key on first install and reusing it with `lookup` on upgrades.

The chart also supports optional Secret-backed values for `ADMIN_DEFAULT_PASSWORD` and `SSO_CLIENT_SECRET`.
External Secrets Operator is exposed as a generic `externalSecrets.items` list so users can materialize the same app Secret or database Secret from their provider.

## Persistence

The upstream container writes to:

- `/app/uploads`
- `/app/backups`
- `/app/logs`

Uploads and backups default to PVCs. Logs default to `emptyDir` because medical application logs can contain sensitive operational traces and should not be retained accidentally.

## Security

The upstream image contains an `appuser` account with UID/GID `999`.
The chart runs the container directly as that user and sets `fsGroup: 999` so mounted volumes are writable without relying on the image's root entrypoint path.
The container drops Linux capabilities, disallows privilege escalation, and uses the runtime default seccomp profile.

## Exposure

MediKeep is an HTTP web app, so the chart supports both Ingress and the canonical HelmForge Gateway API `gatewayAPI.httpRoutes` surface. TLS should normally terminate at the ingress controller or Gateway.

## Validation Scope

The chart includes unit tests for:

- official image and PostgreSQL environment wiring
- app and external database Secrets
- uploads, backups, and logs volume behavior
- Ingress, Gateway API, Service dual-stack, NetworkPolicy, and validation failures

Full readiness is gated by:

```bash
make validate-chart CHART=medikeep
```
