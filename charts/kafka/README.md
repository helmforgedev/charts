# Kafka

Apache Kafka for Kubernetes using the official [`apache/kafka`](https://hub.docker.com/r/apache/kafka) image and a KRaft-only design. This chart intentionally supports two clear topologies:

- `single-broker` for development and simple internal environments
- `cluster` for production-oriented deployments with dedicated controllers and brokers

## Install

### HTTPS repository

```bash
helm repo add helmforge https://repo.helmforge.dev
helm repo update
helm install kafka helmforge/kafka -f values.yaml
```

### OCI registry

```bash
helm install kafka oci://ghcr.io/helmforgedev/helm/kafka -f values.yaml
```

## Supported architectures

| Architecture | When to use | Document |
|-------------|-------------|----------|
| `single-broker` | development, CI, demos, and simple internal workloads without node-level broker redundancy | [docs/single-broker.md](docs/single-broker.md) |
| `cluster` | production-oriented Kafka with dedicated KRaft controllers and brokers | [docs/cluster.md](docs/cluster.md) |
| `cluster` (combined mode) | 3-node HA production deployments where each controller also acts as a broker (`brokers.replicaCount: 0`) | [docs/combined-mode.md](docs/combined-mode.md) |

## What this chart covers

- KRaft only
- official Kafka `4.2.0` runtime image
- persistent storage for single-broker, controllers, and brokers
- stable in-cluster advertised listeners for brokers
- explicit KRaft cluster ID and controller directory ID secret handling
- optional Prometheus metrics through the JMX exporter javaagent
- optional `ServiceMonitor`
- optional `PodDisruptionBudget`

## What this chart does not try to automate in v1

- ZooKeeper mode
- external listeners or cloud load balancer matrices
- TLS, SASL, ACLs, and credential lifecycle
- ecosystem components such as Kafka Connect, MirrorMaker, Schema Registry, or UIs

## Official references

- Kafka downloads: https://downloads.apache.org/kafka/
- Kafka documentation: https://kafka.apache.org/documentation/
- Kafka Docker image: https://hub.docker.com/r/apache/kafka

## Quick start

Single broker:

```yaml
architecture: single-broker

singleBroker:
  persistence:
    size: 8Gi
```

Cluster (dedicated controllers and brokers):

```yaml
architecture: cluster

cluster:
  minInSyncReplicas: 2
  controllers:
    replicaCount: 3
    persistence:
      size: 8Gi
  brokers:
    replicaCount: 3
    persistence:
      size: 50Gi

pdb:
  enabled: true
```

Cluster (combined mode - controllers act as brokers):

```yaml
architecture: cluster

cluster:
  minInSyncReplicas: 2
  controllers:
    replicaCount: 3
    persistence:
      size: 50Gi
  brokers:
    replicaCount: 0  # Combined mode: process.roles=broker,controller

pdb:
  enabled: true
```

Metrics:

```yaml
metrics:
  enabled: true
  serviceMonitor:
    enabled: true
```

## Production direction

- use `cluster` in production
- keep dedicated controllers and brokers
- validate topic creation, producer, and consumer flows before promotion
- keep persistence enabled for both controllers and brokers
- treat external access, TLS, and auth as deliberate follow-up work rather than hidden defaults

## Main values

| Parameter | Description | Default |
|-----------|-------------|---------|
| `architecture` | `single-broker` or `cluster` | `single-broker` |
| `image.repository` | Kafka image repository | `apache/kafka` |
| `image.tag` | Kafka image tag | `4.2.0` |
| `kraft.existingSecret` | Existing secret for cluster ID and controller directory IDs | `""` |
| `listeners.client.port` | Kafka client port | `9092` |
| `listeners.controller.port` | KRaft controller port | `9093` |
| `listeners.interBroker.port` | Inter-broker port | `9094` |
| `config.numPartitions` | Default partitions for new topics | `3` |
| `config.autoCreateTopicsEnabled` | Enable automatic topic creation | `false` |
| `singleBroker.persistence.enabled` | Enable PVC in single-broker mode | `true` |
| `cluster.controllers.replicaCount` | Controller replicas in cluster mode | `3` |
| `cluster.brokers.replicaCount` | Broker replicas in cluster mode. Set to `0` for combined mode (controllers act as brokers) | `3` |
| `cluster.minInSyncReplicas` | Minimum ISR in cluster mode | `2` |
| `metrics.enabled` | Enable JMX exporter javaagent metrics | `false` |
| `metrics.serviceMonitor.enabled` | Create ServiceMonitor resources | `false` |
| `pdb.enabled` | Create PodDisruptionBudgets in cluster mode | `false` |

## CI scenarios

The `ci/` directory covers the main supported paths:

- `single-broker.yaml`
- `cluster.yaml`
- `combined-mode.yaml`
- `metrics.yaml`
- `cluster-tuned.yaml`

## Examples

See `examples/`:

- [single-broker.yaml](examples/single-broker.yaml)
- [cluster-production.yaml](examples/cluster-production.yaml)
- [combined-mode/](examples/combined-mode/)

## Architecture guides

- [Single Broker](docs/single-broker.md)
- [Cluster](docs/cluster.md)
- [Combined Mode](docs/combined-mode.md)

## Important notes

- the bootstrap service is internal-only in v1
- broker advertised listeners use stable StatefulSet pod DNS names
- for production, do not treat this chart as a shortcut around Kafka capacity planning, topic design, and client retry behavior

<!-- @AI-METADATA
type: chart-readme
title: Kafka Helm Chart
description: Apache Kafka chart with KRaft single-broker and production-oriented cluster modes

keywords: kafka, kraft, streaming, messaging, cluster

purpose: Usage guide for the Kafka Helm chart with supported KRaft topologies
scope: Chart

relations:
  - charts/kafka/docs/single-broker.md
  - charts/kafka/docs/cluster.md
path: charts/kafka/README.md
version: 1.0
date: 2026-03-31
-->
