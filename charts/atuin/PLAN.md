# Atuin chart implementation plan

## P0: runnable baseline

- Add chart metadata, pinned official image and default SQLite persistence.
- Add hardened Deployment, Service, Secret and PVC.
- Add startup, readiness and liveness probes against the real `/healthz` endpoint.
- Add schema, template validation, unit tests and a database-backed runtime smoke test.
- Validate the minimal chart on k3d before broadening the surface.

## P1: production database and secret delivery

- Add the HelmForge PostgreSQL dependency.
- Construct the bundled PostgreSQL URI in an init container without placing credentials in values or rendered
  ConfigMaps.
- Support external complete database URI Secrets.
- Add canonical External Secrets Operator `items[]` passthrough.
- Enforce SQLite singleton and PostgreSQL scaling invariants.

## P2: exposure, security and availability

- Add canonical Ingress and Gateway API HTTPRoute support.
- Add NetworkPolicy, PodDisruptionBudget, topology spread, affinity and autoscaling contracts.
- Add separate metrics Service and optional ServiceMonitor.
- Keep public exposure TLS-first in documentation and examples.

## P3: delivery and documentation

- Add README, design notes, operations/security/exposure documentation and production examples.
- Add the official Atuin turtle mark to the site catalog and publish complete chart documentation.
- Run `make validate-chart CHART=atuin`, ESO validation, site sync, repository preflight, PR checks and review-thread
  checks.
- Open linked charts and site pull requests and respond to issue 1382 after both deliveries are ready.

## Explicit exclusions

- No S3 application configuration: Atuin Server does not support it.
- No separate migration Job: migrations are embedded in server startup.
- No raw SQLite file-copy CronJob: consistent backup needs operational coordination and is documented instead.
- No promise of zero-downtime mixed-version upgrades: upstream does not publish that guarantee.
