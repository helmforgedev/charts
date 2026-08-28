# MongoDB Replica Set

## When to use

Use `replicaset` when you need MongoDB high availability with automatic elections and a standard topology for production workloads.

Common cases:

- production applications with a single writable primary
- environments that need automatic primary election
- workloads that want redundancy without full sharding complexity
- teams standardizing on replica set semantics for backup, maintenance, and upgrades

## What this architecture delivers

- multiple data-bearing members
- automatic `rs.initiate()` bootstrap via Helm hook job
- an optional non-data-bearing arbiter for an odd number of election votes
- internal member authentication with key file
- a standard MongoDB replica set topology
- optional metrics and `ServiceMonitor`

## What it does not deliver

- shard-based horizontal data distribution
- write scaling beyond a single primary
- topology abstraction for clients that are not replica-set aware

## Environment requirements

- at least 3 members for a production-grade quorum
- persistent volumes for each member
- network stability between members
- applications and clients configured to use replica set connection strings

## Operational guidance

`replicaset` is usually the right default for production MongoDB when you need HA
but do not need sharding. This chart bootstraps the replica set automatically,
but the operational contract remains MongoDB's standard behavior: one primary,
secondaries replicating from it, and elections on failure.

## Common risks

- running only 2 members and expecting safe elections
- treating an arbiter as a replacement for data redundancy
- forgetting the replica set connection string in clients
- scheduling all members in the same node or zone
- ignoring backup and restore testing because failover exists

## Production practices

- use 3 members as the minimum baseline
- distribute members across failure domains with affinity and topology spread
- keep `auth.enabled=true`
- use `auth.existingSecret` and `auth.existingKeySecret` when credentials are externally managed
- enable metrics and monitor replication lag, elections, and disk usage
- validate maintenance procedures such as rolling restart and version upgrade in a non-production environment

## Most relevant values

| Parameter | Description |
|-----------|-------------|
| `architecture` | Must be `replicaset` |
| `replicaSet.name` | Replica set name used by members and clients |
| `replicaSet.members` | Number of data-bearing members |
| `arbiter.enabled` | Add one non-data-bearing voting member |
| `arbiter.resources` | Resource settings for the arbiter container |
| `auth.replicaSetKey` | Internal auth key when not using existing secret |
| `auth.existingKeySecret` | Existing secret for key file |
| `persistence.*` | Storage settings for the members |
| `affinity` | Placement rules for member distribution |
| `topologySpreadConstraints` | Spread across nodes or zones |
| `metrics.enabled` | Exporter sidecar |

## Example

```yaml
architecture: replicaset

auth:
  enabled: true
  existingSecret: mongodb-credentials
  existingKeySecret: mongodb-keyfile

replicaSet:
  name: rs0
  members: 3

persistence:
  enabled: true
  size: 100Gi

metrics:
  enabled: true
  serviceMonitor:
    enabled: true
```

## Arbiter topology

MongoDB recommends three data-bearing members. When capacity constraints make a
third data copy impractical, the chart can deploy two data-bearing members and
one arbiter:

```yaml
architecture: replicaset

replicaSet:
  members: 2

arbiter:
  enabled: true
```

The arbiter uses the official MongoDB image, the same internal keyFile, stable
StatefulSet DNS, and ephemeral local storage. It votes in elections but does not
store the application data set and cannot become primary. The chart permits one
arbiter with an even number of 2 to 6 data-bearing members. Review MongoDB's
[arbiter limitations](https://www.mongodb.com/docs/manual/core/replica-set-arbiter/),
especially majority write behavior and reduced fault tolerance.

The post-upgrade hook adds or removes the arbiter when `arbiter.enabled`
changes. It can add missing data-bearing members, but deliberately does not
remove them. Follow MongoDB's member-removal procedure before reducing
`replicaSet.members`.

Adding or removing an arbiter can change MongoDB's implicit default write
concern. Before that reconfiguration, the hook preserves the currently effective
implicit value by promoting it to a global default. If the operator already set
a global default, the hook leaves it unchanged. This preservation also runs
before `rs.add()` when scale-up adds a missing data-bearing member. MongoDB 5.0
and newer do not allow the global default write concern to be unset afterward. Review
[`setDefaultRWConcern`](https://www.mongodb.com/docs/manual/reference/command/setDefaultRWConcern/)
before changing `arbiter.enabled` on an existing deployment.

## When to move to another architecture

- move back to `standalone` only for non-critical simplified environments
- move to `sharded` when data size, throughput, or tenant isolation demands shard-based distribution
