# Observability

Envoy Gateway provides comprehensive observability through Prometheus metrics, Grafana dashboards, and structured access logs.

## Architecture

```
EG-managed Proxy Pods → Metrics (dynamic) ─┐
                                            ├→ Prometheus → Grafana
Controller → Metrics (8081) ───────────────┘

EG-managed Proxy Pods → Access Logs → stdout
```

Proxy pods are created dynamically by the EG operator when a `Gateway` resource exists. They are named `envoy-<namespace>-<gateway-name>-<uid>` and do not have a fixed service name, so proxy scraping must use pod-level service discovery.

## Components

- **Prometheus Metrics**: Scraped from the controller (port 8081); proxy pods are discovered dynamically
- **ServiceMonitor**: 1 ServiceMonitor for the controller (proxy service names are dynamic)
- **PrometheusRule**: 6 pre-configured alerts for production monitoring
- **Grafana Dashboards**: Official Envoy Gateway dashboards (ConfigMaps)
- **Access Logs**: Request/response logging in JSON or text format

## Enabling Observability

### Metrics Only

```yaml
monitoring:
  enabled: true
  prometheus:
    serviceMonitor: true
```

This creates ServiceMonitor resources for Prometheus Operator.

### Metrics + Alerts

```yaml
monitoring:
  enabled: true
  prometheus:
    serviceMonitor: true
    prometheusRule: true
```

Includes 6 production-ready alerts:
- **ProxyHighMemoryUsage** — Proxy memory > 80%
- **ProxyHighCPUUsage** — Proxy CPU > 80%
- **ControllerHighMemoryUsage** — Controller memory > 80%
- **ControllerDown** — Controller unavailable
- **ProxyHighConnectionRate** — Unusual connection spikes
- **ProxyHighErrorRate** — 5xx errors > 5%

### Full Observability Stack

```yaml
monitoring:
  enabled: true
  prometheus:
    serviceMonitor: true
    prometheusRule: true
  grafana:
    dashboards: true
  accessLogs:
    enabled: true
    format: json
```

## Prometheus Setup

### With Prometheus Operator

The chart creates ServiceMonitor resources automatically:

```yaml
monitoring:
  enabled: true
  prometheus:
    serviceMonitor: true
    namespace: monitoring  # Prometheus Operator namespace
```

Verify ServiceMonitors:

```bash
kubectl get servicemonitor -l app.kubernetes.io/name=envoy-gateway
```

### Without Prometheus Operator

Manually configure Prometheus scrape jobs. Because proxy pods are provisioned dynamically by the EG operator (named `envoy-<namespace>-<gateway-name>-<uid>`), only the controller can be scraped via a fixed service name. Proxy metrics should be discovered via pod labels:

```yaml
scrape_configs:
- job_name: envoy-gateway-controller
  kubernetes_sd_configs:
  - role: endpoints
    namespaces:
      names:
      - default
  relabel_configs:
  - source_labels: [__meta_kubernetes_service_name]
    action: keep
    regex: envoy-gateway-controller
  - source_labels: [__meta_kubernetes_endpoint_port_name]
    action: keep
    regex: metrics
```

## Metrics

### Controller Metrics

**Endpoint**: `http://envoy-gateway-controller:8081/metrics`

Key metrics:
- `controller_runtime_reconcile_total` — Total reconciliation attempts
- `controller_runtime_reconcile_errors_total` — Reconciliation failures
- `workqueue_depth` — Work queue depth
- `workqueue_longest_running_processor_seconds` — Processing latency
- `rest_client_requests_total` — Kubernetes API calls

**Query Examples**:

```promql
# Reconciliation rate
rate(controller_runtime_reconcile_total[5m])

# Error rate
rate(controller_runtime_reconcile_errors_total[5m])

# API server latency
histogram_quantile(0.99, rate(rest_client_request_duration_seconds_bucket[5m]))
```

### Proxy Metrics

**Endpoint**: Proxy pods are created dynamically by the EG operator with names like `envoy-<namespace>-<gateway-name>-<uid>`. Access metrics via port-forward to a specific pod on port 9090.

