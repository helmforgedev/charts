# Appwrite Architecture

## Overview

Appwrite is deployed as a set of Kubernetes Deployments sharing a common container image (`appwrite/appwrite`) differentiated by entrypoint commands. The console uses a separate image (`appwrite/console`).

## Components

### API Server

The main HTTP server handling all REST and GraphQL API requests. Runs `php -e app/http.php` and listens on port 80. Supports horizontal scaling via `api.replicaCount`.

### Console

The Appwrite web console (dashboard) served as a static SPA by the `appwrite/console` image. Always runs as a single replica.

### Realtime

WebSocket server for real-time event subscriptions. Runs `php -e app/realtime.php` on port 80. Supports horizontal scaling via `realtime.replicaCount`.

### Workers

Background queue processors consuming jobs from Redis. Each worker type processes a specific job queue:

| Worker | Queue | Purpose |
|--------|-------|---------|
| audits | Audit log writes | |
| webhooks | Webhook delivery | |
| deletes | Resource cleanup | |
| databases | Database operations | |
| builds | Function code builds | |
| certificates | SSL certificate management | |
| functions | Function execution dispatch | |
| mails | Email delivery | |
| messaging | Push/SMS notifications | |
| migrations | Data migration jobs | |
| stats-resources | Resource usage stats | |
| stats-usage | API usage stats | |

All workers run `php -e app/worker.php <entrypoint>`.

### Schedulers

Cron-like processes that enqueue scheduled jobs:

- **schedule-functions** — Triggers scheduled function executions
- **schedule-messages** — Triggers scheduled message delivery
- **schedule-executions** — Triggers scheduled task executions (disabled by default)

### Maintenance

Periodic housekeeping task that cleans expired sessions, logs, and other temporary data.

## Data Flow

```
                    ┌─────────┐
        Ingress ──> │ Console │  (/ paths)
           │        └─────────┘
           │        ┌─────────┐
           ├──────> │   API   │  (/v1/* paths)
           │        └────┬────┘
           │             │ enqueues jobs
           │        ┌────▼────┐
           │        │  Redis  │ <── Schedulers
           │        └────┬────┘
           │             │ dequeues
           │        ┌────▼────┐
           │        │ Workers │ (12 types)
           │        └────┬────┘
           │             │
           │        ┌────▼────┐
           ├──────> │Realtime │  (/v1/realtime)
           │        └─────────┘
           │
           │        ┌─────────┐
           └──────> │ MariaDB │
                    └─────────┘
```

## Shared Volumes

Several Appwrite services need access to the same filesystem paths:

| Volume | Mount Path | Used By |
|--------|-----------|---------|
| uploads | `/storage/uploads` | API, workers |
| cache | `/storage/cache` | API, workers |
| certificates | `/storage/certificates` | API, certificate worker |
| functions | `/storage/functions` | API, function/build workers |
| builds | `/storage/builds` | API, build worker |
| sites | `/storage/sites` | API, workers |

When running multiple API or worker replicas, the PVCs must support `ReadWriteMany` access mode. Update `persistence.accessModes` accordingly.

## Not Included (Alpha)

The following Appwrite services are not deployed by this chart:

- **openruntimes-executor** — Requires Docker socket access for function execution
- **appwrite-assistant** — AI assistant service (optional)
- **browser** — Screenshot/preview service (optional)

<!-- @AI-METADATA
type: chart-docs
path: charts/appwrite/docs/architecture.md
date: 2026-03-31
relations:
  - charts/appwrite/README.md
  - charts/appwrite/values.yaml
-->
