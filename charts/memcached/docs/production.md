# Memcached Production Guide

## Deployment Model

Memcached stores cache entries in memory and does not replicate data between
pods. In production, prefer `architecture: distributed` with at least three
replicas and a client library that supports consistent hashing. The chart keeps
stable StatefulSet pod identities and a headless Service so clients can address
individual cache nodes when they need deterministic distribution.

Use `standalone` only when losing a single cache node is acceptable. It is a
good fit for development, CI, preview environments, or small workloads where a
cache miss storm is not a material risk.

## Sizing

Set `memcached.memoryLimitMB` lower than the container memory limit. Memcached
uses the `-m` value for item memory, while the process also needs memory for
connections, slabs, thread overhead, TLS state, and exporter sidecars when
enabled.

A practical starting point is:

```yaml
architecture: distributed
replicaCount: 3

memcached:
  memoryLimitMB: 512
  maxConnections: 2048
  threads: 4
  disableFlushAll: true

resources:
  requests:
    cpu: 250m
    memory: 768Mi
  limits:
    cpu: 1000m
    memory: 1Gi
```

Increase `memcached.maxItemSize` only when applications truly need larger
objects. Large objects reduce slab efficiency and make cache churn more
expensive.

## Placement

For distributed mode, spread pods across nodes or zones so one node drain does
not remove most cache capacity. Combine topology spread constraints or
anti-affinity with a PodDisruptionBudget.

```yaml
pdb:
  enabled: true
  maxUnavailable: 1

topologySpreadConstraints:
  - maxSkew: 1
    topologyKey: kubernetes.io/hostname
    whenUnsatisfiable: DoNotSchedule
    labelSelector:
      matchLabels:
        app.kubernetes.io/name: memcached
```

Do not combine HPA with PVC-backed extstore. The chart blocks that combination
because each extstore path is pod-local and scaling changes cache placement.

## Security Boundary

Memcached is a cache protocol, not an identity platform. Keep the Service
private to trusted namespaces whenever possible and enable NetworkPolicy when
the cluster CNI enforces it.

```yaml
networkPolicy:
  enabled: true
  ingress:
    enabled: true
  egress:
    enabled: true
    allowSameNamespace: true
    allowDNS: true
```

Use ASCII auth for clients that support the text protocol authentication flow.
Use SASL only with clients that support binary protocol SASL and provide a
prepared sasldb Secret. Use TLS when cache traffic crosses an untrusted network
boundary or platform policy requires encryption in transit.

External Secrets Operator can source the auth Secret from a platform secret
store:

```yaml
auth:
  enabled: true
  existingSecret: memcached-auth

externalSecrets:
  enabled: true
  secretStoreRef:
    name: platform-secrets
    kind: ClusterSecretStore
  data:
    - secretKey: authfile
      remoteRef:
        key: memcached/auth
        property: authfile
```

## Observability

Enable the exporter and Prometheus resources for production clusters with
Prometheus Operator installed.

```yaml
metrics:
  enabled: true
  serviceMonitor:
    enabled: true
  prometheusRule:
    enabled: true
```

The upstream exporter can scrape Memcached over TLS, but it does not support
Memcached authentication. The chart prevents `metrics.enabled=true` with
`auth.enabled=true` so the exporter does not run in a permanently failing
state.

Watch these signals during rollout and scaling:

- `curr_connections` and rejected connection errors
- `bytes` relative to the configured memory limit
- eviction rate after pod replacement or scaling events
- cache hit ratio in application metrics
- pod restarts and OOMKilled events

## Rollout Checks

After install or upgrade, verify pod readiness and run a simple cache command
from inside the cluster:

```bash
kubectl rollout status statefulset/memcached
kubectl get pods -l app.kubernetes.io/name=memcached

kubectl run memcached-client --rm -it --restart=Never \
  --image=docker.io/library/busybox:1.37.0 -- \
  sh -ec "printf 'version\r\nquit\r\n' | nc memcached 11211"
```

For distributed deployments, validate that all expected pods are addressable
through the headless Service:

```bash
kubectl get endpoints memcached-headless
kubectl exec statefulset/memcached -c memcached -- sh -ec "hostname && memcached -h | head -n 1"
```

## Related Documents

- [../README.md](../README.md)
- [../DESIGN.md](../DESIGN.md)
- [../examples/production.yaml](../examples/production.yaml)
