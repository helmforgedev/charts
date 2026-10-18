# Paperless-ngx

A Helm chart for deploying [Paperless-ngx](https://docs.paperless-ngx.com/) on Kubernetes with PostgreSQL or SQLite,
Valkey, persistent document storage, optional Apache Tika and Gotenberg, Gateway API, Ingress, and External Secrets.

## Installation

### HTTPS Repository

```bash
helm repo add helmforge https://repo.helmforge.dev
helm repo update
helm install paperless-ngx helmforge/paperless-ngx
```

### OCI Registry

```bash
helm install paperless-ngx oci://ghcr.io/helmforgedev/helm/paperless-ngx
```

## Features

- **Official Paperless-ngx image** from `ghcr.io/paperless-ngx/paperless-ngx`
- **PostgreSQL subchart** bundled PostgreSQL `2.0.5` for default installs, or SQLite for small installs
- **Valkey subchart** bundled Valkey `2.0.4` for the task queue
- **External services** support for managed PostgreSQL and Valkey
- **Persistent volumes** for data, media, consume, and export directories, each with existing-claim support
- **Office documents and emails** through optional Apache Tika and Gotenberg Deployments
- **Rootless by default** with a restricted security context
- **Superuser bootstrap** with a generated password stored in a Secret
- **Ingress support** configurable ingress with TLS
- **Gateway API HTTPRoute** support for clusters using Gateway API
- **External Secrets Operator** integration for the external database password
- **Dual-stack service controls** through `service.ipFamilyPolicy` and `service.ipFamilies`
- **Values schema** `values.schema.json` validates chart inputs and improves Artifact Hub rendering

## Important Notes

- `replicaCount` is limited to `0` or `1`: the web server, task worker, scheduler, and consumer run in one container
- the default update strategy is `Recreate`, so two pods never share the data and media volumes
- PVCs keep `helm.sh/resource-policy: keep` and survive `helm uninstall`; delete them manually to remove documents
- set `paperless.url` (or an ingress host) to the public URL, otherwise logins through that hostname fail CSRF checks
- the image ships OCR languages `eng`, `deu`, `ita`, `spa`, and `fra`; installing more with `PAPERLESS_OCR_LANGUAGES` requires running as root
- the log line `Permission issue on /usr/src/paperless/...: not owned by current user` is expected: volumes are owned by root with
  group `1000` and group write through `fsGroup`, which Paperless-ngx can write to but reports as a warning
- NFS and SMB consume volumes need `paperless.consumer.pollingInterval` because they do not support inotify
- the default image tag is `3.3.2`, validated against GitHub Releases and `ghcr.io/paperless-ngx/paperless-ngx:3.3.2`
- this chart intentionally does not keep `Chart.lock`; dependencies are resolved by the repository release workflow

## Quick Start

```bash
helm install paperless-ngx oci://ghcr.io/helmforgedev/helm/paperless-ngx \
  --set ingress.enabled=true \
  --set ingress.ingressClassName=traefik \
  --set ingress.hosts[0].host=paperless.example.com
```

Read the generated superuser password:

```bash
kubectl get secret paperless-ngx-admin -o jsonpath='{.data.admin-password}' | base64 -d; echo
```

## Example Configurations

### Basic Install

```yaml
paperless:
  url: https://paperless.example.com
  timeZone: Europe/Berlin
  ocrLanguage: deu+eng

ingress:
  enabled: true
  ingressClassName: traefik
  hosts:
    - host: paperless.example.com
      paths:
        - path: /
          pathType: Prefix
```

### Office Documents, Emails, and a Scanner Inbox

```yaml
tika:
  enabled: true

gotenberg:
  enabled: true

persistence:
  consume:
    existingClaim: scanner-inbox

paperless:
  consumer:
    pollingInterval: 60
```

### SQLite

```yaml
postgresql:
  enabled: false
```

### External Services

```yaml
database:
  mode: external
  external:
    host: postgres.example.internal
    existingSecret: paperless-db
  options: "sslmode=require"

postgresql:
  enabled: false

valkey:
  enabled: false
  external:
    host: valkey.example.internal
    existingSecret: paperless-valkey
```

### Gateway API

```yaml
gateway:
  enabled: true
  parentRefs:
    - name: shared-gateway
      namespace: gateway-system
  hostnames:
    - paperless.example.com
```

### Dual-Stack Service

```yaml
service:
  ipFamilyPolicy: PreferDualStack
  ipFamilies:
    - IPv4
    - IPv6
```

### External Secrets

```yaml
database:
  mode: external
  external:
    host: postgres.example.internal
    existingSecret: paperless-db

postgresql:
  enabled: false

externalSecrets:
  enabled: true
  secretStoreRef:
    name: platform-secrets
    kind: ClusterSecretStore
  data:
    - secretKey: database-password
      remoteRef:
        key: paperless/database
        property: password
```

## Key Values

| Key | Default | Description |
|-----|---------|-------------|
| `replicaCount` | `1` | Number of Paperless-ngx pods, `0` or `1` |
| `strategy` | `{}` | Deployment update strategy, `Recreate` when empty |
| `image.repository` | `ghcr.io/paperless-ngx/paperless-ngx` | Paperless-ngx image repository |
| `image.tag` | `3.3.2` | Paperless-ngx image tag |
| `paperless.url` | `""` | Public URL, derived from the first ingress host or gateway hostname when empty |
| `paperless.secretKey` | `""` | Secret key, auto-generated when empty |
| `paperless.existingSecret` | `""` | Existing secret holding the secret key |
| `paperless.timeZone` | `UTC` | Time zone |
| `paperless.ocrLanguage` | `eng` | Default OCR language, for example `deu+eng` |
| `paperless.admin.enabled` | `true` | Create a superuser on startup |
| `paperless.admin.username` | `admin` | Superuser username |
| `paperless.admin.password` | `""` | Superuser password, auto-generated when empty |
| `paperless.consumer.pollingInterval` | `0` | Poll the consume directory every N seconds; `0` uses inotify |
| `paperless.extraEnv` | `[]` | Additional `PAPERLESS_*` environment variables |
| `database.mode` | `auto` | Database mode: `auto`, `external`, `postgresql`, `sqlite` |
| `database.options` | `""` | `PAPERLESS_DB_OPTIONS` driver options |
| `postgresql.enabled` | `true` | Deploy the PostgreSQL subchart |
| `valkey.enabled` | `true` | Deploy the Valkey subchart |
| `valkey.external.host` | `""` | External Valkey host |
| `persistence.data.size` | `2Gi` | Data PVC size (index, classifier, SQLite) |
| `persistence.media.size` | `10Gi` | Media PVC size (documents) |
| `persistence.consume.enabled` | `false` | Create a consume PVC; use `existingClaim` for a shared scanner volume |
| `persistence.export.enabled` | `false` | Create an export PVC for `document_exporter` |
| `tika.enabled` | `false` | Deploy Apache Tika, together with `gotenberg.enabled` |
| `gotenberg.enabled` | `false` | Deploy Gotenberg, together with `tika.enabled` |
| `resources.limits.memory` | `2Gi` | Paperless-ngx memory limit |
| `service.port` | `80` | Service port exposed by Kubernetes |
| `ingress.enabled` | `false` | Enable ingress |
| `ingress.ingressClassName` | `""` | Ingress class (`traefik`, `nginx`, etc.) |
| `gateway.enabled` | `false` | Render a Gateway API HTTPRoute |
| `externalSecrets.enabled` | `false` | Render an ExternalSecret for the external database password |

## Operations

The post-install notes show the superuser password command, logs for the application and init containers,
the document sanity checker, and an export command. Back up the database and the media volume before upgrades;
`document_exporter` writes documents and metadata to the export directory. Keep the secret key stable across
upgrades to preserve sessions and tokens.

## More Information

- [Architecture Notes](docs/architecture.md)
- [Chart design](DESIGN.md)
- [Examples](examples/simple.yaml)
- [Source code and full values reference](https://github.com/helmforgedev/charts/tree/main/charts/paperless-ngx)

### Security Scan: `paperless-ngx`

| Framework | Score |
|---|---|
| MITRE + NSA + SOC2 | **89.82684%** |

> ✅ Security posture acceptable.

<!-- @AI-METADATA
type: chart-readme
title: Paperless-ngx
description: Installation guide, values reference, and operational overview for the Paperless-ngx Helm chart

keywords: paperless-ngx, paperless, document-management, ocr, postgres, valkey, sqlite, tika, gotenberg, gateway-api, external-secrets, dual-stack, helm

purpose: User-facing chart documentation with install instructions, examples, and values reference
scope: Chart

relations:
  - charts/paperless-ngx/docs/architecture.md
  - charts/paperless-ngx/DESIGN.md
path: charts/paperless-ngx/README.md
version: 1.0
date: 2026-10-18
-->