Example:
```bash
kubectl port-forward pod/<envoy-pod-name> 9090:9090
curl http://localhost:9090/stats/prometheus
```

Key metrics:
- `envoy_http_downstream_rq_total` — Total requests
- `envoy_http_downstream_rq_xx` — Requests by status code (2xx, 4xx, 5xx)
- `envoy_http_downstream_rq_time_bucket` — Request latency histogram
- `envoy_cluster_upstream_cx_active` — Active upstream connections
- `envoy_cluster_upstream_cx_connect_fail` — Connection failures
- `envoy_listener_downstream_cx_active` — Active downstream connections
- `envoy_server_memory_allocated` — Memory usage
- `envoy_cluster_ratelimit_ok` — Requests allowed by rate limiter
- `envoy_cluster_ratelimit_over_limit` — Requests rejected by rate limiter

**Query Examples**:

```promql
# Request rate
rate(envoy_http_downstream_rq_total[5m])

# Error rate (5xx)
rate(envoy_http_downstream_rq_5xx[5m]) / rate(envoy_http_downstream_rq_total[5m])

# P99 latency
histogram_quantile(0.99, rate(envoy_http_downstream_rq_time_bucket[5m]))

# Active connections
envoy_listener_downstream_cx_active

# Rate limit rejections
rate(envoy_cluster_ratelimit_over_limit[5m])
```

## Alerts

When `prometheusRule: true`, the chart creates these alerts:

### ProxyHighMemoryUsage

Triggers when proxy memory usage exceeds 80%:

```yaml
- alert: ProxyHighMemoryUsage
  expr: |
    (container_memory_working_set_bytes{pod=~"envoy-gateway-proxy-.*"} 
    / container_spec_memory_limit_bytes{pod=~"envoy-gateway-proxy-.*"}) > 0.8
  for: 5m
  severity: warning
```

**Action**: Increase proxy memory limits or investigate memory leaks.

### ProxyHighCPUUsage

Triggers when proxy CPU usage exceeds 80%:

```yaml
- alert: ProxyHighCPUUsage
  expr: |
    rate(container_cpu_usage_seconds_total{pod=~"envoy-gateway-proxy-.*"}[5m]) 
    / container_spec_cpu_quota{pod=~"envoy-gateway-proxy-.*"} > 0.8
  for: 5m
  severity: warning
```

**Action**: Increase proxy CPU limits or scale horizontally.

### ControllerDown

Triggers when controller is unavailable:

```yaml
- alert: ControllerDown
  expr: up{job="envoy-gateway-controller"} == 0
  for: 2m
  severity: critical
```

**Action**: Check controller pod status and logs.

### ProxyHighConnectionRate

Triggers when connection rate increases 50% above baseline:

```yaml
- alert: ProxyHighConnectionRate
  expr: |
    rate(envoy_listener_downstream_cx_total[5m]) 
    > 1.5 * avg_over_time(rate(envoy_listener_downstream_cx_total[5m])[1h:5m])
  for: 5m
  severity: warning
```

**Action**: Investigate traffic spike, potential DDoS, or legitimate growth.

### ProxyHighErrorRate

Triggers when 5xx error rate exceeds 5%:

```yaml
- alert: ProxyHighErrorRate
  expr: |
    rate(envoy_http_downstream_rq_5xx[5m]) 
    / rate(envoy_http_downstream_rq_total[5m]) > 0.05
  for: 5m
  severity: critical
```

**Action**: Check backend service health and proxy logs.

### ControllerHighMemoryUsage

Triggers when controller memory exceeds 80%:

```yaml
- alert: ControllerHighMemoryUsage
  expr: |
    (container_memory_working_set_bytes{pod=~"envoy-gateway-controller-.*"} 
    / container_spec_memory_limit_bytes{pod=~"envoy-gateway-controller-.*"}) > 0.8
  for: 5m
  severity: warning
```

**Action**: Increase controller memory limits.

## Grafana Dashboards

### Installing Dashboards

Enable dashboard provisioning:

