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

With `hpa.enabled=true`, Deployment and StatefulSet manifests omit `spec.replicas`
so routine Helm upgrades leave the replica count to the autoscaler.
`hpa.minReplicas` and `hpa.maxReplicas` remain configured on the HPA itself.
When HPA is disabled, the workload renders `replicaCount` again.

### Replica ownership during upgrades

Earlier chart versions explicitly rendered `hpa.minReplicas` on the workload.
The first upgrade that removes that field, or a switch from fixed replicas to
HPA, can briefly reset the workload to Kubernetes' default of one replica until
the autoscaler reconciles. New installs can also start at that default before
HPA applies its minimum. Check autoscaler health and plan this ownership
transition for the workload's availability and, for StatefulSets, storage
requirements; a PodDisruptionBudget does not prevent controller scale-down.

Subsequent upgrades with HPA still enabled keep `spec.replicas` absent.
Disabling HPA deliberately returns control to `replicaCount`, which can change
the number of replicas immediately.

See the upstream [HPA migration guidance](https://kubernetes.io/docs/concepts/workloads/autoscaling/horizontal-pod-autoscale/#migrating-deployments-and-statefulsets-to-horizontal-autoscaling).

VPA and KEDA are CRD-backed and disabled by default. Use VPA for recommendations or vertical resizing, and KEDA for event-driven ScaledObjects or ScaledJobs.

KEDA ScaledObjects target the chart-managed Deployment or StatefulSet and require `workload.enabled=true`. Use ScaledJobs for event-driven batch releases that do not render a long-running workload.

Resource metrics accept native `autoscaling/v2` objects as well as Resource shorthand. For example, scale on average CPU consumption per pod, independently of its CPU request:

```yaml
hpa:
  enabled: true
  minReplicas: 2
  maxReplicas: 10
  metrics:
    - type: Resource
      resource:
        name: cpu
        target:
          type: AverageValue
          averageValue: 500m
```

The existing Resource shorthand remains supported: `resource: cpu`, `type: Utilization`, and `target: 75` selects 75%
CPU utilization. Use `targetType: AverageValue` and `target: 500m` for the shorthand equivalent of the example above.
Native metrics and Resource shorthand can appear in the same list.

## Autoscaling and HA safety

Deployment and StatefulSet HPA resources are supported by the Kubernetes `autoscaling/v2` API. Validate StatefulSet scaling
with the application owner before enabling it in production, because ordered identity, storage semantics, and application
clustering behavior remain workload-specific.

KEDA, VPA, PodMonitor, and PrometheusRule resources require their operators and CRDs to exist before enabling those
features. The generic chart keeps them disabled by default and validates only their manifests unless the target cluster
has the matching CRDs installed.

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
