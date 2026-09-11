# Native Prometheus monitoring

Enable `metrics.enabled` to expose the upstream Prometheus exporter on a separate
private port, 9464 by default. `metrics.serviceMonitor.enabled` and
`metrics.prometheusRule.enabled` create the corresponding Prometheus Operator
resources. Install the operator CRDs and configure its selectors to discover these
resources. The chart does not install a monitoring stack.

The native metrics endpoint has no authentication. Keep it internal and limit
`metrics.ingressFrom` to the intended scrapers. The default permits the namespace
named `monitoring`; adjust this to the installation. The application Ingress and
HTTPRoutes target only the application port.

Validated native metric families include `storage_function_calls_total`,
`storage_function_timer`, `gql_query_counter_total`, `socketio_connections`,
`socketio_doc_updates_broadcast_total` and `queue_active_jobs_total`. Storage
`putObject` and `getObject` counters are exercised through actual authenticated
uploads and downloads. These are application metrics, not an invented exporter
endpoint. The bundled alert detects an unavailable scrape target; add workload
alerts through `metrics.prometheusRule.additionalRules` based on observed demand.

Enabling the native metrics switch also enables upstream tracing and a Zipkin
exporter. The chart does not add unrestricted trace egress or assume an environment
variable disables an exporter explicitly created by the application. Review the
upstream trace configuration and your intended destination before enabling trace
delivery. Keep unwanted destinations outside the network allowlist.

Readiness checks a fresh PostgreSQL query, authenticated Redis PING and HTTP
availability. Liveness checks HTTP only, so a dependency outage does not deliberately
restart the application. Monitor PVC capacity, database capacity, Redis memory and
eviction counts alongside the application series.

The behavioral monitoring scenario verifies native exposition, actual storage
activity, a real ServiceMonitor scrape with `up=1`, and a loaded PrometheusRule.
Controller routing, alert delivery and external monitoring retention require their
own environment validation.
