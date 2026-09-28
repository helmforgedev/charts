<!-- markdownlint-disable MD013 -->

# Storage and recovery

## Data layout

One PVC is mounted at `/app/data`. Bulwark owns these subdirectories:

- `settings`: encrypted user settings;
- `admin`: configuration, policy, password hash, plugins, themes, branding;
- `admin-state`: audit and login runtime state;
- `telemetry`: consent and anonymous instance identity;
- `version-check`: update-check state.

`/tmp` is an emptyDir and is not part of backup state.

## Why one PVC

The directories participate in one application lifecycle. A single mount avoids duplicate declarations of the same claim and supports a coherent snapshot. The chart is intentionally single-replica and uses Recreate upgrades.

## Backup

Quiesce the Deployment or use a storage snapshot with filesystem consistency. Back up the runtime Secret at the same recovery point because encrypted settings depend on the session key.

```bash
kubectl -n mail scale deployment/bulwark-mail --replicas=0
kubectl -n mail get secret bulwark-mail -o yaml > bulwark-mail-secret.yaml
```

Create the provider-specific PVC snapshot, then return the Deployment to one replica.

## Restore

Restore or bind the PVC first, restore the Secret, and install with `persistence.existingClaim` and `secrets.existingSecret`. Never allow the chart to generate a new session secret for old encrypted settings.

## Retention

Generated PVCs carry `helm.sh/resource-policy: keep` by default. Uninstall does not delete the volume. Delete it manually only after a verified backup and explicit data-retention decision.

## Troubleshooting

- Wizard restarts: PVC is not mounted or setup state was restored without admin configuration.
- `EACCES`: storage does not honor fsGroup 1001; fix the provisioner or pre-provision ownership.
- Settings reset: session secret changed or `/app/data/settings` was not restored.

<!-- @AI-METADATA
type: chart-docs
title: Bulwark Mail storage
description: Storage, backup, and recovery contract
keywords: bulwark, pvc, backup, restore
purpose: Protect Bulwark Mail state
scope: Chart
relations:
  - charts/bulwark-mail/README.md
path: charts/bulwark-mail/docs/storage.md
version: 1.0
date: 2026-09-28
-->
