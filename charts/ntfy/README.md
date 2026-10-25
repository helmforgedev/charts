<!-- SPDX-License-Identifier: Apache-2.0 -->

# ntfy Helm Chart

Deploy [ntfy](https://ntfy.sh) on Kubernetes using the official
[binwiederhier/ntfy](https://hub.docker.com/r/binwiederhier/ntfy) container image.
A simple HTTP-based pub-sub notification service that lets you send push notifications
to phones and desktops via scripts — no signup, no fees.

## Features

- **HTTP pub-sub** — send notifications via simple HTTP PUT/POST requests
- **Cross-platform** — native Android, iOS apps and web push support
- **Persistent storage** — SQLite cache and auth databases on PVC
- **PostgreSQL support** — load the connection URL from a Kubernetes Secret
- **External Secrets** — materialize database credentials through External Secrets Operator
- **Prometheus metrics** — opt-in `/metrics` endpoint with ServiceMonitor
- **Behind proxy** — trusts X-Forwarded-For headers by default
- **Attachment support** — configurable file size and expiry limits
- **Abuse ban-feed** — opt-in weighted offender feed for fail2ban or equivalent tooling
- **Ingress support** — TLS with cert-manager
- **Dual-stack** — `ipFamilyPolicy`/`ipFamilies` on the Service for IPv4/IPv6 clusters
- **Gateway API** — opt-in `HTTPRoute` (alternative to Ingress; requires Gateway API CRDs)

## Architecture

The chart runs one ntfy Deployment behind a ClusterIP Service. The process
listens on `containerPorts.http` (2586 by default), while `service.port` remains
the client-facing Service port. `/etc/ntfy` is read-only, `/tmp` is a bounded
`emptyDir`, and `/var/cache/ntfy` is either a PVC or a bounded `emptyDir`.

SQLite is the default data store. PostgreSQL can be provided by the optional
HelmForge subchart or an external service. Ingress and Gateway API are optional
edge routes; NetworkPolicy and PodDisruptionBudget resources are opt-in.
See [DESIGN.md](DESIGN.md) for the complete trust and persistence boundaries.

## Installation

**HTTPS repository:**

```bash
helm repo add helmforge https://repo.helmforge.dev
helm repo update
helm install ntfy helmforge/ntfy -f values.yaml
```

**OCI registry:**

```bash
helm install ntfy oci://ghcr.io/helmforgedev/helm/ntfy -f values.yaml
```

## Basic Example

```yaml
# values.yaml
ntfy:
  baseUrl: "https://ntfy.example.com"
```

After deploying:

```bash
# Port-forward to test
kubectl port-forward svc/<release>-ntfy 8080:80

# Send a notification
curl -d "Hello from k8s!" http://localhost:8080/test

# Subscribe
curl -s http://localhost:8080/test/json
```

## Key Values

| Key | Default | Description |
|-----|---------|-------------|
| `ntfy.baseUrl` | `""` | Public base URL of the instance |
| `ntfy.authDefaultAccess` | `"read-write"` | Default access for unauthenticated users |
| `ntfy.behindProxy` | `true` | Trust X-Forwarded-For headers |
| `ntfy.enableMetrics` | `false` | Enable Prometheus `/metrics` endpoint |
| `ntfy.banFeed.enabled` | `false` | Append confirmed abusive visitors to a ban-feed file |
| `ntfy.banFeed.file` | `/var/cache/ntfy/ban.log` | Writable ban-feed file on the data volume |
| `ntfy.database.enabled` | `false` | Use PostgreSQL instead of SQLite stores |
| `ntfy.database.existingSecret` | `""` | Secret containing the PostgreSQL URL |
| `ntfy.database.existingSecretKey` | `database-url` | Secret key containing the PostgreSQL URL |
| `containerPorts.http` | `2586` | ntfy process listener port |
| `persistence.enabled` | `true` | Enable persistence for cache and auth |
| `persistence.size` | `2Gi` | PVC size |
| `persistence.emptyDirSizeLimit` | `1Gi` | Data limit when persistence is disabled |
| `service.type` | `ClusterIP` | Service type |
| `service.port` | `80` | Service port |
| `service.ipFamilyPolicy` | `~` | Dual-stack policy (`SingleStack`, `PreferDualStack`, `RequireDualStack`) |
| `service.ipFamilies` | `[]` | IP families (`IPv4`, `IPv6`) |
| `ingress.enabled` | `false` | Enable ingress |
| `gateway.enabled` | `false` | Render an `HTTPRoute` (requires Gateway API CRDs) |
| `gateway.parentRefs` | `[]` | Gateway parent refs — **required** when `gateway.enabled=true`; each entry must have `name` |
| `gateway.hostnames` | `[]` | Hostnames the `HTTPRoute` matches |
| `serviceAccount.automountServiceAccountToken` | `false` | Mount a Kubernetes API token into application and backup pods |
| `podDisruptionBudget.enabled` | `false` | Protect the singleton pod from voluntary disruption |
| `networkPolicy.enabled` | `false` | Restrict ingress and optional egress |
| `runtimeStorage.tmpSizeLimit` | `128Mi` | Maximum writable `/tmp` storage |
| `postgresql.enabled` | `false` | Deploy HelmForge PostgreSQL `2.1.1` |

## Authentication

ntfy supports user authentication. After deploying, create users via exec:

```bash
kubectl exec -it deploy/<release>-ntfy -- ntfy user add --role=admin admin
```

Then restrict default access:

```yaml
ntfy:
  authDefaultAccess: "deny-all"
```

## PostgreSQL

### Embedded PostgreSQL (Subchart)

Deploy an integrated PostgreSQL instance managed by the HelmForge PostgreSQL subchart:

```yaml
postgresql:
  enabled: true
  auth:
    password: "choose-a-strong-password"
```

### External PostgreSQL

Connect to an existing PostgreSQL database directly via values:

```yaml
ntfy:
  database:
    mode: postgresql
    external:
      host: postgres.example.com
      port: 5432
      name: ntfy
      username: ntfy
      password: "choose-a-strong-password"
```

Alternatively, reference a pre-created Secret containing the complete PostgreSQL connection URL:

```bash
kubectl create secret generic ntfy-database \
  --from-literal=database-url="$NTFY_DATABASE_URL"
```

```yaml
ntfy:
  database:
    enabled: true
    existingSecret: ntfy-database
    existingSecretKey: database-url

persistence:
  enabled: false
```

The chart exposes the Secret key as `NTFY_DATABASE_URL` and omits ntfy's
SQLite-only `cache-file`, `auth-file`, and `web-push-file` options. PostgreSQL
stores messages, access control, and web push subscriptions. Keep persistence
enabled if local attachments, the abuse ban-feed, or other file-backed options
need to survive pod replacement.

PostgreSQL alone does not make this chart highly available. The Deployment
remains single-replica, and local attachment storage is not shared between
pods. Configure and validate shared attachment storage before designing an HA
deployment.

### External Secrets Operator

The same target Secret can be reconciled from a provider:

```yaml
ntfy:
  database:
    enabled: true
    existingSecret: ntfy-database

externalSecrets:
  enabled: true
  items:
    - fullnameOverride: ntfy-database
      spec:
        secretStoreRef:
          name: production-secrets
          kind: ClusterSecretStore
        target:
          name: ntfy-database
        data:
          - secretKey: database-url
            remoteRef:
              key: ntfy/database
              property: url
```

See the [External Secrets Operator documentation](https://external-secrets.io/latest/)
for provider and SecretStore configuration.

Because Kubernetes does not refresh environment variables in running
containers, rotating the target Secret does not update `NTFY_DATABASE_URL` in
an existing ntfy pod. Trigger a Deployment rollout after rotation, or configure
a compatible restart controller to restart the workload when the Secret changes.

## Administrator Bootstrap

Create an initial administrator account automatically when authentication is enforced (e.g. `authDefaultAccess: "deny-all"`):

```yaml
ntfy:
  authDefaultAccess: "deny-all"
  admin:
    enabled: true
    username: "admin"
    # Inline password or leave empty to auto-generate a secure random 32-character password in a managed Secret
    password: "InitialSecretPass123!"
    # Or reference an existing Secret
    # existingSecret: "ntfy-admin-credentials"
    # existingSecretPasswordKey: "password"
```

## Prometheus Metrics

Enable the built-in Prometheus metrics endpoint:

```yaml
ntfy:
  enableMetrics: true

metrics:
  serviceMonitor:
    enabled: true
```

## Abuse Ban-Feed

ntfy 2.26.3 can append confirmed abusive visitor IPs to a weighted ban-feed for
an external fail2ban or equivalent consumer. The chart keeps this disabled by
default. When enabled, the default file is stored on the writable data volume:

```yaml
ntfy:
  banFeed:
    enabled: true
    file: /var/cache/ntfy/ban.log
    window: 10m
    threshold: 100
    weights:
      - "42909:10"
```

The chart configures the feed only; it does not install fail2ban or modify node
firewall rules. The external consumer must be able to read the file, and the
operator must rotate it with a copy-truncate strategy so it cannot grow without
bound.

## Gateway API

```yaml
gateway:
  enabled: true
  parentRefs:
    - name: envoy
      namespace: envoy-gateway
  hostnames:
    - ntfy.example.com
  path: /
  pathType: PathPrefix
```

## Dual-Stack

```yaml
service:
  ipFamilyPolicy: PreferDualStack
  ipFamilies:
    - IPv4
    - IPv6
```

## Upgrade Notes

### Upgrading to v2.32.0

ntfy `v2.32.0` is an upstream release containing new features, bug fixes, and stability improvements.
No breaking configuration or schema changes are introduced in this release.

Review the [official v2.32.0 release notes](https://github.com/binwiederhier/ntfy/releases/tag/v2.32.0).

### Upgrading to v2.31.1

ntfy 2.31.1 upgrades the message database schema (version 16 to 17) to optimize
topic reconnects with a dedicated index on SQLite and PostgreSQL. The schema migration
is automatic upon startup. It also allows starting with a warning when a database
schema is newer than supported, simplifying rollbacks. Back up persistent state before
rollout and review the [2.31.1 release](https://github.com/binwiederhier/ntfy/releases/tag/v2.31.1).

## Limitations

- **Single replica** — the Deployment currently uses one replica regardless of database backend
- **Local attachments** — filesystem attachment storage is not shared across pods

## Security

The default pod and containers run as UID/GID 1000 with a read-only root
filesystem, `RuntimeDefault` seccomp, no privilege escalation, and all Linux
capabilities dropped. Kubernetes API token mounting is disabled. Resource
requests and limits, bounded ephemeral storage, and HTTP health probes are
enabled by default.

NetworkPolicy is opt-in because allowed peers depend on the cluster. When
egress isolation is enabled for an external PostgreSQL deployment,
`networkPolicy.egress.externalDatabaseCIDR` is required. Add explicit egress
rules for SMTP, web push, OIDC, S3, and any other external integration.

Keep credentials in existing Secrets or use External Secrets Operator. Inline
secret values are convenient for development but remain visible in Helm release
state. See the [security guide](docs/security.md) for the complete control and
trust-boundary model.

## Troubleshooting

Start with the rendered release state, pod events, and ntfy logs:

```bash
helm get values <release> -n <namespace>
kubectl get pods,pvc -n <namespace> -l app.kubernetes.io/instance=<release>
kubectl get events -n <namespace> --sort-by=.lastTimestamp
kubectl logs -n <namespace> deploy/<release>-ntfy --tail=200
```

If the pod is not ready, verify that the configured listener matches
`containerPorts.http`, the data volume is writable by UID 1000, and any
database or identity-provider Secret contains the configured key. See the
[operations guide](docs/operations.md) for backup, restore, rollout, and
diagnostic procedures.

## More Information

- [Chart design](DESIGN.md)
- [Configuration guide](docs/configuration.md)
- [Operations guide](docs/operations.md)
- [Security guide](docs/security.md)
- [Production example](examples/production.yaml)
- [ntfy documentation](https://docs.ntfy.sh)
- [Source code](https://github.com/helmforgedev/charts/tree/main/charts/ntfy)

### Security Scan: `ntfy`

| Framework | Score |
|---|---|
| MITRE + NSA + SOC2 | **74.242424%** |

> Security posture acceptable.

## Backup and Restore

The optional CronJob archives `/var/cache/ntfy` and uploads the archive to an
S3-compatible endpoint. Persistence must remain enabled so the Job can mount
the same PVC as ntfy.

```yaml
backup:
  enabled: true
  schedule: "0 3 * * *"
  s3:
    endpoint: https://s3.example.com
    bucket: ntfy-backups
    existingSecret: ntfy-backup-s3
```

The Secret must contain `access-key` and `secret-key` unless the key names are
overridden. Test restore into a separate release before relying on the backup.
The [operations guide](docs/operations.md) documents the full restore sequence.

## SSO (OpenID Connect) and SMTP

ntfy supports native OpenID Connect authentication and outbound SMTP email.
Store both client and SMTP secrets in Kubernetes Secrets:

```yaml
ntfy:
  baseUrl: https://ntfy.example.com

oidc:
  enabled: true
  issuerUrl: https://auth.example.com
  clientId: ntfy
  existingSecret: ntfy-oidc
  existingSecretKey: client-secret
  redirectUrl: https://ntfy.example.com/login

smtp:
  enabled: true
  senderAddr: smtp.example.com:587
  senderFrom: ntfy@example.com
  senderUser: ntfy
  existingSecret: ntfy-smtp
  existingSecretPasswordKey: smtp-password
```

The chart injects secret values through `NTFY_OIDC_CLIENT_SECRET` and
`NTFY_SMTP_SENDER_PASS`; they are not written into the ConfigMap.
