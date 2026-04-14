# Combined Mode

Use `architecture=cluster` with `cluster.brokers.replicaCount=0` for production deployments that need high availability with a simplified topology where each KRaft controller also acts as a broker.

## What this mode does

- deploys only the controller StatefulSet (no separate broker StatefulSet)
- each controller pod runs with `process.roles=broker,controller`
- controller pods expose both the controller port (9093) and client port (9092)
- the client service routes to controller pods instead of broker pods
- internal replication factor is calculated from `controllers.replicaCount` instead of `brokers.replicaCount`
- uses stable per-pod DNS for controller quorum bootstrap and client advertised listeners

## When to use

Combined mode is ideal for:

- **3-node HA production** where the workload doesn't justify 6 total pods (3 controllers + 3 brokers)
- **Cost-optimized production** with moderate throughput requirements
- **Simplified operational model** while maintaining proper quorum and replication

## Trade-offs

**Advantages:**
- Fewer pods to manage (3 instead of 6)
- Lower resource consumption
- Simpler topology

**Disadvantages:**
- Controllers handle both metadata coordination and client traffic
- Cannot scale brokers independently from controllers
- Controller nodes must be sized for both controller and broker workload

## Recommended baseline

- `cluster.controllers.replicaCount=3`
- `cluster.brokers.replicaCount=0` (this triggers combined mode)
- `cluster.minInSyncReplicas=2`
- persistent storage on controllers (sized for broker data, not just metadata)
- `pdb.enabled=true`

## Configuration example

```yaml
architecture: cluster

cluster:
  minInSyncReplicas: 2
  controllers:
    replicaCount: 3
    persistence:
      size: 50Gi  # Size for broker data, not just controller metadata
  brokers:
    replicaCount: 0  # Combined mode

pdb:
  enabled: true
```

## How it works

When `brokers.replicaCount=0`:

1. **StatefulSet rendering**: Only `kafka-controller` StatefulSet is created (no `kafka-broker` StatefulSet)
2. **Process roles**: Start script generates `process.roles=broker,controller` in server.properties
3. **Listeners**: Controllers expose both `CLIENT://0.0.0.0:9092` and `CONTROLLER://0.0.0.0:9093`
4. **Service selector**: The `kafka` client service selector points to `component: controller` pods
5. **Headless service**: Controller headless service exposes both ports (9092 for inter-broker, 9093 for quorum)
6. **Replication factor**: Internal topics use `min(3, controllers.replicaCount)` instead of brokers

## Validation before production

1. Confirm all controller pods reach `Ready` state
2. Verify `process.roles=broker,controller` in pod logs
3. Create a topic with replication factor 2 or 3
4. Produce and consume through the `kafka:9092` bootstrap service
5. Validate pod rescheduling with persistent volumes
6. Test controller election after pod restart

## Scaling considerations

- You **cannot** scale brokers independently in combined mode
- To scale capacity, increase `controllers.replicaCount` (must maintain odd number for quorum)
- Changing from combined mode to dedicated brokers requires migration (not seamless)

## Production checklist

- [ ] Set appropriate resource requests/limits for both controller and broker workload
- [ ] Size persistence for broker data, not just controller metadata
- [ ] Enable PodDisruptionBudget to protect quorum during maintenance
- [ ] Configure anti-affinity to spread controllers across nodes/zones
- [ ] Document that this topology cannot scale brokers independently
- [ ] Monitor both controller metrics and broker metrics on the same pods

## Non-goals of v1

- ZooKeeper mode
- External listeners and load balancer matrices
- TLS and SASL/ACL automation
- Kafka Connect, MirrorMaker, Schema Registry, or UI bundles

<!-- @AI-METADATA
type: chart-docs
title: Kafka - Combined Mode
description: Production-oriented Kafka KRaft combined mode where controllers act as brokers

keywords: kafka, kraft, combined mode, controllers, brokers, process.roles

purpose: Explain the combined mode topology where brokers.replicaCount=0 triggers controller pods to act as both controllers and brokers
scope: Chart Architecture

relations:
  - charts/kafka/README.md
  - charts/kafka/docs/cluster.md
  - charts/kafka/docs/single-broker.md
path: charts/kafka/docs/combined-mode.md
version: 1.0
date: 2026-04-13
-->
