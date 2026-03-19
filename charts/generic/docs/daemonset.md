# Generic Chart for DaemonSets

## When to use

Use `DaemonSet` when the intended behavior is one pod per eligible node.

Common cases:

- node agents
- log shippers
- security collectors
- cluster-level side services that must run close to the node

## What this mode delivers

- one pod per eligible node
- update strategy for rolling replacement
- tolerations and node selection for infrastructure nodes
- reuse of the same container, env, persistence, and observability patterns as other workloads

## What it does not deliver

- replica-based autoscaling
- service patterns typical of front-door applications
- batch execution semantics

## Recommended practices

- use broad tolerations only when the agent truly belongs on all nodes
- set node selectors deliberately if the workload should run only on a subset of nodes
- avoid ingress and external service exposure unless the daemon actually provides a node-facing API
- keep resource requests realistic because a DaemonSet multiplies by node count

## Most relevant values

| Parameter | Description |
|-----------|-------------|
| `workload.type` | Must be `DaemonSet` |
| `workload.updateStrategy` | Rolling update behavior |
| `containers` | Agent container definition |
| `tolerations` | Node tolerance rules |
| `nodeSelector` | Node filtering |
| `serviceMonitor.*` | Observability hooks |

## Example

```yaml
workload:
  enabled: true
  type: DaemonSet
  updateStrategy:
    type: RollingUpdate
    rollingUpdate:
      maxUnavailable: 1

image:
  repository: ghcr.io/example/node-agent
  tag: "0.8.0"

imageTagFormat: simple

containers:
  - name: agent
    ports:
      - containerPort: 9090

tolerations:
  - operator: Exists
```
