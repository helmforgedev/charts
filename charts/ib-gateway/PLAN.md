# IB Gateway - Implementation Plan

**Chart:** `ib-gateway`
**Issue:** helmforgedev/charts#1424
**Target first release:** 1.0.0
**Complexity:** Medium

## Executive summary

Build a production-oriented singleton chart for the official
`gnzsnz/ib-gateway-docker` community image. The chart translates the upstream
Compose contract into secure Kubernetes primitives while preserving the
operational reality of IBKR login, 2FA and raw TCP connectivity.

## Priority 1: core foundations

- Deployment with exactly one replica, Recreate strategy and graceful shutdown.
- Pinned stable multi-architecture image and baseline-compatible security.
- Paper/live/both trading modes with correct Service-to-container port mapping.
- Managed Secret, existing Secret and file-based password projection.
- Optional settings PVC and product-specific exec probes.
- ClusterIP Service, dual-stack fields and client-restricted NetworkPolicy.

P1 acceptance: default install reaches the documented unauthenticated waiting
state without crashes; a deterministic local fixture validates readiness and
TCP routing without requiring real IBKR credentials.

## Priority 2: production operations

- External Secrets Operator `items[]` integration.
- VNC as an opt-in, separate ClusterIP Service with Secret-file password.
- Complete 2FA, restart, session-conflict and Java heap configuration.
- Custom configuration and startup script mounts without secret leakage.
- Pod scheduling controls, checksums, explicit lifecycle limitations and
  backup/restore guidance for settings only.

## Priority 3: deferred capabilities

- SSH reverse tunnel convenience values beyond generic mounts.
- noVNC HTTP sidecar and HTTPRoute support after an official pinned image is
  available and independently secured.
- External authenticated protocol monitoring.

These features are intentionally excluded from the first release rather than
implemented with unverified community images or misleading health semantics.

## Resource model

- One Deployment replica only.
- One main TCP Service for live/paper API ports.
- Optional VNC Service.
- Optional PVC for `tws_settings`.
- Optional managed Secret or ExternalSecret.
- Optional NetworkPolicy; no Kubernetes API permissions.

## Validation strategy

1. Helm lint, template all CI scenarios, unit tests and real-schema kubeconform.
2. Template standards and schema/value parity checks.
3. k3d behavioral validation through `make validate-chart CHART=ib-gateway`.
4. ESO fake-store runtime validation.
5. Verify default, live, both, persistence, VNC, dual-stack and ExternalSecret
   scenarios sequentially.
6. Inspect every container log and event; run chart-specific TCP smoke checks.
7. Run Kubescape and record the generated score in README.

## Documentation plan

- Chart README with safe defaults, API exposure warning, IBC retirement risk,
  security scan and complete parameter reference.
- `DESIGN.md` for singleton, probes, storage and secret decisions.
- Dedicated guides for credentials/ESO, networking and 2FA operations.
- Copy-paste examples for paper, live, both and External Secrets.
- Site page with the complete values surface, playground configuration and
  official upstream links.

## Success criteria

- No plaintext credential in rendered ConfigMaps or Pod environment values.
- Default Service remains internal and NetworkPolicy limits API clients.
- Render-time rejection of replicas other than one and inconsistent modes.
- Full local gate and CI pass with zero unresolved review threads.
- Linked chart and site PRs merged, chart 1.0.0 release confirmed, and requester
  notified only after delivery.
