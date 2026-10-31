<!-- SPDX-License-Identifier: Apache-2.0 -->
# Automatisch Operations

## Readiness and logs

Check both application components after installation or upgrade:

```bash
kubectl get deployment,pod -n automatisch \
  -l app.kubernetes.io/instance=automatisch
kubectl logs -n automatisch deployment/automatisch-automatisch
kubectl logs -n automatisch deployment/automatisch-automatisch-worker
```

The web pod has startup, readiness, and liveness probes on the named HTTP port.
The worker exposes no upstream health listener; monitor Deployment availability,
restart counts, error logs, Redis health, and end-to-end workflow execution.

## Backup and restore

Back up PostgreSQL, the application Secret, and any Secrets referenced by
`database.external.existingSecret` or `redis_config.external.existingSecret` as
one recovery unit. When those Secrets come from an external secret manager,
include its versioned recovery procedure. Redis queue state is operationally
useful but PostgreSQL remains the durable application record. The application
Secret contains encryption and verification keys; a database restored without
its matching keys may contain unusable credentials.

```bash
kubectl get secret -n automatisch automatisch-automatisch-app -o yaml | \
  age --encrypt --recipient "$AGE_RECIPIENT" \
  > automatisch-app-secret.yaml.age
```

Store Secret backups in an encrypted system and never commit them. Use the
backup tooling supported by the selected PostgreSQL deployment. Restore into an
isolated namespace and execute a real test workflow before declaring a backup
valid.

## Upgrade procedure

1. Review chart and upstream release notes.
2. Back up PostgreSQL and the application Secret.
3. Upgrade a staging installation first.
4. Confirm the web Deployment finishes migrations and becomes ready.
5. Confirm the worker stays available and executes a test workflow.
6. Monitor PostgreSQL, Redis, restarts, and logs before promoting the release.

Do not upgrade from chart 1.3.12 with `--reuse-values` alone. It can omit the
newer `networkPolicy` parent map and make template rendering fail at
`.Values.networkPolicy.enabled`. Use `--reset-then-reuse-values` and review the
rendered diff before applying the upgrade.

```bash
helm upgrade automatisch helmforge/automatisch \
  --namespace automatisch \
  --reset-then-reuse-values \
  --wait \
  --timeout 10m
```

Do not change cryptographic keys during an ordinary upgrade. If web startup
fails during migrations, capture logs and database state before attempting a
rollback because schema compatibility may constrain rollback behavior.

## Worker incidents

When the UI is healthy but jobs remain queued, verify that the worker
Deployment exists, its pod contains `WORKER=true`, and it can connect to Redis
and PostgreSQL:

```bash
kubectl describe deployment -n automatisch automatisch-automatisch-worker
kubectl logs -n automatisch deployment/automatisch-automatisch-worker --tail=200
kubectl get pods -n automatisch \
  -l app.kubernetes.io/instance=automatisch,app.kubernetes.io/component=worker
```

Scale workers only after resolving connection failures. More replicas do not
repair an unavailable datastore and can amplify retry traffic.

## Listener incidents

If a custom port is not reachable, inspect the rendered `PORT` variable,
container port, Service target, and NetworkPolicy. They must all derive from
the same named listener contract except for the independently configurable
Service port.

## Related guides

- [Configuration](configuration.md)
- [Security](security.md)
- [Chart design](../DESIGN.md)
