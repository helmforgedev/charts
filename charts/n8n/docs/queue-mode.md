# Queue Mode

n8n supports a **queue mode** that uses Redis as a message broker, enabling horizontal scaling with separate worker processes.

## How It Works

In queue mode, the main n8n instance acts as the web UI and workflow trigger handler. Workflow executions are pushed to a Redis queue and picked up by worker pods. This allows scaling execution capacity independently from the web interface.

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

### With External Redis

```yaml
queue:
  enabled: true
  workers: 3
  external:
    host: redis.example.com
    port: 6379
    password: "redis-password"
```

## Architecture

```
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
| `queue.resources` | `{}` | Resources for worker pods |

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
