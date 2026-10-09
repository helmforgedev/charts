# NautilusTrader research

Issue: helmforgedev/charts#1420

## Findings

NautilusTrader is a trading framework rather than a preconfigured server. A
deployment must supply strategy and adapter code. The official OCI image is a
Python runtime with the NautilusTrader package installed; it does not include a
strategy, entrypoint, HTTP server, health endpoint, or Prometheus exporter.

The upstream publishes the OCI channels `latest` and `nightly`, but no tag that
corresponds to GitHub release `v1.231.0`. HelmForge therefore resolves `latest`
to an immutable multi-architecture digest and records the source revision and
date. Upgrades are explicit digest changes with complete chart validation.

Live trading is singleton by design. One process owns one event loop and trader
identity. Multiple releases are the supported scaling model; multiple replicas
of one release could duplicate orders. The chart therefore has no replica or
HPA surface and uses the Recreate deployment strategy.

## Existing deployment options

| Option | Strength | Gap addressed by this chart |
|---|---|---|
| Official OCI image | Signed multi-arch runtime | No process contract, probes, or Kubernetes resources |
| Official Jupyter image | Interactive research | Not appropriate for unattended live trading |
| Official Docker Compose | Local Redis/PostgreSQL development | Not production configuration and not Kubernetes |
| Community Helm charts | None identified | HelmForge provides the first product-specific chart |

## Production requirements

- User-owned strategy image or mounted Python package.
- Singleton live runtime with graceful SIGTERM handling.
- Readiness follows a callable user-node `is_running` state; when that method is absent, the runner assumes readiness
  after the factory starts `run()`.
- Optional Redis message bus and PostgreSQL cache backing.
- Separate persistent domains for Parquet catalogs, event store, and results.
- Jobs and non-overlapping CronJobs for backtests.
- Existing Secret and External Secrets support for venue credentials.
- Runner-level health and Prometheus metrics without claiming native engine
  metrics that upstream does not expose over HTTP.

## Differentiation

1. A chart-managed runner converts the framework into a Kubernetes lifecycle
   while leaving all trading logic under user control.
2. Fail-fast singleton enforcement prevents accidental active-active trading.
3. Live and backtest execution are separate workload contracts.
4. Optional HelmForge Redis/PostgreSQL dependencies and external endpoints use
   the same documented secret model.
5. Runtime smoke tests verify the real NautilusTrader import, runner endpoints,
   config mount, and batch completion.

## Sources

- <https://github.com/nautechsystems/nautilus_trader>
- <https://nautilustrader.io/docs/latest/how_to/configure_live_trading>
- <https://nautilustrader.io/docs/latest/concepts/architecture>
- <https://nautilustrader.io/docs/latest/concepts/cache>
- <https://nautilustrader.io/docs/latest/concepts/backtesting>
- <https://nautilustrader.io/security/supply-chain>
