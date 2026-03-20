# RabbitMQ

RabbitMQ for Kubernetes with explicit `single-node` and `cluster` modes, optional Management UI, optional TLS, optional metrics, and dedicated operational docs for each architecture.

## Install

### HTTPS repository

```bash
helm repo add helmforge https://repo.helmforge.dev
helm repo update
helm install rabbitmq helmforge/rabbitmq -f values.yaml
```

### OCI registry

```bash
helm install rabbitmq oci://ghcr.io/helmforgedev/helm/rabbitmq -f values.yaml
```

## Supported architectures

| Architecture | When to use | Document |
|-------------|-------------|----------|
| `single-node` | simple environments, development, staging, and workloads without broker-node failover requirements | [docs/single-node.md](docs/single-node.md) |
| `cluster` | production with multiple nodes, quorum queues, and broker redundancy | [docs/cluster.md](docs/cluster.md) |

## What this chart covers

- explicit architecture selection through `architecture`
- authentication with username, password, and Erlang cookie
- `existingSecret` for credentials managed outside the chart
- transparent `rabbitmq.conf` and `enabled_plugins` modeling
- optional Management UI
- optional TLS for AMQP and Management UI
- optional metrics through the native RabbitMQ Prometheus plugin
- optional `ServiceMonitor`
- optional `PodDisruptionBudget`
- ingress support for the Management UI with configurable `ingressClassName`

## How to choose the architecture

- use `single-node` when operational simplicity matters more than broker redundancy
- use `cluster` when queues must survive node loss and the application already handles multi-broker reconnect correctly

Recommended reading before installation:

- [Single Node](docs/single-node.md)
- [Cluster](docs/cluster.md)

## Official product references

- RabbitMQ Downloads: https://www.rabbitmq.com/docs/download
- RabbitMQ Cluster Formation: https://www.rabbitmq.com/docs/cluster-formation
- RabbitMQ Quorum Queues: https://www.rabbitmq.com/quorum-queues.html
- RabbitMQ TLS: https://www.rabbitmq.com/docs/ssl

## Operational direction

- for production, the recommended mode is `cluster` with `queueDefaults.type=quorum`
- use `single-node` only when broker-level HA is not a requirement
- do not treat a RabbitMQ cluster as a substitute for good queue design, routing, or consumer reconnect behavior

## Quick start

Minimal example:

```yaml
architecture: single-node

auth:
  existingSecret: rabbitmq-auth

singleNode:
  persistence:
    enabled: true
    size: 8Gi
```

Cluster example:

```yaml
architecture: cluster

auth:
  existingSecret: rabbitmq-auth

queueDefaults:
  type: quorum

cluster:
  replicaCount: 3
  persistence:
    enabled: true
    size: 20Gi

metrics:
  enabled: true
  serviceMonitor:
    enabled: true
```

Management UI ingress example:

```yaml
management:
  ingress:
    enabled: true
    className: traefik
    hosts:
      - host: rabbitmq.example.com
        paths:
          - path: /
            pathType: Prefix
```

## Best practices

### Security

- use `auth.existingSecret` in production
- keep the Erlang cookie stable across restarts and upgrades
- enable TLS when clients connect outside a trusted internal network boundary
- restrict Management UI exposure

### Queues and topology

- in production, prefer quorum queues over mirrored classic queues
- use `cluster` only when the application truly needs a multi-node topology
- validate client reconnect behavior before promoting the topology to production

### Scheduling

- in `cluster`, spread pods across nodes or zones
- enable `pdb.enabled=true` for production clusters
- keep `replicaCount >= 3` for the operational cluster baseline

### Observability

- enable `metrics.enabled=true` in monitored environments
- use `metrics.serviceMonitor.enabled=true` with Prometheus Operator
- monitor memory, disk, connections, queues, consumers, and node-local alarms

## Main values

| Parameter | Description | Default |
|-----------|-------------|---------|
| `architecture` | `single-node` or `cluster` | `single-node` |
| `image.repository` | RabbitMQ image repository | `rabbitmq` |
| `image.tag` | RabbitMQ image tag | `4.2.4-management` |
| `auth.username` | Application username | `user` |
| `auth.password` | Application password | `""` |
| `auth.erlangCookie` | Erlang cookie | `""` |
| `auth.existingSecret` | Existing secret for credentials | `""` |
| `queueDefaults.type` | `quorum` or `classic` | `quorum` |
| `management.enabled` | Enable management plugin/UI | `true` |
| `management.ingress.enabled` | Enable management ingress | `false` |
| `management.ingress.className` | Ingress class for the Management UI | `traefik` |
| `tls.enabled` | Enable TLS listeners | `false` |
| `singleNode.persistence.enabled` | Enable PVC for single node | `true` |
| `cluster.replicaCount` | Number of cluster nodes | `3` |
| `cluster.partitionHandling` | Cluster partition handling | `pause_minority` |
| `metrics.enabled` | Enable RabbitMQ Prometheus plugin | `false` |
| `metrics.serviceMonitor.enabled` | Enable ServiceMonitor | `false` |
| `pdb.enabled` | Enable PodDisruptionBudget | `false` |

## CI scenarios

The `ci/` scenarios validate the main chart behaviors:

- `single-node.yaml`
- `cluster.yaml`
- `secure.yaml`
- `existing-secret.yaml`
- `metrics.yaml`

## Examples

See `examples/`:

- `single-node.yaml`
- `cluster-ha.yaml`
- `management-tls.yaml`

## Important notes

- `cluster` is not magical HA abstraction; queues, consumers, and reconnect behavior remain application and operations concerns
- quorum queues are the recommended production direction in this chart
- this chart does not attempt to orchestrate federation, shovel, or advanced policy management in v1
- `management.ingress.className` can be set to `traefik`, `nginx`, or any ingress class available in the target cluster
