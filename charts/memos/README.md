<!-- SPDX-License-Identifier: Apache-2.0 -->

# Memos Helm Chart

Deploy [Memos](https://github.com/usememos/memos), a lightweight self-hosted note-taking service, with
production-oriented Kubernetes defaults.

This chart packages the official `docker.io/neosmemo/memos:0.31.0` image and exposes the runtime settings that matter
for Kubernetes: persistent data, SQLite or external database configuration, canonical instance URL, ingress/Gateway API
exposure, network policy, pod disruption budgets, file-backed deployment configuration, and non-root security context.

## Features

- Official pinned Memos image with a non-root, read-only runtime
- Protected first-administrator bootstrap without replacing the upstream binary
- SQLite, external SQL, or maintained HelmForge PostgreSQL and MySQL dependencies
- Native OAuth2 and instance-setting provisioning from a read-only Secret
- Ingress, Gateway API, dual-stack Service, NetworkPolicy, and External Secrets support
- Behavioral validation of persistence, recovery, SQL, OAuth2, S3, MCP, and access policy

## Architecture

Memos is a single Go service with an HTTP UI and API. The upstream container listens on port `5230`, runs as non-root
UID/GID `10001`, and stores persistent data under `/var/opt/memos`.

The default chart topology is intentionally conservative:

- one StatefulSet replica
- one PersistentVolumeClaim mounted at `/var/opt/memos`
- SQLite database stored in that data directory
- ServiceAccount token automount disabled
- non-root container security context

When `database.driver` is `mysql` or `postgres`, the chart uses a complete DSN Secret or builds the native DSN from
Secret-backed password components in a memory volume. Optional HelmForge PostgreSQL and MySQL subcharts manage their own
application credentials; the connection helper reads those credentials without rendering passwords into arguments. The
data volume remains required because Memos can still store local assets and instance data outside the external database.
Ingress class rendering is optional. Set `ingress.ingressClassName: ""` to omit `spec.ingressClassName`. NetworkPolicy
is enabled by default: same-namespace HTTP ingress, DNS egress and the selected database subchart. Add
ingress-controller peers to `networkPolicy.ingressFrom`, external SQL peers to `database.networkPolicyPeers`, and
explicit integration destinations to `networkPolicy.httpsEgress` or `networkPolicy.extraEgress`. DNS defaults to
`kube-system` pods labeled `k8s-app: kube-dns`; override `networkPolicy.dnsEgress` for other DNS configurations.
Enforcement requires a CNI that implements Kubernetes NetworkPolicy. HTTP startup, readiness, and liveness probes call
the upstream `/healthz` endpoint instead of accepting a bare TCP connection.

## Install

```bash
helm repo add helmforge https://repo.helmforge.dev
helm install memos helmforge/memos
```

Forward the service for local validation:

```bash
kubectl port-forward svc/memos-memos 5230:5230
```

Then open `http://127.0.0.1:5230`.

Protected bootstrap creates the initial `admin` account on a loopback-only listener before the public process starts.
Helm NOTES identifies the password Secret. Existing administrators and passwords are preserved. Prefer
`bootstrap.existingSecret` for GitOps, and use the application's password flow to rotate an existing account.

The generated GENERAL provisioning policy closes registration and retains password authentication. It owns the whole
native setting group; settings backed by that file cannot be changed in the UI. For an existing installation with
database-managed policy, set `provisioning.manageGeneralSettings=false` to preserve that policy. An explicit
`provisioning.existingSecret` remains authoritative and suppresses the generated file.

## Production Values

```yaml
memos:
  instanceUrl: https://memos.example.com

ingress:
  enabled: true
  ingressClassName: traefik
  hosts:
    - host: memos.example.com
      paths:
        - path: /
          pathType: Prefix
  tls:
    - secretName: memos-tls
      hosts:
        - memos.example.com

persistence:
  enabled: true
  size: 20Gi

resources:
  requests:
    cpu: 100m
    memory: 128Mi
  limits:
    cpu: 500m
    memory: 512Mi

networkPolicy:
  enabled: true
  ingressFrom:
    - namespaceSelector:
        matchLabels:
          kubernetes.io/metadata.name: kube-system
      podSelector:
        matchLabels:
          app.kubernetes.io/name: traefik
```

`memos.instanceUrl` is the canonical external HTTP(S) URL used by Memos and is never inferred from Ingress or Gateway
hostnames. In Memos 0.31 it does not select public or private behavior. Manage anonymous access independently through
the administrator UI or a file-backed `ACCESS` instance setting. RSS was removed upstream in 0.31.

## Deployment Configuration

Memos 0.31 can load OAuth2 identity providers and instance settings from JSON files under `/etc/secrets`. Keep the JSON
in a Kubernetes Secret and let the chart mount it read-only:

```yaml
provisioning:
  existingSecret: memos-provisioning
```

This Secret replaces the chart-generated provisioning Secret; the two Secret sources are not merged. Memos still
applies precedence by setting group: a group without a file remains database-managed, while a supplied file replaces
that complete group. To guarantee the chart's closed-registration policy while also owning private access, include both
a complete `memos-instance-setting-general.json` with `disallowUserRegistration: true` and
`memos-instance-setting-access.json` with `INSTANCE_ACCESS_MODE_PRIVATE`. Preserve the intended
`disallowPasswordAuth` value and every other `GENERAL` field; omit the `GENERAL` file instead when the database must
remain authoritative for that group.

The Secret keys become filenames and must use Memos' supported names:

- `memos-idp-<label>.json`
- `memos-instance-setting-access.json`
- `memos-instance-setting-general.json`
- `memos-instance-setting-storage.json`
- `memos-instance-setting-memo-related.json`
- `memos-instance-setting-notification.json`
- `memos-instance-setting-ai.json`

Only supported filenames are loaded. Files beginning with `memos-` but not matching a supported pattern produce a
startup warning; invalid matching files fail startup.

For example:

```yaml
apiVersion: v1
kind: Secret
metadata:
  name: memos-provisioning
type: Opaque
stringData:
  memos-instance-setting-access.json: |
    {
      "key": "ACCESS",
      "accessSetting": {
        "accessMode": "INSTANCE_ACCESS_MODE_PRIVATE"
      }
    }
  memos-instance-setting-general.json: |
    {
      "key": "GENERAL",
      "generalSetting": {
        "disallowUserRegistration": true,
        "disallowPasswordAuth": false,
        "weekStartDayOffset": 1
      }
    }
```

Files are validated atomically during startup and remain authoritative for the process lifetime. Each setting file
replaces its complete database-backed group; omitted scalar fields reset to defaults, so include every required field.
Every replica must mount identical files, and Secret changes require an orderly restart of every replica. Supported
instance setting keys are `ACCESS`, `GENERAL`, `STORAGE`, `MEMO_RELATED`, `NOTIFICATION`, and `AI`; Memos rejects `BASIC`, `TAGS`,
unknown fields, duplicate stable keys, and invalid cross-resource authentication configuration.

## Configuration

| Parameter | Description | Default |
| --- | --- | --- |
| `image.repository` | Official Memos image repository | `docker.io/neosmemo/memos` |
| `image.tag` | Pinned Memos release | `0.31.0` |
| `app.port` | Native Memos HTTP listener port | `5230` |
| `memos.instanceUrl` | Canonical external HTTP(S) URL, independent from access policy | `""` |
| `database.driver` | Database backend: `sqlite`, `mysql`, or `postgres` | `sqlite` |
| `database.existingSecret` | Secret containing a complete external SQL DSN | `""` |
| `postgresql.enabled` | Deploy the maintained HelmForge PostgreSQL dependency | `false` |
| `mysql.enabled` | Deploy the maintained HelmForge MySQL dependency | `false` |
| `provisioning.existingSecret` | Secret containing native provisioning files | `""` |
| `bootstrap.existingSecret` | Secret containing the first-administrator password | `""` |
| `persistence.size` | Generated data claim capacity | `5Gi` |
| `service.port` | Kubernetes Service port | `5230` |
| `ingress.enabled` | Render an Ingress | `false` |
| `gatewayAPI.enabled` | Render Gateway API HTTPRoutes | `false` |
| `networkPolicy.enabled` | Render the default restrictive NetworkPolicy | `true` |

Every supported value is documented inline in `values.yaml` and validated by `values.schema.json`.

## External Database

Choose one backend. Bundled databases use the maintained HelmForge subcharts, including their authentication, backup,
monitoring and topology options. Configure those options under `postgresql` or `mysql`.

```yaml
database:
  driver: postgres
postgresql:
  enabled: true
  auth:
    database: memos
    username: memos
```

For MySQL, set `database.driver: mysql`, `mysql.enabled: true` and leave PostgreSQL disabled. The chart rejects two
enabled databases, a mismatched driver, or mixing bundled credentials with external components/full DSNs.

External component mode separates the endpoint from its password Secret:

```yaml
database:
  driver: postgres
  host: postgres.database.example.com
  name: memos
  username: memos
  passwordSecret: memos-database-password
  passwordKey: password
  sslMode: verify-full
  caSecret: database-ca
  networkPolicyPeers:
    - ipBlock:
        cidr: 192.0.2.8/32
```

Replace the example address with your database destination. Component mode defaults to certificate-verified TLS for
external databases and plaintext inside the cluster for bundled databases. Set TLS explicitly when securing a bundled
database. PostgreSQL credentials are URI-encoded; MySQL uses its native Go DSN rather than a PostgreSQL-style URL. Never
move an existing SQLite deployment to SQL merely by switching the driver; migrate and verify its data separately.

SQLite is the safest default for a small single-pod deployment. Use PostgreSQL or MySQL when you need shared database
state or want the database managed outside the pod volume. For `replicaCount > 1`, provide `persistence.existingClaim`
backed by shared storage for `MEMOS_DATA`; generated StatefulSet PVCs are per-pod and can diverge.

```yaml
database:
  driver: postgres
  existingSecret: memos-postgres
  existingSecretKey: dsn
persistence:
  existingClaim: memos-shared-data
```

The Secret must contain a DSN compatible with Memos:

```yaml
apiVersion: v1
kind: Secret
metadata:
  name: memos-postgres
type: Opaque
stringData:
  dsn: postgres://memos:replace-with-encoded-password@postgres.database.example.com:5432/memos?sslmode=verify-full
```

The chart blocks unsafe topologies:

- `replicaCount > 1` with SQLite
- `replicaCount > 1` with MySQL/PostgreSQL and no `persistence.existingClaim`
- MySQL/PostgreSQL without a bundled database, external components or complete DSN source
- external database with no persistent data volume

## Upgrade Notes

### Upgrading to Memos 0.30

This chart revision also changes deployment defaults: protected initial setup, closed registration through a complete
GENERAL provisioning file, a read-only root filesystem, and default network isolation. Existing users and passwords are
preserved. To retain database-managed GENERAL settings, set `provisioning.manageGeneralSettings: false` before upgrade.
Configure ingress-controller and external-service peers before applying network isolation to an existing release.

Back up the data volume and external database before upgrading. Review these upstream compatibility changes:

- the shared-memo endpoint is now `GET /api/v1/shares/{share_token}/memo`
- saved filters use CEL timestamp fields and `now` instead of `now()`; for example,
  `created_ts >= now - duration("24h")`
- MCP is now a stateless tools-only endpoint at `/mcp` with service-prefixed tool names

The release also adds the Web Clipper, a rebuilt Markdown editor, multi-column feeds, signed webhooks, file-backed
settings, and a rebuilt MCP toolset.

### Upgrading to Memos 0.31

Memos 0.31 adds collaborative Spaces, Calendar and Map views, portable ZIP
exports, multiple attachment backends and request hardening. Before upgrading,
review the administrator access expansion, Shortcut-to-View API migration and
RSS removal in the [official release notes](https://github.com/usememos/memos/releases/tag/v0.31.0).

On the first 0.31 startup, if no `ACCESS` setting exists, Memos initializes it to `PUBLIC` when
`memos.instanceUrl` is nonempty and to `PRIVATE` otherwise. The initialized setting is persisted, so later changes to
`memos.instanceUrl` do not change access policy. Deployments that require private access with a canonical instance URL
must provision `memos-instance-setting-access.json` with `INSTANCE_ACCESS_MODE_PRIVATE` before first startup. When
`provisioning.existingSecret` is used, the generated `GENERAL` file is not mounted. Omitting `GENERAL` keeps the
database policy; supplying it replaces the complete group. Include a complete `memos-instance-setting-general.json`
when the deployment must guarantee closed registration, preserving `disallowPasswordAuth` and the other current
policy values. Drain older replicas before changing the policy during a mixed-version rollout because 0.30 still uses
the legacy instance-URL rule.

## Backups

Back up the PersistentVolumeClaim even when using an external database. With SQLite, it contains the database and local
assets. With MySQL/PostgreSQL, it can still contain assets and instance data. Also back up the Secret selected by
`provisioning.existingSecret`; PVC and database backups do not include its mounted OAuth2/IdP and instance-setting JSON
files.

For SQLite, stop the writer and archive the entire data directory, including SQLite WAL files and local assets, or use
an application-consistent storage snapshot. Verify a restore into a fresh volume before relying on the backup.

## Security

Defaults are designed for a private self-hosted service:

- no ServiceAccount token mounted by default
- non-root UID/GID `10001`
- dropped Linux capabilities
- default NetworkPolicy ingress and egress isolation
- protected bootstrap and closed registration
- read-only image filesystem
- optional Secret-backed DSN
- `memos.allowPrivateWebhooks=false` by default

Only enable `memos.allowPrivateWebhooks` when webhook targets are trusted internal services. It allows requests to
private or reserved IP ranges.

## Documentation

- [Operations](docs/operations.md)
- [Database](docs/database.md)
- [Security](docs/security.md)
- [Backup and restore](docs/backup.md)
- [OAuth2 and MCP](docs/integrations.md)

## Examples

- [Production baseline](examples/production.yaml)
- [External database](examples/external-database.yaml)
- [Bundled PostgreSQL](examples/postgresql.yaml)
- [Bundled MySQL](examples/mysql.yaml)
- [Minimal installation](examples/simple.yaml)

## Troubleshooting

| Symptom | Check |
| --- | --- |
| Pod fails before readiness | Inspect startup logs for invalid provisioning JSON or database migration errors. |
| Database connection fails | Verify the selected driver, Secret key, DNS, TLS mode, and NetworkPolicy peers. |
| Anonymous access is unexpected | Inspect the Memos 0.31 `ACCESS` setting; `memos.instanceUrl` is not the policy switch. |
| Attachments disappear after SQL migration | Restore the complete `MEMOS_DATA` volume as well as the database. |
| Secret changes have no effect | Restart every replica because provisioning is loaded only at process startup. |

See [Operations](docs/operations.md) for rollout commands and detailed failure handling.

## Security Scan: `memos`

| Framework | Score       |
| --------- | ----------- |
| Overall   | **100.00%** |
| MITRE     | **100.00%** |
| NSA       | **100.00%** |
| SOC2      | **100.00%** |

Kubescape 4.0.13, default rendered manifests, 2026-09-10. This is a Kubernetes configuration scan; it does not replace
image vulnerability management or application security review.

## Gateway API contract

Use `gatewayAPI.enabled` and `gatewayAPI.httpRoutes[]`. Set each route's `parentRefs` to a shared Gateway that allows
this namespace, and configure its HTTPS listener and public hostname. Routes accept labels, annotations and rules
with matches, filters and optional backend references; omitted backends target this chart's application Service.
Ingress and HTTPRoute resources can coexist. Verify controller conditions and public traffic before production use.
See the [Gateway API documentation](https://gateway-api.sigs.k8s.io/).
