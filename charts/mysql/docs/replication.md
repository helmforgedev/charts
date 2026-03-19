# Replication

## When to use it

Use `replication` when you need one writable MySQL source and separate asynchronous replicas for read traffic.

Typical use cases:

- applications with distinct write and read paths
- services that want horizontal scale for read-only traffic
- environments where failover remains an operational procedure outside the chart

## What it delivers

- one source StatefulSet
- one replica StatefulSet
- dedicated Services for client traffic, source traffic, and replicas
- bootstrap of application and replication users on first initialization
- optional `mysqld-exporter`
- optional `ServiceMonitor`
- a stable read-only replicas endpoint for horizontal read scaling

## What it does not deliver

- automatic failover
- automatic source promotion
- Group Replication or InnoDB Cluster behavior
- operator-style topology management

## Best practices

- keep `readReplicas.replicaCount >= 2` if read scale matters
- use `pdb.enabled=true` before routine maintenance in multi-node environments
- route write traffic only to the source Service
- route read traffic only to the replicas Service
- use the replicas Service for read-only workloads that benefit from horizontal scale
- do not expect the replicas Service to make lag-aware or query-aware routing decisions
- treat this mode as read scaling plus recovery help, not full HA
- if automated failover is a hard requirement, use an operator instead of extending this chart

## Read scaling notes

The replicas Service gives a single endpoint for read-only consumers across multiple replicas.

This is useful for:

- reporting stacks
- background readers
- analytics jobs
- applications with clear separation between write and read paths

Keep in mind:

- balancing happens at the Kubernetes Service level
- MySQL lag is still an application concern
- replica reads are not a substitute for strong consistency requirements
