# Redis Sentinel

## When to use

Use `sentinel` when the application or client can query Sentinel to discover the current primary.

Common cases:

- HA with primary discovery
- Sentinel-compatible clients
- need for failover without adopting Redis Cluster

## What this architecture delivers

- role-neutral Redis data nodes (`<release>-redis-node`)
- dedicated Sentinel pods scaled independently (`<release>-redis-sentinel`)
- configurable quorum
- primary discovery exclusively through the Sentinel service

## What it requires from the client

- the client must support Redis Sentinel
- the application must tolerate primary changes discovered through Sentinel
- do not rely on a fixed `-primary` Service; the elected master can run on any `-node-N` pod after failover

## Environment requirements

- at least 3 Sentinel instances for consistent quorum
- enough data nodes to fail over without losing service
- distribution across nodes or zones to reduce correlated failure
- validated client and library behavior before production rollout

## How to think about this topology

`sentinel` is the right option when you want automatic failover without moving to the Redis Cluster contract.
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
| `node.replicaCount` | Number of Redis data nodes (use >= 2 for data HA) |
| `node.persistence.enabled` | Data node PVCs (default `true`; peer discovery still protects topology during discovery failures) |
| `auth.sentinel` | Require password authentication on the Sentinel control plane |
| `sentinel.replicaCount` | Number of Sentinel pods (independent of data nodes) |
| `sentinel.masterSet` | Master set name that Sentinel clients use for primary discovery |
| `sentinel.quorum` | Quorum for failover decisions |
| `pdb.enabled` | Protection against planned disruption |
| `metrics.enabled` | Exporter for monitoring |

`auth.sentinel=false` keeps the Sentinel control plane unauthenticated while
Redis data nodes remain protected by `auth.enabled`. Set it to `true` when
Sentinel clients also need password authentication. When TLS is enabled,
Sentinel requires a client certificate signed by the configured CA.

## Example

```yaml
architecture: sentinel

auth:
  enabled: true
  existingSecret: redis-auth
  existingSecretPasswordKey: redis-password

node:
  replicaCount: 3

sentinel:
  replicaCount: 3
  masterSet: mymaster
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

## Resilience and trade-offs

### Default: persistence enabled

`node.persistence.enabled` defaults to `true`. Each data node receives a PVC for `/data`.
Anti-split-brain safety does not depend on the bootstrap marker surviving reschedules.
When Sentinel is unreachable, each node probes peer `INFO replication` before choosing a role.

Without additional safeguards, a single restart of the active master pod inside the
`down-after-milliseconds` window would resume it as an empty master and make every
replica full-resync from an empty dataset. The chart mitigates this with
`sentinel.gracefulFailover` (preStop-triggered failover on voluntary disruptions) and
`sentinel.startupFailoverGuard` (a fresh master refuses to resume while peers still
hold data and forces a failover first). Residual data loss remains possible if these
guards are disabled, if no replica is promotable, or if every data node restarts at
the same time. Keep `node.persistence.enabled=true` when RDB/AOF and the
bootstrap marker must survive pod reschedules.

### Replica sync during rollouts and voluntary shutdowns

A restarted replica reloads its own AOF/RDB and then needs a full sync from the
master. While it waits for and receives that sync it already answers `PING`, but
it holds the data from the moment it stopped. Promoting it at that point would
silently drop every write the master accepted since the replica restarted.

Two checks prevent that:

- **Readiness.** A data node running as a replica is ready only when
  `master_link_status:up` and `master_sync_in_progress:0`. A master is ready when
  it answers `PING`. A StatefulSet rollout therefore restarts the next node, which
  may be the master, only after the previous one has caught up. Liveness and
  startup probes still use `PING`, so a replica in a long sync is not restarted.
- **Graceful failover.** Before the active master requests a Sentinel failover, the
  preStop hook waits until every replica it feeds is `state=online` and
  acknowledged within the last second. Sentinel chooses which replica to promote,
  and its list can include a replica that is not connected to this master, so the
  hook also asks every replica a Sentinel could promote whether its link is up and
  its sync finished. It then pauses writes (`CLIENT PAUSE WRITE`), waits until all
  of those replicas reach the master replication offset, and requests the
  failover. If Sentinel
  refuses, for example because it has not reconnected to a replica that just
  restarted, the hook releases the pause and tries again. Once Sentinel accepts,
  or reports that a failover is already in progress, writes stay paused until the
  old master exits, even if the hook cannot confirm the result, so clients retry
  against the new master instead of writing to the old one. If no attempt
  succeeds within `sentinel.gracefulFailover.replicaSyncTimeoutSeconds`, or if the
  `CLIENT` command is unavailable (for example renamed through `config.redis`),
  the hook skips the failover and lets the master restart in place.

When every data node stops at once, for example on `helm uninstall` or namespace
deletion, the master has no replica to hand over to. It keeps serving and waits for
`replicaSyncTimeoutSeconds` before it exits, so the deletion takes that long.

For large datasets a full sync can take minutes. Raise
`sentinel.gracefulFailover.replicaSyncTimeoutSeconds` and
`terminationGracePeriodSeconds` together; the grace period must cover
`replicaSyncTimeoutSeconds + 3 * maxAttempts + 5` seconds plus Redis shutdown time.

### Fail-closed behavior

When persistence is enabled and a node was already bootstrapped, it refuses to start as an
unconfirmed master if neither Sentinel nor any peer can confirm the current topology.
The pod exits with code 1 (CrashLoopBackOff) until Sentinel quorum or peer discovery succeeds.
This is a safety-over-availability trade-off.

A prolonged Sentinel quorum outage can block restarts of persisted nodes until Sentinels recover.

### Hostname discovery

Sentinel is configured with `resolve-hostnames yes` and `announce-hostnames yes`.
`sentinel get-master-addr-by-name mymaster` returns stable pod hostnames instead of ephemeral IPs.

### HA prerequisites

- `node.replicaCount >= 2` for data-plane HA (at least one replica to promote)
- `sentinel.replicaCount >= 3` with `sentinel.quorum` aligned to the Sentinel count
- `pdb.enabled=true` for planned disruption protection
- spread Sentinels and data nodes across failure domains

## End-to-end validation (k3d)

Run on a lab cluster before production rollout. Shell bootstrap logic is not covered by helm unittest.

1. Install with default values (`node.persistence.enabled=true`) and wait for Ready pods.
2. Resolve the master via Sentinel and write a test key.
3. Delete the current master pod; confirm another `-node-N` is promoted and the key survives.
4. Scale Sentinel to 0 or block Sentinel traffic; delete and recreate `-node-0`.
   Confirm it joins as replica (no double master) via peer discovery.
5. After Sentinels recover, confirm `get-master-addr-by-name` returns a hostname, not a pod IP.

## When to move to another mode

- move back to `replication` if the application cannot operate with Sentinel
- move to `cluster` when the primary need becomes shard-based scale rather than failover

## Upgrading from 1.x

See [UPGRADING.md](../UPGRADING.md) for the 2.0.0 breaking change and migration path.
