<!-- SPDX-License-Identifier: Apache-2.0 -->

# Discourse implementation plan

## Scope

Deliver an explicitly beta, single-replica Discourse chart around the official
experimental ESR image. The chart provides a reproducible evaluation and
operational path without claiming upstream support or production readiness.

## Priority 1: runtime foundation

- Pin `discourse/discourse:2026.7.4` by immutable multi-architecture digest.
- Add singleton Deployment, `/shared` persistence, Recreate rollout, and the
  upstream root boot security exception.
- Configure hostname, developer email, SMTP skip mode, PostgreSQL, Redis,
  secret key base, and `/srv/status` probes.
- Add current HelmForge PostgreSQL and Redis subcharts.
- Add Service with independent public port and named target.
- Validate the actual application on local k3d before optional integrations.

## Priority 2: Kubernetes integrations

- Add external PostgreSQL and Redis contracts with existing Secret support.
- Add canonical External Secrets `items[]` rendering.
- Add Ingress, Gateway API HTTPRoute, Service dual-stack, NetworkPolicy, PDB
  guardrails, scheduling controls, and extra environment/volume extensions.
- Add fail-fast validation for replica count, hostname, dependencies, secrets,
  persistence, and unsupported security settings.

## Priority 3: operations and documentation

- Add chart tests for every resource, default/disabled paths, and validation.
- Add CI scenarios for external services, exposure, ESO, dual-stack, custom
  Service port, and persistence.
- Add product-specific README, DESIGN, NOTES, operations, security, backup,
  upgrade, and migration documentation.
- Add the official mark-only icon and the full site catalog/documentation page.

## Validation strategy

- Phase 1: install defaults on `k3d-helmforge-tests-wsl`, wait for Discourse,
  assert `/srv/status`, inspect every container log and event, and verify PVC.
- Complete chart: run `make validate-chart CHART=discourse`, then
  `make standards-check CHART=discourse` and Kubescape.
- Validate External Secrets against the fake ClusterSecretStore.
- Exercise an upgrade with reused values and persistent `/shared` data.
- Run site build, lint, formatting, link checks, site sync, and organization
  parity before requesting permission to push.

## Risks and mitigations

| Risk | Mitigation |
|---|---|
| Upstream runtime is experimental | Beta maturity and prominent unsupported-install warning |
| Numeric image tag is rebuilt | Pin the immutable OCI index digest |
| Root and writable filesystem required | Document exact exception and prevent privilege escalation |
| Concurrent boot migrations | Enforce one replica and Recreate rollouts |
| Upload loss | Persistent `/shared` enabled by default and backup guidance for both data domains |
| Plugins need a custom build | Explicit non-goal; no boot-time plugin installation |
| No native Prometheus endpoint | Do not render a misleading ServiceMonitor |

## Non-goals

- Multi-replica or autoscaled Discourse.
- Separate web and Sidekiq workloads.
- Runtime plugin compilation.
- A HelmForge-built application image.
- Claims of upstream-supported production operation.
