<!-- SPDX-License-Identifier: Apache-2.0 -->

# Velero Operations Guide

## Readiness Checks

Confirm the Deployment is available and the backup storage location reports an
available phase before relying on backups:

```bash
kubectl rollout status deployment/velero -n velero
kubectl get backupstoragelocations.velero.io -n velero
kubectl logs deployment/velero -n velero --since=15m
```

The startup, readiness, and liveness probes use the Velero metrics TCP listener.
Changing `metrics.containerPort` updates the Velero process argument, container
port, probes, and named Service target together. `metrics.service.port` changes
only the Service-facing port.

Charts before 1.6 used `configuration.metricsAddress` and `extraObjects`.
Retained values using those names remain supported: `metricsAddress` overrides
the default process listener and `extraObjects` is rendered together with
`extraManifests`. Migrate to `metrics.containerPort` and `extraManifests` when
editing the configuration.

Do not upgrade from chart 1.5.1 with `--reuse-values` alone. It can omit the
newer `networkPolicy` parent map and make template rendering fail at
`.Values.networkPolicy.enabled`. Use `helm upgrade --reset-then-reuse-values`
and review the rendered diff before applying the upgrade.

## Backup Verification

Create a small backup and inspect its phase and logs:

```bash
velero backup create smoke-test --include-namespaces default
velero backup describe smoke-test --details
velero backup logs smoke-test
```

A successful command is not a disaster-recovery test. Restore into an isolated
namespace or cluster on a regular schedule and verify application data there.

## Monitoring

When `metrics.enabled=true`, the chart creates a Service for the Prometheus
endpoint. Enable `metrics.serviceMonitor.enabled` only when the Prometheus
Operator CRDs are already installed. Monitor at least:

- backup and restore phase transitions
- backup storage location availability
- failed and partially failed backups
- schedule execution and retention
- node-agent availability when filesystem backup is enabled
- repository maintenance and upload/download errors

## Credential Rotation

Prefer `credentials.existingSecret` or workload identity over inline
`credentials.secretContents`. After rotating a mounted Secret, restart the
server and node-agent so the new file and environment values are consumed:

```bash
kubectl rollout restart deployment/velero -n velero
kubectl rollout status deployment/velero -n velero
```

If the node-agent is enabled, restart and observe that DaemonSet as well.

## Upgrade and Rollback

Before an upgrade, review the Velero and provider-plugin compatibility matrix,
export the installed values, and confirm recent restore drills. Helm does not
remove or roll back CRDs automatically. Treat CRD schema changes as a separate,
reviewed operation and keep a copy of the previous release values.
