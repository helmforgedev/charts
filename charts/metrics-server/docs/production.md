<!-- SPDX-License-Identifier: Apache-2.0 -->

# Metrics Server Production Guide

This guide covers the platform prerequisites and operational decisions that are
outside Helm's control. Review them before enabling autoscaling against the
Metrics API.

## Platform Prerequisites

Metrics Server requires the Kubernetes API aggregation layer, kubelet webhook
authentication and authorization, and network paths in both directions:

1. The control plane must reach the Metrics Server Service or pod endpoint.
2. Metrics Server must reach every kubelet using one of the configured
   `preferredAddressTypes` and the kubelet port reported by the Node.
3. Kubelets must expose container resource metrics through the container
   runtime integration.
4. Cluster DNS must resolve Kubernetes services when egress policy is enabled.

Confirm the distribution supports Metrics Server `0.9.x` and the chart's
minimum Kubernetes version before installation. The upstream project tests the
last three Kubernetes minor releases; do not infer support for an older cluster
only because Helm can render its manifests.

## Secure Kubelet TLS

Keep certificate validation enabled:

```yaml
metricsServer:
  kubelet:
    insecureTLS: false
    certificateAuthority: /etc/kubernetes/pki/kubelet-ca.crt
```

Mount the referenced CA through `extraVolumes` and `extraVolumeMounts`. Kubelet
serving certificates must contain the IP address or hostname selected by
`metricsServer.kubelet.preferredAddressTypes`. If they do not, repair kubelet
certificate issuance rather than globally disabling verification.

`metricsServer.kubelet.insecureTLS=true` is an explicit exception for local
k3d/kind validation and other accepted-risk environments. It allows a
machine-in-the-middle attacker on the node network to impersonate a kubelet.

## APIService TLS and Ownership

Metrics Server generates a self-signed serving certificate by default, so the
APIService initially uses `insecureSkipTLSVerify=true`. Platforms with a serving
certificate controller should configure a trusted backend CA through
`apiService.caBundle` and set `apiService.insecureSkipTLSVerify=false`.

Some distributions manage `v1beta1.metrics.k8s.io` and
`system:aggregated-metrics-reader`. The chart skips existing cluster-owned
objects instead of adopting them. Decide whether the platform or Helm owns the
complete Metrics API integration, and avoid splitting lifecycle responsibility
without an explicit runbook.

## High Availability and Capacity

Run at least two replicas across at least two schedulable nodes:

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
```

Enable kube-apiserver aggregator routing where the distribution exposes that
setting; otherwise requests may continue to prefer one replica. A PDB protects
voluntary disruptions but cannot create capacity or protect against a node
failure when all replicas share a node.

Tune resources using node count, pod count, `metricResolution`, scrape latency,
and throttling or out-of-memory observations. Metrics Server retains samples in
memory and has no persistent volume, backup, or restore requirement.

## Networking

Use host networking only when the API server cannot reach the pod network:

```yaml
hostNetwork:
  enabled: true
```

With the default strategy, the chart changes host-network rollouts to
`maxUnavailable: 1` and `maxSurge: 0` so a replacement does not wait for a host
port held by the old pod. A custom strategy overrides that safeguard and must be
validated against node count and scheduling constraints.

NetworkPolicy is opt-in because node and control-plane CIDRs cannot be inferred
portably. Before enabling egress restrictions, identify:

- control-plane or API server CIDRs and port;
- every node CIDR used by the selected kubelet address types;
- the effective kubelet serving port;
- cluster DNS selectors or IP ranges required by the CNI.

Replace the broad default example ranges. Validate from the Metrics Server pod,
not only from an administrator workstation.

## Observability and Verification

The optional ServiceMonitor scrapes process metrics when Prometheus Operator is
installed. Use `serviceMonitor.additionalLabels` for Prometheus discovery
labels. The chart intentionally does not create dashboards or PrometheusRule
objects because alert thresholds and routing belong to the monitoring platform.

After every install or upgrade, run:

```bash
helm test metrics-server --namespace kube-system
kubectl get apiservice v1beta1.metrics.k8s.io
kubectl describe apiservice v1beta1.metrics.k8s.io
kubectl top nodes
kubectl top pods --all-namespaces
kubectl logs -n kube-system \
  -l app.kubernetes.io/name=metrics-server --tail=200
```

Wait at least one metric-resolution interval before treating empty initial
results as a failure. Monitor the APIService availability condition, pod
readiness, failed kubelet scrapes, request errors, latency, throttling, and
memory pressure.

## Production Checklist

- Kubernetes version is within the supported Metrics Server compatibility
  window.
- Aggregation layer and kubelet webhook authentication/authorization are
  enabled.
- Kubelet certificates validate for every preferred address type.
- Control-plane-to-Service and pod-to-kubelet paths are tested.
- NetworkPolicy CIDRs match actual platform networks.
- Two or more replicas are spread across failure domains when HA is required.
- Aggregator routing is enabled where supported.
- Resource requests and limits were reviewed against cluster scale.
- APIService ownership and backend TLS trust are documented.
- Helm test, APIService condition, `kubectl top`, logs, and events are clean.

## Troubleshooting

If the APIService is unavailable, inspect its condition message, Service
endpoints, and control-plane routing. If the APIService is healthy but samples
are absent, inspect logs for kubelet authentication, certificate, address, and
timeout failures. If only some nodes fail, compare their addresses, serving
certificates, firewall paths, runtime configuration, and Node status ports.

Do not use insecure TLS as a general fix for routing, authorization, or runtime
metrics failures: it addresses only kubelet certificate verification.
