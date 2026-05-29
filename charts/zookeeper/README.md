# Apache ZooKeeper

Apache ZooKeeper for Kubernetes using the official `docker.io/library/zookeeper` image.

This chart deploys a stable StatefulSet ensemble with explicit quorum ports, a client Service, optional secure client port,
Prometheus metrics, NetworkPolicy, PDB, External Secrets, and dual-stack Service fields.

## Install

### HTTPS repository

```bash
helm repo add helmforge https://repo.helmforge.dev
helm repo update
helm install zookeeper helmforge/zookeeper -f values.yaml
```

### OCI registry

```bash
helm install zookeeper oci://ghcr.io/helmforgedev/helm/zookeeper -f values.yaml
```

## What This Chart Covers

- official Apache ZooKeeper image with pinned `3.9.5` default tag
- replicated StatefulSet ensemble with stable pod DNS
- default three-node quorum and validation against accidental even replica counts
- standalone development mode with `replicaCount: 1`
- client, headless, and metrics Services with optional dual-stack fields
- optional Prometheus metrics provider, `ServiceMonitor`, and `PrometheusRule`
- optional SASL/Digest client authentication with generated or existing JAAS Secret
- optional secure client port using existing JKS keystore and truststore Secrets
- optional External Secrets Operator v1 integration for credential material
- optional NetworkPolicy for quorum, client, metrics, and DNS flows
- PDB, hardened container security context, explicit probes, and extension hooks

## Topologies

| Topology | Values | Typical Use |
|----------|--------|-------------|
| Ensemble | `replicaCount: 3` | Production and shared platform workloads that need quorum durability. |
| Standalone | `replicaCount: 1` | Local development, CI, and non-critical tests. |

Keep production replica counts odd. The chart blocks even replica counts unless `allowEvenReplicas=true` is set deliberately.

## Quick Start

Ephemeral standalone:

```yaml
replicaCount: 1
persistence:
  enabled: false
```

Production-oriented ensemble:

```yaml
replicaCount: 3

persistence:
  enabled: true
  size: 20Gi
  dataLogDir:
    enabled: true
    size: 10Gi

podDisruptionBudget:
  enabled: true
  maxUnavailable: 1

networkPolicy:
  enabled: true
  egress:
    allowSameNamespace: true

metrics:
  enabled: true
  serviceMonitor:
    enabled: true
```

## Client Endpoint

Use the client Service for applications:

```text
zookeeper.<namespace>.svc.cluster.local:2181
```

StatefulSet pods also have stable DNS names:

```text
zookeeper-0.zookeeper-headless.<namespace>.svc.cluster.local
zookeeper-1.zookeeper-headless.<namespace>.svc.cluster.local
zookeeper-2.zookeeper-headless.<namespace>.svc.cluster.local
```

## Metrics

ZooKeeper 3.9 includes a Prometheus metrics provider. Enable it with:

```yaml
metrics:
  enabled: true
  serviceMonitor:
    enabled: true
  prometheusRule:
    enabled: true
```

Metrics are exposed on `/metrics` through the metrics Service.

## Authentication

SASL/Digest client authentication is optional.

```yaml
auth:
  client:
    enabled: true
    username: app
    password: change-me
```

Existing JAAS Secret:

```yaml
auth:
  client:
    enabled: true
    existingSecret: zookeeper-jaas
    existingSecretJaasKey: jaas.conf
```

The JAAS key should contain a ZooKeeper `Server` login context.

## TLS

The chart supports ZooKeeper's secure client port with existing JKS material.

```yaml
tls:
  client:
    enabled: true
    port: 3181
    existingSecret: zookeeper-client-tls
    keystoreKey: zookeeper.keystore.jks
    truststoreKey: zookeeper.truststore.jks
    keystorePassword: changeit
    truststorePassword: changeit
```

The chart does not generate private keys or truststores.

## External Secrets

External Secrets Operator integration uses `external-secrets.io/v1`.

```yaml
auth:
  client:
    enabled: true

externalSecrets:
  enabled: true
  secretStoreRef:
    name: platform-secrets
    kind: ClusterSecretStore
  data:
    - secretKey: jaas.conf
      remoteRef:
        key: zookeeper/jaas
```

## Dual Stack

Dual-stack Service fields are available across headless, client, and metrics Services:

```yaml
service:
  ipFamilyPolicy: PreferDualStack
  ipFamilies:
    - IPv4
    - IPv6
```

## Main Values

| Parameter | Description | Default |
|-----------|-------------|---------|
| `replicaCount` | Number of ZooKeeper servers | `3` |
| `allowEvenReplicas` | Permit even replica counts | `false` |
| `image.repository` | ZooKeeper image repository | `docker.io/library/zookeeper` |
| `image.tag` | ZooKeeper image tag | `3.9.5` |
| `zookeeper.tickTime` | ZooKeeper tick time in milliseconds | `2000` |
| `zookeeper.initLimit` | ZooKeeper init limit | `10` |
| `zookeeper.syncLimit` | ZooKeeper sync limit | `5` |
| `zookeeper.fourLetterWordWhitelist` | Four-letter-word command whitelist | `srvr,stat,ruok,mntr,conf,isro` |
| `service.ipFamilyPolicy` | Service IP family policy | `""` |
| `persistence.enabled` | Create data PVCs | `true` |
| `persistence.dataLogDir.enabled` | Create a separate transaction log PVC | `false` |
| `auth.client.enabled` | Enable SASL/Digest client authentication | `false` |
| `tls.client.enabled` | Enable secure client port | `false` |
| `metrics.enabled` | Enable Prometheus metrics provider | `false` |
| `metrics.serviceMonitor.enabled` | Create ServiceMonitor | `false` |
| `metrics.prometheusRule.enabled` | Create PrometheusRule | `false` |
| `networkPolicy.enabled` | Create NetworkPolicy | `false` |
| `networkPolicy.egress.allowSameNamespace` | Allow same-namespace egress on client/admin/metrics ports | `false` |
| `externalSecrets.enabled` | Create ExternalSecret | `false` |

## CI Scenarios

The `ci/` directory covers:

- `standalone.yaml`
- `metrics.yaml`
- `dual-stack.yaml`
- `auth.yaml`
- `tls.yaml`
- `network-policy.yaml`
- `external-secrets.yaml`

## References

- [Apache ZooKeeper](https://zookeeper.apache.org)
- [ZooKeeper releases](https://zookeeper.apache.org/releases.html)
- [Official Docker image](https://hub.docker.com/_/zookeeper)

<!-- @AI-METADATA
last_updated: 2026-05-29
agent: codex
-->
