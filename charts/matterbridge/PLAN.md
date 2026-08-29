# Matterbridge Chart Implementation Plan

**Chart:** `matterbridge`
**Issue:** helmforgedev/charts#1077
**Initial chart version:** `1.0.0`
**Application version:** `3.10.7`
**Maturity:** stable
**Complexity:** medium

## Executive Summary

Build a production-ready singleton Matterbridge deployment that works for its
primary home-LAN use case without requiring users to understand Kubernetes
multicast internals. The baseline-compatible default uses pod networking,
persistent coupled state, ordered singleton upgrades and official health
checks. A production/LAN example enables host networking with one value;
advanced pod-network users can add a UDP Service and CNI/reflector integration.

## Priority 1: Functional Core

### P1-1: Stable Official Runtime

- Pin `docker.io/luligu/matterbridge:3.10.7`.
- Configure frontend port 8283 and Matter base port 5540.
- Preserve the upstream `matterbridge --docker` command contract.
- Support an optional profile and additional CLI arguments.

### P1-2: Matter-Correct Networking

- Keep pod networking as the Pod Security baseline-compatible default.
- Provide a one-value host-network production/LAN mode matching upstream.
- Use `ClusterFirstWithHostNet` automatically with host networking.
- Expose the frontend through a ClusterIP Service.
- Provide an optional Matter UDP Service for portable networking mode.
- Document mDNS, multicast, IPv6, VLAN and firewall constraints.

### P1-3: Durable Coupled State

- Create one retained RWO PVC by default.
- Use the official `--homedir /data` option so Matterbridge creates and owns
  all three state trees on the same volume.
- Support an existing claim and ephemeral mode.

### P1-4: Safe Singleton Lifecycle

- Render one replica only.
- Use a one-replica StatefulSet with ordered replacement semantics.
- Configure a 60-second termination grace period.
- Add startup, readiness and liveness probes against `/health`.

### P1 Validation

- Render defaults and portable networking values.
- Deploy defaults on the canonical k3d cluster.
- Verify the Deployment becomes Available, `/health` returns success and logs
  contain no crash/fatal patterns.
- Verify cleanup before production features proceed.

## Priority 2: Production Features

### P2-1: Secure Kubernetes Defaults

- Dedicated ServiceAccount with token automount disabled.
- RuntimeDefault seccomp profile.
- Drop all capabilities and disable privilege escalation.
- Document why upstream currently requires root and a writable root filesystem.

### P2-2: Controlled UI Exposure

- Canonical Ingress with guarded `ingressClassName`.
- Canonical multi-route Gateway API HTTPRoute.
- State clearly that these resources expose only the HTTP UI.
- Recommend private access or an authenticated reverse proxy.

### P2-3: Network Controls

- Optional NetworkPolicy for UI ingress.
- Optional egress enforcement with DNS and complete `extraEgress` rules.
- Explain that host-network policy enforcement depends on the CNI.

### P2-4: Secret and Extension Integration

- Canonical ExternalSecret `items[]` renderer.
- `extraEnv`, `extraEnvFrom`, extra volumes, mounts, containers and manifests.
- Avoid fictitious Matterbridge credential environment variables.

### P2-5: Operational Safety

- Retain PVC on uninstall by default.
- Expose PVC annotations for Velero and storage tooling.
- Add backup/restore guidance covering all three state domains.
- Document port conflicts and single-instance scheduling.

## Priority 3: User Experience and Polish

### P3-1: Complete Validation Surface

- Strict JSON schema for every value.
- Fail-fast checks for ingress hosts, Gateway routes, selector-label
  collisions, invalid port ranges, unsafe replica overrides and incomplete
  ExternalSecret items.
- At least 40 helm-unittest cases across every feature.
- CI values for default, portable networking, dual-stack, ingress, Gateway
  API, NetworkPolicy, existing claims and External Secrets.

### P3-2: Product-Specific Documentation

- README with quick start, networking decision guide and complete values.
- Dedicated networking, persistence/backup and security/operations guides.
- Five tested examples covering simple, production, portable networking,
  Ingress and Gateway API deployments.
- Eight-section operational NOTES dashboard.

### P3-3: Site Integration

- Stable catalog entry and official upstream mark.
- Full site page covering all values and at least ten troubleshooting cases.
- Playground configuration using safe defaults.
- Cross-link chart and site PRs without closing the chart issue from the site.

## Technical Architecture

```text
StatefulSet (replicas=1, ordered replacement)
  |
  +-- Matterbridge container
  |     +-- TCP 8283: frontend and /health
  |     +-- UDP 5540-5559: Matter nodes
  |     +-- hostNetwork for production LAN deployments
  |
  +-- data volume
        +-- plugins      -> /data/Matterbridge
        +-- storage      -> /data/.matterbridge
        +-- certificates -> /data/.mattercert

Service (frontend TCP)
  +-- optional Ingress
  +-- optional HTTPRoute

Optional Matter Service (UDP range for portable mode)
```

## Non-Goals

- Horizontal scaling or active-active Matterbridge.
- Bundled mDNS reflector.
- Automatic plugin installation in a chart hook.
- Prometheus ServiceMonitor without an upstream metrics endpoint.
- Invented database, cache or credential abstractions.
- Scheduled backups in an upstream-incompatible format.

## Validation Strategy

1. `make image-verify IMAGE=docker.io/luligu/matterbridge:3.10.7`.
2. `make deps-check CHART=matterbridge` (expected: no dependencies).
3. `make validate-chart CHART=matterbridge` for the full static and k3d gate.
4. `make standards-check CHART=matterbridge` and template standards check.
5. ESO end-to-end validation with the fake ClusterSecretStore.
6. Kubescape scan and README evidence update.
7. Site lint, format, build, link check and site-sync check.
8. Repository preflight, release and attribution checks.

## Success Criteria

- Default install reaches Available and `/health` succeeds on k3d.
- No floating image tags or non-official runtime images.
- All three durable directories share one correctly initialized PVC.
- Portable mode renders all configured UDP ports and dual-stack fields.
- Ingress and Gateway API never claim to expose Matter traffic.
- Every optional feature has CI values, unit tests and documentation.
- Chart and site PRs are normal PRs to `main`, CI green, zero unresolved
  review threads, and only the chart PR resolves issue #1077.
