# Liwan Operations

## Install

```bash
helm repo add helmforge https://repo.helmforge.dev
helm repo update
helm install liwan helmforge/liwan -f values.yaml
```

## Runtime Checks

Check the rollout:

```bash
kubectl rollout status deployment/liwan-liwan
kubectl get deployment,svc,pvc -l app.kubernetes.io/name=liwan,app.kubernetes.io/instance=liwan
```

Inspect logs:

```bash
kubectl logs -l app.kubernetes.io/name=liwan,app.kubernetes.io/instance=liwan --tail=100
```

Open a local tunnel:

```bash
kubectl port-forward svc/liwan-liwan 9042:80
```

Then open `http://127.0.0.1:9042`.

## Public URL

Set `liwan.baseUrl` before using tracking snippets:

```yaml
liwan:
  baseUrl: https://analytics.example.com
```

If the UI loads but tracking scripts fail, verify that the public URL, Ingress host, TLS host, and browser URL all match.

## Backups

Back up the PVC mounted at `/data`.

Recommended order:

1. Stop writes by scaling the Deployment to zero or pausing traffic.
2. Snapshot the PVC with the cluster storage provider.
3. Restore traffic after the snapshot completes.
4. Test restore into a separate namespace before relying on the backup.

For small installations, a storage-level snapshot is simpler and safer than copying files from a live DuckDB process.

## Upgrades

Before upgrading:

1. Back up the PVC.
2. Review upstream Liwan release notes for storage changes.
3. Run `helm upgrade`.
4. Watch the Deployment rollout.
5. Check logs for startup or DuckDB migration messages.

```bash
helm upgrade liwan helmforge/liwan -f values.yaml
kubectl rollout status deployment/liwan-liwan
kubectl logs -l app.kubernetes.io/name=liwan,app.kubernetes.io/instance=liwan --tail=100
```

## Common Failures

`The pod is pending`

Check whether the PVC is bound and whether the requested StorageClass exists.

`The UI works but tracking scripts use the wrong URL`

Set `liwan.baseUrl` to the public URL and align it with the routing hostname.

`Data disappeared after restart`

Verify `persistence.enabled=true` and that the Deployment is mounting the expected PVC. `emptyDir` mode is ephemeral.

`Ingress returns 404`

Verify the host, path, Ingress class, and controller logs. The Service backend should be `<release>-liwan` on port `80`.
