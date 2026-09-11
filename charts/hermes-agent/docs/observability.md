# Observability

Set `metrics.enabled=true` to enable native Hermes gateway-health OTLP export. The optional pinned OpenTelemetry collector runs in the same Pod, binds its OTLP
HTTP receiver to loopback and publishes Prometheus exposition on port 8889. It does not mount the agent data or provider credentials.

With `metrics.collector.enabled=false`, configure `metrics.externalEndpoint` as the complete OTLP HTTP metrics URL ending in `/v1/metrics`, and allow its
network destination. The upstream exporter does not append that path automatically. The built-in ServiceMonitor/PrometheusRule require the local collector and
an existing Prometheus Operator installation.

Permit your Prometheus Pods using `metrics.ingressFrom`. Add the operator's selection labels through `metrics.serviceMonitor.labels` and
`metrics.prometheusRule.labels`; installing a ServiceMonitor alone does not cause an unrelated Prometheus instance to select it. The native metric names
normalize to names such as `hermes_gateway_up`, `hermes_gateway_active_agents`, `hermes_platform_up` and scheduler/job gauges.

The bundled rules detect an unavailable gateway and absent native gateway metrics. A healthy collector scrape alone cannot prove that the gateway is exporting.
Set additional environment-specific rules through `metrics.prometheusRule.additionalRules`. Job metrics from kube-state-metrics can alert on failed/stale backup
completion; these are separate from Hermes telemetry.

This integration does not fabricate token-cost, model quality, request-latency or billing metrics. Diagnostic and warning-event OTLP export remain disabled.
Kubernetes logs and authenticated detailed health supplement native metrics, but may contain user activity; restrict log access and retention appropriately.

Size memory for the gateway's concurrent work and enabled tools. Browser/terminal/MCP workloads can exceed the default budget. Monitor agent PVC capacity, node
ephemeral storage, container restarts, provider rate limits and backup recovery time. The local k3d suite verifies actual OTLP-to-Prometheus values and
configuration of operator resources; your production Prometheus selection and notification routing require deployment-specific checks.
