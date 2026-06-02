# Metabase Database and Backup Guide

## Bundled PostgreSQL

The default install uses the HelmForge PostgreSQL subchart as the Metabase metadata store:

```yaml
postgresql:
  enabled: true
  auth:
    database: metabase
    username: metabase
```

Use this mode for small and medium self-hosted installations where the application and metadata database should be managed
by one Helm release.

## External PostgreSQL

Use an external PostgreSQL service when your platform already manages HA, patching, backups, and restore testing:

```yaml
postgresql:
  enabled: false

database:
  external:
    host: postgres.example.com
    port: 5432
    name: metabase
    username: metabase
    existingSecret: metabase-db
    existingSecretPasswordKey: password
```

The external database user must be able to create and migrate the Metabase application schema.

## Encryption Key

`MB_ENCRYPTION_SECRET_KEY` protects saved database credentials. Keep it stable after first install:

```yaml
metabase:
  existingSecret: metabase-secrets
  existingSecretKey: encryption-secret-key
```

Back up this key with the database. Changing it after Metabase has stored credentials can make saved connection secrets
unreadable.

## Backups

The chart can create a PostgreSQL dump CronJob and upload the archive to S3-compatible storage:

```yaml
backup:
  enabled: true
  schedule: "0 3 * * *"
  s3:
    endpoint: https://s3.example.com
    bucket: metabase-backups
    existingSecret: metabase-s3
```

Test restore procedures before relying on backups for production recovery.

<!-- @AI-METADATA
type: chart-doc
title: Metabase Database and Backup Guide
description: Database, encryption key, and backup guide for the Metabase Helm chart

keywords: metabase, postgresql, backup, s3, encryption, restore, helm, kubernetes

purpose: Explain database selection, encryption key handling, and backup behavior
scope: Chart Documentation

relations:
  - charts/metabase/README.md
  - charts/metabase/DESIGN.md
  - charts/metabase/docs/production.md
path: charts/metabase/docs/database.md
version: 1.0
date: 2026-06-02
-->
