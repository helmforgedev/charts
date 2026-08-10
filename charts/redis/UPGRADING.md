# Upgrading Redis Chart

## 2.0.0 — Sentinel role-neutral data nodes (#953)

### What changed

In `architecture: sentinel`, the chart no longer renders separate `-primary` and `-replica` StatefulSets. It now renders:

- `<release>-redis-node` — role-neutral Redis data nodes (`node.replicaCount`)
- `<release>-redis-sentinel` — independently scaled Sentinel pods (`sentinel.replicaCount`)

The `-primary` and `-replicas` Services are no longer created in sentinel mode. Clients must discover the current master through the `-sentinel` Service.

Additionally:

- `node.persistence.enabled` defaults to `true` for sentinel data nodes.
- Data nodes probe peer `INFO replication` when Sentinel is unreachable, preventing split-brain on pod reschedule without PVCs.
- Sentinel config includes `announce-hostnames yes` for stable hostname-based master discovery.

### Operational impact

- Fresh installs create a PVC for every Sentinel data node by default.
- With persistence enabled, nodes already bootstrapped fail closed when neither Sentinel nor peers can confirm the role until quorum or peer discovery recovers.
- Enable persistence when RDB/AOF must survive pod reschedules; peer discovery covers topology safety.

### Why this is a breaking change

Kubernetes StatefulSet names and PVC claim names are immutable. An in-place `helm upgrade` from 1.x cannot rename `-primary`/`-replica` workloads to `-node`.

### Migration procedure

1. **Backup data** from all Redis pods (RDB/AOF snapshot or application-level export).
2. **Scale down** the release or accept a maintenance window.
3. **Uninstall** the 1.x release. PVCs remain unless you delete them manually.
4. **Delete** old PVCs if you want a clean topology (`*-primary-*`, `*-replica-*`).
5. **Install** chart 2.0.0 with equivalent sizing:

   ```yaml
   architecture: sentinel
   node:
     replicaCount: 3  # was 1 primary + 2 replicas
     persistence:
       enabled: true
       # Map storageClass, size, accessModes, and related settings from 1.x.
   sentinel:
     replicaCount: 3
     quorum: 2
   ```

   Map `storageClass`, `size`, `accessModes`, and any other persistence settings
   from the former primary and replica values before restoring data.

6. **Restore data** into the new cluster if required, or let replicas resync from the seed master on a fresh install.

### Client changes

- Remove dependencies on the `-primary` Service in sentinel mode.
- Use Sentinel-aware clients pointing at `<release>-redis-sentinel:26379`.
- Update monitoring and runbooks that referenced `-primary-0` as the stable master hostname.

### Validation after upgrade

```bash
kubectl get sts
# <release>-redis-node
# <release>-redis-sentinel

kubectl exec sts/<release>-redis-sentinel-0 -- \
  redis-cli -p 26379 sentinel get-master-addr-by-name mymaster
```

After a forced failover, confirm the elected master pod name is `-node-N`, not `-primary-0`.

See [docs/sentinel.md](docs/sentinel.md) for resilience trade-offs and k3d validation steps.
