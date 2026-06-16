# ZooKeeper Observability

## Overview

ZooKeeper can be monitored through server logs, `zkServer.sh status`,
four-letter commands, JMX, and the Prometheus metrics provider. This chart
focuses on Kubernetes-native Prometheus integration while keeping the
traditional ZooKeeper operational commands available for troubleshooting.

## Prometheus Metrics

Enable the Prometheus metrics provider:

```yaml
metrics:
  enabled: true
```

The chart adds these ZooKeeper configuration lines:

```text
metricsProvider.className=org.apache.zookeeper.metrics.prometheus.PrometheusMetricsProvider
metricsProvider.httpPort=7000
```

Metrics are exposed on the metrics Service at `/metrics`.

## ServiceMonitor

When Prometheus Operator CRDs are installed, render a ServiceMonitor:

```yaml
metrics:
  enabled: true
  serviceMonitor:
    enabled: true
    interval: 30s
    scrapeTimeout: 10s
    additionalLabels:
      release: prometheus
```

Set `metrics.serviceMonitor.namespace` when ServiceMonitors are collected from a
central monitoring namespace.

## PrometheusRule

The chart can render a starter PrometheusRule:

```yaml
metrics:
  enabled: true
  prometheusRule:
    enabled: true
    rules:
      - alert: ZooKeeperDown
        expr: up{job=~".*zookeeper.*"} == 0
        for: 5m
        labels:
          severity: critical
        annotations:
          summary: ZooKeeper metrics target is down
```

Tune rule expressions for your Prometheus labels and scrape topology before
using them as production paging alerts.

## Four-Letter Commands

The default whitelist includes `ruok`, `srvr`, `stat`, `mntr`, `conf`, and
`isro`. These are useful for smoke tests and low-level diagnostics.

Example in-cluster check:

```bash
kubectl run zk-mntr -n zookeeper --rm -i --restart=Never \
  --image=docker.io/library/busybox:1.37.0 -- \
  sh -c "echo mntr | nc zookeeper 2181"
```

Use `mntr` for basic counters and `srvr` or `stat` for server role and
connection information.

## Logs

Inspect the ZooKeeper container logs:

```bash
kubectl logs -n zookeeper zookeeper-0 -c zookeeper --tail=200
```

During startup, verify that the server binds the expected client port, joins the
quorum, and does not repeatedly restart. In production, collect logs centrally
because quorum issues often need correlation across members.

## Troubleshooting

### ServiceMonitor does not scrape

Confirm CRDs and labels:

```bash
kubectl get servicemonitor -A | grep zookeeper
kubectl get service -n zookeeper -l app.kubernetes.io/component=metrics
```

Make sure the ServiceMonitor labels match the Prometheus Operator selector.

### Metrics endpoint is not available

Confirm `metrics.enabled=true` and check the container port:

```bash
kubectl get pod -n zookeeper zookeeper-0 -o jsonpath="{.spec.containers[0].ports}"
kubectl port-forward -n zookeeper svc/zookeeper-metrics 7000:7000
```

Then open `http://127.0.0.1:7000/metrics`.

### Four-letter command is rejected

Check the whitelist:

```bash
helm get values zookeeper -n zookeeper
kubectl logs -n zookeeper zookeeper-0 -c zookeeper --tail=100
```

Only commands listed in `zookeeper.fourLetterWordWhitelist` are enabled.

## References

- [Apache ZooKeeper Administrator's Guide](https://zookeeper.apache.org/doc/current/zookeeperAdmin.html)
- [Prometheus Operator ServiceMonitor](https://prometheus-operator.dev/docs/developer/getting-started/)
