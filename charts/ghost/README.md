<!-- SPDX-License-Identifier: Apache-2.0 -->

# Ghost Helm Chart

Deploy [Ghost](https://ghost.org) on Kubernetes using the official
[ghost](https://hub.docker.com/_/ghost) container image. A modern publishing platform
for building blogs, newsletters, and membership-based content with built-in monetization.

## Features

- **MySQL backend** — bundled via HelmForge subchart or external database
- **Content persistence** — images, media, themes, routes, and redirects on PVC
- **S3 backup** — scheduled content backups to S3-compatible storage
- **Headless CMS** — REST and Content API for headless usage
- **Memberships** — built-in subscriptions, newsletters, and payments
- **Ingress support** — TLS with cert-manager
- **Gateway API support** — optional HTTPRoute for modern ingress stacks
- **External Secrets support** — optional database password synchronization
- **Hardened runtime defaults** — non-root execution, read-only root filesystem, dropped capabilities, seccomp, and no API token mount
- **Operational policies** — optional PodDisruptionBudget and NetworkPolicy with explicit database egress
- **Configurable listener** — `containerPorts.http` updates the Ghost process, probes, Service target, and policies together

## Installation

**HTTPS repository:**

```bash
helm repo add helmforge https://repo.helmforge.dev
helm repo update
helm install ghost helmforge/ghost -f values.yaml
```

**OCI registry:**

```bash
helm install ghost oci://ghcr.io/helmforgedev/helm/ghost -f values.yaml
```

## Basic Example

```yaml
# values.yaml
ghost:
  url: "https://blog.example.com"
```

After deploying:

```bash
kubectl port-forward svc/<release>-ghost 2368:80
# Open http://localhost:2368/ghost to set up admin account
```

## Architecture

The chart runs one Ghost Deployment backed by a persistent content volume and either the bundled HelmForge MySQL
dependency or an external MySQL-compatible database. A ClusterIP Service exposes the named `http` port to an optional
Ingress or Gateway API HTTPRoute. See [DESIGN.md](DESIGN.md) for the trust boundaries and deployment diagrams.

## External MySQL

```yaml
mysql:
  enabled: false

database:
  external:
    host: "mysql.example.com"
    name: ghost
    username: ghost
    password: "secure-password"
```

## External Secrets

External Secrets Operator can project the external MySQL password into the
Secret consumed by Ghost. Install the operator separately, disable the bundled
MySQL chart, and keep the item target aligned with
`database.external.existingSecret`:

```yaml
mysql:
  enabled: false

database:
  external:
    host: mysql.database.svc
    existingSecret: ghost-db-credentials

externalSecrets:
  enabled: true
  items:
    - fullnameOverride: ghost-db-credentials
      spec:
        secretStoreRef:
          name: platform-secrets
          kind: ClusterSecretStore
        data:
          - secretKey: password
            remoteRef:
              key: ghost/database
              property: password
```

The chart renders `external-secrets.io/v1`, defaults the target to the rendered
ExternalSecret name, and supports multiple items. Every item must set either
`name` or `fullnameOverride` so each resource has a unique identity. The legacy
`secretStoreRef`/`data` surface remains compatible for existing releases, but
new configurations should use `externalSecrets.items`.

## Custom Adapter Images

Ghost can load adapters installed outside the content directory. For a
custom image that installs adapters in `/opt/ghost/adapters`, expose the path
through Ghost's environment-based configuration:

```yaml
image:
  repository: registry.example.com/ghost-with-adapters
  tag: "6.71.0"

ghost:
  extraEnv:
    - name: paths__installedAdaptersPath
      value: /opt/ghost/adapters
```

Bake the adapter directory into the custom image. Keeping it outside
`/var/lib/ghost/content` prevents the content PVC from shadowing installed
adapters when the container starts.

## Key Values

| Key | Default | Description |
|-----|---------|-------------|
| `ghost.url` | `""` | Public URL of the Ghost instance |
| `image.tag` | `6.71.0` | Ghost image tag |
| `containerPorts.http` | `2368` | Ghost process listener and container port |
| `mysql.enabled` | `true` | Deploy MySQL subchart |
| `mysql` dependency | `2.1.1` | HelmForge MySQL chart version |
| `mysql.image.tag` | `8.4.11` | MySQL image tag pinned to the Ghost-supported MySQL 8 major |
| `persistence.enabled` | `true` | Enable content persistence |
| `persistence.size` | `10Gi` | Content PVC size |
| `serviceAccount.automountServiceAccountToken` | `false` | Mount the Kubernetes API token into application and backup pods |
| `runtimeStorage.tmpSizeLimit` | `256Mi` | Maximum writable `/tmp` storage |
| `podDisruptionBudget.enabled` | `false` | Protect the singleton pod during voluntary disruption |
| `networkPolicy.enabled` | `false` | Restrict inbound traffic to Ghost |
| `networkPolicy.egress.enabled` | `false` | Restrict egress to DNS, MySQL, and configured rules |
| `backup.enabled` | `false` | Enable S3 content backups |
| `ingress.enabled` | `false` | Enable ingress |
| `gateway.enabled` | `false` | Enable Gateway API HTTPRoute |
| `externalSecrets.enabled` | `false` | Render ExternalSecret for database password |
| `externalSecrets.refreshInterval` | `1h` | Default sync interval for ExternalSecret items |
| `externalSecrets.items` | `[]` | Complete ExternalSecret definitions |

## Upgrade Notes

Ghost `6.71.0` adds automation analytics, self-service site exports, member
location maps and refreshed post/member screens. It also fixes scheduled-post
races, member imports, Portal pricing and initialization, uploads, editor
freezes, social previews and analytics links. Releases 6.66.0 through 6.71.0 do
not document a breaking database or configuration change. Review the
[official release](https://github.com/TryGhost/Ghost/releases/tag/v6.71.0).
Files edited in Ghost Admin remain under `/var/lib/ghost/content/data`, so the
chart's content PVC and S3 content backup already cover them. Review the
upstream Ghost release notes before upgrading
production sites, take a content and database backup, and verify themes, custom
integrations, newsletter flows, comments, and member signup paths in staging
before reusing existing PVCs. The External Secrets contract now follows
`externalSecrets.items[]`; the previous single-secret fields remain supported
for compatibility.

## S3 Backup

```yaml
backup:
  enabled: true
  schedule: "0 3 * * *"
  s3:
    endpoint: "https://s3.example.com"
    bucket: ghost-backups
    accessKey: "minioadmin"
    secretKey: "minioadmin"
```

## Security

The default pod runs as UID/GID 1000, uses `RuntimeDefault` seccomp, drops every Linux capability, prevents privilege
escalation, mounts a read-only root filesystem, and disables service-account token automounting. Writable data is
limited to the content volume and a size-bounded `/tmp` volume. When egress isolation is enabled with an external
database, set `networkPolicy.egress.externalDatabaseCIDR`; the chart rejects an incomplete policy.

Read [Security](docs/security.md) before production deployment and [Operations](docs/operations.md) for disruption,
backup, restore, and observability guidance.

## Troubleshooting

- If Ghost cannot reach MySQL, verify the database Secret, DNS name, port, and NetworkPolicy database egress.
- If the pod cannot write content, verify the PVC is writable by UID/GID 1000 and inspect the volume mount events.
- If a custom listener does not respond, confirm `containerPorts.http`; the chart reserves `server__port` so the
  process and Kubernetes resources cannot diverge.
- If the S3 job succeeds but posts are missing after recovery, restore MySQL separately; the job archives content only.

## Limitations

- **Single instance** — Ghost does not support horizontal scaling out of the box
- **MySQL only** — Ghost requires MySQL 8; PostgreSQL is not supported. The bundled HelmForge MySQL dependency is kept on MySQL 8 through `mysql.image.tag`.

### Security Scan: `ghost`

| Framework | Score |
|---|---|
| MITRE + NSA + SOC2 | **89.39%** |

> Security posture acceptable.

## More Information

- [Chart design](DESIGN.md)
- [Database modes](docs/database.md)
- [Operations](docs/operations.md)
- [Security](docs/security.md)
- [Ghost documentation](https://ghost.org/docs/)
- [Source code](https://github.com/helmforgedev/charts/tree/main/charts/ghost)
