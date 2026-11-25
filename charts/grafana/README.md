# Grafana

Grafana observability dashboards with declarative provisioning and guarded high
availability.

## Features

- pinned official multi-architecture Grafana OSS image;
- durable single-replica SQLite default with retained storage;
- fail-fast PostgreSQL/MySQL requirements for active-active replicas;
- declarative datasources, dashboard providers, dashboards, and alerting;
- administrator and database credentials through managed or existing Secrets;
- native External Secrets Operator resources;
- secure non-root, read-only filesystem defaults;
- Ingress and canonical multi-route Gateway API exposure;
- NetworkPolicy, PodDisruptionBudget, dual-stack Service, and ServiceMonitor;
- application listener overrides wired to the real Grafana process.

## Installation

### Helm repository

```bash
helm repo add helmforge https://repo.helmforge.dev
helm repo update
helm install grafana helmforge/grafana --namespace observability --create-namespace
```

### OCI registry

```bash
helm install grafana oci://ghcr.io/helmforgedev/helm/grafana \
  --version 1.0.0 \
  --namespace observability \
  --create-namespace
```

Read the generated administrator password:

```bash
kubectl get secret -n observability grafana-grafana-admin \
  -o jsonpath='{.data.admin-password}' | base64 --decode
```

Use port forwarding for a private first login:

```bash
kubectl port-forward -n observability svc/grafana-grafana 3000:80
```

Open `http://127.0.0.1:3000` and sign in as `admin`.

## Quick start

Use an existing Secret in any durable environment:

```yaml
admin:
  existingSecret: grafana-admin

persistence:
  enabled: true
  size: 20Gi
```

Create the Secret before installation:

```bash
kubectl create secret generic grafana-admin \
  --namespace observability \
  --from-literal=admin-user=platform-admin \
  --from-literal=admin-password='replace-with-a-secret-manager-value'
```

## Deployment topologies

### Single replica with SQLite

The default topology is one replica backed by a retained PVC. It is suitable
for small teams and straightforward recovery. `Recreate` upgrades prevent two
Grafana processes from sharing the same SQLite file.

```yaml
replicaCount: 1
database:
  type: sqlite3
persistence:
  enabled: true
  accessModes: [ReadWriteOnce]
  size: 20Gi
```

### Active-active with PostgreSQL

Grafana HA requires a shared PostgreSQL or MySQL database. The database is an
external operational dependency and is not installed by this chart.

```yaml
replicaCount: 3
database:
  type: postgres
  host: grafana-postgresql.database.svc.cluster.local
  port: 5432
  name: grafana
  user: grafana
  existingSecret: grafana-database
  passwordKey: password
  sslMode: verify-full
persistence:
  enabled: false
pdb:
  enabled: true
```

The chart rejects multiple replicas with SQLite and rejects shared
`ReadWriteOnce` storage for multiple replicas.

## Declarative provisioning

Provision a Prometheus datasource:

```yaml
provisioning:
  datasources:
    apiVersion: 1
    datasources:
      - name: Prometheus
        uid: prometheus
        type: prometheus
        access: proxy
        url: http://prometheus.monitoring.svc.cluster.local:9090
        isDefault: true
        editable: false
```

Provision dashboards as native JSON objects:

```yaml
provisioning:
  dashboards:
    platform-home:
      title: Platform home
      uid: platform-home
      schemaVersion: 41
      version: 1
      panels: []
```

See [Provisioning](docs/provisioning.md) for dashboard providers, alerting
documents, and GitOps behavior.

## Exposure

### Ingress

```yaml
grafana:
  rootUrl: https://grafana.example.com
ingress:
  enabled: true
  ingressClassName: nginx
  hosts:
    - host: grafana.example.com
      paths:
        - path: /
          pathType: Prefix
  tls:
    - secretName: grafana-tls
      hosts: [grafana.example.com]
networkPolicy:
  ingress:
    extraFrom:
      - namespaceSelector:
          matchLabels:
            kubernetes.io/metadata.name: ingress-nginx
```

### Gateway API

```yaml
gatewayAPI:
  enabled: true
  httpRoutes:
    - parentRefs:
        - name: public
          namespace: gateway-system
      hostnames:
        - grafana.example.com
networkPolicy:
  ingress:
    extraFrom:
      - namespaceSelector:
          matchLabels:
            kubernetes.io/metadata.name: gateway-system
```

See [Production operations](docs/production.md) for TLS, database, and routing
guidance.

## External Secrets

The chart can render External Secrets Operator `ExternalSecret` resources. Set
`admin.existingSecret` to the exact target Secret so Grafana and ESO have one
credential owner.

```yaml
admin:
  existingSecret: grafana-admin
externalSecrets:
  enabled: true
  items:
    - name: admin
      fullnameOverride: grafana-admin
      spec:
        secretStoreRef:
          name: production
          kind: ClusterSecretStore
        target:
          name: grafana-admin
          creationPolicy: Owner
        dataFrom:
          - extract:
              key: grafana/admin
```

See [Security](docs/security.md) for Secret ownership and NetworkPolicy.

## Plugins

Plugins are installed through Grafana's supported preinstall mechanism. Every
plugin must include an exact version:

