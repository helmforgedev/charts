# Metrics Server

Metrics Server for Kubernetes autoscaling pipelines using the official `registry.k8s.io/metrics-server/metrics-server` image.

## Install

### HTTPS repository

```bash
helm repo add helmforge https://repo.helmforge.dev
helm repo update
helm install metrics-server helmforge/metrics-server -n kube-system -f values.yaml
```

### OCI registry

```bash
helm install metrics-server oci://ghcr.io/helmforgedev/helm/metrics-server -n kube-system -f values.yaml
```

## What this chart covers

- official Metrics Server image pinned to `v0.8.1`
- Kubernetes Metrics API `APIService`
- required ServiceAccount, ClusterRole, ClusterRoleBinding, and delegated authentication RoleBinding
- typed kubelet flag modeling instead of a single unstructured args list
- secure default pod and container security contexts
- optional k3d and kind-compatible `--kubelet-insecure-tls`
- optional high availability with replicas, topology spread, and PodDisruptionBudget
- optional hostNetwork mode for clusters where the API server cannot reach pod IPs
- hostNetwork-safe rollout behavior that avoids single-node host port upgrade deadlocks
- dual-stack Service fields
- optional NetworkPolicy and ServiceMonitor
- Helm test pod that checks `/readyz`

## Kubernetes Compatibility

Metrics Server `0.8.x` supports Kubernetes `1.31+`. The chart therefore declares `kubeVersion: >=1.31.0-0`.

## Security Scan

Security Scan: Kubescape local scan against `MITRE,NSA,SOC2` reports a 89.90% resource summary score.

## k3d and Local Clusters

Many local clusters use kubelet serving certificates that do not include the address SANs Metrics Server validates. Use the k3d values file for local validation:

```yaml
metricsServer:
  kubelet:
    insecureTLS: true
```

Do not use `metricsServer.kubelet.insecureTLS=true` for production unless your platform explicitly accepts that risk.

## High Availability

```yaml
replicaCount: 2

pdb:
  enabled: true
  maxUnavailable: 1
  unhealthyPodEvictionPolicy: AlwaysAllow
```

For best HA behavior, configure the kube-apiserver with aggregator routing enabled so APIService requests are distributed across replicas.

## Existing Metrics API Resources

Some Kubernetes distributions preinstall `v1beta1.metrics.k8s.io` and `system:aggregated-metrics-reader`.
When those cluster-scoped resources already exist, the chart does not try to adopt them into the Helm release.
This avoids ownership conflicts while still deploying the Metrics Server workload, Service, RBAC bindings, and optional observability resources.

## Main Values

| Key | Default | Description |
|-----|---------|-------------|
| `image.repository` | `registry.k8s.io/metrics-server/metrics-server` | Official image repository |
| `image.tag` | `v0.8.1` | Metrics Server image tag |
| `replicaCount` | `1` | Deployment replicas |
| `apiService.create` | `true` | Create `v1beta1.metrics.k8s.io` APIService |
| `apiService.insecureSkipTLSVerify` | `true` | Skip APIService backend TLS verification unless `caBundle` is set |
| `rbac.create` | `true` | Create required RBAC resources |
| `containerPort` | `10250` | Metrics Server secure serving port |
| `metricsServer.metricResolution` | `15s` | Metrics collection resolution |
| `metricsServer.kubelet.insecureTLS` | `false` | Disable kubelet TLS verification for local clusters |
| `hostNetwork.enabled` | `false` | Use host networking |
| `service.ipFamilyPolicy` | `~` | Optional Service IP family policy |
| `pdb.enabled` | `false` | Render PodDisruptionBudget |
| `networkPolicy.enabled` | `false` | Render NetworkPolicy |
| `networkPolicy.extraEgress` | `[]` | Append full custom NetworkPolicy egress rules |
| `serviceMonitor.enabled` | `false` | Render Prometheus Operator ServiceMonitor |

## References

- [Metrics Server](https://github.com/kubernetes-sigs/metrics-server)
- [Metrics Server Helm chart](https://github.com/kubernetes-sigs/metrics-server/tree/master/charts/metrics-server)
- [Metrics Server releases](https://github.com/kubernetes-sigs/metrics-server/releases)
