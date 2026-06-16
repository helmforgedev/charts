# Apache Druid Architecture Guide

## Overview

Apache Druid splits query serving, ingestion, coordination, and segment storage
across multiple processes. This chart keeps those processes separate so each
role can be scaled and tuned independently.

## Component Responsibilities

The Coordinator manages segment assignment, balancing, and retention. It is a
control-plane process and does not serve user queries directly.

The Overlord manages ingestion supervisors and tasks. MiddleManager workers
execute those tasks and write task logs or generated segments to the configured
deep storage backend.

The Broker accepts queries from clients, discovers where segments are served,
and fans queries out to Historical and real-time ingestion workers.

The Router exposes the web console and can route API calls to Brokers,
Coordinators, and Overlords. The chart routes Ingress and Gateway API traffic
to the router Service.

Historical nodes download published segments from deep storage into local
segment cache and serve those immutable segments to Brokers.

ZooKeeper provides Druid service discovery and coordination. PostgreSQL stores
Druid metadata such as segment records, datasources, supervisors, and task
state.

## Kubernetes Mapping

```text
Client or Gateway
  -> Service: druid-router
     -> Deployment: router
        -> Broker, Coordinator, and Overlord APIs

Broker
  -> Historical nodes for segment query execution
  -> ZooKeeper for service discovery

MiddleManager
  -> Metadata database for task state
  -> Deep storage for generated segments and task logs

Historical
  -> Deep storage for segment download
  -> Local PVC for segment cache
```

The chart renders StatefulSets for Coordinator, Overlord, Historical, and
MiddleManager. Historical and MiddleManager use PVC templates by default.
Broker and Router are Deployments because they are query-facing stateless
processes.

## Metadata Storage Choices

Use `metadata.mode=subchart` when you want the chart to deploy its own
PostgreSQL metadata store. This is convenient for development, evaluation, and
single-release environments.

Use `metadata.mode=external` when metadata is owned by a managed database
service or a separate database platform team. External metadata mode supports
PostgreSQL and MySQL.

When using external metadata in production, set
`metadata.external.existingSecret` instead of `metadata.external.password`.
That keeps credentials out of Helm values and lets External Secrets Operator or
another secret workflow own rotation.

## ZooKeeper Choices

Use bundled ZooKeeper for a self-contained install. The default single replica
is suitable for development and small environments.

Use external ZooKeeper when the platform already has a managed ensemble or when
Druid availability requirements are tied to a shared coordination layer.

External ZooKeeper is configured with:

```yaml
zookeeper:
  enabled: false

zookeeperConfig:
  mode: external
  external:
    hosts: "zookeeper-0.zookeeper:2181,zookeeper-1.zookeeper:2181,zookeeper-2.zookeeper:2181"
```

## Deep Storage Choices

Local deep storage is the default because it makes the chart easy to install in
CI and labs. It should be treated as non-HA.

S3 deep storage is the recommended production path:

```yaml
deepStorage:
  type: s3
  s3:
    bucket: druid-segments
    baseKey: production/segments
    region: us-east-1
    existingSecret: druid-s3
```

If using MinIO or another S3-compatible service, also set
`deepStorage.s3.endpointUrl` and keep path-style access enabled through the
chart-generated runtime properties.

## Scaling Guidance

Scale Broker and Router first for query concurrency. Scale Historical when
segment serving or cache pressure is the bottleneck. Scale MiddleManager when
ingestion task concurrency is the bottleneck.

Coordinator and Overlord are control-plane components. Increasing their replica
counts should be paired with Druid leader-election behavior and operational
testing for the target version.

## Failure Domains

For production, spread Historical, MiddleManager, Broker, and Router pods with
affinity rules and topology spread constraints supplied through `affinity` and
component labels. Keep PostgreSQL, ZooKeeper, and object storage availability
aligned with the Druid recovery objectives.
