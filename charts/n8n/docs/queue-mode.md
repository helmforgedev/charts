# Queue Mode

n8n supports a **queue mode** that uses Redis as a message broker and a shared
non-SQLite database, enabling horizontal scaling with separate worker processes.

## How It Works

In queue mode, the main n8n instance acts as the web UI and workflow trigger
handler. Workflow executions are pushed to a Redis queue and picked up by worker
pods. This allows scaling execution capacity independently from the web
interface.

Queue mode is intentionally rejected when the chart resolves to SQLite. SQLite
stores state on the main pod volume and cannot safely back multiple worker pods.
Use the PostgreSQL subchart, the MySQL subchart, or an external PostgreSQL/MySQL
database before enabling `queue.enabled`.

## Enable Queue Mode

### With Redis Subchart

```yaml
queue:
  enabled: true
  workers: 2
  concurrency: 10

redis:
  enabled: true
  auth:
    password: "redis-password"

postgresql:
  enabled: true
  auth:
    database: n8n
    username: n8n
    password: "db-password"
```

Workers mount the main `/home/node/.n8n` PVC by default. This preserves persisted
community nodes and files for existing queue-mode releases. If your cluster uses
multi-node `ReadWriteOnce` storage and workers must avoid the main PVC, disable
the shared worker volume explicitly:

```yaml
queue:
  persistence:
    shareMainVolume: false
```

Worker pods wait for the main n8n readiness endpoint before starting. This keeps
database migrations serialized on fresh PostgreSQL or MySQL subchart installs.

The chart sets `N8N_GRACEFUL_SHUTDOWN_TIMEOUT=60` and keeps the pod
`terminationGracePeriodSeconds` above that value so workers can stop cleanly
during queue-mode upgrades.

Queue mode uses external task runners by default. The chart renders a dedicated
`n8nio/runners` sidecar next to the main pod and each worker so every queue
worker has its own runner, matching upstream n8n external runner guidance.

### With External Redis

```yaml
queue:
  enabled: true
  workers: 3
  external:
    host: redis.example.com
    port: 6379
    password: "redis-password"

database:
  external:
    vendor: postgres
    host: postgres.example.com
    name: n8n
    username: n8n
    password: "db-password"
```

## Architecture

```text
┌──────────┐     ┌───────┐     ┌──────────┐
│  n8n UI  │────▶│ Redis │◀────│ Worker 1 │
│ (main)   │     │       │     └──────────┘
└──────────┘     │       │     ┌──────────┐
                 │       │◀────│ Worker 2 │
                 └───────┘     └──────────┘
```

- **Main pod**: Handles the editor UI, webhook triggers, and pushes executions to the queue
- **Worker pods**: Pull executions from Redis and run them
- **Redis**: Message broker between main and workers
- **Database**: Shared by main and all workers (PostgreSQL recommended for production)

## Worker Configuration

| Key | Default | Description |
|-----|---------|-------------|
| `queue.workers` | `1` | Number of worker replicas |
| `queue.concurrency` | `10` | Concurrent workflows per worker |
| `queue.persistence.shareMainVolume` | `true` | Mount the main data PVC into workers |
| `n8n.gracefulShutdownTimeout` | `60` | n8n graceful shutdown timeout in seconds |
| `queue.resources.requests.memory` | `512Mi` | Default worker memory request |

<!-- @AI-METADATA
type: chart-docs
title: Queue Mode
description: Guide for configuring n8n queue mode with Redis for horizontal scaling

keywords: queue, redis, workers, scaling, horizontal, bull

purpose: Help operators configure queue mode for production scaling
scope: Chart

relations:
  - charts/n8n/README.md
  - charts/n8n/docs/database.md
path: charts/n8n/docs/queue-mode.md
version: 1.0
date: 2026-03-23
-->
