# Backtesting

Enable `backtest.enabled` for a one-shot Job and set `backtest.factory` to a callable accepting `backtest.config`.
The returned object may implement `run()` and `dispose()`. With no factory, the safe validation Job only imports the
runtime and exits successfully.

Enable `scheduledBacktest.enabled` for recurring Jobs. The default `Forbid` concurrency policy prevents overlapping
runs. Enable `persistence.results`, use an existing claim, or export artifacts before completed Jobs are collected.
