# Stalwart

Production-oriented Helm chart for the
[Stalwart](https://github.com/stalwartlabs/stalwart) mail and collaboration
server.

## Highlights

- Current Stalwart 0.16 DataStore-only bootstrap contract.
- Single-node RocksDB/PVC default and guarded external-store HA mode.
- Existing ConfigMap or Secret configuration and full environment `valueFrom`.
- Canonical External Secrets Operator integration.
- Split HTTP and mail Services with arbitrary additional listener ports.
- HTTPRoute, TCPRoute, and TLSRoute support, disabled by default.
- Optional declarative `stalwart-cli apply` Job using a mounted NDJSON plan.
- PDB, anti-affinity, topology spread, NetworkPolicy, dual-stack, and
  restricted-style security contexts.
- Prometheus annotations, optional ServiceMonitor, and extra manifests for
  VictoriaMetrics or another operator.

## Install

```bash
helm repo add helmforge https://repo.helmforge.dev
helm repo update
helm install stalwart helmforge/stalwart
```

The default is a one-replica development baseline using RocksDB and a 20 Gi
PVC. Supply `STALWART_RECOVERY_ADMIN` from an existing Secret to establish the
first administrative session; the chart never creates a default password.

```yaml
extraEnv:
  - name: STALWART_RECOVERY_ADMIN
    valueFrom:
      secretKeyRef:
        name: stalwart-recovery
        key: credential
```

## Configuration ownership

Stalwart 0.16 reads exactly one DataStore object from `config.json`. All other
settings are stored in that DataStore. Choose one bootstrap source:

```yaml
config:
  source: generated # generated | existingConfigMap | existingSecret
  dataStore:
    "@type": RocksDb
    path: /var/lib/stalwart
```

For an external PostgreSQL DataStore, use the upstream object schema and an
environment reference for its password. Credentials remain in Kubernetes
Secrets rather than the Helm release values.

See [storage and clustering](docs/storage-and-clustering.md) and
[declarative operations](docs/declarative-operations.md).

## HA

`replicaCount > 1` fails at template time when a local RocksDB/SQLite DataStore
or local PVC is selected. An HA deployment needs a shared external DataStore,
shared blob/search/in-memory backends, and a Coordinator. The latter four are
database-backed Stalwart objects and belong in an apply plan, not `config.json`.

The coordination topic is fixed to `stwt.agora`; dedicate it to one Stalwart
cluster. Zenoh peer-to-peer is not compiled into the standard image.

## Gateway API

One switch controls every route:

```yaml
gatewayAPI:
  enabled: true
```

HTTPRoute handles HTTP/JMAP. TCPRoute handles plaintext and STARTTLS protocols.
TLSRoute handles implicit-TLS passthrough with SNI. TCPRoute and some TLSRoute
controller behaviors require the Gateway API Experimental channel. The chart
does not create Gateways or certificates. See [Gateway API](docs/gateway-api.md).

## Monitoring

Stalwart serves Prometheus-format metrics at `/metrics/prometheus` when metrics
are enabled in its database-backed configuration. Add scrape annotations,
enable the optional ServiceMonitor, or provide a VMServiceScrape through
`extraManifests`.

## Security Scan

🟢 Security Scan: stalwart

| Framework | Score |
| --- | --- |
| MITRE + NSA + SOC2 | **85.85859%** |

> ✅ Security posture acceptable.

Kubescape reported no critical failures. The remaining default findings are
resource limits left for operators to size, opt-in NetworkPolicy, and the Helm
test pod's short-lived utility image. The Stalwart workload runs non-root with
a read-only root filesystem, RuntimeDefault seccomp, and only
`NET_BIND_SERVICE` added for the official binary's privileged listener ports.

## Documentation

- [Architecture and limitations](DESIGN.md)
- [Storage and clustering](docs/storage-and-clustering.md)
- [Declarative operations](docs/declarative-operations.md)
- [Gateway API](docs/gateway-api.md)
- [Operations](docs/operations.md)

## License

This chart is Apache-2.0 licensed. Stalwart Community is distributed under its
upstream AGPL-3.0 terms; operators are responsible for application licensing.