```yaml
plugins:
  preinstall:
    - grafana-clock-panel@2.1.8
```

Plugin installation requires egress. Pin versions, test upgrades, and avoid
unsigned plugins unless the security risk is explicitly accepted.

## Monitoring

Grafana exposes Prometheus metrics on `/metrics` using the same HTTP Service.

```yaml
metrics:
  serviceMonitor:
    enabled: true
    labels:
      release: monitoring
networkPolicy:
  ingress:
    extraFrom:
      - namespaceSelector:
          matchLabels:
            kubernetes.io/metadata.name: monitoring
```

The Prometheus Operator CRD must exist before installing a ServiceMonitor.

## Configuration reference

| Parameter | Description | Default |
|---|---|---:|
| `replicaCount` | Grafana replicas | `1` |
| `image.repository` | Official image | `docker.io/grafana/grafana` |
| `image.tag` | Pinned image tag | `13.3.2` |
| `grafana.port` | Real HTTP listener | `3000` |
| `grafana.rootUrl` | Browser-visible URL | `""` |
| `grafana.serveFromSubPath` | Serve from root URL subpath | `false` |
| `grafana.ini` | Extra INI sections | `{}` |
| `admin.existingSecret` | Administrator Secret | `""` |
| `database.type` | `sqlite3`, `postgres`, or `mysql` | `sqlite3` |
| `database.existingSecret` | External DB password Secret | `""` |
| `persistence.enabled` | Persist `/var/lib/grafana` | `true` |
| `persistence.retain` | Keep generated PVC on uninstall | `true` |
| `provisioning.datasources` | Datasource document | `{}` |
| `provisioning.dashboardProviders` | Provider document | HelmForge provider |
| `provisioning.dashboards` | Dashboard JSON objects | `{}` |
| `provisioning.alerting` | Alerting YAML documents | `{}` |
| `plugins.preinstall` | Pinned plugins | `[]` |
| `ingress.enabled` | Create Ingress | `false` |
| `gatewayAPI.enabled` | Create HTTPRoutes | `false` |
| `metrics.serviceMonitor.enabled` | Create ServiceMonitor | `false` |
| `networkPolicy.enabled` | Isolate ingress | `true` |
| `networkPolicy.egress.enabled` | Isolate egress | `false` |

The complete typed contract is in [values.yaml](values.yaml) and
[values.schema.json](values.schema.json).

## Backup and restore

Back up all state domains together:

- SQLite or the external PostgreSQL/MySQL database;
- chart values and referenced Secrets;
- plugins under `/var/lib/grafana/plugins` when not reproducibly installed;
- declarative provisioning source.

Stop Grafana before directly copying `grafana.db`, or use an
application-consistent storage snapshot. For external databases, use native
database backup tools and test restoration independently.

## Upgrade

```bash
helm repo update
helm upgrade grafana helmforge/grafana \
  --namespace observability \
  --reuse-values
```

Before upgrading, review Grafana release notes, confirm plugin compatibility,
back up metadata, render the release with the new chart, and test it in a
non-production namespace.

## Troubleshooting

Check rollout and logs:

```bash
kubectl rollout status -n observability deployment/grafana-grafana
kubectl logs -n observability deployment/grafana-grafana --tail=200
kubectl get events -n observability --sort-by=.lastTimestamp
```

Call health through the Service:

```bash
kubectl run grafana-health --rm -i --restart=Never -n observability \
  --image=curlimages/curl:8.17.0 -- \
  curl --fail --silent http://grafana-grafana/api/health
```

Common causes include an unwritable PVC, invalid external database TLS mode,
incorrect root URL, blocked datasource/plugin egress, and malformed
provisioning documents.

## Security

The chart uses a non-root UID/GID, read-only root filesystem, dropped Linux
capabilities, RuntimeDefault seccomp, no privilege escalation, and no mounted
Kubernetes API token. Review [Security](docs/security.md) before production.

### Security scan

🟢 Security Scan: grafana

| Framework | Score |
|---|---:|
| MITRE + NSA + SOC2 | 100.000000% |

✅ Security posture acceptable.

## Examples

- [Simple durable deployment](examples/simple.yaml)
- [Production HA](examples/production.yaml)
- [Gateway API](examples/gateway-api.yaml)
- [Provisioned observability](examples/provisioned-observability.yaml)

## Non-goals

This chart does not operate a database, fetch mutable dashboards from the
internet, grant Grafana Kubernetes discovery RBAC, or claim that PVC retention
is a backup.

## Additional resources

- [Grafana documentation](https://grafana.com/docs/grafana/latest/)
- [Grafana source](https://github.com/grafana/grafana)
- [HelmForge Grafana guide](https://helmforge.dev/docs/charts/grafana)

<!-- @AI-METADATA
type: chart-readme
title: Grafana Chart
description: Production-ready Grafana with declarative provisioning and guarded HA
keywords: grafana, observability, dashboards, monitoring, kubernetes
purpose: Install and operate the HelmForge Grafana chart
scope: Chart
relations:
  - charts/grafana/Chart.yaml
  - charts/grafana/values.yaml
  - charts/grafana/DESIGN.md
path: charts/grafana/README.md
version: 1.0
date: 2026-11-25
-->
