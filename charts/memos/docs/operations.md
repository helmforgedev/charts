<!-- SPDX-License-Identifier: Apache-2.0 -->

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

Set `memos.instanceUrl` to the canonical external HTTP(S) URL when links and callbacks must use the public hostname:

```yaml
memos:
  instanceUrl: https://memos.example.com
```

The proxy must preserve `Host` and standard forwarded headers. On the first Memos 0.31 startup, if no `ACCESS` setting
exists, Memos initializes it to `PUBLIC` when `memos.instanceUrl` is nonempty and to `PRIVATE` otherwise. The initialized
setting is persisted, so later changes to the canonical URL do not change anonymous access. A deployment that requires
private access with a canonical instance URL must provision `memos-instance-setting-access.json` with
`INSTANCE_ACCESS_MODE_PRIVATE` before first startup. RSS was removed upstream in 0.31.

## Provisioned Configuration

When `provisioning.existingSecret` is set, it replaces the chart-generated provisioning Secret rather than merging
the two Secret sources. Memos reads matching files from `/etc/secrets` once during startup and applies precedence by
setting group. A group without a file remains database-managed; a supplied file replaces that complete group. To
guarantee the chart's closed-registration policy while also owning private access, include both a complete
`memos-instance-setting-general.json` with `disallowUserRegistration: true` and
`memos-instance-setting-access.json` with `INSTANCE_ACCESS_MODE_PRIVATE`. Preserve the intended
`disallowPasswordAuth` value and all other `GENERAL` fields, or omit the `GENERAL` file to retain the database
policy.

For non-security settings on a single replica, update the Secret and restart the StatefulSet. For an `ACCESS` or
`GENERAL` policy change, first drain external traffic. When `replicaCount` is greater than one, a rolling restart can
leave old and new replicas enforcing different policies. Scale the workload to zero before updating the Secret, then
restore the previous replica count and traffic:

```bash
REPLICAS=3 # Set this to the current replica count.
kubectl scale statefulset/memos --replicas=0
kubectl wait --for=delete pod -l app.kubernetes.io/name=memos --timeout=120s
kubectl apply -f memos-provisioning-secret.yaml
kubectl scale statefulset/memos --replicas="$REPLICAS"
kubectl rollout status statefulset/memos
kubectl logs statefulset/memos --tail=100
```

Do not restore traffic until every replica is Ready and startup logs confirm that the new files loaded successfully.

An unreadable file, invalid JSON, unknown field, duplicate key, or unsafe authentication combination prevents startup.
Memos does not partially apply a file set.

## Upgrades

Before upgrading:

1. Back up the PVC.
2. Back up the external database if `database.driver` is `mysql` or `postgres`.
3. Confirm the target image tag in the chart release notes.
4. Review the 0.30 API/filter changes and the 0.31 access-policy, Shortcut-to-View, and RSS compatibility notes.
5. Run the upgrade with `helm upgrade`.
6. Watch the StatefulSet rollout, `/healthz`, and logs.

```bash
helm upgrade memos helmforge/memos -f values.yaml
kubectl rollout status statefulset/memos
kubectl exec statefulset/memos -- wget -qO- http://127.0.0.1:5230/healthz
kubectl logs statefulset/memos --tail=100
```

## Common Failures

`Cannot write to the data directory`

Verify the PVC is bound and writable by UID/GID `10001`.

`Database connection errors`

Verify `database.driver`, the DSN format, DNS resolution to the database service, and any TLS options embedded in the
DSN.

`Reverse proxy issues`

Verify `memos.instanceUrl`, proxy forwarding headers, and the independent Memos `ACCESS` policy.

`Attachments missing after migration`

Check whether the old instance stored assets under `MEMOS_DATA`. Migrating only the external database is not enough when
assets are stored on disk.
