# Memos Operations

## Runtime Checks

Check the StatefulSet and Service:

```bash
kubectl get statefulset,svc,pvc -l app.kubernetes.io/name=memos
kubectl rollout status statefulset/memos
```

Inspect logs:

```bash
kubectl logs statefulset/memos
```

Open a local tunnel:

```bash
kubectl port-forward svc/memos 5230:5230
```

Memos should answer on `http://127.0.0.1:5230`. Verify the application health endpoint separately:

```bash
curl --fail http://127.0.0.1:5230/healthz
```

## Reverse Proxy

When exposing Memos through Ingress, Gateway API, or an external proxy, set:

```yaml
memos:
  instanceUrl: https://memos.example.com
```

The proxy must preserve `Host` and standard forwarded headers. If generated links or redirects point at the internal service name, verify `MEMOS_INSTANCE_URL` and proxy headers first.
In Memos 0.30, omitting `MEMOS_INSTANCE_URL` selects private mode and disables anonymous RSS access.

## Provisioned Configuration

When `provisioning.existingSecret` is set, Memos reads matching files from `/etc/secrets` once during startup. After updating the Secret, restart the
StatefulSet and watch both the rollout and startup logs:

```bash
kubectl rollout restart statefulset/memos
kubectl rollout status statefulset/memos
kubectl logs statefulset/memos --tail=100
```

An unreadable file, invalid JSON, unknown field, duplicate key, or unsafe authentication combination prevents startup. Memos does not partially apply a
file set.

## Upgrades

Before upgrading:

1. Back up the PVC.
2. Back up the external database if `database.driver` is `mysql` or `postgres`.
3. Confirm the target image tag in the chart release notes.
4. Review the 0.30 public-mode, shared API, saved-filter, and MCP compatibility notes.
5. Run the upgrade with `helm upgrade`.
6. Watch the StatefulSet rollout, `/healthz`, and logs.

```bash
helm upgrade memos helmforge/memos -f values.yaml
kubectl rollout status statefulset/memos
kubectl logs statefulset/memos --tail=100
```

## Common Failures

`Cannot write to the data directory`

Verify the PVC is bound and writable by UID/GID `10001`.

`Database connection errors`

Verify `database.driver`, the DSN format, DNS resolution to the database service, and any TLS options embedded in the DSN.

`Reverse proxy issues`

Verify `memos.instanceUrl` and proxy forwarding headers.

`Attachments missing after migration`

Check whether the old instance stored assets under `MEMOS_DATA`. Migrating only the external database is not enough when assets are stored on disk.
