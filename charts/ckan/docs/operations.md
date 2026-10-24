<!-- SPDX-License-Identifier: Apache-2.0 -->
# CKAN operations

## Installation verification

```bash
kubectl get deployment,statefulset,pod,service,pvc,networkpolicy \
  --namespace ckan \
  --selector app.kubernetes.io/instance=ckan
kubectl get endpointslice \
  --namespace ckan \
  --selector kubernetes.io/service-name=ckan-ckan
```

The public Service must select only the CKAN Deployment. DataPusher and Solr
have component-specific Services and are not public entry points.

## First startup and upgrades

The official image checks PostgreSQL and Solr, initializes or upgrades the CKAN
schema, configures plugins, and creates the sysadmin before starting uWSGI.
Follow the application logs during first boot and upgrades:

```bash
kubectl logs --namespace ckan deployment/ckan-ckan --follow
kubectl get events --namespace ckan --sort-by=.lastTimestamp
```

Do not interrupt a database upgrade. Back up PostgreSQL, uploaded files, and the
application Secret before changing CKAN or extension versions.

## Health and dependency checks

```bash
kubectl port-forward --namespace ckan service/ckan-ckan 5000:80
curl --fail http://127.0.0.1:5000/api/action/status_show
kubectl logs --namespace ckan statefulset/ckan-ckan-solr --tail=100
kubectl logs --namespace ckan deployment/ckan-ckan-datapusher --tail=100
```

When using non-default names or ports, substitute the release name and the
configured `service.port`. A Ready CKAN pod confirms the web action responded;
it does not validate every extension or DataPusher job.

## Backup and restore

The optional CronJob dumps the configured CKAN PostgreSQL database and uploads
the compressed archive to S3-compatible storage. It does not include uploaded
files, application Secrets, Solr, Redis, or a separate DataStore database.

Use an encrypted backup system for the CKAN file PVC and every referenced
Secret. Restore PostgreSQL, file storage, and Secrets from a consistent recovery
point, then reindex Solr and validate extensions and DataPusher.

Trigger and inspect a database backup:

```bash
kubectl create job --namespace ckan \
  --from=cronjob/ckan-ckan-backup ckan-backup-manual
kubectl logs --namespace ckan job/ckan-backup-manual --all-containers
```

Test restore procedures outside production. A successful upload is not proof
that an archive is complete or restorable.

## Troubleshooting

- PostgreSQL failures: verify mode alignment, Secret names and keys, TLS mode,
  DNS, and the writable primary Service.
- Redis failures: verify authentication, TLS, database number, and whether the
  selected subchart topology exposes the expected Service.
- Solr failures: check the `ckan` core, PVC permissions, configured port, and
  `/solr/ckan/admin/ping`.
- Repeated sysadmin or migration failures: inspect the complete `prerun.py`
  output; do not suppress errors or run concurrent manual migrations.
- DataPusher failures: verify the service endpoint, DataStore plugin, DataStore
  database roles, and resource URL reachability.
