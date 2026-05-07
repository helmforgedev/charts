# Memcached

Memcached for Kubernetes using the official `docker.io/library/memcached` image.

The chart supports a simple standalone cache for development and a distributed set of independent Memcached nodes for production workloads where clients perform sharding or consistent hashing.

## Install

### HTTPS repository

```bash
helm repo add helmforge https://repo.helmforge.dev
helm repo update
helm install memcached helmforge/memcached -f values.yaml
```

### OCI registry

```bash
helm install memcached oci://ghcr.io/helmforgedev/helm/memcached -f values.yaml
```

## What this chart covers

- official Memcached image with pinned default tag
- `standalone` and `distributed` topologies
- stable StatefulSet pod DNS through a headless Service
- client Service with optional dual-stack fields
- optional ASCII auth file or SASL startup mode
- optional TLS using an existing Kubernetes TLS Secret
- optional extstore for flash-backed cache extension
- optional Prometheus memcached exporter sidecar
- optional `ServiceMonitor` and `PrometheusRule`
- optional `NetworkPolicy` ingress, metrics, and egress rules
- optional `PodDisruptionBudget` and HPA
- optional External Secrets Operator v1 integration
- hardened default pod and container security contexts
- extension points through `extraEnv`, `extraVolumes`, `extraContainers`, and `extraManifests`

## Topologies

| Architecture | Contract | Typical use |
|--------------|----------|-------------|
| `standalone` | One Memcached pod behind one Service. | Development, tests, small non-critical caches. |
| `distributed` | Multiple independent Memcached pods behind one Service and stable pod DNS. | Production caches where the client library handles node distribution. |

Memcached does not replicate cache entries between nodes. In distributed mode, use client-side consistent hashing when cache hit ratio matters during scale events.

## Development quick start

```yaml
architecture: standalone
replicaCount: 1
```

```bash
helm install memcached helmforge/memcached -f values.yaml
```

Test from inside the cluster:

```bash
kubectl run memcached-client --rm -it --restart=Never \
  --image=docker.io/library/busybox:1.37.0 -- \
  sh -ec "printf 'set hello 0 60 5\r\nworld\r\nget hello\r\nquit\r\n' | nc memcached 11211"
```

## Production path

Production-ready deployments are possible through values. The defaults stay development-friendly because many users first need a disposable cache for local and CI environments.

Start from [examples/production.yaml](examples/production.yaml) and adapt:

- use `architecture: distributed` with at least three replicas
- size `memcached.memoryLimitMB` and Kubernetes memory limits together
- set explicit CPU and memory requests
- disable `flush_all` with `memcached.disableFlushAll=true`
- enable authentication or place Memcached behind trusted network boundaries
- enable TLS when clients and Memcached exchange data across untrusted networks
- enable `networkPolicy.enabled` when the cluster CNI enforces policies
- keep `serviceAccount.automountServiceAccountToken=false`
- enable metrics and alerts
- use topology spread constraints or anti-affinity across nodes

## Authentication

Authentication is disabled by default. Memcached authentication is not a full authorization system; it is a connection gate.

ASCII auth file mode:

```yaml
auth:
  enabled: true
  mode: ascii
  username: app
  password: change-me
```

Existing Secret:

```yaml
auth:
  enabled: true
  existingSecret: memcached-auth
  authFileKey: authfile
```

The Secret key must contain lines in Memcached auth-file format:

```text
app:change-me
```

ASCII auth forces Memcached to start with ASCII protocol because upstream disables binary protocol when `-Y` is active.
Clients authenticate by sending a fake `set` command with a `username password` payload before regular cache commands.
The payload byte length must match the credentials string.

SASL mode starts Memcached with `-S` and should be used only with clients that support binary protocol SASL.
The official Memcached image does not build a SASL database from plain username/password values at startup, so
SASL requires an existing Secret with a `memcached.conf` file and a prepared sasldb file:

```yaml
auth:
  enabled: true
  mode: sasl
  existingSecret: memcached-sasl
  sasl:
    configKey: memcached.conf
    databaseKey: memcachedsasldb

memcached:
  protocol: binary
```

The `memcached.conf` file should point at the mounted database path, for example:

```text
mech_list: plain
sasldb_path: /sasl2/memcachedsasldb
```

## External Secrets

External Secrets Operator integration is optional and uses `external-secrets.io/v1`.

```yaml
auth:
  enabled: true
  existingSecret: memcached-auth

externalSecrets:
  enabled: true
  secretStoreRef:
    name: platform-secrets
    kind: ClusterSecretStore
  data:
    - secretKey: authfile
      remoteRef:
        key: memcached/auth
        property: authfile
```

## TLS

TLS uses an existing Secret. The chart does not generate private keys.

```yaml
tls:
  enabled: true
  existingSecret: memcached-tls
  certKey: tls.crt
  keyKey: tls.key
  caKey: ca.crt
  verifyMode: "0"
  minVersion: "2"
```

