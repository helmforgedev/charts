# Atuin Helm chart

Deploy the official [Atuin](https://atuin.sh) shell history sync server with safe SQLite defaults or PostgreSQL for
production scaling.

## Install

```console
helm upgrade --install atuin oci://ghcr.io/helmforgedev/helm/atuin \
  --namespace atuin --create-namespace
```

The default creates one hardened pod, a 5 GiB PVC and a ClusterIP Service. Registration is closed. Temporarily set
`atuin.openRegistration=true` to create the first account, then close it again.

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

## Security Scan

Security scan results use the same Kubescape policy set as HelmForge CI.

Security Scan: atuin

| Framework                |       Score |
| ------------------------ | ----------: |
| MITRE                    | **100.00%** |
| NSA                      |  **92.50%** |
| SOC 2                    |  **90.00%** |
| Aggregate resource score |  **93.94%** |

Kubescape reported no critical or high-severity control failures. The medium findings concern unrestricted ingress and
egress when the optional NetworkPolicy is disabled by default; the low finding belongs to a generated dependency
resource rather than the hardened Atuin container.
