# NoteDiscovery Chart Design

This chart deploys NoteDiscovery as a self-hosted knowledge base using the
official `ghcr.io/gamosoft/notediscovery:0.27.3` image.

## Product Model

NoteDiscovery serves the UI and API from one Python process and stores durable
Markdown notes and related data in a local data directory. The upstream Docker
workflow mounts `/app/data` and exposes HTTP on port `8000`.

The chart therefore treats the application as a single-writer workload by
default. It uses a Deployment with `Recreate` strategy and a chart-managed
PersistentVolumeClaim. `Recreate` avoids overlapping writes during rollouts for
the default single-replica topology.

## Runtime Configuration

Upstream NoteDiscovery reads `config.yaml`. The chart renders that file in two modes:

- unauthenticated installs use a ConfigMap
- authenticated installs use a Secret

`auth.existingSecret` points at a Secret containing a complete `config.yaml`.
The chart does not split individual auth keys into separate environment
variables because the upstream contract is file-based. Keeping the full file
together avoids partially duplicated configuration paths.

## Default Topology

Defaults target a production-style single instance:

- `replicaCount: 1`
- `persistence.enabled: true`
- data mounted at `/app/data`
- generated unauthenticated config for local bootstrap
- non-root UID/GID `1000`
- ServiceAccount token automount disabled

Authentication remains opt-in because the upstream app is often first configured
locally. Documentation and examples show Secret-backed auth for shared
deployments.

## Scaling

The chart blocks `replicaCount > 1` unless `persistence.existingClaim` is set.
Generated PVCs are single workload claims and do not prove that a storage
backend is safe for multiple writers.

Operators that scale NoteDiscovery must provide their own claim and choose
storage semantics appropriate for the workload, typically ReadWriteMany storage.
The chart keeps the default topology single-replica because note files are
durable local state.

## Exposure

The chart supports:

- ClusterIP, NodePort, or LoadBalancer Service
- Kubernetes Ingress with `ingressClassName`
- Gateway API HTTPRoute
- dual-stack Service fields

`notediscovery.allowedOrigins` should be restricted to the public HTTPS origin
when exposing the app through a reverse proxy.

## External Secrets

External Secrets support renders `ExternalSecret` resources that can materialize
the complete `config.yaml` Secret. The expected production pattern is:

- `auth.existingSecret` names the target Secret
- `externalSecrets.items[].spec.target.name` materializes the same Secret
- `externalSecrets.items[].spec.data[].secretKey` is `config.yaml`

This keeps sensitive configuration outside the chart values while preserving the upstream config-file contract.

## Security Choices

The chart uses a non-root security context, drops Linux capabilities, disables
ServiceAccount token automount, and supports NetworkPolicy.
`readOnlyRootFilesystem` remains false because the upstream Python application
and image may need write access outside the mounted note directory during
startup.

## Validation Scope

The chart has template tests for:

- official pinned image
- generated ConfigMap and Secret config
- existing config Secret references
- invalid scaling and auth combinations
- ExternalSecret rendering
- Gateway API HTTPRoute
- NetworkPolicy
- dual-stack Service fields
- Ingress TLS rendering

Behavioral validation uses the default single-replica topology because it can
run in an isolated k3d cluster without external secret manager dependencies.
