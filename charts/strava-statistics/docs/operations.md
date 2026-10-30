<!-- SPDX-License-Identifier: Apache-2.0 -->

# Dreeve Operations Runbook

This runbook covers the stateful lifecycle of a Dreeve release. Replace `<release>` and `<namespace>` in every command.

## Health Review

Confirm both containers are Ready, have zero restarts, and expose a Service endpoint:

```bash
kubectl get pod,svc,endpoints,pvc -n <namespace> -l app.kubernetes.io/instance=<release>
kubectl logs -n <namespace> deploy/<release>-strava-statistics -c strava-statistics --tail=200
kubectl logs -n <namespace> deploy/<release>-strava-statistics -c daemon --tail=200
kubectl get events -n <namespace> --sort-by=.lastTimestamp
```

The web container owns database migrations. The daemon waits for the schema and then starts background work. A daemon
that repeatedly reports schema waits usually indicates a failed web migration or an unwritable database directory.

## Backup

Dreeve stores durable data on one PVC. The database directory is critical; build, files, gear-maintenance, and watch
data are also part of a complete recovery point.

1. Pause imports and other writes.
2. Snapshot the PVC with the storage provider, or stop the Deployment before a file-level copy.
3. Record the chart version, image tag, values, Secret names, and snapshot identifier.
4. Verify the snapshot is Ready before resuming writes.

Never copy a live SQLite file without storage-level snapshot consistency or stopping writers.

## Restore Drill

Test restores in an isolated namespace:

1. Restore the snapshot into a new PVC.
2. Install the same chart and image versions with `persistence.existingClaim` set to the restored claim.
3. Wait for both containers to become Ready.
4. Verify admin login, activity history, uploaded files, and one representative import.
5. Inspect both container logs and confirm zero restarts.

A backup is not considered operationally valid until this drill succeeds.

## Upgrade

Before upgrading, read the upstream release notes, verify the image manifest, and create a recovery point. Dreeve uses
`Recreate`, so a short outage is expected while migrations and cache rendering complete.

```bash
helm upgrade <release> oci://ghcr.io/helmforgedev/helm/strava-statistics \
  --namespace <namespace> \
  --reset-then-reuse-values \
  --values reviewed-values.yaml \
  --wait \
  --timeout 10m
```

Review and reapply the installation's user overrides in `reviewed-values.yaml`; do not carry the previous chart's
coalesced defaults forward. Afterward, confirm the image tag, both containers, migration logs, daemon logs, admin login,
and an import. Do not roll back across a database migration until upstream compatibility is confirmed; prefer restoring
the pre-upgrade snapshot.

## Capacity

Monitor PVC utilization and pod memory. Large imports can approach the default `4G` PHP limit and `5Gi` container limit.
Increase PHP and Kubernetes limits together, and leave enough node headroom for the web and daemon containers to import
concurrently. PVC expansion depends on the StorageClass and may require an explicit operator action.

## Credential Rotation

- Rotate `APP_SECRET` only when invalidating existing admin sessions is acceptable.
- Update the bcrypt admin hash in the referenced Secret, then restart the Deployment.
- Strava refresh tokens can rotate during OAuth use; protect the database backup as well as the bootstrap Secret.
- Keep `DREEVE_API_KEY` absent unless the upload API is required, and rotate it as a bearer credential.

## Incident Triage

Collect the rendered values with secrets redacted, pod description, current and previous logs for both containers,
events, PVC status, and node pressure conditions. Preserve a storage snapshot before attempting manual SQLite repair.
Do not scale above one replica to work around availability incidents; concurrent SQLite writers can make recovery harder.
