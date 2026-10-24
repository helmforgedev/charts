<!-- SPDX-License-Identifier: Apache-2.0 -->
# Middleware operations and recovery

## Health verification

```bash
kubectl wait --for=condition=available deployment/middleware-middleware \
  --namespace middleware --timeout=300s
kubectl get endpoints middleware-middleware --namespace middleware
kubectl logs deployment/middleware-middleware --namespace middleware \
  --container migrate-database
```

The pod becomes Ready only when ports 3333, 9696, 9697, and embedded Redis on
6385, or the configured application-port replacements, accept connections.

## Backup set

Treat these items as one logical backup set:

1. PostgreSQL database and roles.
2. The PVC mounted at `/app/backend/analytics_server/mhq/config`.
3. Referenced database credential Secrets, or the external secret manager
   configuration that recreates them.
4. The Helm values and application image tag.

The key PVC contains `config.ini`, including the RSA key pair used for provider
credentials. Encrypt backups and restrict access as you would for database
credentials.

## PVC backup example

Use the cluster's CSI snapshot or backup controller when available. To inspect
the active claim before creating a snapshot:

```bash
kubectl get pvc middleware-middleware-data --namespace middleware
kubectl exec deployment/middleware-middleware --namespace middleware \
  --container middleware -- \
  test -s /app/backend/analytics_server/mhq/config/config.ini
```

Do not copy the key file into an unencrypted local archive.

## Restore order

1. Restore PostgreSQL and its roles.
2. Restore or provision the key PVC.
3. Restore the database credential Secret.
4. Install or upgrade the chart with `persistence.existingClaim` when the
   restored claim has a different name.
5. Verify migration init-container completion.
6. Confirm the frontend, analytics, and sync listeners become Ready.
7. Test one stored provider integration to verify decryption.

## Rollout and upgrade

The Deployment uses `Recreate`; expect a brief outage. Preserve PostgreSQL
password Secrets when a database PVC already exists. A newly generated password
does not update the password stored inside an existing database.

```bash
helm upgrade middleware helmforge/middleware \
  --namespace middleware \
  --reuse-values
kubectl rollout status deployment/middleware-middleware \
  --namespace middleware --timeout=300s
```

Review new defaults instead of using `--reuse-values` indefinitely.

## Diagnostics

```bash
kubectl describe pod --namespace middleware \
  -l app.kubernetes.io/instance=middleware
kubectl logs deployment/middleware-middleware --namespace middleware \
  --container migrate-database
kubectl logs deployment/middleware-middleware --namespace middleware \
  --container middleware --tail=200
kubectl get events --namespace middleware --sort-by=.lastTimestamp
```

Migration failures usually indicate an incorrect Service name, password key,
database role ownership or `CREATE` privilege, SSL mode, or network route.
Readiness failures after successful migrations indicate that one of the three
supervised processes did not start.