```yaml
monitoring:
  grafana:
    dashboards: true
    namespace: monitoring  # Grafana namespace
```

The chart creates ConfigMaps with official Envoy Gateway dashboards:
- **Envoy Proxy Dashboard** — Traffic, latency, errors, connections
- **Envoy Gateway Controller Dashboard** — Reconciliation, API calls, queue depth

### Importing Manually

If not using ConfigMap provisioning:

1. **Export dashboard ConfigMap**:
```bash
kubectl get configmap envoy-gateway-grafana-dashboard -o jsonpath='{.data.dashboard\.json}' > dashboard.json
```

2. **Import to Grafana**:
   - Open Grafana UI
   - Go to Dashboards → Import
   - Upload `dashboard.json`

### Dashboard Panels

**Envoy Proxy Dashboard**:
- Request rate (RPS)
- Error rate (%)
- P50/P95/P99 latency
- Active connections
- Memory usage
- CPU usage
- Rate limit rejections

**Controller Dashboard**:
- Reconciliation rate
- Reconciliation errors
- Work queue depth
- API server latency
- Memory usage
- CPU usage

## Access Logs

### Enabling Access Logs

```yaml
monitoring:
  accessLogs:
    enabled: true
    format: json
```

Access logs are written to stdout (viewable with `kubectl logs`).

### JSON Format

**Recommended for production**:

```yaml
monitoring:
  accessLogs:
    enabled: true
    format: json
```

Example log entry:

```json
{
  "start_time": "2026-04-09T10:15:30.123Z",
  "method": "GET",
  "path": "/api/users",
  "protocol": "HTTP/1.1",
  "response_code": 200,
  "response_flags": "-",
  "bytes_received": 0,
  "bytes_sent": 1234,
  "duration": 45,
  "upstream_service_time": 42,
  "x_forwarded_for": "203.0.113.42",
  "user_agent": "Mozilla/5.0",
  "request_id": "abc123",
  "authority": "api.example.com",
  "upstream_host": "10.42.0.15:8080"
}
```

**Benefits**:
- Structured for log aggregation (Loki, Elasticsearch)
- Easy to parse and query
- Machine-readable

### Text Format

```yaml
monitoring:
  accessLogs:
    enabled: true
    format: text
```

Example log entry:

```
[2026-04-09T10:15:30.123Z] "GET /api/users HTTP/1.1" 200 - 0 1234 45 42 "203.0.113.42" "Mozilla/5.0" "abc123" "api.example.com" "10.42.0.15:8080"
```

### Viewing Access Logs

Proxy pods are dynamically provisioned by the EG operator. Get the pod name first:

```bash
# List EG-managed proxy pods
kubectl get pods -l app.kubernetes.io/component=proxy

# Tail proxy logs
kubectl logs -f <envoy-pod-name> -c envoy

# Filter by status code (JSON format)
kubectl logs <envoy-pod-name> -c envoy | jq 'select(.response_code >= 500)'

# Filter by path
kubectl logs <envoy-pod-name> -c envoy | jq 'select(.path | startswith("/api"))'
```

### Log Aggregation

**With Grafana Loki**:

```yaml
# Promtail configuration
- job_name: envoy-gateway
  kubernetes_sd_configs:
  - role: pod
  relabel_configs:
  - source_labels: [__meta_kubernetes_pod_label_app_kubernetes_io_name]
    action: keep
    regex: envoy-gateway
  - source_labels: [__meta_kubernetes_pod_container_name]
    action: keep
    regex: envoy
  pipeline_stages:
  - json:
      expressions:
        response_code: response_code
        path: path
        duration: duration
  - labels:
      response_code:
      path:
```

Query examples:
```logql
# 5xx errors
{app="envoy-gateway"} | json | response_code >= 500

# Slow requests (>1s)
{app="envoy-gateway"} | json | duration > 1000

# Specific path
{app="envoy-gateway"} | json | path =~ "/api/.*"
```

## Distributed Tracing

Envoy Gateway supports OpenTelemetry tracing:

