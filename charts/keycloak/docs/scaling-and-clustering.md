# Scaling and Clustering

## When to use this guide

Read this guide before increasing `replicaCount` above `1` in `mode: production`.

## What scaling means in this chart

Multiple replicas in this chart provide:

- more application instances behind the service
- distributed cache configuration through `KC_CACHE=ispn`
- explicit cache stack selection through `cache.stack`

Multiple replicas in this chart do not provide:

- operator-style cluster lifecycle management
- coordinated failover across application and data layers
- automatic validation of reverse-proxy affinity behavior

## Current recommendation

For the current chart scope:

- use `replicaCount: 1` when the environment is small, disposable, or operationally simple
- use multiple replicas only with a stable external database, explicit ingress behavior, and clear rollout procedures
- keep `cache.enabled: true` when `replicaCount > 1`
- keep `cache.stack: jdbc-ping` unless there is a tested reason to move away from it

## About `jdbc-ping`

`jdbc-ping` is the current recommended stack in this chart because it keeps node discovery tied to the shared production database instead of requiring Kubernetes-specific discovery plugins.

That helps keep the chart smaller and easier to reason about, but it has limits:

- it is discovery and cache transport plumbing, not a full cluster control plane
- it depends on a healthy shared database
- it does not remove the need for careful rolling updates
- it does not replace reverse-proxy correctness or sticky-session behavior

## Scheduling recommendations

When running multiple replicas in production:

- use at least two or three replicas depending on the failure domain policy
- add anti-affinity or topology spread constraints
- use a `PodDisruptionBudget`
- avoid single-node packing for all replicas

The chart now applies scheduling defaults automatically when all of these are true:

- `replicaCount > 1`
- `cache.multiReplicaDefaults.enabled: true`
- `affinity` is not set explicitly
- `topologySpreadConstraints` is not set explicitly

Default behavior:

- soft pod anti-affinity on `kubernetes.io/hostname`
- topology spread on `kubernetes.io/hostname` with `ScheduleAnyway`

If the environment needs stricter placement, define `affinity` or `topologySpreadConstraints` explicitly and the chart will stop injecting the defaults.

The chart already exposes:

- `affinity`
- `topologySpreadConstraints`
- `pdb`
- `priorityClassName`

## Probe tuning

The chart exposes configurable management probes:

- `probes.liveness`
- `probes.readiness`
- `probes.startup`

Use the defaults first. Increase startup timing only when the environment consistently needs more time for image pull, JVM bootstrap, or cluster convergence.

## Rollout and rollback guidance

For production rollouts:

- update one Keycloak version at a time
- validate readiness on the management service
- validate public login and admin console access before widening traffic
- confirm the database schema migration path is understood before rollout
- keep a rollback plan for image, chart values, ingress, and proxy behavior together

If providers or themes are mounted:

- confirm compatibility against the target Keycloak version before rollout
- expect restart or rollout behavior to matter more than in a plain image-only deployment

## Readiness expectations

Application readiness is only one part of production health. Before calling a rollout successful, confirm:

- the public hostname serves the expected discovery and login endpoints
- the admin hostname reaches the intended admin flows
- management health remains healthy during and after the rollout
- session behavior at the ingress layer matches the chosen controller settings

## Example production baseline

```yaml
mode: production

replicaCount: 3

cache:
  enabled: true
  stack: jdbc-ping

pdb:
  enabled: true
  minAvailable: 1
```

## Official product references

- Keycloak caching and transport stacks: https://www.keycloak.org/server/caching
- Keycloak production configuration: https://www.keycloak.org/server/configuration-production
