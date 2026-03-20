# External Database Backup

## Why this guide exists

When Vaultwarden runs with:

- `database.mode=external`
- `database.mode=postgresql`
- or `database.mode=mysql`

backup can no longer be treated as a SQLite-only problem.

You must preserve two separate state planes:

1. database state
2. Vaultwarden `/data`

## Production recommendation

For production, the strongest operational model is:

- use a managed or independently operated PostgreSQL/MySQL service
- let that database platform own database backup and restore
- keep Vaultwarden filesystem backup separate and explicit

This produces cleaner responsibilities:

- the database platform handles PITR, retention, and database-consistent restore
- Vaultwarden backup handles `config.json`, `rsa_key*`, attachments, and sends

## What belongs to the database backup

Back up:

- Vaultwarden relational data stored in PostgreSQL or MySQL

Do not rely on `/data` backup to cover this once SQLite is no longer the active backend.

## What belongs to the `/data` backup

Back up:

- `config.json`
- `rsa_key*`
- `attachments/`
- `sends/`

These remain part of the restore boundary even when the main database is external.

## Recommended architecture

Use two backup workflows:

1. database-native backup workflow
2. Vaultwarden `/data` backup workflow

### Database-native workflow

Examples:

- managed PostgreSQL backup / PITR
- managed MySQL backup / PITR
- platform-native snapshot or dump workflow controlled outside the Vaultwarden chart

### Vaultwarden `/data` workflow

Use a separate release based on the [`generic`](../../generic/README.md) chart with a `CronJob` that archives `/data` to S3-compatible object storage.

This keeps:

- app release lifecycle
- database lifecycle
- backup lifecycle

separate and easier to reason about.

## Why this is better than one monolithic backup job

A single job that tries to back up both database and `/data` from the Vaultwarden release usually creates more coupling:

- database credentials leak into the app release boundary
- restore logic becomes less transparent
- failure domains become harder to understand

Separate workflows are easier to test and easier to restore from.

## Restore sequence

Recommended order:

1. stop Vaultwarden traffic
2. restore the database
3. restore `/data`
4. redeploy or restart Vaultwarden
5. validate runtime behavior

If you reverse this casually, the application may come up against mismatched filesystem and database state.

## What to validate after restore

- user login
- organization access
- attachment download
- send access
- admin page access
- email and invitation behavior
- generated links using the configured `domain`

## Subchart note

If you use local subcharts:

- `postgresql.enabled=true`
- or `mysql.enabled=true`

the same logic still applies.

The main difference is only where the database lifecycle is hosted. Backup remains a two-plane problem:

- database data
- Vaultwarden `/data`

## References

- Vaultwarden configuration template: https://raw.githubusercontent.com/dani-garcia/vaultwarden/main/.env.template
- Generic chart in this repository: [`charts/generic`](../../generic/README.md)
