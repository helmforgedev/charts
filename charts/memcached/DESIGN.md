# Memcached Chart Design

## Scope

This chart deploys Memcached on Kubernetes using the official image. It focuses on predictable cache infrastructure, secure-by-option production settings,
and integration points commonly required by platform teams.

It does not turn Memcached into a replicated database. Cache distribution remains a client responsibility.

## Architecture

### Standalone

```text
Applications
     |
     v
+---------------------+
| Service             |
| <release>-memcached |
+---------------------+
     |
     v
+---------------------+
| StatefulSet         |
| memcached-0         |
+---------------------+
     |
     v
+---------------------+
| memory cache        |
+---------------------+
```

Standalone is intentionally small. It is appropriate for development, CI, or production cases where a single cache instance is acceptable.

### Distributed

```text
                       client-side hashing
Applications -------------------------------------+
     |                                            |
     v                                            v
+---------------------+                 +------------------------+
| Client Service      |                 | Headless Service       |
| <release>-memcached |                 | stable pod DNS         |
+---------------------+                 +------------------------+
     |                                            |
     +-------------------+------------------------+
                         |
       +-----------------+-----------------+
       v                 v                 v
+-------------+   +-------------+   +-------------+
| pod-0       |   | pod-1       |   | pod-2       |
| independent |   | independent |   | independent |
| cache node  |   | cache node  |   | cache node  |
+-------------+   +-------------+   +-------------+
```

Memcached does not replicate entries. A production client should use consistent hashing or another distribution strategy and tolerate cache misses during node replacement.

### Secure Integration Flow

```text
External secret store
        |
        | ExternalSecret (optional)
        v
Kubernetes Secret <------------------ cert-manager / platform PKI
  - authfile or SASL files           - TLS Secret
        |                                  |
        +----------------+-----------------+
                         v
                Memcached StatefulSet
                  - auth or SASL mount
                  - TLS file mount
                  - read-only rootfs
                  - no API token by default
```

The chart can generate ASCII auth-file Secrets from values. SASL mode uses the official Memcached `-S`
startup path and therefore requires an externally prepared Secret with a SASL config file and sasldb file.
CA material is optional, and the chart does not generate certificates.

### Observability Flow

```text
Memcached container
        |
        | localhost:11211
        v
Exporter sidecar
        |
        | :9150 /metrics
        v
Metrics Service --> ServiceMonitor --> Prometheus
```

The exporter is optional and disabled by default. It supports TLS to Memcached, but it does not
support Memcached authentication. The chart blocks auth plus metrics to avoid a permanently failing
exporter. When TLS scraping is enabled, the exporter verifies the Memcached certificate with a
Service DNS server name by default while still connecting to the local pod address.

## Production Controls

The default values are designed for a disposable development cache. A production deployment should normally configure:

- `architecture=distributed` and `replicaCount>=3`
- memory sizing aligned between `memcached.memoryLimitMB` and container memory limits
- CPU and memory requests
- `memcached.disableFlushAll=true`
- explicit topology spread constraints or pod anti-affinity
- authentication, TLS, or strict NetworkPolicy depending on the trust boundary
- `networkPolicy.enabled=true` when the CNI enforces policies
- `metrics.enabled=true` with alert rules
- `pdb.enabled=true`
- `serviceAccount.automountServiceAccountToken=false`
- External Secrets Operator for production credentials

## Design Decisions

- Official image only: no vendor-specific Memcached image or Bitnami dependency.
- No `latest` tags: image tags are pinned and appVersion tracks the upstream version.
- StatefulSet over Deployment: stable pod identities and headless DNS help clients that address individual cache nodes.
- No Chart.lock: the chart has no dependencies.
- Extstore is optional: extstore can improve cache capacity but is not durable storage.
- No Gateway API: expose Memcached with a Service when an external endpoint is required.
- Secrets are explicit: production users can supply existing Secrets or External Secrets instead of committing credentials to values.
- TLS avoids TCP probes: kubelet TCP probes do not perform a TLS handshake and produce noisy Memcached accept logs.
- StatefulSet names reserve space for Kubernetes-generated pod and controller labels, so long release names are truncated before suffixed Service names are built.
- Dual-stack Services also adjust the default Memcached bind address to `0.0.0.0,::`, while preserving explicit `memcached.listenAddress` overrides.

## Explicit Non-Goals

- replicated cache data
- automatic sharding or consistent hashing
- Memcached operator behavior
- persistent application data
- certificate generation
- installing Prometheus Operator CRDs

## Related Documents

- [README.md](README.md)
- [examples/production.yaml](examples/production.yaml)
- [values.yaml](values.yaml)
