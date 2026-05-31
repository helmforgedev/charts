# Valkey

Valkey for Kubernetes with explicit support for `standalone`, `replication`, `sentinel`, and `cluster` topologies.

## Install

### HTTPS repository

```bash
helm repo add helmforge https://repo.helmforge.dev
helm repo update
helm install valkey helmforge/valkey -f values.yaml
```

### OCI registry

```bash
helm install valkey oci://ghcr.io/helmforgedev/helm/valkey -f values.yaml
```

## What this chart covers

- topology selection with `architecture`
- password authentication through generated, inline, existing, or externally reconciled secrets
- optional External Secrets Operator integration
- persistence settings by topology
- internal service DNS customization with `clusterDomain`
- dual-stack service fields through `service.ipFamilyPolicy` and `service.ipFamilies`
- optional TLS file wiring for Valkey server configuration
- optional Valkey exporter sidecar and `ServiceMonitor`
- optional `PodDisruptionBudget`
- topology-specific Services, StatefulSets, and Valkey Cluster bootstrap Job
- `extraEnv`, `extraVolumes`, `extraVolumeMounts`, and `extraManifests` extension points

## Supported architectures

| Architecture | Contract | Primary resources | Document |
|-------------|----------|-------------------|----------|
| `standalone` | One Valkey pod, lowest operational complexity, no HA contract | headless Service, client Service, StatefulSet | [docs/standalone.md](docs/standalone.md) |
| `replication` | One fixed primary with read replicas, no automatic promotion | headless Service, primary Service, replica Service, primary and replica StatefulSets | [docs/replication.md](docs/replication.md) |
| `sentinel` | Valkey replication plus Sentinel primary discovery and failover for compatible clients | replication resources, Sentinel Service, Sentinel StatefulSet | [docs/sentinel.md](docs/sentinel.md) |
| `cluster` | Valkey Cluster sharding and HA for Valkey Cluster-compatible clients | headless Service, client Service, cluster StatefulSet, cluster init Job | [docs/cluster.md](docs/cluster.md) |

## How to choose the architecture

- Use `standalone` for development, simple workloads, and systems that do not need Valkey-level HA.
- Use `replication` when applications can tolerate a fixed primary endpoint and only need read replicas.
- Use `sentinel` when clients can query Sentinel and need automatic primary discovery after failover.
- Use `cluster` when clients support Valkey Cluster and data must be sharded across nodes.

Read the topology document before production use:

- [Standalone](docs/standalone.md)
- [Replication](docs/replication.md)
- [Sentinel](docs/sentinel.md)
- [Cluster](docs/cluster.md)

## Quick start

Minimal standalone deployment with an existing password Secret:

```yaml
architecture: standalone

auth:
  enabled: true
  existingSecret: valkey-auth
  existingSecretPasswordKey: valkey-password

standalone:
  persistence:
    enabled: true
    size: 8Gi
```

Install:

```bash
helm install valkey helmforge/valkey -f valkey-values.yaml
```

## Authentication

The chart supports four credential patterns:

| Pattern | Values | Notes |
|---------|--------|-------|
| Generated password | `auth.enabled=true`, empty `auth.password`, empty `auth.existingSecret` | Useful for quick starts. The generated value is stored in the chart-managed Secret. |
| Inline password | `auth.password` | Acceptable for local testing. Avoid committing real credentials. |
| Existing Secret | `auth.existingSecret` and `auth.existingSecretPasswordKey` | Recommended for production when another process owns the Secret. |
| ExternalSecret | `externalSecrets.enabled=true` and `auth.existingSecret` | Recommended when External Secrets Operator reconciles the Secret from an external provider. |

When `externalSecrets.enabled=true`, set `auth.existingSecret` to the same target Secret name. This avoids drift between a chart-managed Secret and an externally reconciled Secret.

Example:

```yaml
auth:
  enabled: true
  existingSecret: valkey-auth
  existingSecretPasswordKey: valkey-password

externalSecrets:
  enabled: true
  secretStoreRef:
    name: platform-secrets
    kind: ClusterSecretStore
  data:
    - secretKey: valkey-password
      remoteRef:
        key: valkey/auth
        property: password
```

## Networking

The chart creates a headless Service for stable StatefulSet pod DNS and topology-specific client Services.

| Mode | Client-facing service |
|------|-----------------------|
| `standalone` | `<release>-valkey-client` |
| `replication` | `<release>-valkey-primary` for writes, `<release>-valkey-replicas` for reads |
| `sentinel` | `<release>-valkey-sentinel` for Sentinel, plus replication services |
| `cluster` | `<release>-valkey-client` |

### Cluster domain

Set `clusterDomain` when the Kubernetes cluster does not use `cluster.local`:

```yaml
clusterDomain: corp.internal
```

The value is used for internal FQDNs rendered into Valkey replication, Sentinel, Valkey Cluster announce hostnames, cluster bootstrap commands, and `NOTES.txt`.

### Dual-stack services

Service dual-stack fields are available through:

```yaml
service:
  ipFamilyPolicy: PreferDualStack
  ipFamilies:
    - IPv4
    - IPv6
```

Leave these values empty to use the cluster defaults.

## Persistence

Persistence is configured under each topology:

- `standalone.persistence`
- `replication.primary.persistence`
- `replication.replica.persistence`
- `sentinel.persistence`
- `cluster.persistence`

Use persistent volumes for production stateful modes. Disable persistence only for ephemeral tests and short-lived environments.

## Observability

Enable the Valkey exporter sidecar with:

```yaml
metrics:
  enabled: true
```

When Prometheus Operator is installed, enable a `ServiceMonitor`:

```yaml
metrics:
  enabled: true
  serviceMonitor:
    enabled: true
    labels:
      prometheus: monitoring
```

