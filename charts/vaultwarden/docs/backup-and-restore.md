# Backup and Restore

## What must be backed up

For the current chart scope, a valid backup is not only the SQLite database file.

Back up the full `/data` lifecycle set:

- `db.sqlite3`
- `config.json`
- `rsa_key*`
- `attachments/`
- `sends/`

If any of these pieces are missing, restore may succeed technically but still be incomplete operationally.

## Why backup is not trivial here

This chart is intentionally based on `sqlite + PVC + single instance`.

That keeps the runtime small, but it also means:

- the database and file assets share the same operational boundary
- drift can exist between Helm values and settings persisted by the admin interface in `/data/config.json`
- backup and restore must be designed around the data volume, not only around one database file

## Recommended architecture

The most practical production architecture for this repository is:

1. `vaultwarden` as the main application release
2. an object storage bucket compatible with S3
3. a separate backup release using the [`generic`](../../generic/README.md) chart as a `CronJob`
4. a backup container that understands Vaultwarden data layout and pushes archives to object storage
5. monitoring for backup success and failure

This keeps backup lifecycle independent from the main release:

- schedule changes do not require touching the application chart
- credentials for object storage stay separated from the application
- restore workflows stay explicit instead of pretending to be automatic

## Important limitation for SQLite PVC backups

Do not treat every Kubernetes storage class as equivalent.

For a separate backup pod to mount the same data claim safely, your platform must support the access pattern you are planning:

- `ReadWriteMany` storage is the cleanest option for a separate backup pod
- `ReadWriteOnce` may work only under stricter node-placement conditions and is not the safest default assumption for a detached backup job

If your platform uses a strict `ReadWriteOnce` PVC and cannot guarantee the mount pattern for a separate `CronJob`, the more reliable direction is:

- snapshot-capable storage with `VolumeSnapshot` orchestration
- or a future in-pod backup design that shares the already-mounted volume

For the current repository scope, the recommended documented automation is a separate backup release only when the storage semantics are compatible.

## Object storage recommendations

Use an S3-compatible bucket with:

- server-side encryption
- bucket versioning
- lifecycle policy for retention
- immutability or object lock when your platform supports it
- separate credentials for backup write access

That is the difference between "we upload a file somewhere" and a backup posture that survives operator error and accidental overwrites.

## Recommended automation pattern with the generic chart

The [`generic`](../../generic/README.md) chart is a good fit for the backup automation because the backup workload is a product-specific batch process, not part of the Vaultwarden runtime itself.

Suggested pattern:

- `workload.enabled=false`
- one `CronJob`
- PVC mounted read-only when the storage pattern allows it
- rclone configuration and object storage credentials injected through secrets
- notifications sent on success and failure

Illustrative example:

```yaml
workload:
  enabled: false

image:
  repository: ttionya/vaultwarden-backup
  tag: latest
  pullPolicy: IfNotPresent

imageTagFormat: simple

env:
  - name: DATA_DIR
    value: /data
  - name: RCLONE_REMOTE_NAME
    value: BitwardenBackup
  - name: RCLONE_REMOTE_DIR
    value: /vaultwarden/prod
  - name: CRON
    value: "0 15 2 * * *"
  - name: BACKUP_KEEP_DAYS
    value: "30"
  - name: BACKUP_FILE_SUFFIX
    value: "%Y%m%d-%H%M%S"
  - name: ZIP_ENABLE
    value: "TRUE"
  - name: ZIP_TYPE
    value: "7z"
  - name: TIMEZONE
    value: America/Sao_Paulo
  - name: DISPLAY_NAME
    value: vaultwarden-prod
  - name: PING_URL_WHEN_SUCCESS
    valueFrom:
      secretKeyRef:
        name: vaultwarden-backup-monitoring
        key: ping-success
  - name: PING_URL_WHEN_FAILURE
    valueFrom:
      secretKeyRef:
        name: vaultwarden-backup-monitoring
        key: ping-failure

envFrom:
  - secretRef:
      name: vaultwarden-backup-rclone

persistence:
  volumes:
    - name: vaultwarden-data
      persistentVolumeClaim:
        claimName: vaultwarden-data
  mounts:
    - name: vaultwarden-data
      mountPath: /data
      readOnly: true

cronjobs:
  - name: backup
    schedule: "0 15 2 * * *"
    concurrencyPolicy: Forbid
    successfulJobsHistoryLimit: 3
    failedJobsHistoryLimit: 3
    containers:
      - name: backup
```

Adjust the claim name, secrets, schedule, and storage assumptions to your cluster reality.

## Restore principles

Restore should be treated as a controlled maintenance event.

Minimum restore sequence:

1. stop Vaultwarden traffic
2. stop the running application pod
3. restore the complete `/data` set, not only `db.sqlite3`
4. verify `config.json`, `rsa_key*`, `attachments/`, and `sends/`
5. start the application again
6. validate login, attachments, sends, and admin access

## Validation after restore

At minimum, validate:

- user login
- organization access
- attachment download
- send access
- admin page reachability
- expected domain and email behavior

## References used for this guidance

- Vaultwarden configuration template: https://raw.githubusercontent.com/dani-garcia/vaultwarden/main/.env.template
- Generic chart in this repository: [`charts/generic`](../../generic/README.md)
