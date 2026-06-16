<!-- SPDX-License-Identifier: Apache-2.0 -->

# Listmonk Architecture

Listmonk is a web application for newsletters, mailing lists, campaigns, and
transactional email. The HelmForge chart runs the application with PostgreSQL and
upload storage as the durable state layers.

## Components

| Component | Kubernetes resource | Purpose |
| --- | --- | --- |
| Listmonk | Deployment | Runs the web UI, API, campaign worker, and SMTP sender. |
| Database init | Init containers | Waits for PostgreSQL, installs schema, and applies upgrades. |
| PostgreSQL | Subchart or external service | Stores subscribers, lists, campaigns, settings, and SMTP config. |
| Uploads | PersistentVolumeClaim | Stores uploaded media and campaign assets. |
| Service | Service | Exposes Listmonk HTTP on port 80 inside the cluster. |
| Ingress | Ingress | Optional external HTTP/TLS route. |
| Backup | ConfigMap, Secret, CronJob | Optional PostgreSQL dump and S3-compatible upload flow. |

## Request Flow

```text
User
   |
   | HTTP request
   v
Ingress or port-forward
   |
   v
Service port 80
   |
   v
Listmonk container port 9000
```

Listmonk stores application settings, including SMTP settings configured through
the UI, in PostgreSQL. Uploaded assets are stored on the uploads PVC.

## Database Flow

With bundled PostgreSQL, the application points at the release-scoped
PostgreSQL Service and reads the generated application user Secret. With external
PostgreSQL, the chart points Listmonk at the configured host and reads the
password from an existing Secret or chart-managed Secret.

For external databases, create the database, user, privileges, and required
extensions before installing the chart. The Listmonk init container still runs
the idempotent schema install and upgrade commands.

## Backup Flow

```text
CronJob schedule
   |
   v
postgres-backup init container
   |
   | writes dump archive
   v
emptyDir work directory
   |
   v
upload container
   |
   v
S3-compatible bucket
```

Backups read the same database Secret as Listmonk and read S3 credentials from
`backup.s3.existingSecret` or the chart-managed backup Secret.

## Scaling Boundary

The chart defaults to one replica. Before increasing `replicaCount`, validate
session behavior, uploads storage semantics, database connection limits, and
campaign scheduling behavior for multiple Listmonk pods.
