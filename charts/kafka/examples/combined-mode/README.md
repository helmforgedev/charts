# Combined Mode Example

This example demonstrates Kafka in **combined mode**, where each KRaft controller also acts as a broker (`process.roles=broker,controller`).

## When to use

Combined mode is ideal for:

- **3-node HA production deployments** that need high availability without the overhead of 6 total pods (3 controllers + 3 brokers)
- **Cost-optimized production** where workload doesn't justify separate controller and broker StatefulSets
- **Simplified topology** while maintaining proper Kafka quorum (3 nodes for controller quorum)

## What happens

When `cluster.brokers.replicaCount: 0`:

- Only the controller StatefulSet is created (3 replicas)
- Each controller pod runs with `process.roles=broker,controller`
- The client service (`kafka:9092`) routes to controller pods
- Controller pods expose both ports: `9093` (controller) and `9092` (client)
- Internal replication factor uses `min(3, controllers.replicaCount)`

## Trade-offs

**Advantages:**
- Fewer pods (3 instead of 6)
- Lower resource usage
- Simpler to manage

**Disadvantages:**
- Controllers handle both metadata and client traffic
- Cannot scale brokers independently from controllers
- Controller workload includes broker responsibilities

## Install

```bash
helm install kafka helmforge/kafka -f values.yaml
```

## Verify

```bash
kubectl get pods -l app.kubernetes.io/name=kafka
kubectl logs kafka-controller-0 | grep "process.roles"
```

You should see:
```
process.roles=broker,controller
```

## Test

Create a topic and produce/consume:

```bash
kubectl exec -it kafka-controller-0 -- /opt/kafka/bin/kafka-topics.sh \
  --create --topic test-topic \
  --partitions 3 --replication-factor 2 \
  --bootstrap-server kafka:9092

kubectl exec -it kafka-controller-0 -- /opt/kafka/bin/kafka-console-producer.sh \
  --topic test-topic \
  --bootstrap-server kafka:9092

kubectl exec -it kafka-controller-0 -- /opt/kafka/bin/kafka-console-consumer.sh \
  --topic test-topic \
  --from-beginning \
  --bootstrap-server kafka:9092
```

## Production checklist

- [ ] Set appropriate resource requests/limits based on workload
- [ ] Enable PodDisruptionBudget (`pdb.enabled: true`)
- [ ] Configure persistence size based on retention policy
- [ ] Enable metrics and monitoring (`metrics.enabled: true`)
- [ ] Plan for node affinity/anti-affinity if needed
- [ ] Document that this topology cannot scale brokers independently
