# Redis Chart Design

Status: draft-approved for implementation start

Date: 2026-03-19

## Goal

Build a Redis chart that is explicit about topology and honest about operational tradeoffs.

This chart must not behave like a generic stateful workload wrapper. It must model Redis-specific runtime concerns:

- standalone
- replication
- sentinel
- Redis Cluster

## References

- Internal quality reference: [`charts/mongodb`](../mongodb/)
- Bitnami Redis chart values: https://raw.githubusercontent.com/bitnami/charts/main/bitnami/redis/values.yaml
- Redis Sentinel docs: https://redis.io/docs/latest/operate/oss_and_stack/management/sentinel/
- Redis Cluster docs: https://redis.io/docs/latest/operate/oss_and_stack/management/scaling/

## Product Positioning

This chart will support both HA families that operators actually choose:

1. `replication` + `sentinel`
This is the right answer when the application expects a single writable primary and operator-managed failover.

2. `cluster`
This is the right answer when the application is cluster-aware and needs sharding/scaling at the Redis protocol level.

`standalone` remains useful for development, small environments and simple single-node production cases.

## Supported Topologies In v1

- `standalone`
- `replication`
- `sentinel`
- `cluster`

Decision:

- `replication` and `sentinel` are separate modes in values and templates.
- `sentinel` is not hidden inside replication because it changes the operational contract.
- `cluster` is modeled separately because it is not just HA; it is a different client and topology model.

## Explicit Non-Goals In v1

- Redis Enterprise or active-active
- arbitrary Redis modules as first-class chart features
- operator-grade rebalancing or node replacement automation
- complete zero-downtime cluster reshaping

## High-Level Values Model

Top-level decision:

```yaml
architecture: standalone | replication | sentinel | cluster
```

Core sections planned:

- `image`
- `auth`
- `tls`
- `standalone`
- `replication`
- `sentinel`
- `cluster`
- `persistence`
- `service`
- `metrics`
- `podSecurityContext`
- `securityContext`
- `resources`
- `nodeSelector`
- `affinity`
- `tolerations`
- `topologySpreadConstraints`
- `serviceMonitor`
- `existingSecret`
- `extraEnv`
- `extraVolumes`
- `extraVolumeMounts`
- `extraManifests`

## Redis-Specific Runtime Decisions

### Auth

- password auth supported in every mode
- `existingSecret` supported
- ACL support should be designed in values, but can stay limited in v1 if needed

### TLS

- optional in v1
- must be explicit in docs if only server-side TLS is supported initially

### Persistence

- `standalone`, `replication`, `sentinel` data nodes use PVCs
- sentinel pods may be stateless or lightly stateful depending on final design
- `cluster` nodes use PVCs per node

### Metrics

- optional Redis exporter
- optional `ServiceMonitor`
- exporter wiring must match each topology cleanly

### Scheduling

- `replication`, `sentinel` and `cluster` must support anti-affinity and topology spread
- HA modes should offer `PDB`

## Kubernetes Resource Model

### Standalone

- `Secret`
- `ConfigMap`
- `Service`
- `StatefulSet`
- optional `ServiceMonitor`

### Replication

- `Secret`
- `ConfigMap`
- headless `Service`
- client `Service`
- primary `StatefulSet`
- replica `StatefulSet`
- optional `PDB`
- optional `ServiceMonitor`

### Sentinel

- `Secret`
- `ConfigMap`
- headless `Service`
- client `Service`
- primary/replica data resources
- `StatefulSet` for sentinel pods, or a tightly justified alternative
- optional `PDB`
- optional `ServiceMonitor`

### Cluster

- `Secret`
- `ConfigMap`
- headless `Service`
- client `Service`
- cluster `StatefulSet`
- cluster bootstrap `Job`
- optional `PDB`
- optional `ServiceMonitor`

## Template Plan

Required:

- `_helpers.tpl`
- `secret.yaml`
- `configmap.yaml`
- `service.yaml`
- `service-headless.yaml`
- `pdb.yaml`
- `servicemonitor.yaml`
- `extra-manifests.yaml`

Topology-specific:

- `standalone-statefulset.yaml`
- `replication-primary-statefulset.yaml`
- `replication-replica-statefulset.yaml`
- `sentinel-statefulset.yaml`
- `cluster-statefulset.yaml`
- `cluster-init-job.yaml`

## CI Plan

`ci/standalone.yaml`

- 1 Redis node
- auth enabled
- persistence enabled
- no sentinel
- no cluster

`ci/replication.yaml`

- primary + replicas
- headless and client services
- auth enabled
- anti-affinity enabled

`ci/sentinel.yaml`

- replication plus sentinel resources
- sentinel service exposure
- failover configuration rendered

`ci/cluster.yaml`

- cluster node count set
- bootstrap job rendered
- cluster service model rendered

`ci/existing-secret.yaml`

- no generated auth secret
- all secret refs point to external secret

`ci/metrics.yaml`

- exporter rendered
- `ServiceMonitor` rendered when enabled

## Main Differentials Versus References

- smaller values surface than Bitnami
- topology is the first concept in values, not hidden in nested switches
- separate operational contracts for sentinel and cluster
- CI explicitly validates every supported topology
- README will explain when to use each mode, not only how to enable it

## Implementation Order

1. `Chart.yaml`
2. `values.yaml`
3. `_helpers.tpl`
4. standalone templates
5. replication templates
6. sentinel templates
7. cluster templates
8. `ci/*.yaml`
9. `examples/*.yaml`
10. `README.md`

## Ready To Implement

Yes.
