<!-- markdownlint-disable MD013 -->

# Bulwark Mail chart design

## Goals

Provide a secure, reproducible Bulwark 1.11.2 deployment with explicit wizard and declarative modes, durable state, external secret integration, modern HTTP exposure, and behavioral acceptance.

## Workload choice

Bulwark is packaged as a Deployment because it has one HTTP identity and no stable network identity requirement. `Recreate` prevents simultaneous attachment and writes against the single RWO data volume during upgrades.

The chart refuses multiple replicas and autoscaling. Bulwark mutates settings, admin configuration, audit state, telemetry identity, and version-check state on local files. Sharing that state safely across independent pods is not an upstream-supported HA contract.

## Storage

One volume is mounted once at `/app/data`. Upstream subdirectories remain application-owned. This avoids mounting one claim through duplicate Kubernetes volumes and makes backup/restore atomic across related state. `/tmp` is a separate emptyDir so the root filesystem can remain read-only.

## Configuration modes

Wizard mode follows the upstream installation experience and therefore requires persistence. Declarative mode requires `JMAP_SERVER_URL`, while admin read-only mode is a separate explicit setting. Keeping it writable during bootstrap allows `ADMIN_PASSWORD` to create persisted `admin.json`; operators can enable `config.admin.readOnly` after bootstrap. Both modes retain the PVC for settings and runtime state.

Environment values are not claimed to override existing admin files: upstream precedence deliberately gives saved admin configuration priority. The documentation calls out the migration boundary.

## Secret lifecycle

The session secret is required for remember-me sessions and settings encryption. The default generated Secret uses Helm lookup so upgrades retain the key. Operators may replace it with an existing Secret or an ExternalSecret target.

Admin, OAuth, and JWT master values share one Secret contract but are referenced only by enabled features. JWT impersonation is guarded as a complete tuple because partial configuration is unsafe and non-functional.

## Exposure

Ingress and Gateway API target the HTTP Service only. They are mutually exclusive to keep ownership and troubleshooting unambiguous. The upstream image bakes base paths during image build, so this chart supports only `/` and fails fast on subpaths.

## Network policy

The default leaves network policy disabled for compatibility. The opt-in policy restricts ingress to the named HTTP port and egress to DNS, JMAP ports, and explicit operator additions. The open-by-port default for JMAP avoids pretending the chart can derive an IP selector from a public URL.

## Security

The chart matches upstream UID/GID 1001, drops all capabilities, uses RuntimeDefault seccomp, disables privilege escalation, disables ServiceAccount token mounting, and keeps the root filesystem read-only. Writable paths are intentionally limited to `/app/data` and `/tmp`.

## Dependencies and non-goals

There are no chart dependencies. Stalwart has an independent lifecycle, storage topology, mail listeners, certificates, DNS, and upgrade risk. Bundling a community Stalwart subchart would weaken both contracts.

## Upgrade and recovery

Recreate upgrades trade a short outage for deterministic single-writer storage. Recovery requires the data PVC and matching session secret. The chart retains newly created PVCs by default to reduce accidental data loss during uninstall.

## Validation

Template tests cover deployment, storage, secrets, validation failures, HTTP exposure, Gateway API, dual-stack, NetworkPolicy, and External Secrets. Runtime validation checks upstream health, public configuration, session-backed features, and setup-mode behavior.
