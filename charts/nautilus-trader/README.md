<!-- SPDX-License-Identifier: Apache-2.0 -->

# NautilusTrader Helm chart

Deploy the official [NautilusTrader](https://nautilustrader.io) Python runtime for singleton live nodes, one-shot
backtests, or scheduled research workloads.

## Features

- Immutable official upstream image digest and explicit strategy-image override
- Non-trading validation mode by default and singleton live-node lifecycle
- One-shot Job and non-overlapping scheduled backtest CronJob
- Optional catalog, event-store, and results PVCs
- Bundled or external PostgreSQL and Redis contracts
- External Secrets, NetworkPolicy, ServiceMonitor, and PrometheusRule support
- Restricted pod security, bounded temporary storage, and disabled API token mount
- Optional PodDisruptionBudget for the live singleton

## Architecture

The chart-managed Python runner loads the official package and exposes internal
health and metrics endpoints. In live mode it loads an operator-owned factory;
in batch modes it runs that factory in a Job or CronJob. Persistent catalog,
event-store, and result paths are independent PVCs. PostgreSQL and Redis are
optional integration coordinates, not automatically enabled application
adapters. Run each live trading node in a separate Helm release.

## Install

```console
helm upgrade --install nautilus-trader oci://ghcr.io/helmforgedev/helm/nautilus-trader \
  --namespace nautilus-trader --create-namespace
```

The safe default starts a hardened pod in `validate` mode. It imports the pinned NautilusTrader runtime and exposes
runner health, but cannot connect to a venue or trade. To run a strategy, package its Python code in a derived image or
mount it, then configure `live.mode=live` and a `live.factory` in `module:callable` form.

## Immutable upstream image

Upstream publishes only floating `latest` and `nightly` OCI channels, not release-numbered image tags. HelmForge pins
the multi-architecture digest resolved from official `latest` on 2026-10-09 (upstream revision `7b766f`). Upgrades are
therefore explicit and reproducible. The standard `image.repository`, `image.tag`, and `image.digest` values remain
available for a reviewed replacement; clear `image.digest` when selecting a tag.

## Runtime integrations

The optional HelmForge PostgreSQL and Redis dependencies are suitable for evaluation. External services are preferred
for production. The chart exposes connection metadata to user strategy code; it does not claim that every pinned
NautilusTrader build enables every database or message-bus adapter automatically.

Use `secrets.existingSecret` or `externalSecrets.items` for venue credentials. Never commit credentials to values.

## Configuration

| Parameter | Default | Purpose |
| --- | --- | --- |
| `image.digest` | pinned SHA-256 | Immutable official upstream image |
| `live.enabled` | `true` | Deploy the singleton runtime |
| `live.mode` | `validate` | Non-trading validation or live factory mode |
| `live.factory` | `""` | Python `module:callable` factory |
| `runner.port` | `8080` | Health and metrics listener |
| `backtest.enabled` | `false` | Render a one-shot backtest Job |
| `scheduledBacktest.enabled` | `false` | Render a scheduled backtest CronJob |
| `scheduledBacktest.schedule` | `0 2 * * *` | Backtest cron schedule |
| `database.mode` | `none` | None, bundled PostgreSQL, or external PostgreSQL |
| `messageBus.mode` | `none` | None, bundled Redis, or external Redis |
| `postgresql.enabled` | `false` | Deploy HelmForge PostgreSQL 2.1.1 |
| `redis.enabled` | `false` | Deploy HelmForge Redis 3.1.0 |
| `persistence.catalog.enabled` | `false` | Persist market-data catalogs |
| `persistence.eventStore.enabled` | `false` | Persist event-store data |
| `persistence.results.enabled` | `false` | Persist backtest results |
| `secrets.existingSecret` | `""` | Secret projected into strategy workloads |
| `externalSecrets.enabled` | `false` | Render ExternalSecret resources |
| `monitoring.serviceMonitor.enabled` | `false` | Render a ServiceMonitor |
| `monitoring.prometheusRule.enabled` | `false` | Render runner availability alerts |
| `networkPolicy.enabled` | `false` | Isolate ingress to the runner Service |
| `networkPolicy.egressEnabled` | `false` | Enable explicit egress isolation |
| `podDisruptionBudget.enabled` | `false` | Protect the singleton from voluntary disruption |
| `runtimeStorage.tmpSizeLimit` | `256Mi` | Writable `/tmp` limit for all workloads |
| `serviceAccount.automountServiceAccountToken` | `false` | Mount the Kubernetes API token |

See `values.yaml` and `values.schema.json` for the complete contract.

## Examples

The [`examples/`](examples/) directory contains focused values files for safe
validation, live strategies, one-shot and scheduled backtests, external state
services, and restricted egress. Start from the smallest profile that matches
the workload and keep credentials in an existing Secret or ExternalSecret.

Render an example before applying it:

```console
helm template nautilus-trader oci://ghcr.io/helmforgedev/charts/nautilus-trader \
  --namespace nautilus-trader \
  --values examples/safe-validation.yaml
```

For a live node with explicit network isolation, combine the strategy and
restricted-egress examples after replacing the placeholder factory and CIDRs:

```console
helm upgrade --install nautilus-trader oci://ghcr.io/helmforgedev/charts/nautilus-trader \
  --namespace nautilus-trader --create-namespace \
  --values examples/live-strategy.yaml \
  --values examples/restricted-egress.yaml
```

## Backtesting

Set `backtest.enabled=true` for a Job. Set `scheduledBacktest.enabled=true` for a CronJob. Configure a factory and
persistent results storage before production use. See [backtesting](docs/backtesting.md).

## Observability

The chart runner supplies `/healthz`, `/readyz`, and `/metrics`. These report process and factory lifecycle state, not
exchange connectivity, portfolio correctness, or order execution. Optional ServiceMonitor and PrometheusRule resources
integrate the runner with Prometheus Operator.

## Security

All chart-managed workloads run as UID/GID 10001 with runtime-default seccomp,
no privilege escalation, all capabilities dropped, a read-only root filesystem,
and no Kubernetes API token. Writable `/tmp` is a bounded `emptyDir`. Secrets
enter through Secret references or External Secrets; they are not accepted as
plain chart values. NetworkPolicy remains opt-in because venue, market-data,
database, message-bus, and telemetry destinations are installation-specific.

## Troubleshooting

- A pod that never becomes Ready: inspect the runner logs, factory import path,
  mounted strategy code, and `runner.readinessTimeoutSeconds`.
- PostgreSQL or Redis connection failures: confirm the selected mode, Service or
  external host, Secret key names, TLS requirement, and adapter availability in
  the pinned image.
- A backtest without output: configure persistent results storage and inspect the
  completed Job logs before its TTL expires.
- Missing metrics resources: install the Prometheus Operator CRDs before enabling
  ServiceMonitor or PrometheusRule.
- NetworkPolicy timeouts: explicitly allow DNS plus every venue, data provider,
  external state service, and telemetry endpoint required by the strategy.

## Documentation

- [Live runtime](docs/live-runtime.md)
- [Backtesting](docs/backtesting.md)
- [Dependencies and secrets](docs/dependencies-secrets.md)
- [Observability](docs/observability.md)
- [Design](DESIGN.md)

## Uninstall

```console
helm uninstall nautilus-trader --namespace nautilus-trader
```

Back up catalogs, event stores, and results before deleting retained or dynamically provisioned storage.

## Security Scan

Security scan results use the same Kubescape policy set as HelmForge CI.

Security Scan: nautilus-trader

| Framework                | Score |
| ------------------------ | ----: |
| MITRE                    | **100.00%** |
| NSA                      |  **95.00%** |
| SOC 2                    |  **90.00%** |
| Aggregate resource score |  **95.45%** |

Kubescape reported no critical or high-severity failures. The two medium findings concern unrestricted ingress and
egress because NetworkPolicy remains opt-in for venue- and service-specific connectivity.
