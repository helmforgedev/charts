# NetBird operations

## Readiness and rollout

The server and dashboard are separate Deployments. Wait for both and inspect restarts before accepting a rollout:

```bash
kubectl rollout status deploy/netbird-server -n netbird
kubectl rollout status deploy/netbird-dashboard -n netbird
kubectl get pods -n netbird
```

Server probes are disabled by default because first boot can spend several minutes preparing GeoLite data. Enable
`server.probes.enabled=true` after measuring startup in the target environment. The health listener evaluates more than
local process liveness, so validate public relay reachability separately.

## Metrics and logs

Prometheus metrics are served on `server.containerPorts.metrics` and published through `server.service.metricsPort`.
The chart does not create a ServiceMonitor. Configure the platform scraper against the server Service and collect both
containers' stdout and stderr:

```bash
kubectl port-forward svc/netbird-server 9090:9090 -n netbird
curl --fail http://127.0.0.1:9090/metrics
kubectl logs deploy/netbird-server -n netbird
kubectl logs deploy/netbird-dashboard -n netbird
```

Alert on unavailable replicas, restart increases, PVC saturation, database connection failures, authentication errors,
and failed public relay or STUN checks.

## Backup and restore

Treat the database, data PVC, and chart-managed config Secret as one consistency boundary. The Secret contains the
stable encryption key required to decrypt stored values. Quiesce write activity, take a database-native backup, snapshot
or copy `/var/lib/netbird`, and export the Secret metadata and data to an encrypted backup system.

For restore, recreate credentials and the config Secret first, restore the database and volume from the same recovery
point, then deploy the chart with the original public URL. Test API authentication, embedded or external OIDC, dashboard
login, peer synchronization, routes, relay, and STUN before reopening access.

## Upgrades and rollback

Read upstream release notes for database migrations and security changes. Back up every state component, stage the new
image with representative peers, and upgrade with explicit values:

```bash
helm upgrade netbird helmforge/netbird \
  --namespace netbird \
  --reset-then-reuse-values \
  --set server.image.tag=0.81.5
```

`--reset-then-reuse-values` also reapplies a previously explicit image tag, so set the intended tag as shown or remove
the stale override and reapply required values from a reviewed file. `--reuse-values` alone has the same risk. A rollback
must use state compatible with the older NetBird version; restore the pre-upgrade database and PVC snapshot if upstream
migrations are not backward compatible.

## Disruption budgets and node drains

The chart renders one PDB per enabled application workload. With singleton Deployments,
`pdb.minAvailable: 1` prevents voluntary eviction, so a node drain waits until the value changes or the PDB is removed.
For a planned maintenance window, scale a database-backed server topology appropriately or temporarily disable the PDB.

## Non-default listeners

Use `server.containerPorts` and `dashboard.containerPorts.http` to change actual process listeners. HTTP, metrics, health,
and dashboard Service ports remain independent and continue targeting named pod ports. The STUN Service port must match
`server.containerPorts.stun` because NetBird advertises the configured listener port to peers. After any override,
validate inside the pod and through the Service; do not infer success from rendered Deployment metadata alone.

## Incident triage

```bash
kubectl describe pod -l app.kubernetes.io/instance=netbird -n netbird
kubectl get events -n netbird --sort-by=.lastTimestamp
kubectl get endpointslice -n netbird
helm get values netbird -n netbird
```

Authentication failures usually point to issuer, callback, audience, or encryption-key drift. Peer failures should be
split into API/gRPC, relay WebSocket, and UDP STUN paths because each can fail independently.
