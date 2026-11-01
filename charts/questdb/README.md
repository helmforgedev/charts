# QuestDB Helm chart

QuestDB is a high-performance open-source database for time-series and real-time
analytics. This chart deploys one hardened QuestDB OSS instance with durable
storage, secure generated credentials, External Secrets support, network
isolation and optional Prometheus integration.

## Features and architecture

- fixed one-replica StatefulSet matching the QuestDB OSS single-node model;
- retained persistent storage for the complete `/var/lib/questdb` root;
- generated, existing, or External Secrets-managed protocol credentials;
- HTTP, PostgreSQL wire, optional legacy ILP TCP, and internal metrics Services;
- optional TLS-terminated Ingress, Gateway API HTTPRoute, and ServiceMonitor;
- per-protocol NetworkPolicy and a restricted, non-root security context.

See [DESIGN.md](DESIGN.md) for the Mermaid topology, ownership boundaries, and
intentional limitations.

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

## Configuration

Keep `persistence.enabled=true` for durable installations. Use
`persistence.existingClaim` to attach a pre-provisioned or restored volume, and
keep `questdb.existingSecret`, `pgPasswordKey`, and `httpPasswordKey` stable
across upgrades. `questdb.serverConfig` accepts documented QuestDB properties;
secret values belong in a Secret and `questdb.envFrom`, not plain values.

The chart distinguishes protocol exposure from application listeners:
`service.pgWireEnabled` and `service.ilpTcpEnabled` control Service ports while
QuestDB continues to own its internal protocol configuration. Review
[Configuration](docs/configuration.md) for all supported value groups.

## Examples

- [Simple installation](examples/simple.yaml)
- [Production installation](examples/production.yaml)
- [External Secrets](examples/external-secrets.yaml)

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

## Upgrade safety

Back up and verify the retained database before upgrading. Pin the target chart
version explicitly, review rendered changes, and preserve the PVC, authentication
Secret contract, UID/GID, and protocol settings. Use `--reuse-values` only when
you have audited old overrides against current defaults; with `--reset-values`,
restate every non-default persistence, Secret, storage, and exposure setting.

Never replace a retained PVC or generated Secret merely to complete an upgrade.
Restore and test in an isolated namespace before combining a chart upgrade with
a QuestDB major-version or storage migration.

## Troubleshooting

Inspect the StatefulSet rollout, Pod events, and QuestDB logs first. If the Pod
cannot mount the database, confirm that the selected PVC contains the complete
`/var/lib/questdb` tree and is writable by UID/GID 10001. Authentication errors
usually indicate a changed Secret name or key contract. For connectivity issues,
verify the relevant Service port and matching NetworkPolicy peer list; HTTP
health on port 9003 does not prove PostgreSQL or ILP reachability.

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
