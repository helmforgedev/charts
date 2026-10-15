# Storage and clustering

## Backend matrix

| Singleton | Single-node choices | Shared production choices | Chart location |
| --- | --- | --- | --- |
| DataStore | RocksDB, SQLite | PostgreSQL, MySQL/MariaDB, FoundationDB | `config.json` |
| BlobStore | filesystem, DataStore | S3-compatible, Azure, shared database | apply plan |
| SearchStore | DataStore | Meilisearch, Elasticsearch, shared database | apply plan |
| InMemoryStore | DataStore | Redis/Valkey standalone, cluster, sentinel | apply plan |
| Coordinator | disabled | NATS, Redis, Redis Cluster/Sentinel, Kafka/Redpanda | apply plan |

The chart validates only facts visible during rendering. It cannot prove that
an endpoint is replicated, durable, reachable, or correctly licensed.

## S3-compatible storage

The Stalwart v0.16 S3 BlobStore supports a custom endpoint and custom region,
bucket, key prefix, retries, verification, and credentials from environment or
files. It does not expose a `pathStyle`/`forcePathStyle` property in the current
object schema. Do not add an unsupported field to an apply plan.

## Coordinator

NATS is a useful middle ground between Redis and Kafka. Every coordinator uses
the fixed topic `stwt.agora`; it is not configurable and must not be shared
with an unrelated Stalwart cluster. Zenoh requires a custom server build and is
not supported by the default chart image.

## Roles and releases

One StatefulSet applies one `STALWART_ROLE` and `STALWART_PUSH_SHARD` to all of
its replicas. Install multiple releases when frontend, maintenance, and push
shards need distinct roles or scaling policies.

## Persistence

The default PVC is per pod and is appropriate for a local single-node store.
It is not shared storage. HA therefore requires `persistence.enabled=false`.
Back up external databases and object stores with their native consistent
backup and point-in-time recovery facilities.
