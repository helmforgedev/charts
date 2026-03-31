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

<!-- @AI-METADATA
type: chart-docs
title: Velero - Filesystem Backup
description: Filesystem backup guidance for the Velero node-agent

keywords: velero, node-agent, filesystem-backup, kopia

purpose: Explain the optional filesystem backup mode for Velero
scope: Chart Architecture

relations:
  - charts/velero/README.md
  - charts/velero/docs/s3-compatible.md
path: charts/velero/docs/filesystem-backup.md
version: 1.0
date: 2026-03-31
-->
