<!-- SPDX-License-Identifier: Apache-2.0 -->

# Apache Answer Helm Chart

Deploy [Apache Answer](https://answer.apache.org/) on Kubernetes with an official,
pinned image, persistent storage, explicit listener configuration, optional SQL
databases, secure defaults, and database-aware backups.

## Features

- SQLite by default for a small, zero-dependency installation.
- Optional HelmForge PostgreSQL and MySQL `2.1.1` subcharts.
- External PostgreSQL or MySQL with passwords sourced from an existing Secret.
- Unattended initial setup using the environment variables supported upstream.
- A configurable application listener independent from the Kubernetes Service port.
- Startup, liveness, and readiness probes against the named HTTP port.
- A default ingress NetworkPolicy that exposes only the Answer HTTP listener.
- RuntimeDefault seccomp, non-root execution, a read-only root filesystem, dropped
  capabilities, and disabled service-account-token mounting.
- Ingress and Gateway API routing, dual-stack Services, External Secrets, and
  database-aware S3-compatible backups.
- Scheduling controls, extra volumes, pod metadata, and extra manifests.

## Architecture

The chart always deploys one Answer server and one Service. The Service forwards
its client-facing `service.port` to the named `http` container port. Answer receives
`INSTALL_PORT`, `SITE_ADDR`, and `SWAGGER_ADDRESS_PORT` from
`containerPorts.http`, so changing the value changes the process listener instead
of only changing Kubernetes metadata.

SQLite stores the database, uploads, generated configuration, and plugins under
`/data`. PostgreSQL and MySQL modes retain the Answer data volume for uploads and
application state while placing relational data in the selected database. See
[DESIGN.md](DESIGN.md) for trust boundaries and lifecycle decisions.

## Installation

Install from the HTTPS repository:

```bash
helm repo add helmforge https://repo.helmforge.dev
helm repo update
helm install answer helmforge/answer
```

Or install from OCI:

```bash
helm install answer oci://ghcr.io/helmforgedev/helm/answer
```

Inspect every supported value before production use:

```bash
helm show values helmforge/answer
```

## Usage Examples

### SQLite

SQLite is suitable for evaluation and small installations with a single Answer
pod. Keep persistence enabled because `/data` contains both the database and
uploaded content.

```yaml
answer:
  siteName: My Q&A
  siteUrl: https://qa.example.com

admin:
  existingSecret: answer-admin
  existingSecretPasswordKey: admin-password

persistence:
  enabled: true
  size: 10Gi
```

### Bundled PostgreSQL

```yaml
database:
  mode: postgresql

postgresql:
  enabled: true
  auth:
    database: answer
    username: answer
    password: replace-me
  standalone:
    persistence:
      enabled: true
      size: 20Gi
```

For GitOps with an external database, provide credentials through
`database.external.existingSecret` and `externalSecrets.database`. Bundled
PostgreSQL mode rejects `database.external.existingSecret`, so this flow does
not apply to the bundled database.

### External database

```yaml
database:
  mode: external
  external:
    vendor: postgres
    host: postgres.database.svc.cluster.local
    port: "5432"
    name: answer
    username: answer
    existingSecret: answer-database
    existingSecretPasswordKey: database-password
```

The chart rejects ambiguous combinations, such as enabling a bundled database
while also configuring an external host.

### Independent listener and Service ports

```yaml
containerPorts:
  http: 8080

service:
  port: 9080
```

This makes Answer listen on `8080` inside the pod while clients use port `9080`
on the Service. Probes and the named Service target continue to follow the real
listener. Do not add `INSTALL_PORT`, `SITE_ADDR`, or `SWAGGER_ADDRESS_PORT` to
`answer.extraEnv`; the chart rejects those overrides to prevent split-brain port
configuration.

## Configuration

| Key | Default | Description |
| --- | --- | --- |
| `global` | `{}` | Values shared with chart dependencies. |
| `image.repository` | `docker.io/apache/answer` | Official Apache Answer image repository. |
| `image.tag` | `2.0.3` | Pinned Answer image tag. |
| `answer.siteName` | `Apache Answer` | Site name used during unattended installation. |
| `answer.siteUrl` | `""` | Public URL; inferred from routing when empty. |
| `answer.autoInstall` | `true` | Run the supported unattended installation flow. |
| `answer.logLevel` | `INFO` | Application log level. |
| `answer.extraEnv` | `[]` | Additional non-listener environment variables. |
| `containerPorts.http` | `80` | Port opened by the Answer process. |
| `service.port` | `80` | Client-facing Kubernetes Service port. |
| `database.mode` | `auto` | `auto`, `sqlite`, `external`, `postgresql`, or `mysql`. |
| `postgresql.enabled` | `false` | Deploy the PostgreSQL subchart. |
| `mysql.enabled` | `false` | Deploy the MySQL subchart. |
| `persistence.enabled` | `true` | Persist `/data`. |
| `persistence.size` | `5Gi` | Answer data PVC size. |
| `networkPolicy.enabled` | `true` | Limit inbound traffic to the named HTTP listener. |
| `networkPolicy.extraIngress` | `[]` | Optional peers that may reach the listener. |
| `serviceAccount.automountServiceAccountToken` | `false` | Mount Kubernetes API credentials. |
| `ingress.enabled` | `false` | Render an Ingress. |
| `gateway.enabled` | `false` | Render an HTTPRoute. |
| `externalSecrets.enabled` | `false` | Render ExternalSecret resources. |
| `backup.enabled` | `false` | Render the database-aware backup CronJob. |

The JSON schema validates the full values contract. Database, backup, routing,
and External Secrets examples are also available under `examples/` and `docs/`.

## Security

The default pod runs as UID/GID `1000`, uses RuntimeDefault seccomp, prevents
privilege escalation, drops all Linux capabilities, and adds only
`NET_BIND_SERVICE` because the official default listener is port `80`. The root
filesystem is read-only; writable state is limited to `/data` and an ephemeral
`/tmp`. The application does not need Kubernetes API access, so token automounting
is disabled.

The default NetworkPolicy selects only the Answer server component. It accepts
traffic solely on the named HTTP port and does not impose egress restrictions,
because Answer may need SMTP, identity-provider, plugin, and embedded-content
connections. With an empty `networkPolicy.extraIngress`, any source can reach the
HTTP listener. Populate the list with namespace or pod selectors to restrict the
allowed sources to your ingress controller or gateway.

Secrets generated by the chart are intended for initial setup. For production,
use `admin.existingSecret`, database existing-Secret settings, or the optional
External Secrets integration. Never store real credentials in a committed values
file.

## Operations and Troubleshooting

Check rollout and application health:

```bash
kubectl rollout status deployment/RELEASE-answer -n NAMESPACE
kubectl get pods,svc,pvc -n NAMESPACE -l app.kubernetes.io/instance=RELEASE
kubectl logs deployment/RELEASE-answer -n NAMESPACE -c answer --tail=200
```

If probes fail after changing ports, compare `containerPorts.http` with the
rendered `SITE_ADDR`; `service.port` may differ, but `targetPort` must remain the
named `http` port. Confirm the process endpoint through the Service:

```bash
kubectl run answer-health -n NAMESPACE --rm -i --restart=Never \
  --image=docker.io/library/busybox:1.37 -- \
  wget -qO- http://RELEASE-answer:SERVICE_PORT/healthz
```

For database startup failures, inspect the `wait-for-db` init container and verify
DNS, port, credentials, and the selected `database.mode`:

```bash
kubectl logs deployment/RELEASE-answer -n NAMESPACE -c wait-for-db
```

Back up `/data` and the selected database before changing database mode, storage
classes, or major application versions. The chart does not migrate data between
SQLite, PostgreSQL, and MySQL. See [database operations](docs/database.md),
[backup and restore](docs/backup.md), [routing](docs/routing.md), and
[External Secrets](docs/external-secrets.md). The [security guide](docs/security.md)
explains hardening overrides and policy behavior.

## Resources Generated

| Resource | Condition |
| --- | --- |
| Deployment, Service, NetworkPolicy | Always, except NetworkPolicy when disabled |
| ServiceAccount | `serviceAccount.create` |
| Admin or database Secret | No corresponding existing Secret is configured |
| PVC | Persistence enabled without an existing claim |
| Ingress or HTTPRoute | Corresponding routing option enabled |
| ExternalSecret | External Secrets and the specific secret type enabled |
| Backup ConfigMap, Secret, and CronJob | Backup enabled |

## More Information

- [Apache Answer documentation](https://answer.apache.org/docs/)
- [Chart design](DESIGN.md)
- [Database configuration](docs/database.md)
- [Backup and restore](docs/backup.md)
- [Routing](docs/routing.md)
- [External Secrets](docs/external-secrets.md)
- [Security and network policy](docs/security.md)
- [HelmForge chart source](https://github.com/helmforgedev/charts/tree/main/charts/answer)

### Security Scan: answer

| Framework | Score |
| --- | --- |
| MITRE + NSA + SOC2 | **86.580086%** |

Security posture: acceptable.
