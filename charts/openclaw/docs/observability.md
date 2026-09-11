# Observability

`metrics.enabled` activates the release-bundled diagnostics-otel plugin. The gateway exports native metrics over OTLP HTTP
to a loopback collector. The pinned official collector translates metrics into Prometheus format on a separate private
Service, port 8889. Enable `metrics.serviceMonitor.enabled` for an installed Prometheus Operator and set its discovery
labels and `metrics.ingressFrom` peer selectors.

This integration does not install the separate diagnostics-prometheus plugin at startup and does not share the gateway
operator token with the scraper. The collector receives metrics only; prompt/tool content capture, traces and logs are
disabled. Native usage and latency series depend on activity and provider reporting. They are operational observations,
not guaranteed billing records. Empty activity-dependent series are expected before requests occur.

To use an existing OTLP collector, disable the local collector and set `metrics.externalEndpoint` to its OTLP HTTP base
URL. Allow the destination in NetworkPolicy. ServiceMonitor and chart Prometheus rules require the local collector.
External collector authentication and TLS policy can be supplied through supported upstream environment configuration
in the credentials Secret; verify the endpoint integration in your environment.

The optional PrometheusRule detects failed scrapes; add deployment-specific alerts with `additionalRules`. Also monitor
gateway readiness, restart count, PVC fullness, node ephemeral storage and failed/missing scheduled backup Jobs. A local
OpenClaw backup success record does not prove S3 publication. Kubernetes Job completion and the remote manifest do.