```yaml
apiVersion: gateway.envoyproxy.io/v1alpha1
kind: EnvoyProxy
metadata:
  name: tracing-config
spec:
  telemetry:
    tracing:
      provider:
        type: OpenTelemetry
        openTelemetry:
          host: otel-collector.observability.svc.cluster.local
          port: 4317
```

Apply to Gateway:

```yaml
apiVersion: gateway.networking.k8s.io/v1
kind: GatewayClass
metadata:
  name: envoy-gateway
spec:
  controllerName: gateway.envoyproxy.io/gatewayclass-controller
  parametersRef:
    group: gateway.envoyproxy.io
    kind: EnvoyProxy
    name: tracing-config
```

## Monitoring Best Practices

1. **Enable ServiceMonitor + PrometheusRule** — Automated scraping and alerts
2. **Use JSON access logs** — Better for log aggregation and querying
3. **Set up Grafana dashboards** — Visual monitoring is essential
4. **Configure alert notifications** — Integrate with PagerDuty, Slack, etc.
5. **Track error rates** — Set up SLIs/SLOs for availability
7. **Use distributed tracing** — Debug complex request flows
8. **Aggregate logs centrally** — Don't rely on kubectl logs for production

## Troubleshooting

### Metrics Not Appearing

**Symptom**: Prometheus not scraping Envoy Gateway metrics

**Diagnosis**:

```bash
# Check ServiceMonitor exists (only controller ServiceMonitor is created)
kubectl get servicemonitor -l app.kubernetes.io/name=envoy-gateway

# Check Prometheus targets
# (Access Prometheus UI → Status → Targets)

# Test controller metrics endpoint
kubectl port-forward svc/envoy-gateway-controller 8081:8081
curl http://localhost:8081/metrics

# Test proxy metrics (proxy pods have dynamic names)
kubectl get pods -l app.kubernetes.io/component=proxy
kubectl port-forward pod/<envoy-pod-name> 9090:9090
curl http://localhost:9090/stats/prometheus
```

**Common Causes**:
1. ServiceMonitor namespace doesn't match Prometheus Operator config
2. Prometheus RBAC doesn't allow scraping
3. Metrics ports not exposed

### Alerts Not Firing

**Symptom**: Expected alerts not triggering

**Diagnosis**:

```bash
# Check PrometheusRule exists
kubectl get prometheusrule envoy-gateway-alerts

# Verify alert is loaded in Prometheus UI
# (Access Prometheus UI → Alerts)

# Check alert expression manually
# (Access Prometheus UI → Graph → Run expression)
```

**Common Causes**:
1. PrometheusRule not created (`prometheusRule: false`)
2. Alert expression syntax error
3. Metrics not available
4. Alertmanager not configured

### No Access Logs

**Symptom**: No logs in kubectl logs output

**Diagnosis**:

```bash
# Check access logs enabled
helm get values envoy-gateway | grep accessLogs

# Check proxy logs (proxy pods are dynamically named by EG operator)
kubectl get pods -l app.kubernetes.io/component=proxy
kubectl logs <envoy-pod-name> -c envoy

# Check for errors
kubectl logs deployment/envoy-gateway-controller
```

**Common Causes**:
1. Access logs disabled (`enabled: false`)
2. No traffic to proxy
3. Wrong container name (use `-c envoy`)

<!-- @AI-METADATA
type: chart-docs
title: Observability Guide
description: Comprehensive monitoring with Prometheus, Grafana, alerts, and access logs for Envoy Gateway
keywords: observability, prometheus, grafana, metrics, alerts, access-logs, monitoring, tracing, envoy-gateway
purpose: Guide for configuring monitoring, metrics, alerts, dashboards, and logging
scope: Chart
relations:
  - charts/envoy-gateway/README.md
  - charts/envoy-gateway/values.yaml
  - charts/envoy-gateway/examples/production.yaml
  - charts/envoy-gateway/examples/staging.yaml
  - charts/envoy-gateway/examples/monitoring-values.yaml
path: charts/envoy-gateway/docs/observability.md
version: 1.0
date: 2026-04-09
-->
