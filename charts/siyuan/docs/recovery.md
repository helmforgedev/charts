# Workspace recovery

## Consistent backup

Schedule downtime, stop the Deployment and wait for the old pod to terminate. Use the same namespace and explicit
context for all commands. Do not run a second SiYuan process against the claim.

```bash
kubectl -n siyuan scale deployment/siyuan-siyuan --replicas=0
kubectl -n siyuan wait --for=delete pod -l app.kubernetes.io/instance=siyuan --timeout=60s
```

Mount the workspace read-only in a temporary restricted maintenance pod, along with a separate writable backup volume.
Use the pinned SiYuan image's tar utility to archive the entire workspace. Store each backup under a unique name.
Preserve file permissions and the full data/conf/history/storage tree, including encrypted content and identity
material.

After a successful archive and integrity check, remove the maintenance pod and scale the original Deployment back to
one. Replicas remain one in Helm values so a subsequent upgrade does not preserve maintenance downtime accidentally.

## Restore

Provision a new empty claim of sufficient capacity. With no application writer using it, mount the archive volume and
extract the entire workspace into the new claim using UID/GID 1000. Remove the maintenance pod before starting the
application.

```yaml
persistence:
  existingClaim: siyuan-recovered
```

Install the same tested image version with this value and the original auth/OIDC Secret references. Verify native login,
notebook listing, document export, attachments and any encrypted notebooks before routing traffic. The chart's recovery
CI follows this procedure with a quiesced archive and a fresh claim, and verifies identical Unicode document content.

Do not substitute a copy of the live SQLite index for a workspace backup. Do not expect Helm rollback to undo storage
migrations. Keep recovery passwords for encrypted notebooks separately; also create native encrypted-notebook backups
where appropriate.

## Retention

The generated PVC is kept on release uninstall by default. Uninstalling is not a backup. Namespace deletion,
underlying-volume deletion and storage-provider policies are separate operations. Configure backup encryption,
off-cluster copies and retention according to your data requirements.

<!-- @AI-METADATA
 type: guide
 title: SiYuan recovery
 description: Quiesced complete-workspace backup and restore
 keywords: siyuan, backup, restore, pvc
 purpose: Recover durable workspace state
 scope: chart
 path: charts/siyuan/docs/recovery.md
 version: 1.0
 date: 2026-09-10
-->
