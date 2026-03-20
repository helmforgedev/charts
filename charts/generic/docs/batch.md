---
title: Generic Chart - Batch Workloads
description: Jobs and CronJobs for the generic chart
keywords: [generic, job, cronjob, batch]
scope: chart-docs
audience: users
---

# Generic Chart for Jobs and CronJobs

## When to use

Use batch mode when the release is centered on one-off jobs or scheduled tasks, not on a continuously running workload.

Common cases:

- database migrations
- cleanup routines
- recurring exports
- nightly or hourly maintenance tasks

## What this mode delivers

- `jobs` for one-time execution
- `cronjobs` for scheduled execution
- shared container conventions for image, env, mounts, and resources
- the ability to ship a batch-only release with `workload.enabled: false`

## What it does not deliver

- a long-running service endpoint
- inherited global probes
- autoscaling semantics for batch runs

## Recommended practices

- set `workload.enabled: false` when the release exists only for jobs or cronjobs
- keep job commands explicit and deterministic
- set timeouts and retry behavior intentionally
- avoid bundling unrelated maintenance tasks into one release unless lifecycle is shared

## Most relevant values

| Parameter | Description |
|-----------|-------------|
| `workload.enabled` | Disable long-running workload when batch-only |
| `jobs` | One-time job definitions |
| `cronjobs` | Scheduled job definitions |
| `env` | Shared environment variables |
| `persistence.*` | Shared volumes and mounts when needed |
| `serviceAccount.*` | Batch identity and permissions |

## Example

```yaml
workload:
  enabled: false

image:
  repository: ghcr.io/example/maintenance
  tag: "1.4.0"

jobs:
  - name: db-migrate
    command: ["./bin/migrate"]
    backoffLimit: 2

cronjobs:
  - name: cleanup
    schedule: "0 2 * * *"
    command: ["./bin/cleanup"]
    concurrencyPolicy: Forbid
```

<!-- @AI-METADATA
type: chart-docs
title: Generic Chart - Batch Workloads
description: Jobs and CronJobs for the generic chart

keywords: generic, job, cronjob, batch

purpose: Batch workloads (Job and CronJob) configuration guide for the generic chart
scope: Chart Architecture

relations:
  - charts/generic/README.md
path: charts/generic/docs/batch.md
version: 1.0
date: 2026-03-20
-->
