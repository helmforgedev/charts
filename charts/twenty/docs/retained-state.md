# Coordinated recovery and upgrades

Retain the native `ENCRYPTION_KEY` and `SERVER_ID`, PostgreSQL database, application PVC and persistent Redis queue as
one recovery set. With S3 enabled, preserve the corresponding bucket recovery point as well. The PVC's hidden ownership
marker contains IDs and a key fingerprint; it does not replace a backup of the Secret itself.

The application uses one Recreate Pod. Initialization admits the retained key identity before migrations, runs native
upgrade/cache/cron commands sequentially and verifies administrator membership and closed public invite links before
reopening the public listener. Replacing the bootstrap password Secret does not rotate native credentials or enrollment
identity.

Quiesce both native server and worker before collecting database and file snapshots. Redis contains pending and
scheduled work, so include a consistent Redis persistence snapshot after clients are quiesced and Redis shuts down
cleanly. Copy dotfiles, preserve volume ownership and restore only into empty destinations. Reopen the application after
every component and key is present.

The implemented restore acceptance creates a delayed native SDK-generation job, quiesces clients, dumps PostgreSQL and
copies application and Redis persistence. It restores into a fresh database and two new PVCs, then requires that pending
job to complete through the native worker and write its SDK archive again. Original session, company, attachment bytes
and identity must also survive.
This acceptance passed with a fresh database and two fresh PVCs. The restored
pending job completed and rewrote its native SDK ZIP after recovery; its restored
queue entry alone was not considered proof of worker functionality.

A database-only restore does not prove files or pending jobs were recovered. Queue reinitialization is not a substitute
for recovering accepted work. The local fixture does not prove cross-region S3 recovery or simultaneous active instances
against the same data.

Before upgrading, preserve a recovery set and validate native migrations against a restored copy. Legacy APP_SECRET
installations and key rotation require the upstream migration procedure and deliberate ownership-marker reconciliation;
the chart does not silently adopt or rewrite a legacy database. Never change the encryption Secret merely to resolve a
startup admission failure.
