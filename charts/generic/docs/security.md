# Generic Chart Security

## Scope

The generic chart provides opt-in security primitives without assuming a cluster security stack.

## Security presets

`securityPreset` can be empty, `baseline`, or `restricted`. Presets only apply when explicit `podSecurityContext`,
`securityContext`, or per-container `securityContext` values are not set.

- `baseline` sets non-root pod defaults, RuntimeDefault seccomp, disables privilege escalation, and drops capabilities.
- `restricted` also sets default UID/GID/fsGroup and `readOnlyRootFilesystem`.

Ephemeral debug containers are intentionally not modeled as a values contract because Kubernetes manages them through
the pod `ephemeralcontainers` subresource. Use `kubectl debug` or `extraManifests` for operator-specific debug flows.

## ServiceAccount

`serviceAccount.create` creates a dedicated ServiceAccount. `serviceAccount.automountServiceAccountToken` defaults to `false`, so pods do not mount Kubernetes API tokens unless explicitly requested.

## Secrets

Use `secrets[]` for chart-managed Kubernetes Secrets:

```yaml
secrets:
  - name: app
    type: Opaque
    stringData:
      password: change-me
```

Use `externalSecrets.enabled` or `sealedSecrets.enabled` only when the matching CRD is installed. These resources are disabled by default.

## RBAC

`rbac.create` creates a Role and RoleBinding for the release ServiceAccount. `rbac.clusterRole.create` is available for cluster-scoped permissions, but should be used only when a namespaced Role is insufficient.

## NetworkPolicy

`networkPolicy.enabled` creates a NetworkPolicy targeting the release pods. Use `networkPolicy.defaultDeny: true` to start from a deny posture and add explicit ingress/egress rules.

<!-- @AI-METADATA
type: chart-docs
title: Generic Chart - Security
description: ServiceAccount, Secrets, RBAC, and NetworkPolicy for the generic chart
keywords: generic, security, rbac, secrets, networkpolicy
purpose: Security configuration guide for the generic chart
scope: Chart Architecture
relations:
  - charts/generic/README.md
path: charts/generic/docs/security.md
version: 1.0
date: 2026-04-27
-->
