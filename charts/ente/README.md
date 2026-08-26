# Ente

A production-ready Helm chart for [Ente](https://ente.io), the end-to-end
encrypted photo platform. The chart deploys Museum, Ente's web applications,
and HelmForge PostgreSQL while using durable external S3-compatible object
storage.

## Status

- Maturity: stable
- Kubernetes: 1.26 or newer
- Architectures: amd64 and arm64
- Museum image: official `ghcr.io/ente/server`, pinned to the upstream
  production commit
- Web image: official `ghcr.io/ente/web`, pinned to an immutable commit
- License: Apache-2.0 for the chart; Ente is AGPL-3.0

### Security Scan: `ente`

| Framework | Score |
|---|---|
| MITRE + NSA + SOC2 | **89.11616%** |

> Security posture acceptable. Kubescape 4.0.9 reported no critical failures.

## Architecture

Ente clients encrypt photos before upload. Museum stores metadata and encryption
material in PostgreSQL and returns presigned object-storage URLs. Clients then
transfer encrypted objects directly to S3.

```text
Browser / mobile client
        | HTTPS
        +--------------------> Ente web applications
        |
        +--------------------> Museum API
                                  | PostgreSQL protocol
                                  +------> PostgreSQL
                                  |
                                  | S3 control operations
                                  +------> external S3
        |
        | presigned S3 URLs
        +------------------------> external S3
```

The S3 endpoint must be reachable from both the cluster and end-user clients.
The chart deliberately does not bundle MinIO because upstream recommends an
external provider for long-lived self-hosted installations.

## Features

- Official, immutable, multi-architecture Museum and web images
- Stable cryptographic keys preserved through Helm upgrades
- Existing Secret and External Secrets Operator integration
- HelmForge PostgreSQL dependency or external PostgreSQL
- Museum API and singleton job-worker HA topology
- PostgreSQL advisory-lock gate for serialized HA migrations
- Photos, Accounts, and Albums enabled by default
- Auth, Cast, Share, Embed, and Memories optional
- One hardened web Deployment instead of duplicated images
- Non-root containers and read-only root filesystems
- Restricted service accounts without API tokens
- Startup, readiness, and liveness probes
- Ingress with per-application hosts and TLS
- Gateway API HTTPRoutes
- Dual-stack Services
- PDB and HPA for API and web workloads
- NetworkPolicy with S3, SMTP, and private-network extension points
- Native Museum metrics, ServiceMonitor, and PrometheusRule
- PostgreSQL dump-to-S3 CronJob
- Helm test hook for API and enabled web applications
- Complete JSON schema, CI scenarios, and unit tests

## Installation

### Helm repository

```bash
helm repo add helmforge https://repo.helmforge.dev
helm repo update
helm install ente helmforge/ente -f values-production.yaml
```

### OCI registry

```bash
helm install ente oci://ghcr.io/helmforgedev/helm/ente \
  -f values-production.yaml
```

## Required production inputs

A production installation needs:

1. An S3-compatible bucket without object lock or versioning.
2. CORS configured for the Ente web origins.
3. A public HTTPS Museum API origin.
4. HTTPS hosts for Photos, Accounts, and Albums.
5. Durable Museum cryptographic secrets.
6. Durable PostgreSQL.
7. SMTP is strongly recommended for one-time login codes. Without SMTP, Museum
   writes the codes to its logs and the installation is not suitable for normal
   production authentication.

Set `productionMode=true` to reject evaluation placeholders and local-bucket
workarounds.

## Production quick start

Create Museum, S3, and SMTP Secrets before installation:

```yaml
apiVersion: v1
kind: Secret
metadata:
  name: ente-museum
type: Opaque
stringData:
  encryption-key: REPLACE_WITH_32_BYTE_STANDARD_BASE64
  hash-key: REPLACE_WITH_64_BYTE_STANDARD_BASE64
  jwt-secret: REPLACE_WITH_32_BYTE_URL_SAFE_BASE64
---
apiVersion: v1
kind: Secret
metadata:
  name: ente-s3
type: Opaque
stringData:
  access-key: REPLACE_WITH_ACCESS_KEY
  secret-key: REPLACE_WITH_SECRET_KEY
---
apiVersion: v1
kind: Secret
metadata:
  name: ente-smtp
type: Opaque
stringData:
  username: REPLACE_WITH_SMTP_USERNAME
  password: REPLACE_WITH_SMTP_PASSWORD
```

Generate Ente key material with a cryptographically secure tool. Do not use the
fixed development values from upstream `local.yaml`.

Create `values-production.yaml`:

```yaml
productionMode: true

museum:
  externalUrl: https://api.ente.company.tld
  existingSecret: ente-museum
  config:
    webauthn:
      rpid: accounts.ente.company.tld
      rporigins:
        - https://accounts.ente.company.tld

storage:
  s3:
    endpoint: https://s3.us-east-1.amazonaws.com
    region: us-east-1
    bucket: company-ente-photos
    existingSecret: ente-s3

smtp:
  enabled: true
  host: smtp.company.tld
  port: 587
  email: ente@company.tld
  senderName: Ente
  encryption: tls
  existingSecret: ente-smtp

web:
  apps:
    photos:
      externalUrl: https://photos.ente.company.tld
    accounts:
      externalUrl: https://accounts.ente.company.tld
    albums:
      externalUrl: https://albums.ente.company.tld

ingress:
  enabled: true
  ingressClassName: nginx
  hosts:
    - host: api.ente.company.tld
      service: museum
      paths:
        - path: /
          pathType: Prefix
    - host: photos.ente.company.tld
      service: photos
      paths:
        - path: /
          pathType: Prefix
    - host: accounts.ente.company.tld
      service: accounts
      paths:
        - path: /
          pathType: Prefix
    - host: albums.ente.company.tld
      service: albums
      paths:
        - path: /
          pathType: Prefix
  tls:
    - secretName: ente-tls
      hosts:
        - api.ente.company.tld
        - photos.ente.company.tld
        - accounts.ente.company.tld
        - albums.ente.company.tld
```

## PostgreSQL modes

The default `database.mode=auto` chooses the external configuration when set,
otherwise the HelmForge PostgreSQL dependency.

### Bundled PostgreSQL

```yaml
postgresql:
  enabled: true
  architecture: standalone
  auth:
    database: ente
    username: ente
  standalone:
    persistence:
      enabled: true
      size: 100Gi
```

The bundled architecture is durable but does not provide automatic database
failover. Use managed PostgreSQL or a Kubernetes database operator for HA.

### External PostgreSQL

```yaml
database:
  mode: external
  external:
    host: ente-rw.database.svc.cluster.local
    port: 5432
    name: ente
    username: ente
    existingSecret: ente-postgresql
    existingSecretPasswordKey: database-password
    sslMode: verify-full

postgresql:
  enabled: false
```

Museum supports PostgreSQL 14 and newer and applies migrations during startup.

## High availability

Museum runs scheduled and background work inside the API process. Multiple
cron-enabled replicas are unsafe. The chart rejects that configuration.

Use API replicas with jobs disabled plus one singleton worker:

```yaml
museum:
  api:
    replicaCount: 3
    skipBackgroundJobs: true
  worker:
    enabled: true

web:
  replicaCount: 3

pdb:
  museum:
    enabled: true
  web:
    enabled: true
```

The worker has no public Service and uses `Recreate` to prevent overlapping
schedulers during rollout.

Every Museum process attempts database migrations during startup. In HA, the
chart adds a hardened PostgreSQL client sidecar to every Museum pod. The sidecar
uses `pg_try_advisory_lock` without holding an active transaction, starts one
Museum process, waits for port 8080, and only then releases the next pod. This
avoids concurrent `CREATE INDEX CONCURRENTLY` migrations and a dirty migration
state. Disabling `museum.migrationGate` in an HA or HPA topology is rejected.

## Autoscaling

```yaml
museum:
  api:
    skipBackgroundJobs: true
  worker:
    enabled: true

autoscaling:
  museum:
    enabled: true
    minReplicas: 2
    maxReplicas: 8
    targetCPUUtilizationPercentage: 70
  web:
    enabled: true
    minReplicas: 2
    maxReplicas: 10
    targetCPUUtilizationPercentage: 70
```

Resource requests must remain set for utilization-based HPA metrics.

## External Secrets Operator

The chart accepts complete ExternalSecret specifications in `items[]`. This
keeps provider-specific authentication and advanced ESO features available.

```yaml
museum:
  existingSecret: ente-museum
storage:
  s3:
    existingSecret: ente-s3

externalSecrets:
  enabled: true
  items:
    - name: museum
      spec:
        secretStoreRef:
          name: production
          kind: ClusterSecretStore
        target:
          name: ente-museum
        dataFrom:
          - extract:
              key: ente/museum
    - name: s3
      spec:
        secretStoreRef:
          name: production
          kind: ClusterSecretStore
        target:
          name: ente-s3
        dataFrom:
          - extract:
              key: ente/s3
```

## Object storage

Museum readiness only checks PostgreSQL. Validate S3 independently with an
upload and download through an Ente client.

Required CORS methods:

- GET
- HEAD
- POST
- PUT
- DELETE

Required request headers include `Content-Type`, `Content-MD5`, and
`UPLOAD-URL`. Expose response headers needed by your provider and Ente client.

Do not enable `storage.s3.localBuckets` in production. That setting activates
upstream workarounds for local MinIO evaluation environments.

## Backup and restore

Enable the PostgreSQL dump CronJob:

```yaml
backup:
  enabled: true
  schedule: "0 3 * * *"
  s3:
    endpoint: https://backup.example.com
    bucket: platform-backups
    prefix: ente/postgresql
    existingSecret: ente-backup-s3
```

The CronJob backs up PostgreSQL only. Back up the object bucket and Museum
Secrets with provider-native tools. Restore all three as one consistency set.

Test a manual backup:

```bash
kubectl create job ente-backup-test \
  --from=cronjob/ente-postgresql-backup
kubectl wait --for=condition=complete job/ente-backup-test --timeout=10m
kubectl logs job/ente-backup-test --all-containers
```

## Observability

Museum exposes Prometheus metrics on port 2112.

```yaml
metrics:
  enabled: true
  serviceMonitor:
    enabled: true
    labels:
      release: kube-prometheus-stack
  prometheusRule:
    enabled: true
```

ServiceMonitor and PrometheusRule remain disabled by default because they
require Prometheus Operator CRDs.

## Network policy

```yaml
networkPolicy:
  enabled: true
  egress:
    allowDNS: true
    allowSameNamespacePostgresql: true
    allowObjectStorage: true
    objectStoragePorts:
      - 443
```

The default object-storage rule permits public IPv4 and IPv6 destinations on
TCP 443 while excluding private and link-local ranges. For a private or
in-cluster S3 endpoint, replace
`networkPolicy.egress.objectStorageDestinations` with explicit `ipBlock`,
`namespaceSelector`, or `podSelector` peers. Add plaintext ports such as 80 or
9000 to `objectStoragePorts` only when the endpoint and network are trusted.

For external PostgreSQL or restricted SMTP, add shared rules to
`networkPolicy.extraEgress` or Museum-only rules to
`networkPolicy.egress.museumExtraRules`. NetworkPolicy cannot authorize a DNS
hostname directly; use stable provider CIDRs or a controlled egress gateway.

## Gateway API

```yaml
gateway:
  enabled: true
  parentRefs:
    - name: public
      namespace: gateway-system
  routes:
    - name: museum
      service: museum
      hostnames: [api.ente.example.com]
    - name: photos
      service: photos
      hostnames: [photos.ente.example.com]
```

TLS is configured on the referenced Gateway listener.

## Web applications

The single web image contains multiple static applications. Enabled apps receive
individual Services and may receive individual routes.

| Application | Default | Container port |
| --- | --- | ---: |
| Photos | enabled | 3000 |
| Accounts | enabled | 3001 |
| Albums | enabled | 3002 |
| Auth | disabled | 3003 |
| Cast | disabled | 3004 |
| Share | disabled | 3005 |
| Embed | disabled | 3006 |
| Memories | disabled | 3010 |

Ente Paste and Locker are separate products and are outside this chart's scope.

## Upgrade procedure

1. Back up Museum Secrets, PostgreSQL, and S3.
2. Read chart and upstream release notes.
3. Render the upgrade with production values.
4. Confirm immutable image changes intentionally.
5. Run `helm upgrade` without `--reuse-values` so new chart defaults are merged.
6. Wait for the API, worker, and web rollouts.
7. Run `helm test`.
8. Verify account login, upload, download, and public albums.

```bash
helm upgrade ente oci://ghcr.io/helmforgedev/helm/ente \
  -f values-production.yaml \
  --wait \
  --timeout 10m
helm test ente --logs
```

## Troubleshooting

### Museum is not Ready

`/ping` checks PostgreSQL. Inspect database DNS, credentials, TLS mode, and
Museum logs.

### Museum is Ready but uploads fail

Check S3 client reachability, credentials, bucket CORS, endpoint TLS, and
path-style settings. `/ping` does not check S3.

### Login code does not arrive

Check SMTP host, port, encryption, sender policy, and credentials. Without SMTP,
the code appears in Museum logs.

### Passkeys fail

The Accounts hostname must match `museum.config.webauthn.rpid` and the exact
HTTPS origin must appear in `rporigins`.

### Upgrade rotates keys

Restore the previous Museum Secret immediately. Configure `existingSecret` or
ensure the Helm-managed Secret was not deleted before the upgrade.

### Multiple jobs execute

Ensure every API uses `skipBackgroundJobs=true` and exactly one worker exists.

### Web pod cannot write files

Do not remove the web-content, nginx-cache, nginx-run, or tmp emptyDir mounts.
They are required by the hardened read-only runtime.

### NetworkPolicy blocks PostgreSQL

Add the external database namespace, pod selector, or CIDR to
`networkPolicy.extraEgress` for shared access or `museumExtraRules` for Museum
only.

### Museum reports a dirty database version

Stop concurrent Museum starts and restore or repair PostgreSQL according to the
upstream migration procedure. Keep `museum.migrationGate.enabled=true` for HA
and inspect both `museum` and `migration-gate` container logs before retrying.

### Metrics resources are rejected

Install Prometheus Operator CRDs or disable ServiceMonitor and PrometheusRule.

### Backup upload fails

Inspect both `dump` init-container and `upload` container logs. Confirm the
backup bucket and Secret independently from the Ente object bucket.

## Validation

```bash
helm lint . --strict
helm unittest .
helm template ente . -f examples/production-ha.yaml
helm test ente -n ente --logs
```

## Additional documentation

- [Architecture](docs/architecture.md)
- [Object storage](docs/object-storage.md)
- [High availability](docs/high-availability.md)
- [Backup and restore](docs/backup-restore.md)
- [Security](docs/security.md)
- [Upstream self-hosting documentation](https://help.ente.io/self-hosting)

## Non-goals

This chart does not deploy S3, SMTP, Paste, Locker, or an automatic PostgreSQL
failover system. It does not treat Ente's multi-bucket replication as backup.

## Contributing

See [CONTRIBUTING.md](../../CONTRIBUTING.md).
