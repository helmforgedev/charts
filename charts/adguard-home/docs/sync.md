# AdGuardHome Sync

This chart optionally deploys [adguardhome-sync](https://github.com/bakito/adguardhome-sync) to synchronize configuration from an origin AdGuard Home instance to one or more replicas.

## How It Works

The sync sidecar runs as a separate Deployment alongside your main AdGuard Home instance. It periodically reads the configuration from the **origin** instance via its API and pushes it to each **replica**.

This is useful for:

- **High availability** - multiple AdGuard Home instances with synchronized filter lists and settings
- **Multi-site deployments** - keeping DNS configurations consistent across locations

## Enabling Sync

```yaml
sync:
  enabled: true
  origin:
    url: "http://adguard-primary:80"
    username: admin
    password: changeme
  replicas:
    - url: "http://adguard-replica-1:80"
      username: admin
      password: changeme
    - url: "http://adguard-replica-2:80"
      username: admin
      password: changeme
```

## Schedule

By default, sync runs every 10 minutes and also on startup:

```yaml
sync:
  cron: "*/10 * * * *"
  runOnStart: true
```

Set `cron: ""` for continuous daemon mode (watches for changes).

## Feature Selection

Control which settings are synchronized:

```yaml
sync:
  features:
    dns:
      serverConfig: true
      accessLists: true
      rewrites: true
    dhcp:
      serverConfig: true
      staticLeases: true
    general:
      settings: true
      protection: true
      clients: true
      filters: true
      services: true
```

## Using an Existing Secret

For production environments, store credentials in a pre-created Secret:

```yaml
sync:
  enabled: true
  existingSecret: my-sync-credentials
```

The Secret must contain these keys:

| Key | Description |
|-----|-------------|
| `ORIGIN_URL` | Origin AdGuard Home URL |
| `ORIGIN_USERNAME` | Origin admin username |
| `ORIGIN_PASSWORD` | Origin admin password |
| `REPLICA1_URL` | First replica URL |
| `REPLICA1_USERNAME` | First replica username |
| `REPLICA1_PASSWORD` | First replica password |

Add `REPLICA2_*`, `REPLICA3_*`, etc. for additional replicas.

## Resources Generated

| Resource | Condition |
|----------|-----------|
| Deployment (`*-sync`) | `sync.enabled` |
| Secret (`*-sync`) | `sync.enabled` and no `sync.existingSecret` |

<!-- @AI-METADATA
type: chart-docs
title: AdGuardHome Sync
description: Multi-instance configuration synchronization using adguardhome-sync
keywords: adguard, sync, multi-instance, replication, adguardhome-sync
purpose: Guide for enabling and configuring adguardhome-sync in the AdGuard Home chart
scope: Chart
relations:
  - charts/adguard-home/README.md
  - charts/adguard-home/values.yaml
path: charts/adguard-home/docs/sync.md
version: 1.0
date: 2026-03-23
-->
