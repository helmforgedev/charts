# Declarative provisioning

Grafana provisioning turns datasources, dashboards, and alerting configuration
into reviewable release inputs. This chart renders provisioning ConfigMaps and
mounts each document in the directory expected by Grafana.

## Datasources

`provisioning.datasources` is the complete Grafana datasource provisioning
document. Use stable `uid` fields so dashboard references survive renames.

```yaml
provisioning:
  datasources:
    apiVersion: 1
    deleteDatasources: []
    datasources:
      - name: Prometheus
        uid: prometheus
        type: prometheus
        access: proxy
        url: http://prometheus.monitoring.svc.cluster.local:9090
        isDefault: true
        editable: false
        jsonData:
          timeInterval: 30s
```

Secrets such as basic-auth passwords or datasource tokens should not be placed
in values. Create a Secret-backed environment variable and use Grafana's
supported environment expansion in `secureJsonData`, or manage the datasource
through a separate secret-aware delivery pipeline.

## Dashboard providers

The default provider watches `/var/lib/grafana/dashboards/helmforge` every 30
seconds. Replace the complete provider document when multiple folders or
policies are needed.

```yaml
provisioning:
  dashboardProviders:
    apiVersion: 1
    providers:
      - name: platform
        orgId: 1
        folder: Platform
        type: file
        disableDeletion: true
        editable: false
        updateIntervalSeconds: 30
        options:
          path: /var/lib/grafana/dashboards/helmforge
```

`disableDeletion: true` prevents file removal from deleting the dashboard.
Choose this intentionally: GitOps users often prefer `false` so the repository
remains authoritative.

## Dashboards

Each `provisioning.dashboards` key becomes `<key>.json`. The value is a native
dashboard JSON object, not an escaped string.

```yaml
provisioning:
  dashboards:
    platform-home:
      title: Platform home
      uid: platform-home
      schemaVersion: 41
      version: 1
      refresh: 30s
      panels: []
```

Keep dashboards reasonably sized. Kubernetes ConfigMaps have a total object
size limit. Large catalogs are better split across releases or delivered by a
dashboard-specific controller.

## Unified alerting

Each `provisioning.alerting` key becomes a YAML file under
`/etc/grafana/provisioning/alerting`.

```yaml
provisioning:
  alerting:
    contact-points:
      apiVersion: 1
      contactPoints:
        - orgId: 1
          name: operations
          receivers:
            - uid: operations-webhook
              type: webhook
              settings:
                url: ${ALERT_WEBHOOK_URL}
    policies:
      apiVersion: 1
      policies:
        - orgId: 1
          receiver: operations
          group_by: [grafana_folder, alertname]
```

Inject referenced secret values with `grafana.extraEnv` using `valueFrom`. Do
not commit webhook URLs or tokens to values files.

## Rollout behavior

The Deployment carries a checksum of the `provisioning` value tree. Any change
triggers a controlled rollout. Grafana also polls dashboard files, but the
rollout keeps datasource and alerting behavior deterministic across versions.

## Troubleshooting

Inspect rendered ConfigMaps:

```bash
kubectl get configmap -n observability grafana-grafana-provisioning -o yaml
kubectl get configmap -n observability grafana-grafana-dashboards -o yaml
```

Search logs for provisioning errors:

```bash
kubectl logs -n observability deployment/grafana-grafana | \
  grep -iE 'provision|dashboard|datasource|alert'
```

If a dashboard is missing, verify its provider path matches
`/var/lib/grafana/dashboards/helmforge`, its JSON has a stable `uid`, and the
combined ConfigMap size remains within Kubernetes limits.

<!-- @AI-METADATA
type: chart-docs
title: Grafana Provisioning
description: Datasource, dashboard, and alerting provisioning for Grafana
keywords: grafana, provisioning, dashboards, datasources, alerting
purpose: Operate Grafana configuration as code
scope: Chart
relations:
  - charts/grafana/README.md
  - charts/grafana/values.yaml
path: charts/grafana/docs/provisioning.md
version: 1.0
date: 2026-11-25
-->
