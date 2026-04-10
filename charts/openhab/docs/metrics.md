# Prometheus Metrics

openHAB exposes Prometheus-format metrics via the official **Metrics addon**.
The chart supports two scraping modes: classic pod annotations and ServiceMonitor
for Prometheus Operator.

## Architecture

```
openHAB (port 8080)
  └─> GET /rest/metrics/prometheus
        └─> Prometheus scraper (annotation-based or ServiceMonitor)
```

The metrics endpoint is served by openHAB itself — no sidecar or exporter required.

## Prerequisites

The **Metrics addon** must be installed in openHAB before the endpoint becomes active.

Install it via the openHAB UI:

1. Go to **Settings → Add-on Store → Integrations**
2. Find **Metrics** and click **Install**
3. Wait for the bundle to activate (~10 seconds)
4. Verify: `curl http://localhost:8080/rest/metrics/prometheus`

Or install it via the Karaf console:

```bash
# Port-forward to Karaf SSH (if enabled)
kubectl port-forward svc/<release>-karaf 8101:8101
ssh -p 8101 openhab@127.0.0.1

# Inside Karaf:
feature:install openhab-io-metrics
```

## Endpoint Details

| Property | Value |
|----------|-------|
| URL | `http://<pod>:8080/rest/metrics/prometheus` |
| Method | GET |
| Authentication | None required |
| Format | Prometheus text exposition format |
| Content-Type | `text/plain; version=0.0.4` |

## Enabling Metrics in the Chart

### Mode 1: Pod Annotations (no Prometheus Operator)

Adds `prometheus.io/*` annotations to the pod, enabling annotation-based
discovery by any Prometheus deployment that watches pod annotations.

```yaml
metrics:
  enabled: true
  podAnnotations:
    enabled: true
```

This renders the following annotations on the StatefulSet pod template:

```yaml
annotations:
  prometheus.io/scrape: "true"
  prometheus.io/path: /rest/metrics/prometheus
  prometheus.io/port: "8080"
```

### Mode 2: ServiceMonitor (Prometheus Operator)

Creates a `ServiceMonitor` CRD resource for use with
[kube-prometheus-stack](https://github.com/prometheus-community/helm-charts/tree/main/charts/kube-prometheus-stack)
or any Prometheus Operator installation.

```yaml
metrics:
  enabled: true
  podAnnotations:
    enabled: false   # disable annotations if using ServiceMonitor
  serviceMonitor:
    enabled: true
    interval: 60s
    scrapeTimeout: 10s
    # Must match your Prometheus instance's serviceMonitorSelector labels
    additionalLabels:
      release: prometheus
```

#### Custom Relabelings

```yaml
metrics:
  enabled: true
  serviceMonitor:
    enabled: true
    relabelings:
      - sourceLabels: [__meta_kubernetes_pod_label_app_kubernetes_io_instance]
        targetLabel: instance
    metricRelabelings:
      - sourceLabels: [__name__]
        regex: "jvm_.*"
        action: keep
```

## Prometheus Scrape Config (without Operator)

If you manage Prometheus configuration manually, add this job to your
`prometheus.yml`:

```yaml
scrape_configs:
  - job_name: openhab
    scrape_interval: 1m
    static_configs:
      - targets:
          - <release-service>.<namespace>.svc.cluster.local:8080
    metrics_path: /rest/metrics/prometheus
```

## Metrics Exposed

### openHAB Application Metrics

| Metric | Description |
|--------|-------------|
| `openhab_events_total` | Total event count per topic |
| `openhab_bundle_state` | OSGi bundle state (0=uninstalled, 32=active) |
| `openhab_thing_state` | Thing state (online/offline/unknown) |
| `openhab_rule_runs_total` | Rule execution count |
| `openhab_threadpool_*` | Threadpool size, active threads, queue size |

### JVM Metrics

| Metric | Description |
|--------|-------------|
| `jvm_memory_used_bytes` | JVM heap/non-heap usage |
| `jvm_gc_pause_seconds` | Garbage collection pause times |
| `jvm_threads_*` | Thread states and counts |
| `jvm_classes_loaded` | Number of loaded classes |
| `process_cpu_usage` | CPU usage of the JVM process |

## Verifying the Endpoint

```bash
# Port-forward the main HTTP service
kubectl port-forward svc/<release> 8080:8080

# Verify metrics are exposed
curl -s http://localhost:8080/rest/metrics/prometheus | head -20

# Expected output (after Metrics addon is installed):
# HELP jvm_memory_used_bytes ...
# TYPE jvm_memory_used_bytes gauge
# jvm_memory_used_bytes{area="heap",...} 1.23456789E8
# ...
```

If you get a 404, the Metrics addon is not yet installed or activated.

## Troubleshooting

### Endpoint returns 404

The Metrics addon is not installed or not yet active.
Install it via *Settings → Add-on Store → Integrations → Metrics*.

### No metrics appear in Prometheus

Check that the `prometheus.io/scrape: "true"` annotation is present on the pod:

```bash
kubectl get pod -l app.kubernetes.io/name=openhab \
  -o jsonpath='{.items[0].metadata.annotations}' | jq .
```

For ServiceMonitor, verify your Prometheus picks up the ServiceMonitor:

```bash
kubectl get servicemonitor <release>
# Check Prometheus UI → Status → Targets for the openhab job
```

### ServiceMonitor not discovered by Prometheus

The `additionalLabels` on the ServiceMonitor must match the `serviceMonitorSelector`
configured in your Prometheus instance. Check with:

```bash
kubectl get prometheus -o jsonpath='{.items[0].spec.serviceMonitorSelector}'
```

Then set matching labels:

```yaml
metrics:
  serviceMonitor:
    additionalLabels:
      release: prometheus   # or whatever your Prometheus expects
```

### Metrics addon shows as installed but endpoint still 404

Restart the bundle via Karaf console:

```bash
ssh -p 8101 openhab@127.0.0.1
# Inside Karaf:
bundle:list | grep metrics
bundle:restart <bundle-id>
```
