# Envoy Gateway CRDs Design

## Purpose

`envoy-gateway-crds` separates cluster API lifecycle from the Envoy Gateway
controller release. This solves first-install discovery failures in Helm diff
workflows and makes CRD upgrade ordering explicit.

## Design Decisions

### CRDs remain in `crds/`

The chart does not template CRDs. Helm installs objects from `crds/` before
normal templates, excludes them from the release manifest, skips existing
objects, and never deletes them. This prevents both the Helm release Secret size
failure and accidental cluster-wide data loss.

The consequence is intentional: `helm upgrade` does not update schemas. Every
CRD upgrade uses an explicit server-side apply step before the controller
upgrade.

### Conditional internal subcharts

Helm does not template files in `crds/`, so individual documents cannot be
selected with values. Two internal subcharts provide the required selection
boundary:

- `gateway-api-crds`: 10 Gateway API v1.6.1 Experimental CRDs.
- `envoy-gateway-extension-crds`: 8 Envoy Gateway v1.9.0 CRDs.

Helm removes disabled dependencies before recursively collecting CRD objects.
This supports a provider-managed Gateway API without moving CRDs into
templates.

### No application dependency

The Envoy Gateway application chart must not depend on this chart. A dependency
would render CRDs and custom resources inside the same Helm operation and would
not create a discovery boundary for `helm-diff`.

### Explicit policy management

The safe-upgrade policy has three modes. `managed` gives Helm real ownership of
the policy and binding. `external` declares a different owner. `disabled` is
reserved for bootstrap, CRD-only rendering, and migration. The chart never
silently suppresses ownership conflicts.

### Forward-only CRD lifecycle

CRD downgrade is unsupported. A Helm rollback changes release metadata and
policy templates but cannot and must not roll schemas backwards. Application
rollback is supported only when the live CRD bundle remains compatible with the
target controller version.

## Security Model

CRDs and admission policies are cluster-scoped and require cluster-admin level
authority. The release contains no pods, containers, credentials, Services, or
network endpoints.

The policy uses `failurePolicy: Fail` and the upstream Gateway API CEL rules.
Both policy resources are retained on uninstall. Their ownership must be
audited before adoption from an existing application release.

## Non-Goals

- Installing the Envoy Gateway controller.
- Creating GatewayClass, Gateway, Route, or Envoy extension custom resources.
- Automatically forcing server-side apply conflicts.
- Supporting CRD downgrades.
- Deleting CRDs or custom resources during uninstall.
- Claiming Helm ownership metadata on CRDs that Helm does not track.

## Release Contract

Chart major versions may change the supported Envoy Gateway or Gateway API
compatibility set. Minor and patch releases may correct documentation,
validation, or metadata without changing the pinned bundle unexpectedly.

Application controller upgrades always occur after the matching CRD release is
installed and its APIs are discoverable.
