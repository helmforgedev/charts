# Native Prometheus monitoring

Pocket ID exports OpenTelemetry metrics through its native Prometheus exporter. The chart enables that listener
separately from the public identity endpoint; no exporter sidecar is required.

```yaml
metrics:
  enabled: true
  ingressFrom:
    - namespaceSelector:
        matchLabels:
          kubernetes.io/metadata.name: monitoring
      podSelector:
        matchLabels:
          app.kubernetes.io/name: prometheus
  serviceMonitor:
    enabled: true
    labels:
      release: monitoring
  prometheusRule:
    enabled: true
    labels:
      release: monitoring
```

Install Prometheus Operator CRDs before enabling these resources. Match the labels to your Prometheus resource's
ServiceMonitor and rule selectors, and match the network peers to the actual Prometheus pods. NetworkPolicy requires an
enforcing CNI. Without explicit `ingressFrom`, the chart permits metric scraping from the release namespace. Keep
`serviceMonitor.scrapeTimeout` no greater than `serviceMonitor.interval`; the operator rejects invalid timing.

The metrics Service is separate from HTTP and is omitted from the chart's Ingress and HTTPRoute. The native metrics
listener is not an authenticated public API; keep access limited to monitoring workloads. The private bootstrap process
always disables metric export, even when the main application exporter is enabled.

The included `PocketIDMetricsUnavailable` alert detects a discovered target with `up == 0` for five minutes. It does not
detect an absent ServiceMonitor, broken discovery or an unavailable Prometheus server. Monitor those conditions in the
monitoring platform. `metrics.prometheusRule.additionalRules` accepts application-specific recording or alert rules
based on the native series available in your version.

Health probes use the application's HTTP health endpoint. A successful health probe does not prove a relying party can
complete authentication; keep a synthetic login check for your production origin and OIDC clients.
