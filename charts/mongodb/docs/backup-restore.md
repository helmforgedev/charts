# Backup and Restore

## Built-in backup strategy

This chart includes an optional backup CronJob that runs `mongodump`, writes a compressed archive, and uploads it to S3-compatible storage.

The backup connects to the topology entrypoint that represents the full cluster view:

- `standalone`: the chart client Service
- `replicaset`: the chart client Service, which targets the replica set members
- `sharded`: the `mongos` Service, so the dump covers the sharded logical databases

## Scope

The built-in backup is a logical dump workflow. It is designed for scheduled full backups to object storage.

It does not replace:

- point-in-time recovery design
- filesystem snapshot tooling
- object retention governance
- restore testing and approval workflows

## Minimum production practices

- keep regular logical backups
- align bucket retention with recovery requirements
- test restores in a non-production environment
- document whether restores target standalone, replica set, or sharded topologies

## Restore workflow

Prefer restoring into a fresh release or a maintenance window where writes are fully stopped.

### 1. Download the archive

```bash
mc cp backup/my-mongodb-backups/mongodb/mongodb-mongodb-20260331T163124Z.archive.gz /tmp/
```

### 2. Restore with `mongorestore`

Standalone or replica set entrypoint:

```bash
mongorestore \
  --host <mongodb-host> \
  --port 27017 \
  --username <admin-user> \
  --password <admin-password> \
  --authenticationDatabase admin \
  --archive=/tmp/mongodb-mongodb-20260331T163124Z.archive.gz \
  --gzip
```

Sharded topology:

- restore through the `mongos` endpoint, not directly to individual shard members
- keep the topology shape aligned with the original backup expectation before running restore

### 3. Validate before reopening traffic

- restore into a controlled maintenance workflow
- validate users, roles, and expected databases after restore
- validate expected collections and indexes for critical application paths
- for sharded environments, verify mongos routing and shard registration before resuming application traffic
- re-enable scheduled backups only after the restored environment is validated

<!-- @AI-METADATA
type: chart-docs
title: MongoDB - Backup
description: Backup and restore

keywords: mongodb, backup, restore, mongodump

purpose: MongoDB backup and restore procedures using mongodump
scope: Chart Architecture

relations:
  - charts/mongodb/README.md
path: charts/mongodb/docs/backup-restore.md
version: 1.0
date: 2026-03-31
-->
