# Moodle backup and recovery

## Consistency boundary

A recoverable Moodle site consists of the database, moodledata, exact application
code/plugins and deployment configuration. A course backup is not a full-site
backup. A PVC snapshot without a database recovery point is also insufficient.

This chart does not enable an automatic site-backup CronJob. The selected database
subchart may perform database backups, but those do not include Moodledata.
Use your backup platform or the coordinated maintenance procedure below for
complete recovery points. The site catalog therefore does not advertise this
chart as having built-in automated backups.

Backups contain student records, submissions and credentials/configuration.
Apply your organization's encryption, access, retention and restore-testing
requirements to every artifact. Keep backup copies outside the source cluster.

## Prepare a recovery point

Record the exact deployed chart version and values:

```bash
mkdir -p moodle-recovery
chmod 700 moodle-recovery
helm get values moodle -n learning -o yaml > moodle-recovery/values.yaml
helm get metadata moodle -n learning -o yaml > moodle-recovery/release.yaml
```

These commands can capture sensitive inline values. Prefer existing Secret
references and keep the recovery directory private. Preserve the required
secret versions in your secret-management system.

Record `image.repository`, `image.tag`, `image.digest`, `source.url`,
`source.sha256`, custom plugins and configuration alongside the recovery point.
An upstream download being available today is not an archival guarantee; retain
your own verified code artifact or immutable image.

## Quiesce writes

Stop scheduling and drain tasks before interrupting pods:

```bash
kubectl -n learning exec deployment/moodle -c moodle -- \
  php /var/www/html/admin/cli/cron.php --disable-wait=600
kubectl -n learning exec deployment/moodle -c moodle -- \
  php /var/www/html/admin/cli/maintenance.php --enable
```

Verify no active ad-hoc or scheduled tasks remain. Drain user traffic at the
gateway and wait for in-flight PHP requests, integrations and uploads to finish.
For HA, this applies to all web replicas. Maintenance mode alone is not proof
that a request which started earlier has stopped writing.

Take the database backup and the filesystem copy while writes remain quiesced.
Do not resume between these two steps.

## MySQL and MariaDB backup

Keep the same quiescence and Moodledata snapshot procedure described below.
Use the matching server vendor's dump client and a private client options file
containing the connection, password and verified TLS settings:

```bash
mysqldump --defaults-extra-file=/secure/mysql-backup.cnf \
  --single-transaction --quick --hex-blob --no-tablespaces moodle \
  > moodle-recovery/database.sql
# For MariaDB, use mariadb-dump with its own compatible client options file.
```

The transaction snapshot covers InnoDB data; keep DDL and Moodle writes stopped
until both database and Moodledata snapshots complete. Validate the dump by
restoring with `mysql` or `mariadb` into a separate empty database of the same
engine, then run the restored Moodle checks. A successful dump command alone
does not verify recoverability. Encrypt, checksum and restrict this dump just
like the PostgreSQL archive. Adapt the checksum filename below to database.sql.

## PostgreSQL backup

Use `pg_dump --format=custom` from a PostgreSQL client version compatible with
the server. With a managed database, use its documented consistent backup
mechanism and record the recovery point identifier.

Example with client connection settings supplied through a protected libpq
service/password file:

```bash
PGSERVICE=moodle-backup pg_dump --format=custom \
  --file=moodle-recovery/database.dump
pg_restore --list moodle-recovery/database.dump \
  > moodle-recovery/database-contents.txt
```

Use the schema owner or a dedicated appropriately privileged backup account.
Do not put database passwords into shell history. A database backup that cannot
be listed and restored is not accepted recovery evidence.

## Moodledata backup

Stream an archive from a quiesced application pod using a shell that preserves
binary stdout, such as Bash:

```bash
kubectl -n learning exec deployment/moodle -c moodle -- \
  tar -C /var/moodledata -czf - . > moodle-recovery/moodledata.tgz
tar -tzf moodle-recovery/moodledata.tgz \
  > moodle-recovery/moodledata-contents.txt
sha256sum moodle-recovery/database.dump moodle-recovery/moodledata.tgz \
  > moodle-recovery/SHA256SUMS
```

The archive includes shared data and configuration generated under moodledata.
For large sites, a storage snapshot or backup agent with incremental transfers
is preferable to streaming a full archive through the Kubernetes API.

If using a storage/object-file-system plugin, identify which objects are outside
the PVC. Back them up at the same logical recovery point. The default chart
does not configure an object-storage plugin or include external objects in a
PVC archive.

## Resume after successful backup

Verify both artifacts and record their common maintenance window. Only then
resume application traffic and tasks:

```bash
kubectl -n learning exec deployment/moodle -c moodle -- \
  php /var/www/html/admin/cli/maintenance.php --disable
kubectl -n learning exec deployment/moodle -c moodle -- \
  php /var/www/html/admin/cli/cron.php --enable
```

If a backup step fails, keep the site quiesced while deciding whether to retry
or deliberately resume without a new recovery point. Do not describe partial
artifacts as a complete site backup.

## Restore drill

Restore first into an isolated namespace with separate database, data PVC,
Redis prefix and hostname. Disable email and external integrations.

1. Verify archive checksums and list database/archive contents.
2. Provision a new empty database with the required owner and extensions.
3. Restore the custom-format dump with `pg_restore --exit-on-error`.
4. Restore moodledata into an empty PVC with UID/GID 33 and group-writable
   directories, preserving file names and contents.
5. Deploy the exact matching code and configuration with
   `moodle.autoInstall=false` and `moodle.noEmailEver=true`.
6. Set a restore-specific public URL, then disable maintenance after inspection.
7. Purge local caches, verify a real administrator login and open representative
   courses, submissions and uploaded files.
8. Run scheduled-task checks and a controlled cron cycle.
9. Record elapsed recovery time and any excluded external data.

Use a unique Redis prefix or an isolated Redis database; restored sessions must
not overlap production sessions. Keep the restored site blocked from production
SMTP and webhooks until deliberately configured.

Never test restoration over the live database or reuse the production PVC.
Retained PVCs and Secrets are a deletion safeguard, not a disaster-recovery copy.

## Migration from Bitnami

Bitnami's environment variables and entrypoint are not an upstream Moodle API.
Map the public URL, proxy settings, SMTP, administrator bootstrap and Secret
references to this chart's explicit values.

Bitnami commonly uses MariaDB. Select `database.type: mariadb` and connect to
the restored MariaDB database, externally or through the HelmForge subchart.
Preserving the engine avoids an unnecessary cross-engine conversion. A MariaDB
dump cannot be loaded into PostgreSQL with `pg_restore`. If changing engines,
perform an upstream-supported Moodle database transfer and verify it in an
isolated environment. This chart does not automate cross-engine conversion.

Do not mount a Bitnami application directory as moodledata. Separate the code
tree from the actual data directory, preserve plugins/themes and use matching
Moodle versions for the initial recovery test. Database engine conversion,
container migration and a major Moodle upgrade should have separately tested
recovery checkpoints.

Upstream references:

- [Site backup](https://docs.moodle.org/en/Site_backup)
- [Site restore](https://docs.moodle.org/en/Site_restore)
- [Upgrading](https://docs.moodle.org/502/en/Upgrading)
