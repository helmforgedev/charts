# Bulwark Mail implementation plan

## Priority 1: functional deployment

- Pin the official deterministic 1.11.2 image.
- Deploy one hardened pod with Recreate strategy.
- Persist `/app/data` and expose port 3000.
- Implement health probes and wizard mode.
- Validate on k3d before treating production features as complete.

## Priority 2: production contract

- Add declarative external JMAP configuration.
- Support generated and existing Secrets.
- Add OAuth, admin bootstrap, and guarded JWT impersonation.
- Add Ingress, Gateway API, NetworkPolicy, dual-stack, and retained storage.
- Add canonical External Secrets integration.

## Priority 3: operational depth

- Document backup, restore, upgrade, CORS, and secret rotation.
- Cover every major feature with template tests.
- Verify the health, config, and setup contracts against the real image.
- Run schema, lint, unittest, kubeconform, Artifact Hub, security, and k3d gates.

## Acceptance criteria

- More than 40 product-specific assertions/examples pass.
- Default wizard installation survives pod replacement.
- Declarative rendering exposes the selected JMAP URL and hides setup.
- No Stalwart chart dependency exists.
- Full `make validate-chart CHART=bulwark-mail` passes.
