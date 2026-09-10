# Backup and recovery

Back up the whole workspace claim and all credential Secrets, including a generated initial-password Secret. It includes
configs with H2 state, customFiles and pipeline. Copying one live H2 file is not a consistent backup.

1. Restrict new traffic and finish active conversions and pipeline jobs.
2. Record values, image version, claim name and Secret references.
3. Scale the Deployment to zero and wait for termination so H2 closes cleanly.
4. Archive the complete claim from a restricted helper. Store the archive independently, encrypted with suitable
   retention.
5. Resume the Deployment and verify native login and conversion.

Restore into a fresh PVC with compatible ownership and set persistence.existingClaim. Start with the original image.
Verify login, retained API keys, custom files, pipeline state and a real conversion before switching traffic. Never run
source and restored instances against the same H2 files.

No automatic online H2 backup is claimed. Coordinate volume snapshots with quiescing and regularly test restoration.
Helm rollback does not reverse database migrations.

For GNU tar without root, archive the complete `configs`, `customFiles` and `pipeline` directories without a mount-root
`.` entry. Restore with `--no-same-owner --no-overwrite-dir`. The PVC mount root may be root-owned with writable fsGroup
permissions; attempting to restore its metadata fails even when file extraction succeeds. Preserve provider-owned root
metadata and verify ownership and content of restored files. Include any operator-added state directories explicitly.
