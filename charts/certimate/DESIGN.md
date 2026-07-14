# certimate Chart Design

Certimate is packaged as a single web application container. The upstream Docker deployment exposes HTTP on port `8090` and persists all runtime state in `/app/pb_data`.

## Workload Model

The chart uses a Deployment with `Recreate` strategy and defaults to
`replicaCount: 1`. This avoids concurrent writers against the same PocketBase
data directory. Operators that need more than one replica must provide storage
semantics that are safe for their environment and set
`persistence.existingClaim`.

## Storage

The generated PVC is mounted at `/app/pb_data`. This directory contains
application data, user accounts, provider credentials, ACME state, workflows,
and issued certificate material. Backup and restore procedures should treat the
whole directory as sensitive.

Certimate is PocketBase-backed in the upstream container. The chart deliberately
does not add PostgreSQL, MySQL, or Redis subcharts because there is no official
external database contract to wire those dependencies safely. A database subchart
would create a false production signal without moving Certimate state out of
`/app/pb_data`.

Disabling persistence is a breaking, explicit choice: users must set
`persistence.ephemeral=true` together with `persistence.enabled=false`. This
keeps disposable CI and demo installs available while preventing accidental loss
of certificates, ACME accounts, provider credentials, and workflow state.

## Exposure

The chart supports Kubernetes Ingress and Gateway API HTTPRoute. TLS termination is expected at the ingress controller or gateway. Certimate itself remains an internal HTTP service.

## Secrets

Certimate manages most user and provider secrets inside PocketBase. The chart
does not invent a separate configuration file. `app.env`, `app.envFrom`, and
`externalSecrets.items` are available for deployment-specific environment
variables.

## Network Policy

NetworkPolicy is optional because certificate workflows vary widely. Production
installs should enable it and model required egress explicitly: DNS provider
APIs, ACME endpoints, SMTP, webhook receivers, SSH/API targets, and Kubernetes
services used by deployment tasks.

## Validation

The chart includes unit tests for rendering, storage, exposure, Gateway API,
NetworkPolicy, ExternalSecret, and validation failures. Runtime readiness is
verified through the HelmForge `make validate-chart CHART=certimate` gate.
