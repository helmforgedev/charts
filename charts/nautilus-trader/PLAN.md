# NautilusTrader implementation plan

## Scope

Deliver a production-oriented singleton live runtime plus isolated backtest Job
and CronJob paths. The chart does not ship a trading strategy, exchange adapter
configuration, credentials, or claims of high availability.

## Priority 1: safe runtime foundation

- Pin the official image by immutable multi-architecture digest.
- Add a chart-managed Python runner with SIGTERM, stop, and dispose handling.
- Expose runner health, readiness, and minimal Prometheus metrics.
- Mount non-sensitive JSON configuration and user strategy code.
- Validate live factory configuration and selector-label safety.
- Validate the MVP on local k3d before optional integrations.

## Priority 2: production integrations

- Add External Secrets using the canonical `items[]` contract.
- Add optional HelmForge Redis and PostgreSQL dependencies.
- Support external Redis/PostgreSQL endpoints with Secret references.
- Add separate catalog, event-store, and result PVC contracts.
- Add NetworkPolicy and hardened non-root pod defaults.

## Priority 3: research workloads and operations

- Add one-shot backtest Job and scheduled CronJob.
- Enforce `concurrencyPolicy: Forbid` by default.
- Add ServiceMonitor, PrometheusRule, examples, and operational documentation.
- Add product-level runtime smoke coverage and site documentation.

## Validation strategy

- Unit tests cover workload, validation, secrets, storage, integrations,
  monitoring, networking, Job, and CronJob templates.
- Every `ci/*.yaml` file renders and installs through the canonical gate.
- The k3d smoke script checks the real package import, `/healthz`, `/readyz`,
  `/metrics`, mounted config, and backtest Job completion.
- External Secrets is validated against the fake ClusterSecretStore.
- Kubescape, template standards, dependency policy, site sync, org sync, and
  repository preflight must pass before PR creation.

## Risks and mitigations

| Risk | Mitigation |
|---|---|
| Upstream has no versioned OCI tag | Pin digest and document revision/date |
| Strategy APIs change | Keep strategy factory user-owned and explicit |
| Duplicate live traders | Fixed singleton plus Recreate rollout |
| False readiness | Readiness follows runner/node state, not market activity |
| Lost state on force kill | Ninety-second grace period and coordinated dispose |
| Misleading metrics | Clearly label metrics as runner-level only |
