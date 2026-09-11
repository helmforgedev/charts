# Native web and Sidekiq monitoring

Enable `metrics.enabled` to expose native metrics through a private Service. The
public application endpoint continues to return 404 for `/metrics`.

The metrics Service has two authenticated ports:

| Endpoint | Default port | Purpose |
| --- | --- | --- |
| `metrics` | 9464 | Rails, ActiveRecord and Puma metrics, with native Sidekiq aggregation |
| `worker-metrics` | 9394 | Direct native Sidekiq exporter availability and queue/job metrics |

The private NGINX listener exposes only `/metrics`. Basic authentication is enforced
by the native application and worker, using the same Secret. The chart generates and
retains a random password unless `metrics.auth.existingSecret` is configured. Secret
key names are configurable; the ServiceMonitor reads those keys directly.

## Prometheus Operator

Enable `metrics.serviceMonitor.enabled` after installing Prometheus Operator CRDs.
Configure labels to match the operator's ServiceMonitor selector and set
`metrics.ingressFrom` to its scraper Pods/namespaces. A second direct worker target
is intentional: the aggregate web endpoint can return web-only metrics if the worker
exporter fails, so its HTTP 200 response alone does not prove worker health.

`metrics.prometheusRule.enabled` installs an availability rule for either target.
Use `additionalRules` for workload-specific thresholds. Useful native signals include
`sidekiq_jobs_success_total`, `sidekiq_jobs_failed_total`, `sidekiq_jobs_waiting_count`,
`sidekiq_jobs_retry_count`, `sidekiq_jobs_dead_count`, `sidekiq_queue_latency` and
`rails_requests_total`. Select `endpoint="worker-metrics"` when alerting on direct
worker metrics to avoid counting the aggregate and direct copies together.

## Readiness and operational scope

Web startup/liveness use native HTTP health. Web readiness adds a new PostGIS query
and authenticated cache PING. Worker readiness checks the current Pod's native
Sidekiq heartbeat and rejects a stale or quiet process. A real queued GPX import is
part of behavioral acceptance; neither a running PID nor a TCP port proves job
execution.

CPU, memory and PVC alerts remain responsibilities of cluster monitoring. These
application metrics do not implement distributed tracing or a backup system.
