<!-- SPDX-License-Identifier: Apache-2.0 -->

# Metrics Server

Production-oriented Helm chart for Kubernetes Metrics Server using the official
`registry.k8s.io/metrics-server/metrics-server` image. Metrics Server collects
CPU and memory usage from kubelets and exposes the aggregated
`metrics.k8s.io/v1beta1` API used by `kubectl top`, Horizontal Pod Autoscaler,
and Vertical Pod Autoscaler.

## Features

- Official Metrics Server image pinned to `v0.9.0`.
- Explicit APIService, ServiceAccount, ClusterRole, ClusterRoleBinding, and
  delegated-authentication RoleBinding ownership.
- Typed settings for common kubelet and Metrics Server flags, with
  `metricsServer.extraArgs` as a controlled escape hatch.
- Restricted pod and container security contexts, including non-root execution,
  dropped capabilities, a read-only root filesystem, and RuntimeDefault seccomp.
- Optional high availability with replicas, PodDisruptionBudget, topology
  spread, and host-network-aware rollout behavior.
- Optional NetworkPolicy, Prometheus Operator ServiceMonitor, dual-stack
  Service configuration, and hardened Helm readiness test.
- Guarded rendering when a Kubernetes distribution already owns the APIService
  or aggregated metrics reader ClusterRole.

## Installation

Install from the HTTPS repository:

```bash
helm repo add helmforge https://repo.helmforge.dev
helm repo update
helm install metrics-server helmforge/metrics-server \
  --namespace kube-system \
  --create-namespace
```

Or install from the OCI registry:

```bash
helm install metrics-server \
  oci://ghcr.io/helmforgedev/helm/metrics-server \
  --namespace kube-system \
  --create-namespace
```

Metrics Server `0.9.x` is tested upstream against the last three Kubernetes
minor releases. This chart declares `kubeVersion: >=1.31.0-0`; verify the
upstream compatibility matrix whenever upgrading Kubernetes or overriding the
image tag.

## Architecture

Metrics Server watches Kubernetes nodes and pods, connects to each kubelet
resource metrics endpoint, and retains a short-lived in-memory view. The
Kubernetes API aggregation layer forwards Metrics API requests to the chart
Service, which targets the named `https` container port. The value
`containerPort` also configures the real process listener through
`--secure-port`; `service.port` remains an independent cluster-facing port.

The main pod needs its ServiceAccount token to watch Kubernetes objects and use
delegated authentication. The Helm test pod does not need API access and keeps
token automounting disabled. Metrics Server is not a historical monitoring
store: it does not persist samples and does not replace Prometheus or another
application observability system.

See [DESIGN.md](DESIGN.md) for resource ownership, trust boundaries, rollout
behavior, known limitations, and non-goals.

## Security

The default container runs as a non-root user, drops all Linux capabilities,
disables privilege escalation, uses a read-only root filesystem, and applies
RuntimeDefault seccomp. The main ServiceAccount token is intentionally mounted
because Metrics Server must watch Kubernetes objects and participate in
delegated authentication. Review cluster-scoped RBAC, APIService TLS, kubelet
trust, and node-network policy as part of the platform security boundary.

Security Scan: metrics-server

| Framework | Score |
|---|---:|
| MITRE + NSA + SOC2 | 89.90% |

Security posture acceptable. The score is produced by the repository's local
Kubescape validation and must be refreshed by CI when rendered resources or
security controls change.

## Production Example

Use multiple replicas, disruption protection, and topology spread. Replace the
example NetworkPolicy CIDRs with the real control-plane and node networks for
your platform:

```yaml
replicaCount: 2

pdb:
  enabled: true
  maxUnavailable: 1
  unhealthyPodEvictionPolicy: AlwaysAllow

topologySpreadConstraints:
  - maxSkew: 1
    topologyKey: kubernetes.io/hostname
    whenUnsatisfiable: DoNotSchedule
    labelSelector:
      matchLabels:
        app.kubernetes.io/name: metrics-server

networkPolicy:
  enabled: true
  ingress:
    apiServerCidrs:
      - 10.0.0.0/24
  egress:
    enabled: true
    kubeletCidrs:
      - 10.0.0.0/16
    apiServerCidrs:
      - 10.0.0.0/24
```

High availability requires at least two schedulable nodes. Where configurable,
enable kube-apiserver aggregator routing so requests are distributed across
Metrics Server replicas. Size CPU and memory from cluster node and pod counts,
scrape resolution, and observed request latency rather than treating the
defaults as universal production capacity.

## TLS and Local Cluster Example

Kubelet certificate validation is enabled by default. For production, mount a
trusted CA and configure its path:

```yaml
metricsServer:
  kubelet:
    insecureTLS: false
    certificateAuthority: /etc/kubernetes/pki/kubelet-ca.crt

extraVolumes:
  - name: kubelet-ca
    secret:
      secretName: kubelet-serving-ca

extraVolumeMounts:
  - name: kubelet-ca
    mountPath: /etc/kubernetes/pki
    readOnly: true
```

