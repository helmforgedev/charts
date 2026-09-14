# Backup, restore and upgrades

## Backup boundary

Back up the complete `/data` directory, including `id_ed25519`,
`id_ed25519.pub`, `db_v2.sqlite3` and any SQLite sidecars or native relay files.
If identity comes from an existing Secret or ESO, back up that source separately:
the mounted Secret files are not stored in the underlying PVC.
Encrypt backups containing the private key and restrict restore access.

A retained PVC is not a backup. The default keep annotation protects against
Helm uninstall, not namespace deletion, storage failure or administrator deletion.
The chart provides no scheduled backup Job or remote backup destination.

## Quiesced copy or snapshot

Schedule a maintenance window: active sessions will disconnect. Record the
current chart/application version, values and public key fingerprint. Stop both
processes by scaling the Deployment to zero and wait until its Pod is deleted:

```bash
kubectl -n rustdesk scale deployment/rustdesk-rustdesk-server --replicas=0
kubectl -n rustdesk wait --for=delete pod \
  -l app.kubernetes.io/instance=rustdesk --timeout=60s
```

Take a CSI volume snapshot or mount the stopped PVC in an approved maintenance
Pod with a pinned backup image and UID/GID compatible with the data. Copy the
complete directory to an off-cluster backup. Do not attempt `kubectl cp` against
the scratch server image. A live filesystem copy can produce inconsistent SQLite
state; this procedure deliberately stops all writers first.

Restart the original Deployment after backup and confirm the public identity
and client connections. Retention and backup schedules belong to your storage
and operational policy.

## Restore into a fresh PVC

1. Provision an empty compatible PVC in the target namespace.
2. Restore the complete directory while no RustDesk writer mounts that claim.
3. Ensure UID/GID 1000 can read and write the restored data, or configure matching
   pod security settings supported by your storage driver.
4. Restore the separate identity Secret/provider data if used.
5. Install or upgrade with `persistence.existingClaim` set to the restored PVC.

```bash
helm upgrade --install rustdesk helmforge/rustdesk-server -n rustdesk \
  -f production-values.yaml --set persistence.existingClaim=rustdesk-restored
```

Check that hbbs and hbbr report the original public key. Test a previously
registered client identity and a real relay session between endpoints on
different networks. A newly generated key or an empty peer database means the
restore boundary was incomplete. The local chart gate exercises a stopped copy
to a fresh PVC and repeats identity, SQLite association and payload checks.

## Application upgrades and rollback

Review upstream release notes, take a quiesced backup and select a pinned version.
The Recreate strategy stops the old pair before starting the new pair. Expect
downtime; there is no rolling session transfer. Verify the same public identity,
native registration and relay behavior after upgrading.

Helm rollback changes Kubernetes configuration, not database contents. If an
upstream version changes persisted formats, restore a compatible backup together
with its application version. Never run two releases against one restored claim.
To reuse a retained claim after uninstall, pass its actual name through
`persistence.existingClaim` instead of allowing Helm to create a replacement.
