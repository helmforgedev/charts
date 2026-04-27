# Generic Chart for Deployments

## When to use

Use `Deployment` for the majority of stateless workloads.

Common cases:

- web applications
- internal APIs
- background workers that run continuously
- services exposed through `Service` and `Ingress`

## What this mode delivers

- rolling updates
- replica-based scaling
- HPA and VPA compatibility
- service and ingress integration
- extra Services, headless Service mode, custom Ingress backends, and Gateway API HTTPRoutes
- support for sidecars, init containers, probes, and ConfigMaps
- optional Secrets, RBAC, NetworkPolicy, PodMonitor, PrometheusRule, and KEDA resources

## What it does not deliver

- stable pod identity
- per-replica persistent identity
- one-pod-per-node placement

## Recommended practices

- use `workload.type: Deployment`
- define `service` and `ingress` only when the app is actually network-facing
- enable `hpa` only with meaningful metrics and sane requests
- add `pdb.enabled=true` for production services with multiple replicas
- use `topologySpreadConstraints` or anti-affinity for critical services
- set `rollout.restartAt` only when you intentionally want to roll pods without another spec change

## Most relevant values

| Parameter | Description |
|-----------|-------------|
| `workload.type` | Must be `Deployment` |
| `replicaCount` | Number of replicas |
| `containers` | Main and sidecar containers |
| `service.*` | Service exposure |
| `ingress.*` | HTTP ingress exposure |
| `services[]` | Additional Service resources |
| `gatewayApi.*` | Optional Gateway API HTTPRoutes |
| `secrets[]` / `rbac.*` / `networkPolicy.*` | Opt-in security resources |
| `podMonitor.*` / `prometheusRule.*` | Prometheus Operator resources |
| `rollout.restartAt` | Explicit restart marker for intentional pod rollouts |
| `rollout.checksum.*` | ConfigMap/Secret checksum-driven rollouts |
| `hpa.*` | Horizontal autoscaling |
| `keda.*` | Event-driven autoscaling with KEDA CRDs |
| `pdb.*` | Disruption protection |
| `updateStrategy.*` | Rolling update behavior |

## Example

```yaml
workload:
  enabled: true
  type: Deployment

replicaCount: 3

image:
  repository: ghcr.io/example/api
  tag: "1.2.0"

containers:
  - name: app
    ports:
      - containerPort: 8080

service:
  port: 80
  targetPort: 8080

ingress:
  enabled: true
  hosts:
    - host: api.example.com
      paths:
        - /

hpa:
  enabled: true
  minReplicas: 3
  maxReplicas: 10

rollout:
  restartAt: ""
```

<!-- @AI-METADATA
type: chart-docs
title: Generic Chart - Deployment
description: Deployment configuration

keywords: generic, deployment, rolling-update

purpose: Deployment workload configuration guide for the generic chart
scope: Chart Architecture

relations:
  - charts/generic/README.md
path: charts/generic/docs/deployment.md
version: 1.0
date: 2026-03-20
-->
