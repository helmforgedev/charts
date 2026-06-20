# Valkey Sentinel

## When to use

Use `sentinel` when the application or client can query Sentinel to discover the current primary.

Common cases:

- HA with primary discovery
- Sentinel-compatible clients
- need for failover without adopting Valkey Cluster

## What this architecture delivers

- role-neutral Valkey data nodes (`<release>-valkey-node`)
- dedicated Sentinel pods scaled independently (`<release>-valkey-sentinel`)
- configurable quorum
- primary discovery exclusively through the Sentinel service

## What it requires from the client

- the client must support Valkey Sentinel
- the application must tolerate primary changes discovered through Sentinel
- do not rely on a fixed `-primary` Service; the elected master can run on any `-node-N` pod after failover

## Environment requirements

- at least 3 Sentinel instances for consistent quorum
- enough data nodes to fail over without losing service
- distribution across nodes or zones to reduce correlated failure
- validated client and library behavior before production rollout

## How to think about this topology

`sentinel` is the right option when you want automatic failover without moving to the Valkey Cluster contract.
It keeps one active primary at a time and uses Sentinels for election, health observation, and replica promotion.
Data node pod names are role-neutral: `-node-0` is only the seed master at cold start, not a permanent primary identity.

## Common risks

- choosing a quorum incompatible with the number of Sentinels
- concentrating Sentinels and data nodes on the same node
- using clients that do not discover the primary correctly
- treating Sentinel as a substitute for sharding
- coupling Sentinel count to data node count (not required in this chart)

## Production best practices

- keep 3 Sentinels as the minimum baseline
- use majority quorum
- distribute Sentinels and data nodes across failure domains
- enable `pdb.enabled=true`
- validate real failover and application reconnect timing
- monitor primary changes, replication lag, and Sentinel health

## Best practices

- use at least 3 Sentinels
- keep `quorum` aligned with the number of Sentinels
- distribute Sentinels and data nodes across distinct nodes
- enable `pdb.enabled=true`
- validate failover behavior in the real environment

## Most relevant values

| Parameter | Description |
|-----------|-------------|
| `architecture` | Must be `sentinel` |
| `node.replicaCount` | Number of Valkey data nodes |
| `sentinel.replicaCount` | Number of Sentinel pods (independent of data nodes) |
| `sentinel.quorum` | Quorum for failover decisions |
| `pdb.enabled` | Protection against planned disruption |
| `metrics.enabled` | Exporter for monitoring |

## Example

```yaml
architecture: sentinel

auth:
  enabled: true
  existingSecret: valkey-auth
  existingSecretPasswordKey: valkey-password

node:
  replicaCount: 3

sentinel:
  replicaCount: 3
  quorum: 2
```

Decoupled sizing (2 data nodes + 3 Sentinels):

```yaml
architecture: sentinel

node:
  replicaCount: 2

sentinel:
  replicaCount: 3
  quorum: 2
```

## When to move to another mode

- move back to `replication` if the application cannot operate with Sentinel
- move to `cluster` when the primary need becomes shard-based scale rather than failover

## Upgrading from 1.x

See [UPGRADING.md](../UPGRADING.md) for the 2.0.0 breaking change and migration path.
