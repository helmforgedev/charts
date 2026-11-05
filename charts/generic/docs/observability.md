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

KEDA ScaledObjects target the chart-managed Deployment or StatefulSet and require `workload.enabled=true`. Use ScaledJobs for event-driven batch releases that do not render a long-running workload.

## Autoscaling and HA safety

Deployment and StatefulSet HPA resources are supported by the Kubernetes `autoscaling/v2` API. Validate StatefulSet scaling
with the application owner before enabling it in production, because ordered identity, storage semantics, and application
clustering behavior remain workload-specific.

KEDA, VPA, PodMonitor, and PrometheusRule resources require their operators and CRDs to exist before enabling those
features. The generic chart keeps them disabled by default and validates only their manifests unless the target cluster
has the matching CRDs installed.

### VPA update modes

`vpa.updateMode` supports `Off`, `Initial`, `Recreate`, `InPlaceOrRecreate`, and `Auto`; the default remains `Off`.
`InPlaceOrRecreate` attempts to resize running Pods in place and falls back to eviction and recreation when necessary.
It requires VPA 1.4.0 or newer with matching CRDs and Kubernetes 1.33 or newer with in-place Pod resource resizing enabled.
Enable the required Kubernetes and VPA feature gates for your installed versions; see the
[upstream VPA requirements](https://github.com/kubernetes/autoscaler/blob/vertical-pod-autoscaler-1.6.0/vertical-pod-autoscaler/docs/features.md#requirements).
Allowing this value in the chart does not enable those cluster features or guarantee disruption-free updates.

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
