# Production operations

## Choose the metadata topology

Use SQLite only for one Grafana replica. The database file lives on the data
PVC and the Deployment uses `Recreate` upgrades. This is simple and durable but
does not provide active-active application availability.

Use PostgreSQL or MySQL for multiple replicas. Every Grafana pod must connect
to the same database. Operate that database with independent backups, upgrades,
capacity planning, monitoring, and availability objectives.

```yaml
replicaCount: 3
database:
  type: postgres
  host: grafana-postgresql.database.svc.cluster.local
  port: 5432
  name: grafana
  user: grafana
  existingSecret: grafana-database
  sslMode: verify-full
persistence:
  enabled: false
pdb:
  enabled: true
```

If local plugin files must be shared between replicas, use a storage system
that safely supports `ReadWriteMany`. Prefer reproducible pinned plugin
installation so application pods remain replaceable.

## Edge and root URL

Grafana uses its root URL for redirects, links, OAuth callbacks, and public
asset locations. Set it to the exact browser-visible URL.

```yaml
grafana:
  rootUrl: https://observability.example.com/grafana
  serveFromSubPath: true
```

The proxy must preserve the expected host and scheme headers. Terminate TLS at
Ingress or Gateway and redirect plaintext traffic at the edge.

## High availability details

Grafana application replicas are active-active with a shared database. Grafana
Alerting has an additional peer coordination model. If alert notification
deduplication matters, configure the documented alerting HA peer or Redis
topology through `grafana.ini`, expose the necessary peer ports with explicit
resources, and test failover. This chart does not invent an alerting topology
because peer discovery and network policy are cluster-specific.

## Disruption and scheduling

Enable the PDB only with multiple replicas. Add topology spread or anti-affinity
so replicas do not share one node or failure zone.

```yaml
pdb:
  enabled: true
  maxUnavailable: 1
topologySpreadConstraints:
  - maxSkew: 1
    topologyKey: topology.kubernetes.io/zone
    whenUnsatisfiable: DoNotSchedule
    labelSelector:
      matchLabels:
        app.kubernetes.io/name: grafana
```

## Capacity

Start with the chart defaults, then measure dashboard concurrency, alert rule
evaluation, plugin behavior, and datasource latency. Memory pressure can cause
slow queries and restarts. Keep requests representative enough for scheduling
and set limits only after observing real workloads.

## Backup scope

Back up the Grafana database, configuration, provisioning source, and any
non-reproducible plugins. For SQLite, stop Grafana before copying `grafana.db`
or use an application-consistent volume snapshot. For PostgreSQL/MySQL, use
native logical or physical backup procedures.

PVC retention protects against accidental Helm uninstall, not storage failure,
corruption, operator error, or disaster. Test a complete restore into another
namespace and verify login, datasources, dashboards, alert rules, and plugins.

## Upgrade procedure

1. Review Grafana release notes and breaking changes.
2. Confirm every pinned plugin supports the target Grafana version.
3. Back up the database and provisioning source.
4. Render the upgrade with current production values.
5. Test the upgrade and rollback in a non-production namespace.
6. Upgrade one environment and verify `/api/health`, logs, dashboards, alerts,
   and datasource queries before wider rollout.

```bash
helm repo update
helm upgrade grafana helmforge/grafana \
  --namespace observability \
  --reuse-values \
  --wait \
  --timeout 10m
```

## Egress isolation

Grafana may need DNS, database, datasource, SMTP, OAuth/OIDC, webhook, rendering,
and plugin endpoints. Build the complete dependency inventory before enabling
egress isolation. The chart accepts explicit Kubernetes NetworkPolicy rules in
`networkPolicy.egress.extraEgress`.

## Operational checks

```bash
kubectl rollout status -n observability deployment/grafana-grafana
kubectl get pods,pvc,svc -n observability -l app.kubernetes.io/instance=grafana
kubectl logs -n observability deployment/grafana-grafana --tail=200
kubectl get events -n observability --sort-by=.lastTimestamp
```

The health response must show database status `ok`. A healthy HTTP process with
an unhealthy database is not ready for production traffic.

<!-- @AI-METADATA
type: chart-docs
title: Grafana Production Operations
description: HA, backup, networking, capacity, and upgrade guidance
keywords: grafana, production, high-availability, backup, upgrade
purpose: Define the production operating boundary for Grafana
scope: Chart
relations:
  - charts/grafana/README.md
  - charts/grafana/DESIGN.md
path: charts/grafana/docs/production.md
version: 1.0
date: 2026-11-25
-->
