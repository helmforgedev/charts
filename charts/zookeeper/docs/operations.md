# ZooKeeper Operations

## Overview

ZooKeeper is a replicated coordination service. Availability depends on a
majority of ensemble members being healthy, reachable, and able to persist
state. This chart models that requirement with a StatefulSet, stable pod DNS,
default three-replica quorum, persistent volumes, and validation that blocks
accidental even replica counts.

## Ensemble Sizing

Use an odd number of servers for production:

- `replicaCount=3` tolerates one failed server.
- `replicaCount=5` tolerates two failed servers.
- even sizes add cost without improving failure tolerance over the next lower
  odd size.

The chart fails rendering for even replica counts above one unless
`allowEvenReplicas=true` is set deliberately.

## Standalone Mode

Use standalone mode for development and CI only:

```yaml
replicaCount: 1

persistence:
  enabled: false
```

When `replicaCount=1` and `zookeeper.standaloneEnabled=true`, the generated
configuration avoids quorum server entries and runs a single ZooKeeper server.

## Production Baseline

```yaml
replicaCount: 3

persistence:
  enabled: true
  size: 20Gi
  dataLogDir:
    enabled: true
    size: 10Gi

podDisruptionBudget:
  enabled: true
  maxUnavailable: 1

resources:
  requests:
    cpu: 500m
    memory: 1Gi
  limits:
    memory: 2Gi

networkPolicy:
  enabled: true
```

Use a storage class with predictable latency. ZooKeeper is sensitive to slow
fsync and inconsistent disk performance.

## Connection Endpoints

Applications should use the client Service:

```text
zookeeper.<namespace>.svc.cluster.local:2181
```

Peers use stable pod names under the headless Service:

```text
zookeeper-0.zookeeper-headless.<namespace>.svc.cluster.local
zookeeper-1.zookeeper-headless.<namespace>.svc.cluster.local
zookeeper-2.zookeeper-headless.<namespace>.svc.cluster.local
```

## Operational Checks

Run the Helm test:

```bash
helm test zookeeper -n zookeeper
```

Check pod readiness:

```bash
kubectl get pods -n zookeeper -l app.kubernetes.io/name=zookeeper
```

Check ZooKeeper server status:

```bash
kubectl exec -n zookeeper zookeeper-0 -- zkServer.sh status
```

Check enabled four-letter commands from inside the cluster:

```bash
kubectl run zk-check -n zookeeper --rm -i --restart=Never \
  --image=docker.io/library/busybox:1.37.0 -- \
  sh -c "echo ruok | nc zookeeper 2181"
```

Expected response for `ruok` is `imok` when the command is whitelisted and the
server is healthy.

## Rolling Updates

Update one pod at a time and wait for quorum health before continuing:

```bash
kubectl rollout status statefulset/zookeeper -n zookeeper --timeout=5m
kubectl get pods -n zookeeper -l app.kubernetes.io/name=zookeeper
```

For production clusters, confirm `zkServer.sh status` on every member after a
restart and verify that one member is leader while the rest are followers.

## Troubleshooting

### Pods are not ready

Check StatefulSet events and container logs:

```bash
kubectl describe statefulset zookeeper -n zookeeper
kubectl logs -n zookeeper zookeeper-0 -c zookeeper --tail=200
kubectl get events -n zookeeper --sort-by=.lastTimestamp
```

### Quorum does not form

Confirm headless DNS resolution from a pod:

```bash
kubectl exec -n zookeeper zookeeper-0 -- getent hosts \
  zookeeper-1.zookeeper-headless.zookeeper.svc.cluster.local
```

### Storage is slow

Look for repeated session expiry, fsync warnings, or long startup times in logs.
Move production ensembles to a storage class with lower latency and set resource
requests high enough for steady JVM operation.

## References

- [Apache ZooKeeper Administrator's Guide](https://zookeeper.apache.org/doc/current/zookeeperAdmin.html)
- [Apache ZooKeeper Getting Started](https://zookeeper.apache.org/doc/current/zookeeperStarted.html)