Monitor memory usage, connected clients, command latency, replication lag, Sentinel state, and Valkey Cluster health depending on the selected topology.

## Scheduling and availability

For HA-oriented modes, configure:

- `pdb.enabled=true`
- `affinity` or pod anti-affinity
- `topologySpreadConstraints`
- resource requests and limits
- a storage class with the required availability profile

The chart exposes scheduling knobs but does not enforce a single cluster layout. Match these values to your node topology and maintenance policy.

## Extension points

Use the generic extension values when platform-specific integration is needed:

- `commonLabels`
- `podLabels`
- `podAnnotations`
- `annotations`
- `extraEnv`
- `extraVolumes`
- `extraVolumeMounts`
- `extraManifests`

`extraManifests` are rendered with `tpl`.

## Main values

| Parameter | Description | Default |
|-----------|-------------|---------|
| `architecture` | Valkey topology: `standalone`, `replication`, `sentinel`, or `cluster` | `standalone` |
| `clusterDomain` | Kubernetes cluster DNS domain used for internal service FQDNs | `cluster.local` |
| `image.repository` | Valkey image repository | `docker.io/valkey/valkey` |
| `image.tag` | Valkey image tag | `9.1.0` |
| `auth.enabled` | Enable password authentication | `true` |
| `auth.password` | Inline Valkey password | `""` |
| `auth.existingSecret` | Existing Secret containing the Valkey password | `""` |
| `auth.existingSecretPasswordKey` | Secret key used for the Valkey password | `valkey-password` |
| `tls.enabled` | Enable Valkey TLS settings. Requires `tls.existingSecret`. | `false` |
| `standalone.persistence.enabled` | Enable persistence for standalone mode | `true` |
| `replication.replicaCount` | Number of replica pods in replication and sentinel modes | `2` |
| `sentinel.replicaCount` | Number of Sentinel pods | `3` |
| `sentinel.quorum` | Sentinel quorum | `2` |
| `cluster.nodes` | Number of Valkey Cluster nodes | `6` |
| `cluster.replicasPerMaster` | Valkey Cluster replicas per master | `1` |
| `service.type` | Client Service type where applicable | `ClusterIP` |
| `service.ipFamilyPolicy` | Service IP family policy for dual-stack clusters | `null` |
| `service.ipFamilies` | Service IP families for dual-stack clusters | `[]` |
| `metrics.enabled` | Enable redis_exporter sidecar | `false` |
| `metrics.serviceMonitor.enabled` | Create ServiceMonitor | `false` |
| `tests.enabled` | Render Helm test connection pod | `true` |
| `tests.image.repository` | Helm test image repository | `docker.io/valkey/valkey` |
| `tests.image.tag` | Helm test image tag | `9.1.0` |
| `automountServiceAccountToken` | Mount Kubernetes API service account token into pods | `false` |
| `podSecurityContext.seccompProfile.type` | Pod seccomp profile | `RuntimeDefault` |
| `securityContext.capabilities.drop` | Linux capabilities dropped by default | `["ALL"]` |
| `pdb.enabled` | Create PodDisruptionBudget for HA modes | `false` |
| `externalSecrets.enabled` | Render an ExternalSecret for the auth Secret | `false` |
| `externalSecrets.secretStoreRef.name` | SecretStore or ClusterSecretStore name | `""` |
| `extraManifests` | Extra Kubernetes manifests rendered with `tpl` | `[]` |

## CI scenarios

The `ci/` scenarios validate chart behavior across common configurations:

- `standalone.yaml`
- `replication.yaml`
- `sentinel.yaml`
- `cluster.yaml`
- `existing-secret.yaml`
- `external-secrets.yaml`
- `metrics.yaml`
- `dual-stack.yaml`
- `tls-replication.yaml`
- `tls-cluster.yaml`

Local validation should include:

```bash
helm dependency build charts/valkey
helm lint charts/valkey --strict
helm unittest charts/valkey
helm template valkey charts/valkey
helm test valkey -n <namespace>
for f in charts/valkey/ci/*.yaml; do helm template valkey charts/valkey -f "$f" >/dev/null; done
```

## Examples

See `examples/`:

- `standalone-simple.yaml`
- `replication-production.yaml`
- `cluster.yaml`

## Operational notes

- `replication` and `sentinel` are different operational contracts.
- `sentinel` requires Sentinel-compatible clients for automatic primary discovery.
- `cluster` requires Valkey Cluster-compatible clients.
- If `auth.password` is not set and `auth.existingSecret` is not used, the chart generates a password automatically.
- If your cluster domain is not `cluster.local`, set `clusterDomain` before installing stateful topologies.
- For production, verify storage, credentials, scheduling, network policy, monitoring, backup strategy, and client compatibility before exposing Valkey to applications.

## Official product references

- Valkey Sentinel: <https://valkey.io/docs/latest/operate/oss_and_stack/management/sentinel/>
- Valkey Cluster: <https://valkey.io/docs/latest/operate/oss_and_stack/management/scaling/>
- Valkey security: <https://valkey.io/docs/latest/operate/oss_and_stack/management/security/>

<!-- @AI-METADATA
type: chart-readme
title: Valkey Helm Chart
description: Valkey chart with standalone, replication, sentinel, and cluster architectures

keywords: Valkey, cache, in-memory, replication, sentinel, cluster, dual-stack, external-secrets

purpose: Usage guide for the Valkey Helm chart with authentication, networking, observability, and topology guidance
scope: Chart

relations:
  - charts/valkey/DESIGN.md
  - charts/valkey/docs/standalone.md
  - charts/valkey/docs/replication.md
  - charts/valkey/docs/sentinel.md
  - charts/valkey/docs/cluster.md
path: charts/valkey/README.md
version: 1.1
date: 2026-05-05
-->
