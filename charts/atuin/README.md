<!-- SPDX-License-Identifier: Apache-2.0 -->

# Atuin Helm chart

Deploy the official [Atuin](https://atuin.sh) shell history sync server with safe SQLite defaults or PostgreSQL for
production scaling.

## Features

- Official, pinned Atuin image with no floating tags.
- Safe single-replica SQLite default and shared-state PostgreSQL topology.
- Independently configurable application listener and Kubernetes Service port.
- Ingress and Gateway API exposure with TLS-first operational guidance.
- Hardened non-root runtime, optional NetworkPolicy, HPA and disruption budget.
- Native External Secrets resources and a separate private metrics listener.
- Startup, readiness and liveness probes that follow the configured route prefix.

## Architecture

The default topology runs one Atuin server with its SQLite database on a
ReadWriteOnce PVC. PostgreSQL mode uses either the HelmForge PostgreSQL
dependency or a complete connection URI read from an existing Secret. Atuin is
stateless once PostgreSQL owns the shared state, so replicas and autoscaling can
then be enabled. See [DESIGN.md](DESIGN.md) for topology diagrams, boundaries
and intentional non-goals.

## Install

```console
helm upgrade --install atuin oci://ghcr.io/helmforgedev/helm/atuin \
  --namespace atuin --create-namespace
```

The default creates one hardened pod, a 5 GiB PVC and a ClusterIP Service. Registration is closed. Temporarily set
`atuin.openRegistration=true` to create the first account, then close it again.

## Configuration

`containerPorts.http` configures the real Atuin HTTP listener through
`ATUIN_PORT`. `service.port` is the independent client-facing Kubernetes
Service port and targets the named `http` container port. Both default to
`8888`, but changing only `service.port` does not move the process listener.
Because Atuin runs as UID 1000 with all capabilities dropped, application and
metrics listener ports must be 1024 or higher.

| Value                                           | Default               | Purpose |
| ----------------------------------------------- | --------------------- | ------- |
| `containerPorts.http`                           | `8888`                | Atuin HTTP process listener |
| `service.port`                                  | `8888`                | Kubernetes Service-facing port |
| `atuin.openRegistration`                        | `false`               | Allow controlled account registration |
| `atuin.path`                                    | `""`                  | Optional prefix for API and health routes |
| `atuin.maxRecordSize`                           | `1GiB`                | Maximum encrypted sync record size |
| `database.type`                                 | `sqlite`              | Select SQLite or PostgreSQL |
| `database.existingSecret`                       | `""`                  | Secret containing an external PostgreSQL URI |
| `postgresql.enabled`                            | `false`               | Deploy the HelmForge PostgreSQL dependency |
| `persistence.size`                              | `5Gi`                 | SQLite PVC capacity |
| `metrics.enabled`                               | `false`               | Enable the private Prometheus listener |
| `metrics.port`                                  | `9001`                | Prometheus process and Service port |
| `serviceAccount.automountServiceAccountToken`   | `false`               | Keep the Kubernetes API token unmounted |
| `securityContext.readOnlyRootFilesystem`        | `true`                | Prevent writes outside declared volumes |
| `networkPolicy.enabled`                         | `false`               | Enable baseline ingress and egress isolation |

The complete contract is in `values.yaml` and `values.schema.json`. Detailed
database, exposure, operations and security guidance is linked below.

## Examples

The [`examples/`](examples/) directory includes simple SQLite, production
PostgreSQL, Gateway API and External Secrets configurations. Start from the
smallest applicable example and keep credentials in Secrets rather than plain
values.

## Production PostgreSQL

```yaml
database:
  type: postgresql
postgresql:
  enabled: true
  auth:
    database: atuin
    username: atuin
```

The HelmForge PostgreSQL dependency generates and retains credentials. With an external database, create a Secret whose
`db-uri` value is a complete `postgres://` URI, set `database.type=postgresql`, `database.existingSecret`, and leave
`postgresql.enabled=false`.

Every Atuin replica may open 100 PostgreSQL connections. Size the database or pooler before increasing replicas.
Upstream migrations run automatically on startup; back up before upgrades.

## HTTPS

Public installations must terminate TLS at Ingress or Gateway API. Atuin warns that passwords are exposed over plain
HTTP. See [exposure](docs/exposure.md).

## Monitoring

Set `metrics.enabled=true` to expose the private metrics Service. Set `metrics.serviceMonitor.enabled=true` when
Prometheus Operator CRDs are installed.

## Security

The pod runs as UID/GID 1000 with RuntimeDefault seccomp, a read-only root
filesystem, no privilege escalation, every Linux capability dropped and no
automatically mounted service account token. Public endpoints must terminate
TLS because login credentials are not protected by Atuin's history encryption.
See [security](docs/security.md) before enabling public exposure or external
database and webhook egress.

## Backup

For SQLite, stop or quiesce Atuin before copying the database and its WAL files, or use a CSI volume snapshot with
application coordination. For PostgreSQL, use `pg_dump --format=custom --no-owner --no-acl` or your managed database
backup facility. See [operations](docs/operations.md).

## S3 clarification

Atuin Server 18.23.0 stores synchronized records in SQL and has no native S3 backend. This chart does not expose
misleading S3 application settings. An independent backup system may still store database backups in object storage.

## Documentation

- [Configuration](docs/configuration.md)
- [Exposure](docs/exposure.md)
- [Operations](docs/operations.md)
- [Security](docs/security.md)
- [Design](DESIGN.md)

## Uninstall

```console
helm uninstall atuin --namespace atuin
```

Helm deletes the default PVC during uninstall unless
`persistence.annotations` includes `helm.sh/resource-policy: keep`. Confirm
backups before uninstalling or removing storage.

## Troubleshooting

- If a SQLite release rejects multiple replicas, switch to PostgreSQL before
  scaling; this is an intentional data-safety check.
- If the pod never becomes ready, inspect the init container, database Secret
  keys and PostgreSQL Service endpoints.
- If clients receive 404 responses, align `atuin.path`, proxy rewriting and the
  client `sync_address`.
- If health succeeds while sync fails, inspect database connectivity and run a
  real login or sync canary; `/healthz` only proves HTTP process availability.
- If metrics have no targets, confirm both `metrics.enabled` and
  `metrics.serviceMonitor.enabled`, then inspect ServiceMonitor selectors.

## Security Scan: `atuin`

Security scan results use the same Kubescape policy set as HelmForge CI.

| Framework                |       Score |
| ------------------------ | ----------: |
| MITRE                    | **100.00%** |
| NSA                      |  **92.50%** |
| SOC 2                    |  **90.00%** |
| Aggregate resource score |  **93.94%** |

Kubescape reported no critical or high-severity control failures. The medium findings concern unrestricted ingress and
egress when the optional NetworkPolicy is disabled by default; the low finding belongs to a generated dependency
resource rather than the hardened Atuin container.
