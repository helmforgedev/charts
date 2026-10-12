# QuestDB operations

## Backup

QuestDB OSS backup consistency requires database coordination:

1. Execute `CHECKPOINT CREATE` and wait for success.
2. Copy the retained PVC or create the external block-volume snapshot.
3. Execute `CHECKPOINT RELEASE` even when the copy operation fails.
4. Verify the backup by restoring it into an isolated environment.

Do not describe an uncoordinated CSI snapshot of a running instance as a
consistent backup.

## Restore

Scale or stop the workload, attach a verified copy containing the complete
`/var/lib/questdb` tree, and set `persistence.existingClaim`. Restore with the
same QuestDB major version first, validate queries and only then upgrade.

## Upgrade

Review upstream release notes and test the new image against a backup before
changing versions. QuestDB can migrate on-disk metadata during startup, so a
rollback may require restoring the pre-upgrade volume rather than only changing
the image tag.

## Availability

This chart deploys one OSS instance. Enabling the PodDisruptionBudget with
`minAvailable: 1` blocks voluntary node drains; leaving it disabled permits a
drain but causes downtime. Multi-replica HA belongs to QuestDB Enterprise and
its supported operator.

## Host and storage preparation

Follow upstream production guidance for fast local block storage,
`vm.max_map_count=1048576` and high open-file limits. Storage that ignores
`fsGroup` must be provisioned with UID/GID 10001 ownership.