Local k3d and kind clusters often use kubelet certificates without address
subject alternative names. The following override is suitable for local smoke
testing, but it disables kubelet identity verification and should not be copied
to production:

```yaml
metricsServer:
  kubelet:
    insecureTLS: true
```

The APIService has a separate TLS boundary. Its default
`apiService.insecureSkipTLSVerify=true` supports the self-signed serving
certificate generated by Metrics Server. Platforms that inject or manage a
trusted serving certificate should set `apiService.caBundle` and disable the
skip option.

## Existing Cluster Resources

Some Kubernetes distributions already provide `v1beta1.metrics.k8s.io` or the
`system:aggregated-metrics-reader` ClusterRole. The chart uses cluster lookups
to avoid adopting those platform-owned resources into the Helm release. When a
platform owns the complete integration, disable the relevant chart resources
deliberately and keep ownership documented:

```yaml
apiService:
  create: false

rbac:
  create: false
```

The chart rejects the inconsistent combination in which it manages the
APIService but RBAC creation is disabled.

## Observability

Enable a ServiceMonitor when Prometheus Operator is already installed:

```yaml
serviceMonitor:
  enabled: true
  additionalLabels:
    release: prometheus
  interval: 30s
  scrapeTimeout: 10s
```

This integration exposes Metrics Server's own process metrics. It does not
export or retain the application resource metrics returned by the aggregated
API. Monitor the APIService `Available` condition, pod readiness, scrape-error
logs, and API request latency alongside process metrics.

## Validation

After installation, verify both the direct serving path and the aggregation
path:

```bash
helm test metrics-server --namespace kube-system
kubectl get apiservice v1beta1.metrics.k8s.io
kubectl wait --for=condition=Available \
  apiservice/v1beta1.metrics.k8s.io --timeout=120s
kubectl top nodes
kubectl top pods --all-namespaces
```

Metrics samples may take one or more collection intervals to appear after a
fresh installation. A ready pod alone does not prove that kubelet scraping or
API aggregation works.

## Troubleshooting

| Symptom | Investigation | Corrective action |
|---|---|---|
| `Metrics API not available` | Describe `v1beta1.metrics.k8s.io` and inspect Service endpoints. | Correct APIService, endpoint, or control-plane-to-Service routing. |
| Kubelet certificate errors | Compare the node address with certificate SANs and CA trust. | Repair certificate issuance or mount the trusted CA; use insecure TLS only for local testing. |
| HPA reports missing metrics | Check Metrics Server logs, node readiness, and kubelet connectivity. | Restore kubelet auth, routing, or runtime resource metrics. |
| Requests time out with NetworkPolicy | Confirm DNS, API server, node CIDRs, and kubelet port rules. | Replace example CIDRs with cluster-specific ranges. |
| Host-network upgrade stalls | Inspect node count, pod placement, and port conflicts. | Keep the chart's host-network-safe rollout or provide a compatible custom strategy. |

For deployment prerequisites, security decisions, capacity guidance, and a
production checklist, read the [production guide](docs/production.md).

## Main Values

| Key | Default | Description |
|---|---:|---|
| `image.repository` | `registry.k8s.io/metrics-server/metrics-server` | Official image repository. |
| `image.tag` | `v0.9.0` | Pinned Metrics Server image tag. |
| `replicaCount` | `1` | Deployment replica count. |
| `containerPort` | `10250` | Secure process listener port. |
| `service.port` | `443` | Cluster-facing Service and APIService port. |
| `apiService.create` | `true` | Create `v1beta1.metrics.k8s.io`. |
| `apiService.caBundle` | `""` | Trusted backend serving CA bundle. |
| `rbac.create` | `true` | Create cluster and delegated-authentication RBAC. |
| `metricsServer.metricResolution` | `15s` | Resource collection interval. |
| `metricsServer.kubelet.insecureTLS` | `false` | Disable kubelet TLS verification for local clusters. |
| `hostNetwork.enabled` | `false` | Use the node network namespace. |
| `pdb.enabled` | `false` | Create a PodDisruptionBudget. |
| `networkPolicy.enabled` | `false` | Create ingress and optional egress policy. |
| `serviceMonitor.enabled` | `false` | Create a Prometheus Operator ServiceMonitor. |
| `tests.enabled` | `true` | Create the Helm readiness test pod. |

## Documentation

- [Production guide](docs/production.md)
- [Design and architecture](DESIGN.md)
- [Default values](values.yaml)
- [Metrics Server upstream project](https://github.com/kubernetes-sigs/metrics-server)
- [Upstream compatibility matrix](https://github.com/kubernetes-sigs/metrics-server#compatibility-matrix)
- [HelmForge chart documentation](https://helmforge.dev/docs/charts/metrics-server)
