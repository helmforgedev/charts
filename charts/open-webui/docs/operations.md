<!-- SPDX-License-Identifier: Apache-2.0 -->
# Open WebUI operations

## Installation verification

```bash
kubectl get deployment,pod,service,pvc,networkpolicy \
  --namespace open-webui \
  --selector app.kubernetes.io/instance=open-webui
kubectl get endpointslice \
  --namespace open-webui \
  --selector kubernetes.io/service-name=open-webui-open-webui
```

The Service endpoints must contain only the web pod. Backup Job pods use the
`backup` component label and are intentionally excluded.

## First startup

Open WebUI may download an embedding model during its first start. Observe the
startup probe and logs before increasing the probe budget:

```bash
kubectl describe pod --namespace open-webui \
  --selector app.kubernetes.io/name=open-webui
kubectl logs --namespace open-webui \
  deployment/open-webui-open-webui --follow
```

Repeated model downloads usually indicate that persistence is disabled, the
PVC is not mounted, or the application cannot write `/app/backend/data`.

## Health and connectivity

Startup and liveness call `/health`. Readiness calls `/health/db` and removes a
pod from endpoints when the database is unavailable. Diagnose a readiness
failure from inside the cluster:

```bash
kubectl port-forward --namespace open-webui \
  service/open-webui-open-webui 8080:80
curl --fail http://127.0.0.1:8080/health
curl --fail http://127.0.0.1:8080/health/db
```

For bundled PostgreSQL or Redis failures, inspect dependency pods, Services,
Endpoints, and Secrets in the same namespace. Do not print Secret values into
shared terminals or CI logs.

## Backup verification

List scheduled jobs and create a one-time Job from the CronJob:

```bash
kubectl get cronjob --namespace open-webui
kubectl create job --namespace open-webui \
  --from=cronjob/open-webui-open-webui-backup \
  open-webui-backup-manual
kubectl logs --namespace open-webui \
  job/open-webui-backup-manual --all-containers
```

Confirm the resulting object exists and has a plausible size. A successful Job
does not prove recoverability; schedule restore drills into an isolated database.

## Restore outline

1. Stop Open WebUI so no process writes during restore.
2. Provision an empty compatible PostgreSQL database.
3. Download and verify the selected backup object.
4. Restore with the PostgreSQL client version appropriate for the dump.
5. Point a temporary Open WebUI release at the restored database.
6. Validate authentication, chats, knowledge bases, and provider configuration.
7. Restore data-PVC files separately when uploads are part of the recovery goal.

The chart deliberately does not automate destructive restore operations.

## Upgrades

Back up data and review Open WebUI release notes. The Deployment uses `Recreate`,
so an upgrade has brief downtime but never runs old and new versions together.
After an upgrade, verify `/health/db`, recent logs, provider connectivity, and a
representative RAG query.

## Common failures

### Pod remains in startup

Check outbound access to model and package hubs, DNS, available memory, and PVC
write access. Preserve the long default startup budget for cold installs.

### Readiness fails but liveness passes

The application process is alive but the database is unavailable. Check the
PostgreSQL Service, Endpoints, credentials, TLS requirements, and NetworkPolicy.

### Redis WebSockets are inconsistent

Confirm both Redis URL variables exist, the `-redis-client` Service has ready
endpoints, and the `-redis-auth` Secret contains `redis-password`.

### PVC is pending

Inspect StorageClasses and PVC events. Set `persistence.storageClass` explicitly
or pre-create a compatible claim and set `persistence.existingClaim`.

### Backup Job fails before upload

Inspect the `postgres-backup` init-container logs. Verify host, database, user,
password Secret, and PostgreSQL reachability.

### Backup Job fails during upload

Inspect the `upload` container logs. Verify S3 endpoint TLS, bucket policy,
credentials, DNS, and egress policy.

### Helm rendering fails

Read the fail-fast error. Conflicting database or Redis modes, missing ingress
hosts, dual credential sources, and incomplete backup values are intentionally
rejected before Kubernetes receives an invalid release.
