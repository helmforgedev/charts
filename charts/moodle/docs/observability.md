# Moodle observability

## Authenticated application metrics

Enable `metrics.enabled` to install the upstream
[tool_monitoring plugin](https://github.com/daniil-berg/moodle-tool_monitoring)
1.1.0 and its Prometheus exporter. The archive is pinned to commit
`23c45f66b6c3ed409b0749017b3387c1744016cc` and verified with SHA-256 before
extraction. Set `metrics.plugin.mode: image` when both plugins are already
included in your immutable application image.

The exporter exposes course counts, user account counts, online users,
in-progress quizzes and overdue scheduled/ad-hoc tasks. Configure the enabled
families through `metrics.enabledMetrics`. The chart reconciles these five
built-in families during startup; additional custom metrics remain operator-managed.

```yaml
metrics:
  enabled: true
  existingSecret: moodle-monitoring
  serviceMonitor:
    enabled: true
    labels:
      release: kube-prometheus-stack
  prometheusRule:
    enabled: true
    labels:
      release: kube-prometheus-stack
```

Create the existing Secret in the release namespace with a nonempty `token` key.
Alternatively, omit `existingSecret` to generate a retained token Secret. An
existing Secret can be populated by your secret manager. Tokens are mounted as
files, never embedded in ConfigMaps or values. Secret projections and Prometheus
configuration reloads are eventually consistent; allow propagation after rotation.

Prometheus Operator and its CRDs must already exist. Configure its ServiceMonitor
and PrometheusRule selectors to match the labels above and include the Moodle
namespace. The chart does not install Prometheus itself.

The dedicated ClusterIP Service listens on port 9090. Only
`/r.php/monitoringexporter_prometheus/metrics` is allowed on that listener, with
Bearer authentication. Missing and invalid tokens return 403. The application
listener rejects the monitoring route, including requests with valid tokens.
Public Ingress and HTTPRoute resources do not expose the metrics Service.

When `networkPolicy.enabled` is true, restrict `metrics.ingressFrom` to the
actual Prometheus namespace and pod labels. An empty list permits internal
clients to reach the authenticated listener. The default scrape interval is
60 seconds; these metrics query Moodle's database, so measure database impact
before shortening it.

## Lifecycle on existing installations

A fresh installation registers both plugins automatically. Adding or updating
the plugin on an existing database requires the documented maintenance upgrade
workflow: drain cron and workers, enable maintenance, run the upgrade Job with
`metrics.enabled: true`, then disable maintenance and resume the application.
Normal startup refuses a missing or mismatched plugin database version.

Keep metrics enabled throughout those maintenance operations. Disabling the
ServiceMonitor only stops discovery. Setting `metrics.enabled: false` does not
uninstall registered Moodle plugins: properly uninstall both plugins through
Moodle's supported administration workflow before removing their chart code.

## Queries and alerts

Every replica reports the same global database counts. Deduplicate replicas
before summing dimensions; for example, total courses for one release:

```promql
sum(max by (visible) (tool_monitoring_courses{namespace="learning",service="moodle-metrics"}))
```

The optional rules report an unavailable metrics target after five minutes and
overdue tasks persisting for fifteen minutes. The overdue-task rule is omitted
when its metric family is disabled. These rules describe exporter availability
and task backlog; they do not replace HTTP probes or infrastructure alerts.

PostgreSQL and Redis retain their own independent HelmForge exporter settings
(`postgresql.metrics` and `redis.metrics`). Enable their ServiceMonitors separately
when database and cache infrastructure metrics are also required.

## Runtime evidence

The metrics CI scenario creates a temporary Prometheus instance through the
Operator. The application smoke hook checks rejected credentials, authenticated
exposition, public/private listener isolation, ServiceMonitor discovery and
healthy rule evaluation. It creates a real temporary course, waits for its
count to appear in Prometheus, removes it and verifies the original count.

For a fresh disposable lab, install the official Prometheus Operator bundle
before running the full chart gate. This is a lab prerequisite, not a chart
dependency. Use only the designated local Kubernetes context:

```bash
kubectl --context k3d-helmforge-tests-wsl apply --server-side -f \
  https://raw.githubusercontent.com/prometheus-operator/prometheus-operator/v0.94.0/bundle.yaml
kubectl --context k3d-helmforge-tests-wsl -n default rollout status \
  deployment/prometheus-operator --timeout=180s
make validate-chart CHART=moodle TIMEOUT=900
```

If an Operator is already installed, verify it watches the validation namespace
instead of installing another controller. The validated lab used Operator
0.94.0 and the fixture pins Prometheus 3.14.0 by image digest.
