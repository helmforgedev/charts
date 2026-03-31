---
title: Kafka - Cluster
description: Production-oriented Kafka KRaft cluster topology with dedicated controllers and brokers
keywords: [kafka, kraft, cluster, controllers, brokers]
scope: chart-docs
audience: users
---

# Cluster

Use `architecture=cluster` for production-oriented Kafka deployments that need dedicated KRaft controllers, replicated internal topics, and broker redundancy.

## What this mode does

- deploys a dedicated controller quorum through its own StatefulSet
- deploys dedicated brokers through a separate StatefulSet
- uses stable per-pod DNS for controller quorum bootstrap and broker advertised listeners
- uses replicated internal-topic defaults based on broker replica count

## Recommended baseline

- `cluster.controllers.replicaCount=3`
- `cluster.brokers.replicaCount=3`
- `cluster.minInSyncReplicas=2`
- persistent storage on both controllers and brokers
- `pdb.enabled=true`

## Non-goals of v1

- ZooKeeper mode
- external listeners and load balancer matrices
- TLS and SASL/ACL automation
- Kafka Connect, MirrorMaker, Schema Registry, or UI bundles

## Validation before production

1. confirm the controllers and brokers all reach `Ready`
2. create a topic and confirm replication succeeds
3. produce and consume through the bootstrap service
4. validate pod rescheduling with persistent volumes in the target cluster

<!-- @AI-METADATA
type: chart-docs
title: Kafka - Cluster
description: Production-oriented Kafka KRaft cluster topology with dedicated controllers and brokers

keywords: kafka, kraft, cluster, controllers, brokers

purpose: Explain the supported cluster topology and its production baseline
scope: Chart Architecture

relations:
  - charts/kafka/README.md
  - charts/kafka/docs/single-broker.md
path: charts/kafka/docs/cluster.md
version: 1.0
date: 2026-03-31
-->
