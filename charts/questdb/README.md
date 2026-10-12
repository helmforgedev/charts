# QuestDB Helm chart

QuestDB is a high-performance open-source database for time-series and real-time
analytics. This chart deploys one hardened QuestDB OSS instance with durable
storage, secure generated credentials, External Secrets support, network
isolation and optional Prometheus integration.

## Install

```bash
helm install questdb oci://ghcr.io/helmforgedev/charts/questdb \
  --namespace questdb --create-namespace
```

The default installation creates and retains random PostgreSQL and HTTP
passwords. Read the HTTP password with:

```bash
kubectl get secret -n questdb questdb-questdb \
  -o jsonpath='{.data.http-password}' | base64 -d
```

Port-forward the authenticated Web Console and API:

```bash
kubectl port-forward -n questdb service/questdb-questdb 9000:9000
```

Open `http://localhost:9000` and authenticate as `admin` with the generated HTTP
password.

## Security Scan

Security scan results use the same Kubescape policy set as HelmForge CI.

Security Scan: questdb

| Framework                |       Score |
| ------------------------ | ----------: |
| MITRE                    | **100.00%** |
| NSA                      | **100.00%** |
| SOC 2                    | **100.00%** |
| Aggregate resource score | **100.00%** |

Kubescape reported zero failed resources at critical, high, medium or low
severity for the default rendered workload.

## Production contract

- QuestDB OSS is singleton software. This chart always deploys one replica and
  does not claim HA, replication or automated failover.
- The official image is pinned by tag and multi-architecture OCI digest.
- `/var/lib/questdb` is persistent and the chart-created PVC is retained.
- NFS and distributed filesystems are unsupported for QuestDB database storage.
- Native transport TLS is unavailable in OSS. Keep services internal or add TLS
  termination through Ingress, Gateway API or a service mesh.
- Production capacity planning starts at 4 CPU and 8Gi memory and requires fast
  storage sized for workload-specific IOPS.

## Credentials

Use an existing Secret with keys `pg-password` and `http-password`:

```yaml
questdb:
  existingSecret: questdb-auth
```

External Secrets Operator uses the canonical HelmForge `items[].spec` contract;
see [examples/external-secrets.yaml](examples/external-secrets.yaml).

## Protocols

| Interface | Port | Default | Notes |
|---|---:|---|---|
| HTTP, REST, Web Console, ILP HTTP, QWP | 9000 | enabled | Preferred ingestion path |
| PostgreSQL wire | 8812 | enabled | OSS transport has no native TLS |
| Legacy ILP TCP | 9009 | disabled | Enable with `service.ilpTcpEnabled` |
| Health and metrics | 9003 | internal | `/status`; `/metrics` when enabled |

## Observability

```yaml
metrics:
  enabled: true
  serviceMonitor:
    enabled: true
networkPolicy:
  metricsFrom:
    - namespaceSelector:
        matchLabels:
          kubernetes.io/metadata.name: monitoring
```

When NetworkPolicy is enabled, `metricsFrom` is required with a ServiceMonitor
so the Prometheus namespace can reach port 9003.

## Backup and restore

For a consistent OSS backup, execute `CHECKPOINT CREATE`, copy or snapshot the
volume, and then execute `CHECKPOINT RELEASE`. Restore into the same QuestDB
major version, verify the copy, and test upgrades separately. Raw live-volume
snapshots are not claimed to be consistent.

## Documentation

- [Configuration](docs/configuration.md)
- [Operations](docs/operations.md)
- [Security](docs/security.md)
- [Production example](examples/production.yaml)
- [Research](RESEARCH.md)
- [Design](DESIGN.md)

## Uninstall

```bash
helm uninstall questdb --namespace questdb
```

The default PVC and generated Secret remain because both contain recovery
material. Delete them only after verifying a backup and confirming data loss is
intended.
