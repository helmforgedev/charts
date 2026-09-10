# Memos Helm Chart

Deploy [Memos](https://github.com/usememos/memos), a lightweight self-hosted note-taking service, with
production-oriented Kubernetes defaults.

This chart packages the official `docker.io/neosmemo/memos:0.30.0` image and exposes the runtime settings that matter
for Kubernetes: persistent data, SQLite or external database configuration, public instance URL, ingress/Gateway API
exposure, network policy, pod disruption budgets, file-backed deployment configuration, and non-root security context.

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

Set `memos.instanceUrl` only when public-mode behavior is intended. A nonempty value enables anonymous access to public
content and RSS; it is not merely reverse-proxy metadata. Leave it empty for private instances, even behind HTTPS
Ingress. The production example above deliberately enables public mode; private memos remain subject to application
authorization.

## Deployment Configuration

Memos 0.30 can load OAuth2 identity providers and instance settings from JSON files under `/etc/secrets`. Keep the JSON
in a Kubernetes Secret and let the chart mount it read-only:

```yaml
provisioning:
  existingSecret: memos-provisioning
```

The Secret keys become filenames and must use Memos' supported names:

- `memos-idp-<label>.json`
- `memos-instance-setting-general.json`
- `memos-instance-setting-storage.json`
- `memos-instance-setting-memo-related.json`
- `memos-instance-setting-notification.json`
- `memos-instance-setting-ai.json`

Unsupported instance-setting suffixes are ignored.

For example:

```yaml
apiVersion: v1
kind: Secret
metadata:
  name: memos-provisioning
type: Opaque
stringData:
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
instance setting keys are `GENERAL`, `STORAGE`, `MEMO_RELATED`, `NOTIFICATION`, and `AI`; Memos rejects `BASIC`, `TAGS`,
unknown fields, duplicate stable keys, and invalid cross-resource authentication configuration.

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

## Upgrading To Memos 0.30

This chart revision also changes deployment defaults: protected initial setup, closed registration through a complete
GENERAL provisioning file, a read-only root filesystem, and default network isolation. Existing users and passwords are
preserved. To retain database-managed GENERAL settings, set `provisioning.manageGeneralSettings: false` before upgrade.
Configure ingress-controller and external-service peers before applying network isolation to an existing release.

Back up the data volume and external database before upgrading. Review these upstream compatibility changes:

- an unset `memos.instanceUrl` now creates a private instance; set it to retain anonymous public access and RSS
- the shared-memo endpoint is now `GET /api/v1/shares/{share_token}/memo`
- saved filters use CEL timestamp fields and `now` instead of `now()`; for example,
  `created_ts >= now - duration("24h")`
- MCP is now a stateless tools-only endpoint at `/mcp` with service-prefixed tool names

The release also adds the Web Clipper, a rebuilt Markdown editor, multi-column feeds, signed webhooks, file-backed
settings, and a rebuilt MCP toolset.

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

## Security Scan: `memos`

| Framework | Score       |
| --------- | ----------- |
| Overall   | **100.00%** |
| MITRE     | **100.00%** |
| NSA       | **100.00%** |
| SOC2      | **100.00%** |

Kubescape 4.0.13, default rendered manifests, 2026-09-10. This is a Kubernetes configuration scan; it does not replace
image vulnerability management or application security review.