`verifyMode` and `minVersion` map to Memcached OpenSSL extended options. `tls.caKey` is optional and should be set only when the Secret contains a CA file.
For mutual TLS, provide a CA certificate and set the verify mode required by your client policy.

## Extstore

Extstore allows Memcached to keep larger or colder objects on a local file-backed cache path. It is cache storage, not durable application data.

Ephemeral extstore:

```yaml
extstore:
  enabled: true
  size: 4G
```

PVC-backed extstore:

```yaml
extstore:
  enabled: true
  persistence:
    enabled: true
    size: 20Gi
```

Do not combine PVC-backed extstore with HPA. The chart blocks that combination because each PVC is pod-local.

## Autoscaling

HPA is available only for `architecture=distributed`. Standalone mode is intentionally fixed to one pod.
When CPU utilization scaling is enabled, set `resources.requests.cpu`; when memory utilization scaling is
enabled, set `resources.requests.memory`. Kubernetes needs those requests to compute utilization percentages.

## Metrics

Metrics are exposed through a sidecar exporter.

```yaml
metrics:
  enabled: true
  serviceMonitor:
    enabled: true
```

The exporter scrapes `localhost:11211` from the pod. Validate exporter compatibility before combining it with strict auth or TLS-only listener policies.

The upstream exporter supports TLS but does not support Memcached authentication. The chart blocks `metrics.enabled=true` together with `auth.enabled=true`.

Exporter with Memcached TLS:

```yaml
tls:
  enabled: true
  existingSecret: memcached-tls

metrics:
  enabled: true
  memcachedTLS:
    enabled: true
```

## Networking

The chart creates:

- `<release>-memcached-headless` for StatefulSet pod DNS
- `<release>-memcached` for clients
- `<release>-memcached-metrics` when metrics are enabled

Dual-stack Services:

```yaml
service:
  ipFamilyPolicy: PreferDualStack
  ipFamilies:
    - IPv4
    - IPv6
```

NetworkPolicy:

```yaml
networkPolicy:
  enabled: true
  egress:
    enabled: true
    allowSameNamespace: true
    allowDNS: true
```

## Important values

| Value | Default | Description |
|-------|---------|-------------|
| `architecture` | `standalone` | `standalone` or `distributed`. |
| `replicaCount` | `1` | Number of Memcached pods. Must be `1` for standalone. |
| `image.repository` | `docker.io/library/memcached` | Official Memcached image. |
| `image.tag` | `1.6.41` | Pinned image tag. |
| `memcached.memoryLimitMB` | `64` | Memcached item memory limit passed to `-m`. |
| `memcached.maxConnections` | `1024` | Maximum simultaneous connections. |
| `memcached.threads` | `4` | Worker threads. |
| `memcached.maxItemSize` | `1m` | Maximum item size passed to `-I`. |
| `auth.enabled` | `false` | Enables auth file mounting. |
| `auth.mode` | `ascii` | `ascii` or `sasl`. |
| `auth.sasl.configKey` | `memcached.conf` | Secret key containing SASL configuration for SASL mode. |
| `auth.sasl.databaseKey` | `memcachedsasldb` | Secret key containing a prepared SASL database for SASL mode. |
| `tls.enabled` | `false` | Enables TLS startup flags. |
| `extstore.enabled` | `false` | Enables Memcached extstore options. |
| `metrics.enabled` | `false` | Enables Prometheus exporter sidecar and metrics Service. |
| `metrics.memcachedTLS.enabled` | `false` | Enables TLS when the exporter scrapes Memcached. |
| `networkPolicy.enabled` | `false` | Enables NetworkPolicy resources. |
| `networkPolicy.egress.allowSameNamespace` | `true` | Allows cache and metrics responses to same-namespace clients. |
| `service.ipFamilyPolicy` | `""` | Optional Kubernetes Service dual-stack policy. |
| `externalSecrets.enabled` | `false` | Renders External Secrets Operator v1 resource. |
| `serviceAccount.automountServiceAccountToken` | `false` | Keeps Kubernetes API token disabled by default. |

## Operations

Scale distributed mode:

```bash
helm upgrade memcached helmforge/memcached \
  --reuse-values \
  --set architecture=distributed \
  --set replicaCount=3
```

Inspect endpoints:

```bash
kubectl get endpoints memcached
kubectl get pods -l app.kubernetes.io/name=memcached
```

Check logs:

```bash
kubectl logs statefulset/memcached -c memcached
```

## Design

Read [DESIGN.md](DESIGN.md) for architecture diagrams, production trade-offs, and non-goals.

<!-- @AI-METADATA
type: chart-readme
title: Memcached Helm Chart
description: Documentation for the HelmForge Memcached chart
keywords: memcached, cache, kubernetes, helm, tls, extstore, metrics, external-secrets
purpose: Explain install, configuration, production path, and operations
scope: Chart Documentation
relations:
  - charts/memcached/Chart.yaml
  - charts/memcached/values.yaml
  - charts/memcached/DESIGN.md
path: charts/memcached/README.md
version: 1.0
date: 2026-05-06
-->
