<!-- SPDX-License-Identifier: Apache-2.0 -->
# CKAN configuration

## Application

| Value | Default | Purpose |
|---|---|---|
| `ckan.containerPort` | `5000` | CKAN uWSGI listener. |
| `ckan.uwsgiProcesses` | `2` | uWSGI workers. |
| `ckan.uwsgiHarakiri` | `60` | Maximum request duration. |
| `ckan.siteUrl` | `http://localhost:5000` | Canonical public URL. |
| `ckan.siteTitle` | `CKAN` | Portal title. |
| `ckan.plugins` | core views | Space-separated plugin list. |
| `ckan.replicaCount` | `1` | CKAN Deployment replicas. |
| `ckan.existingSecret` | `""` | Operator-managed application Secret. |
| `ckan.extraEnv` | `[]` | Additional CKAN environment entries. |

The Secret must contain the keys selected by
`ckan.existingSecretPasswordKey`, `ckan.existingSecretSessionKey`, and
`ckan.existingSecretJwtKey`. Generated values are preserved during upgrades,
but an operator-owned Secret is safer for disaster recovery.

## PostgreSQL

| Value | Default | Purpose |
|---|---|---|
| `database.mode` | `subchart` | Select bundled or external PostgreSQL. |
| `database.external.host` | `""` | External hostname. |
| `database.external.port` | `5432` | External port. |
| `database.external.ckanDatabase` | `ckan` | Catalog database. |
| `database.external.datastoreDatabase` | `datastore` | DataStore database. |
| `database.external.username` | `ckan` | Catalog role. |
| `database.external.datastoreReadUsername` | `datastore_ro` | DataStore read-only role. |
| `database.external.existingSecret` | `""` | Password Secret. |
| `database.external.existingSecretDatastoreReadPasswordKey` | `datastore-read-password` | DataStore read password key. |
| `database.external.sslMode` | `require` | libpq SSL mode. |
| `postgresql.enabled` | `true` | Deploy the HelmForge subchart. |
| `postgresql.architecture` | `standalone` | Standalone or replication topology. |

`database.mode=subchart` requires `postgresql.enabled=true`.
`database.mode=external` requires the subchart to be disabled and requires a
host plus inline or Secret-backed credentials. Replication mode uses the
writable primary Service.

When `sslMode=verify-full`, mount the trusted PostgreSQL CA through
`extraVolumes` and `extraVolumeMounts`, then set `PGSSLROOTCERT` to the
mounted file with `ckan.extraEnv`. The value must be readable by the CKAN
container.

The chart configures DataStore write and read URLs when the `datastore` plugin
is enabled. It deliberately does not create the separate database or roles.
Prepare them with upstream `ckan datastore set-permissions` guidance first.
DataStore requires `database.mode=external`; the chart rejects the plugin with
the bundled single-database PostgreSQL topology.

## Redis

| Value | Default | Purpose |
|---|---|---|
| `redisConfig.mode` | `subchart` | Select bundled or external Redis. |
| `redisConfig.external.host` | `""` | External hostname. |
| `redisConfig.external.port` | `6379` | External port. |
| `redisConfig.external.database` | `0` | Logical database. |
| `redisConfig.external.tls` | `true` | Use `rediss://`. |
| `redisConfig.external.sslCertReqs` | `required` | Certificate verification mode. |
| `redisConfig.external.sslCaCerts` | `""` | Mounted CA bundle path; empty uses system trust. |
| `redisConfig.external.existingSecret` | `""` | Password Secret. |
| `redis.enabled` | `true` | Deploy the HelmForge subchart. |
| `redis.architecture` | `standalone` | Standalone or replication topology. |

External Redis always requires a password. TLS verifies certificates by
default; mount a private CA with `extraVolumes` and `extraVolumeMounts`, then
set `sslCaCerts` to its container path. Replication topology uses the writable
primary Service; standalone uses the client Service.

At startup, the chart writes PostgreSQL credentials to a private `PGPASSFILE`
with mode `0600`; database passwords are not embedded in command arguments or
connection URLs. Redis credentials are URL-encoded before CKAN consumes them.
Passwords containing reserved characters such as `@`, `/`, `%`, `:`, or `\`
are supported. Raw credential variables use the chart-private `HELMFORGE_CKAN_`
prefix so the CKAN environment plugin does not interpret them as settings.

## Solr and DataPusher

| Value | Default | Purpose |
|---|---|---|
| `solr.enabled` | `true` | Deploy the CKAN Solr StatefulSet. |
| `solr.port` | `8983` | Solr process and Service port. |
| `solr.externalUrl` | `""` | Required when bundled Solr is disabled. |
| `solr.persistence.enabled` | `true` | Persist the Solr index. |
| `datapusher.enabled` | `true` | Deploy DataPusher. |
| `datapusher.port` | `8800` | DataPusher process and Service port. |

Solr is required for CKAN search. DataPusher additionally requires the CKAN
DataStore plugin and correctly provisioned DataStore database roles.

## Exposure and persistence

| Value | Default | Purpose |
|---|---|---|
| `service.type` | `ClusterIP` | CKAN Service type. |
| `service.port` | `80` | Cluster-facing Service port. |
| `persistence.enabled` | `true` | Persist uploaded resources. |
| `persistence.size` | `10Gi` | CKAN file volume capacity. |
| `persistence.existingClaim` | `""` | Reuse an existing PVC. |
| `ingress.enabled` | `false` | Render an Ingress. |

`service.port` does not change the application listener. Set
`ckan.containerPort` when the uWSGI process itself must listen elsewhere.

## Security and scheduling

The chart creates a dedicated ServiceAccount, disables API token mounting, and
enables NetworkPolicy by default. `networkPolicy.ingressFrom` restricts the
public CKAN listener. `networkPolicy.egress` defaults to unrestricted access;
replace it only after including DNS, datastores, Solr, DataPusher, remote
resources, and extension destinations.

Pod and container security contexts, resources, affinity, tolerations, node
selectors, topology spread constraints, priority class, extra volumes, and
extra manifests are configurable. The default UIDs match the official images.

## Backup

`backup.enabled` creates a CronJob that dumps the selected CKAN PostgreSQL
database to S3-compatible storage. Supply S3 credentials through
`backup.s3.existingSecret`. Backup containers run without privilege escalation,
with a read-only root filesystem and without a Kubernetes API token. Review
[operations.md](operations.md) for its scope and the additional file-storage
and Secret backups required for recovery.
