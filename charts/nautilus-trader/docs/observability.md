# Observability

The runner exposes `/healthz`, `/readyz`, and Prometheus text metrics on the internal Service. Enable
`monitoring.serviceMonitor.enabled` and `monitoring.prometheusRule.enabled` when Prometheus Operator CRDs are installed.

Runner metrics measure process health, readiness, runs, failures, and uptime. They do not measure market-data freshness,
venue sessions, account reconciliation, risk limits, or order outcomes. User strategy code should publish those domain
signals separately and alert on them before production trading.
