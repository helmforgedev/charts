# Operations

Atuin runs embedded migrations before opening the HTTP listener. Review upstream release notes and take a database
backup before chart or image upgrades. Mixed-version rolling upgrades are not guaranteed by upstream; use a controlled
strategy when compatibility is uncertain.

SQLite backup requires a consistent database and WAL snapshot. Stop the Deployment, copy the PVC contents, and restart
it, or coordinate a CSI snapshot. PostgreSQL backup should use a compatible `pg_dump` client and custom format; restore
into a controlled empty database with `pg_restore`.

The health endpoint only proves the HTTP process responds. Monitor application errors, database health and a real client
sync workflow separately. Each PostgreSQL replica can open 100 connections.
