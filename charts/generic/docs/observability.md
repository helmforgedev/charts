# Generic Chart Observability

## Prometheus Operator resources

`serviceMonitor.enabled`, `podMonitor.enabled`, and `prometheusRule.enabled` render Prometheus Operator custom resources. Enable them only in clusters where those CRDs already exist.

```yaml
podMonitor:
  enabled: true
  podMetricsEndpoints:
    - port: http
      path: /metrics

prometheusRule:
  enabled: true
  groups:
    - name: generic.rules
      rules:
        - alert: GenericDown
          expr: up == 0
```

## Autoscaling

HPA supports Resource metrics plus native autoscaling/v2 metric shapes such as Pods, Object, External, and ContainerResource. HPA is blocked for DaemonSets and requires `hpa.maxReplicas`.

VPA and KEDA are CRD-backed and disabled by default. Use VPA for recommendations or vertical resizing, and KEDA for event-driven ScaledObjects or ScaledJobs.

## Autoscaling and HA safety

Deployment and StatefulSet HPA resources are supported by the Kubernetes `autoscaling/v2` API. Validate StatefulSet scaling with the application owner before enabling it in production, because ordered identity, storage semantics, and application clustering behavior remain workload-specific.

KEDA, VPA, PodMonitor, and PrometheusRule resources require their operators and CRDs to exist before enabling those features. The generic chart keeps them disabled by default and validates only their manifests unless the target cluster has the matching CRDs installed.

<!-- @AI-METADATA
type: chart-docs
title: Generic Chart - Observability
description: Monitoring and autoscaling integrations for the generic chart
keywords: generic, servicemonitor, podmonitor, prometheusrule, hpa, vpa, keda
purpose: Observability and autoscaling guide for the generic chart
scope: Chart Architecture
relations:
  - charts/generic/README.md
path: charts/generic/docs/observability.md
version: 1.0
date: 2026-04-27
-->
