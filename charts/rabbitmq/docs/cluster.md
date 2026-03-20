---
title: RabbitMQ - Cluster
description: Cluster deployment
keywords: [rabbitmq, cluster, quorum]
scope: chart-docs
audience: users
---

# RabbitMQ Cluster

## When to use

Use `cluster` when the solution truly needs multiple brokers.

Common cases:

- production with quorum queues
- environments that require broker redundancy
- workloads with correct client reconnect behavior

## What this architecture delivers

- multiple RabbitMQ nodes in a `StatefulSet`
- cluster formation through `rabbitmq_peer_discovery_k8s`
- optional Management UI
- quorum queues as the recommended direction
- optional TLS
- optional metrics

## What it requires

- at least 3 nodes for a production baseline
- persistence per node
- clients that handle reconnect correctly
- pod distribution across nodes or zones

## Best practices

- keep `cluster.replicaCount >= 3`
- use `queueDefaults.type=quorum`
- enable `pdb.enabled=true`
- spread pods with affinity or topology spread constraints
- monitor memory, disk, queues, alarms, and connections

## Base example

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
```
