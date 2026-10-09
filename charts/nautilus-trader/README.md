# NautilusTrader Helm chart

Deploy the official [NautilusTrader](https://nautilustrader.io) Python runtime for singleton live nodes, one-shot
backtests, or scheduled research workloads.

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

## Backtesting

Set `backtest.enabled=true` for a Job. Set `scheduledBacktest.enabled=true` for a CronJob. Configure a factory and
persistent results storage before production use. See [backtesting](docs/backtesting.md).

## Observability

The chart runner supplies `/healthz`, `/readyz`, and `/metrics`. These report process and factory lifecycle state, not
exchange connectivity, portfolio correctness, or order execution. Optional ServiceMonitor and PrometheusRule resources
integrate the runner with Prometheus Operator.

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
