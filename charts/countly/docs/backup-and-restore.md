<!-- SPDX-License-Identifier: Apache-2.0 -->
# Backup and Restore

## Backup Flow

When `backup.enabled=true`, a CronJob runs `mongodump` into an `emptyDir` and
then uploads the compressed archive with the HelmForge `mc` image. The temporary
archive is not durable and must fit on the selected node's ephemeral storage.
The chart does not enforce retention or object locking.

External MongoDB credentials can be supplied through:

- `backup.database.existingSecret` and
  `backup.database.existingSecretUriKey`;
- the application's `externalMongodb.existingSecret`;
- `backup.database.uri`; or
- the bundled MongoDB Secret.

`backup.database.mongodumpArgs` is an array:

```yaml
backup:
  database:
    mongodumpArgs:
      - --readPreference=secondaryPreferred
```

Legacy releases accepted a space-delimited string. That form remains supported
so existing Helm values continue to render, but new configurations should use
the array form because each item is passed directly to `mongodump` without shell
evaluation.

The backup init container never passes a MongoDB URI or password on its command
line. URI Secrets are mounted only into that container, and the script writes a
mode `0600` `mongodump --config` file in an isolated in-memory volume. The
bundled MongoDB root password follows the same pattern and is not exposed in an
environment variable.

## Verification

Create an ad-hoc Job from the CronJob and inspect both containers:

```bash
kubectl -n countly create job --from=cronjob/countly-countly-backup countly-backup-check
kubectl -n countly logs job/countly-backup-check -c mongodb-backup
kubectl -n countly logs job/countly-backup-check -c upload
```

Confirm the object exists, is non-empty, and is protected by the intended
retention and encryption controls.

## Restore

The chart deliberately does not automate destructive restores. Restore into an
isolated MongoDB first:

1. download and checksum the selected archive;
2. create a clean target database;
3. run `mongorestore --archive=<file> --gzip` with an appropriately scoped URI;
4. deploy a temporary Countly release against the restored database;
5. verify users, applications, dashboards, events, and enabled plugins;
6. document the recovery time and only then plan production cutover.

Never test a restore by overwriting the active production database.
