# Live runtime

Create a Python callable that accepts the decoded `live.nodeConfig` dictionary and returns an object with `run()`.
For graceful shutdown, implement `stop()` and `dispose()`. Implement `is_ready()` to report connected and reconciled
clients and `is_healthy()` to report event-loop or queue health; the runner falls back to `is_running()` for readiness.
Package the module in a derived image or mount it using `extraVolumes` and `extraVolumeMounts`, then set
`live.mode=live` and `live.factory=my_strategy:create_node`.

Use a separate release and namespace for each independent trading node. Test venue connectivity, reconciliation, and
shutdown in a sandbox before enabling live trading. A Ready pod proves only that the factory reports a running node.
