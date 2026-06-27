# Upgrading Valkey Chart

## 2.0.0 — Sentinel role-neutral data nodes (#542)

### What changed

In `architecture: sentinel`, the chart no longer renders separate `-primary` and `-replica` StatefulSets. It now renders:

- `<release>-valkey-node` — role-neutral Valkey data nodes (`node.replicaCount`)
- `<release>-valkey-sentinel` — independently scaled Sentinel pods (`sentinel.replicaCount`)

The `-primary` and `-replicas` Services are no longer created in sentinel mode. Clients must discover the current master through the `-sentinel` Service.

### Why this is a breaking change

Kubernetes StatefulSet names and PVC claim names are immutable. An in-place `helm upgrade` from 1.x cannot rename `-primary`/`-replica` workloads to `-node`.

### Migration procedure

1. **Backup data** from all Valkey pods (RDB/AOF snapshot or application-level export).
2. **Scale down** the release or accept a maintenance window.
3. **Uninstall** the 1.x release. PVCs remain unless you delete them manually.
4. **Delete** old PVCs if you want a clean topology (`*-primary-*`, `*-replica-*`).
5. **Install** chart 2.0.0 with equivalent sizing:

   ```yaml
   architecture: sentinel
   node:
     replicaCount: 3  # was 1 primary + 2 replicas
   sentinel:
     replicaCount: 3
     quorum: 2
   ```

6. **Restore data** into the new cluster if required, or let replicas resync from the seed master on a fresh install.

### Client changes

- Remove dependencies on the `-primary` Service in sentinel mode.
- Use Sentinel-aware clients pointing at `<release>-valkey-sentinel:26379`.
- Update monitoring and runbooks that referenced `-primary-0` as the stable master hostname.

### Validation after upgrade

```bash
kubectl get sts
# <release>-valkey-node
# <release>-valkey-sentinel

kubectl exec sts/<release>-valkey-sentinel-0 -- \
  valkey-cli -p 26379 sentinel get-master-addr-by-name mymaster
```

After a forced failover, confirm the elected master pod name is `-node-N`, not `-primary-0`.

## 2.0.x — Sentinel hardening (peer discovery, persistence default)

### What changed

- `node.persistence.enabled` now defaults to `false` for sentinel data nodes.
- Data nodes probe peer `INFO replication` when Sentinel is unreachable, preventing split-brain
  on pod reschedule without PVCs.
- Sentinel config includes `announce-hostnames yes` for stable hostname-based master discovery.

### Operational impact

- Fresh installs no longer create node PVCs unless you set `node.persistence.enabled=true`.
- With persistence enabled, nodes already bootstrapped fail closed when neither Sentinel nor peers
  can confirm the role until quorum or peer discovery recovers.
- Enable persistence when RDB/AOF must survive pod reschedules; peer discovery covers topology safety.

See [docs/sentinel.md](docs/sentinel.md) for resilience trade-offs and k3d validation steps.
