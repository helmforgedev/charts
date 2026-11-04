<!-- SPDX-License-Identifier: Apache-2.0 -->

# Operations

## First boot

The node must pull and unpack an unusually large image. Discourse then migrates
the database, seeds defaults, and precompiles assets. Allow at least 20 minutes
for a cold node and inspect progress rather than restarting the pod.

```bash
kubectl get pods -n NAMESPACE -w
kubectl logs deployment/RELEASE-discourse -n NAMESPACE -c discourse -f
kubectl logs deployment/RELEASE-discourse -n NAMESPACE -c wait-for-services
```

Transient `/srv/status` 502 responses are expected before Unicorn starts. A
repeated migration error is not expected; verify PostgreSQL ownership and the
`pg_trgm`, `unaccent`, and `vector` extensions.

## Upgrades

Back up PostgreSQL and `/shared`, retain one replica and `Recreate`, then run:

```bash
helm upgrade RELEASE helmforge/discourse -n NAMESPACE --reuse-values --wait --timeout 20m
```

Do not run two releases against one database during an upgrade. Test new image
and dependency versions in an isolated namespace first. Rollback may be unsafe
after an irreversible database migration; restore the coordinated backup when
the upstream release does not support downgrade.

## Health and troubleshooting

```bash
kubectl get events -n NAMESPACE --sort-by=.lastTimestamp
kubectl describe deployment RELEASE-discourse -n NAMESPACE
kubectl get endpoints RELEASE-discourse -n NAMESPACE
kubectl exec deployment/RELEASE-discourse -n NAMESPACE -- \
  curl -fsS -H 'Host: HOSTNAME' http://127.0.0.1/srv/status
```

Check resource pressure when asset compilation stalls. The defaults request 1 GiB
and permit 3 GiB; busy forums need measured CPU, memory, and storage sizing.
