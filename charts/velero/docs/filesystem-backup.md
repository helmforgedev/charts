# Filesystem Backup

Enable `nodeAgent.enabled=true` when you need filesystem backup for pod volumes.

## What this chart does

When enabled, the chart deploys the Velero node-agent as a DaemonSet and wires the host paths required for pod volume access.

## What to validate

- your cluster policy allows the node-agent hostPath mounts
- your storage and workload patterns are compatible with filesystem backup
- the object storage location is already healthy before enabling schedules
- the node-agent pods reach `Ready` on the intended nodes

## Recommended first validation

1. install Velero with a working `BackupStorageLocation`
2. enable `nodeAgent`
3. create one controlled backup that uses filesystem backup
4. inspect backup status before enabling recurring schedules
