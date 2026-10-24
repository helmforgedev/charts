<!-- SPDX-License-Identifier: Apache-2.0 -->
# Flowise configuration

The chart validates the final merged values with `values.schema.json` and with
topology-specific template checks. Use an existing Secret for production
credentials and keep inline values for disposable environments only.

## Application and Service ports

`flowise.containerPort` controls the Flowise process through `PORT` and the
container's named `http` port. `service.port` controls only the Kubernetes
Service. They can differ:

```yaml
flowise:
  containerPort: 3100
service:
  port: 8080
```

Ingress and Gateway API resources target the Service, which targets the named
container port.

## Authentication Secret

Create the Secret before installing the chart:

```bash
kubectl create secret generic flowise-auth \
  --from-literal=encryption-key='replace-me' \
  --from-literal=jwt-auth-token-secret='replace-me' \
  --from-literal=jwt-refresh-token-secret='replace-me' \
  --from-literal=express-session-secret='replace-me' \
  --from-literal=token-hash-secret='replace-me'
```

Reference it with `auth.existingSecret: flowise-auth`. Key names can be changed
through the `auth.existingSecret*Key` values. External Secrets Operator users
can set `externalSecrets.enabled=true`, set `auth.existingSecret`, and provide
the remote mappings in `externalSecrets.data`.

## External database

For external PostgreSQL:

```yaml
database:
  mode: external
  external:
    vendor: postgres
    host: postgres.database.svc.cluster.local
    port: 5432
    name: flowise
    username: flowise
    existingSecret: flowise-database
    existingSecretPasswordKey: database-password
    ssl: true
    rejectUnauthorized: true
```

MySQL is supported by setting `vendor: mysql`. Queue mode should use
PostgreSQL, as recommended by Flowise for production workloads.

## Queue and S3

Queue mode requires Redis, a non-SQLite database, S3 storage, and
`persistence.enabled=false`. External Redis credentials can come from
`redis.external.existingSecret`. S3 credentials can come from
`storage.s3.existingSecret` with the keys configured by
`existingSecretAccessKeyKey` and `existingSecretSecretKeyKey`.

## NetworkPolicy

The main policy accepts the application listener from all sources by default.
Restrict it to ingress-controller namespaces when labels are stable:

```yaml
networkPolicy:
  ingressFrom:
    - namespaceSelector:
        matchLabels:
          kubernetes.io/metadata.name: ingress-system
```

The default egress rule is deliberately open because database, Redis, S3, and
model-provider addresses are installation-specific. Replacing it with a closed
allowlist also requires DNS egress.

## Writable paths

The container root filesystem is read-only. The chart mounts writable data at
`persistence.mountPath` and a separate `emptyDir` at `/tmp`. Keep
`database.sqlite.path`, `storage.local.path`, `flowise.logPath`, and
`flowise.secretKeyPath` under the writable data mount unless separately mounted
through `extraVolumes` and `extraVolumeMounts`.
