# Backup and Restore

## What the built-in backup focuses on

The built-in backup feature is mode-aware:

- SQLite mode backs up `/data`
- database-backed modes back up the database dump

This is intentional.

The chart focuses on producing a reliable backup artifact for the authoritative state of the chosen mode instead of trying to bundle every possible secondary file into one generic process.

## Why backup is not trivial here

Vaultwarden mixes:

- persisted application files in `/data`
- runtime configuration that may drift through `/data/config.json`
- one of several possible database backends

That means backup and restore must be designed around both:

- filesystem state
- selected database mode

## Recommended architecture

The intended production architecture is now:

1. `vaultwarden` as the main application release
2. the built-in backup `CronJob` enabled inside this chart
3. an S3-compatible bucket as backup target
4. documentation and runbooks that explain restore separately from backup generation

## SQLite-specific limitation

Do not treat every Kubernetes storage class as equivalent.

For the SQLite backup CronJob to mount the same data claim safely, your platform must support the access pattern you are planning:

- `ReadWriteMany` storage is the cleanest option for a separate backup pod
- `ReadWriteOnce` may work only under stricter node-placement conditions and is not the safest default assumption for a detached backup job

If your platform uses a strict `ReadWriteOnce` PVC and cannot guarantee the mount pattern for a separate `CronJob`, the more reliable direction is:

- snapshot-capable storage with `VolumeSnapshot` orchestration
- or a future in-pod backup design that shares the already-mounted volume

For the current chart scope, the built-in SQLite backup assumes that the scheduled backup pod can safely mount the same claim and read `/data`.

## External database and local subchart backups

When Vaultwarden runs with PostgreSQL or MySQL, the built-in backup is centered on the database dump.

That matches the current product decision for this chart: the important operational backup artifact in DB-backed modes is the database itself.

### External database mode

Recommended production pattern:

- let the built-in backup CronJob generate the database dump artifact
- send the compressed dump to an S3-compatible bucket
- treat restore as a documented operational workflow, not as an automatic chart action

### Local PostgreSQL/MySQL subchart mode

Subcharts simplify installation, but they do not eliminate database backup needs.

If you enable:

- `postgresql.enabled=true`
- or `mysql.enabled=true`

the built-in backup still follows the same logic: create a database dump and upload it.

## Object storage recommendations

Use an S3-compatible bucket with:

- server-side encryption
- bucket versioning
- lifecycle policy for retention
- immutability or object lock when your platform supports it
- separate credentials for backup write access

That is the difference between "we upload a file somewhere" and a backup posture that survives operator error and accidental overwrites.

## Backup automation in this chart

The built-in backup feature is now the preferred automation path for Vaultwarden in this repository.

Review [Backup Automation](backup-automation.md) for the CronJob contract and configuration.

## Restore principles

Restore should be treated as a controlled maintenance event.

Restore is not just file copy plus restart. You must preserve consistency between:

- database mode
- `/data`
- the effective runtime configuration kept in `config.json`
- the release values that will be used after restart

Minimum restore sequence for SQLite:

1. stop Vaultwarden traffic
2. stop the running application pod
3. restore the complete `/data` set, not only `db.sqlite3`
4. verify `config.json`, `rsa_key*`, `attachments/`, and `sends/`
5. start the application again
6. validate login, attachments, sends, and admin access

For SQLite, do not mix a newly generated empty `db.sqlite3` with restored `attachments/`, `rsa_key*`, or `config.json`. Restore the whole boundary together.

Minimum restore sequence for external PostgreSQL/MySQL:

1. stop Vaultwarden traffic
2. restore the target database from the database backup workflow
3. restore `/data`
4. verify `config.json`, `rsa_key*`, `attachments/`, and `sends/`
5. start Vaultwarden again
6. validate login, organizations, attachments, sends, and admin access

When the restored database points to a different operational environment, verify:

- `domain`
- SMTP sender identity
- reverse proxy headers
- any SSO or admin-access assumptions

Minimum restore sequence for local PostgreSQL/MySQL subcharts:

1. stop Vaultwarden traffic
2. restore the subchart-managed database data
3. restore Vaultwarden `/data`
4. confirm the selected `database.mode` and subchart values still match the restored state
5. start the release again
6. validate login, organizations, attachments, sends, and admin access

For local subcharts, do not assume the app and database can be restored independently without checking release values. The Helm release still needs to describe the same database mode after recovery.

## PVC restore patterns

The chart supports two explicit restore-friendly patterns:

1. `data.persistence.existingClaim`
2. a dynamically created PVC with `data.persistence.selectorLabels`

Use these only when you intentionally want Vaultwarden to reattach to restored storage.

For concrete guidance, review [Data Restore Patterns](data-restore-patterns.md).

## Validation after restore

At minimum, validate:

- user login
- organization access
- attachment download
- send access
- admin page reachability
- expected domain and email behavior
- expected database mode behavior after restore

## References used for this guidance

- Vaultwarden configuration template: https://raw.githubusercontent.com/dani-garcia/vaultwarden/main/.env.template

<!-- @AI-METADATA
type: chart-docs
title: Vaultwarden - Backup
description: Backup and restore

keywords: vaultwarden, backup, restore

purpose: Backup and restore procedures for Vaultwarden
scope: Chart Architecture

relations:
  - charts/vaultwarden/README.md
  - charts/vaultwarden/docs/backup-automation.md
path: charts/vaultwarden/docs/backup-and-restore.md
version: 1.0
date: 2026-03-20
-->
