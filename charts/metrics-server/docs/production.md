# Production

Use the secure kubelet TLS path in production:

```yaml
metricsServer:
  kubelet:
    insecureTLS: false
```

If kubelet serving certificates are not signed by a trusted cluster CA or do not include node address SANs, fix kubelet certificate issuance rather than disabling verification.

## High Availability

```yaml
replicaCount: 2

pdb:
  enabled: true
  maxUnavailable: 1
```

Metrics Server HA works best when kube-apiserver aggregator routing is enabled.

## APIService TLS

The default APIService uses `insecureSkipTLSVerify=true` because Metrics Server generates a self-signed serving certificate.
Set `apiService.caBundle` when your platform injects or manages a trusted serving CA.

If the cluster already provides `v1beta1.metrics.k8s.io` or `system:aggregated-metrics-reader`, the chart skips those
cluster-scoped resources instead of adopting ownership from the platform-managed object.

## Host Network

Enable host networking only when the API server cannot reach the Metrics Server pod network:

```yaml
hostNetwork:
  enabled: true
```

When `hostNetwork.enabled=true` and the default rolling update strategy is unchanged, the chart renders `maxUnavailable: 1` and `maxSurge: 0`.
This avoids single-node upgrades stalling while a replacement pod waits for the same host-network secure port still held by the old pod.

## NetworkPolicy

Metrics Server must reach kubelets on every node. When enabling egress NetworkPolicy, verify your CNI policy model allows traffic to node IPs and kubelet ports.
