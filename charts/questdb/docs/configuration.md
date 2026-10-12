# QuestDB configuration

## Server properties

Set ordinary QuestDB properties under `questdb.serverConfig`; the chart maps
them to QuestDB's `QDB_` environment convention:

```yaml
questdb:
  serverConfig:
    cairo.sql.copy.root: /var/lib/questdb/import
```

Environment variables in `questdb.extraEnv` override file properties according
to QuestDB's `QDB_` mapping. Do not put passwords or tokens in either field.
Use a Secret, ExternalSecret or an additional read-only Secret volume instead.

## Password Secret

The default Secret is generated once and retained. To manage it externally:

```yaml
questdb:
  existingSecret: questdb-auth
  pgPasswordKey: pg-password
  httpPasswordKey: http-password
```

Both keys are required. They are projected with file mode `0400` and consumed
through the upstream `_FILE` configuration convention.

## Persistence

```yaml
persistence:
  enabled: true
  storageClass: fast-block
  size: 100Gi
```

Use an existing recovery claim with `persistence.existingClaim`. Setting
`persistence.enabled: false` creates an ephemeral database suitable only for
evaluation. Do not use NFS or distributed filesystems for QuestDB storage.

## External exposure

Ingress requires an explicit class, host and TLS Secret. Gateway API routes must
reference a parent Gateway that terminates TLS. Only HTTP port 9000 is routed.
PostgreSQL, ILP TCP and QWP require a trusted internal network or service mesh if
transport encryption is mandatory.

When `metrics.serviceMonitor.enabled` and NetworkPolicy are both enabled, set
`networkPolicy.metricsFrom` to the Prometheus namespace selector. The chart
rejects a ServiceMonitor that would be unreachable under the default policy.
