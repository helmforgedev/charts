# Authenticated native Prometheus

Enable metrics.enabled for /actuator/prometheus on a separate ClusterIP Service. It rejects requests without a valid
native X-API-KEY. Restrict metrics.ingressFrom to Prometheus pods. The application Ingress targets only the HTTP
Service.

Native samples are http_requests_total with method, uri and session labels. Upstream excludes JVM/GC meters. Session
cardinality can grow; set sample limits and retention. Dropping session labels without aggregation can produce duplicate
series. Monitor Kubernetes memory, restarts and volume capacity separately.

## Prometheus Operator

The supported ServiceMonitor schema cannot send arbitrary headers. An API key is not a Bearer JWT. Use a native job:

```yaml
metrics:
  enabled: true
  ingressFrom:
    - podSelector:
        matchLabels:
          prometheus: documents-monitor
  scrapeConfig:
    enabled: true
    apiKeySecret: stirling-monitoring-key
    apiKeyKey: api-key
```

Create stirling-monitoring-key from a dedicated native monitoring account's API key in the Prometheus namespace. Keep it
out of values files and ConfigMaps. The generated scrape Secret is in the application namespace; a Prometheus resource
referencing it must share that namespace, or incorporate the job into your independently managed scrape Secret. ESO can
synchronize credential material across namespaces.

For a standalone same-namespace Prometheus, merge these fields into its existing spec:

```yaml
spec:
  additionalScrapeConfigs:
    name: stirling-pdf-stirling-pdf-scrape
    key: additional-scrape-configs.yaml
  secrets:
    - stirling-monitoring-key
```

The job uses http_headers.X-API-KEY.files to read /etc/prometheus/secrets/stirling-monitoring-key/api-key.
additionalScrapeConfigs is a single Secret reference: combine job lists and mounts instead of replacing other jobs.
Validate the final configuration with your version's promtool. The runtime fixture uses Prometheus 3.14.0 and verifies a
real successful scrape and native conversion request counter.

Rotate the native key and Secret together, allow projected-volume propagation and verify target up=1. Limit Secret RBAC.
