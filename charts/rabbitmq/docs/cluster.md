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
- keep `auth.existingSecret` stable across upgrades
- prefer External Secrets Operator for production credentials
- use Gateway API or Ingress only for the Management UI, not AMQP traffic

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

## Management UI via Gateway API

```yaml
management:
  enabled: true
  gateway:
    enabled: true
    parentRefs:
      - name: public
        namespace: gateway-system
    hostnames:
      - rabbitmq.example.com
```

AMQP clients should continue to connect through the RabbitMQ Service ports.

<!-- @AI-METADATA
type: chart-docs
title: RabbitMQ - Cluster
description: Cluster deployment

keywords: rabbitmq, cluster, quorum

purpose: RabbitMQ cluster deployment guide with quorum queues
scope: Chart Architecture

relations:
  - charts/rabbitmq/README.md
path: charts/rabbitmq/docs/cluster.md
version: 1.1
date: 2026-06-02
-->
