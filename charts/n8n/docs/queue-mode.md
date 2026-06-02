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

Workers use `emptyDir` for `/home/node/.n8n` by default. This avoids scheduling
contention when the main pod uses a `ReadWriteOnce` PVC. If your deployment
requires workers to share the main data PVC, enable it explicitly:

```yaml
queue:
  persistence:
    shareMainVolume: true
```

Worker pods wait for the main n8n readiness endpoint before starting. This keeps
database migrations serialized on fresh PostgreSQL or MySQL subchart installs.

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
| `queue.persistence.shareMainVolume` | `false` | Mount the main data PVC into workers |
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
