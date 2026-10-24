<!-- SPDX-License-Identifier: Apache-2.0 -->
# Middleware configuration

## Runtime

| Value | Default | Purpose |
|---|---|---|
| `middleware.frontendPort` | `3333` | Frontend `PORT` and container port. |
| `middleware.analyticsPort` | `9696` | Analytics `ANALYTICS_SERVER_PORT`. |
| `middleware.syncPort` | `9697` | Sync `SYNC_SERVER_PORT`. |
| `middleware.environment` | `prod` | Backend and frontend environment. |
| `middleware.timezone` | `UTC` | IANA timezone for DORA metric windows. |
| `middleware.extraEnv` | `[]` | Additional application environment entries. |

`middleware.internalDbEnabled` must remain `"false"`; the chart supplies a
separate PostgreSQL. `middleware.internalRedisEnabled` must remain `"true"`
because the upstream 0.3.1 remote Redis client cannot authenticate and assumes
TLS for every non-loopback hostname.

## PostgreSQL modes

Exactly one database mode must be enabled:

- `postgresql.enabled: true` deploys the HelmForge PostgreSQL subchart.
- `externalDatabase.enabled: true` connects to an operator-managed database and
  requires `postgresql.enabled: false`.

The chart mirrors PostgreSQL `nameOverride`, `fullnameOverride`, replication
primary naming, `auth.existingSecret`, custom user password keys, and External
Secrets target names when it builds the application connection.

On a fresh bundled installation, a subchart init script makes the application
role the owner of `mhq-oss`. This permits the upstream migration to create its
required `extensions` schema. External databases must grant the application
role equivalent ownership or `CREATE` privileges.

For an external database, set:

| Value | Default | Purpose |
|---|---|---|
| `externalDatabase.host` | `""` | Required PostgreSQL hostname. |
| `externalDatabase.port` | `5432` | PostgreSQL port. |
| `externalDatabase.name` | `mhq-oss` | Application database. |
| `externalDatabase.user` | `middleware` | Application role. |
| `externalDatabase.existingSecret` | `""` | Preferred password Secret. |
| `externalDatabase.existingSecretPasswordKey` | `user-password` | Password key. |
| `externalDatabase.password` | `""` | Development-only inline source, moved to a Secret. |
| `externalDatabase.sslMode` | `disable` | libpq SSL mode. |

See [external-datastores.md](external-datastores.md) for a complete setup.

## Persistence

The chart mounts the key volume at
`/app/backend/analytics_server/mhq/config`, the path used by the upstream image.
The generated `config.ini` must remain paired with the PostgreSQL data it
encrypts.

| Value | Default | Purpose |
|---|---|---|
| `persistence.enabled` | `true` | Create or mount key storage. |
| `persistence.size` | `1Gi` | PVC capacity. |
| `persistence.storageClass` | `""` | StorageClass selection. |
| `persistence.accessModes` | `[ReadWriteOnce]` | PVC access modes. |
| `persistence.existingClaim` | `""` | Reuse a pre-created PVC. |

Disabling persistence uses `emptyDir` and is intended only for disposable
environments.

## Exposure and ports

`service.port` is the client-facing Service port. It targets the named
frontend port and is independent of `middleware.frontendPort`. Ingress requires
at least one entry under `ingress.hosts`.

The analytics and sync ports are deliberately not exposed through the Service.
They are internal processes used by the frontend and background jobs.

## Security and scheduling

The chart creates a dedicated ServiceAccount and disables API token mounting by
default. Pod seccomp and container privilege/capability settings are
configurable through `podSecurityContext` and `securityContext`.

`networkPolicy.enabled` restricts ingress to the named frontend port. Use
`networkPolicy.additionalIngressFrom` to limit that access to selected
namespaces or pods; despite the legacy key name, a nonempty list is the complete
allowlist. Egress remains open when `networkPolicy.additionalEgress` is empty.
A nonempty egress list replaces unrestricted access and must include DNS,
PostgreSQL, and every configured provider endpoint.

Scheduling controls include `nodeSelector`, `affinity`, `tolerations`,
`topologySpreadConstraints`, and `priorityClassName`. Additional files can be
mounted with `extraVolumes` and `extraVolumeMounts`; arbitrary resources can be
supplied with `extraManifests`.

## Probes

Startup and readiness probes use Bash TCP checks for all three application
listeners and the loopback Redis listener. Liveness checks the frontend. Probe timing is configurable under
`probes.startup`, `probes.readiness`, and `probes.liveness`.

Do not reduce startup tolerance without testing initial migration, archive
extraction, frontend build extraction, and all supervised processes on the
target storage class and nodes.
