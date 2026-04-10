# openHAB

Production-ready openHAB home automation platform for Kubernetes.

openHAB is an open-source home automation platform that integrates with hundreds
of smart home technologies and provides a unified interface for all your devices.

> **Note**: openHAB does not support horizontal scaling. This chart deploys a
> single instance backed by three persistent volumes.

## Installation

### Using HTTPS Repository

```bash
helm repo add helmforge https://repo.helmforge.dev
helm repo update
helm install my-openhab helmforge/openhab
```

### Using OCI Repository

```bash
helm install my-openhab oci://ghcr.io/helmforgedev/helm/openhab --version 0.1.0
```

## Quick Start

### Minimal Installation

```bash
helm install my-openhab helmforge/openhab
```

After installation, port-forward and open the setup wizard:

```bash
kubectl port-forward svc/my-openhab 8080:8080
# Open http://127.0.0.1:8080 and complete the admin setup wizard
```

### With Ingress

```bash
helm install my-openhab helmforge/openhab \
  --set ingress.enabled=true \
  --set ingress.ingressClassName=nginx \
  --set "ingress.hosts[0].host=openhab.myhouse.com" \
  --set "ingress.hosts[0].paths[0].path=/" \
  --set "ingress.hosts[0].paths[0].pathType=Prefix"
```

### With GitOps Configuration (ConfigMaps)

```yaml
# values.yaml
configMaps:
  sitemaps:
    enabled: true
    files:
      myhome.sitemap: |
        sitemap myhome label="My Home" {
          Frame label="Lights" {
            Switch item=Light_Living label="Living Room"
          }
        }
  items:
    enabled: true
    files:
      lights.items: |
        Switch Light_Living "Living Room" <light>
```

```bash
helm install my-openhab helmforge/openhab -f values.yaml
```

## Features

- Single-instance StatefulSet with stable PVC attachment
- Three persistent volumes (userdata, conf, addons) with configurable sizes
- ConfigMap-based live configuration reload (sitemaps, things, items)
- Correct security context (`fsGroup: 9001`; `runAsUser`/`runAsGroup` intentionally unset — entrypoint manages privilege drop via gosu)
- Startup/liveness/readiness probes via `/rest/uuid` (returns 200, no auth required)
- Optional Ingress with websocket annotation guidance for `/rest/events`
- Optional Karaf SSH admin console (port 8101)
- Optional admin credentials Secret
- Prometheus metrics via `/rest/metrics/prometheus` (pod annotations + ServiceMonitor)
- Automated S3 backup via CronJob (tar + MinIO client)
- Fail-fast validation (replicaCount must be 1)

## Configuration

### Profile Presets

openHAB does not support clustering, so this chart does not use profile presets.
Use feature flags instead to enable optional components.

### Key Parameters

| Parameter | Description | Default |
|-----------|-------------|---------|
| `image.tag` | openHAB image tag | `4.2.2` |
| `image.repository` | Image repository | `docker.io/openhab/openhab` |
| `replicaCount` | Must be 1 — no clustering support | `1` |
| `podSecurityContext.fsGroup` | fsGroup for PVC ownership after privilege drop | `9001` |
| `service.type` | Service type | `ClusterIP` |
| `service.port` | HTTP port | `8080` |
| `ingress.enabled` | Enable Ingress | `false` |
| `ingress.ingressClassName` | Ingress class name | `""` |
| `env.TZ` | Timezone | `UTC` |
| `env.EXTRA_JAVA_OPTS` | Extra JVM options | `""` |
| `karaf.enabled` | Enable Karaf SSH console | `false` |
| `admin.secretEnabled` | Create admin credentials Secret | `false` |

### Persistence Parameters

| Parameter | Description | Default |
|-----------|-------------|---------|
| `persistence.userdata.enabled` | Enable userdata PVC | `true` |
| `persistence.userdata.size` | userdata PVC size | `5Gi` |
| `persistence.userdata.storageClass` | Storage class | `""` (cluster default) |
| `persistence.userdata.existingClaim` | Use existing PVC | `""` |
| `persistence.conf.enabled` | Enable conf PVC | `true` |
| `persistence.conf.size` | conf PVC size | `1Gi` |
| `persistence.addons.enabled` | Enable addons PVC | `true` |
| `persistence.addons.size` | addons PVC size | `2Gi` |

### ConfigMap Parameters

| Parameter | Description | Default |
|-----------|-------------|---------|
| `configMaps.sitemaps.enabled` | Enable sitemaps ConfigMap | `false` |
| `configMaps.sitemaps.files` | Map of filename → content | `{}` |
| `configMaps.things.enabled` | Enable things ConfigMap | `false` |
| `configMaps.things.files` | Map of filename → content | `{}` |
| `configMaps.items.enabled` | Enable items ConfigMap | `false` |
| `configMaps.items.files` | Map of filename → content | `{}` |

### Metrics Parameters

| Parameter | Description | Default |
|-----------|-------------|---------|
| `metrics.enabled` | Enable Prometheus metrics support | `false` |
| `metrics.podAnnotations.enabled` | Add `prometheus.io/*` pod annotations | `true` |
| `metrics.serviceMonitor.enabled` | Create ServiceMonitor for Prometheus Operator | `false` |
| `metrics.serviceMonitor.namespace` | ServiceMonitor namespace | release namespace |
| `metrics.serviceMonitor.interval` | Scrape interval | `60s` |
| `metrics.serviceMonitor.scrapeTimeout` | Scrape timeout | `10s` |
| `metrics.serviceMonitor.additionalLabels` | Extra labels on ServiceMonitor | `{}` |

### Backup Parameters

| Parameter | Description | Default |
|-----------|-------------|---------|
| `backup.enabled` | Enable automated backup CronJob | `false` |
| `backup.schedule` | Cron schedule | `0 3 * * *` |
| `backup.suspend` | Suspend the CronJob | `false` |
| `backup.concurrencyPolicy` | CronJob concurrency policy | `Forbid` |
| `backup.successfulJobsHistoryLimit` | Successful job history to retain | `3` |
| `backup.failedJobsHistoryLimit` | Failed job history to retain | `3` |
| `backup.backoffLimit` | Job backoff limit | `1` |
| `backup.archivePrefix` | Archive filename prefix | `openhab` |
| `backup.include.userdata` | Back up `/openhab/userdata` | `true` |
| `backup.include.conf` | Back up `/openhab/conf` | `true` |
| `backup.images.utility.repository` | Backup utility image | `docker.io/library/alpine` |
| `backup.images.utility.tag` | Backup utility tag | `3.22` |
| `backup.images.uploader.repository` | S3 uploader image | `docker.io/helmforge/mc` |
| `backup.images.uploader.tag` | S3 uploader tag | `1.0.0` |
| `backup.resources` | Resource requests/limits for backup containers | `{}` |
| `backup.s3.endpoint` | S3-compatible endpoint URL | `""` |
| `backup.s3.bucket` | Target bucket name | `""` |
| `backup.s3.prefix` | Key prefix within the bucket | `openhab` |
| `backup.s3.accessKey` | S3 access key | `""` |
| `backup.s3.secretKey` | S3 secret key | `""` |
| `backup.s3.existingSecret` | Existing Secret name (keys: `access-key`, `secret-key`) | `""` |

## Prometheus Metrics

openHAB exposes Prometheus metrics via the **Metrics addon** at:

```
GET /rest/metrics/prometheus   (port 8080, no authentication required)
```

**Step 1** — Install the Metrics addon in openHAB:
*Settings → Add-on Store → Integrations → Metrics*

**Step 2** — Enable metrics in chart values:

```yaml
# Annotation-based scraping (works without Prometheus Operator)
metrics:
  enabled: true
  podAnnotations:
    enabled: true

# --- OR ---

# Prometheus Operator (ServiceMonitor)
metrics:
  enabled: true
  podAnnotations:
    enabled: false
  serviceMonitor:
    enabled: true
    interval: 60s
    additionalLabels:
      release: prometheus   # must match your Prometheus selector
```

**Metrics exposed**: openHAB events (per topic), bundle states, thing states,
rule executions, threadpool statistics, JVM metrics (memory, GC, threads).

See [Prometheus Metrics Guide](docs/metrics.md) for full details.

## Examples

- [Simple Deployment](examples/simple.yaml)
- [With Ingress + TLS](examples/with-ingress.yaml)
- [With ConfigMaps (GitOps)](examples/with-configmaps.yaml)
- [Full Production](examples/production.yaml)

## Automated Backup

The chart includes an optional CronJob that archives your openHAB data and uploads it to any S3-compatible storage using the MinIO client.

```yaml
backup:
  enabled: true
  schedule: "0 3 * * *"
  s3:
    endpoint: "https://minio.example.com"
    bucket: "openhab-backups"
    prefix: "prod"
    accessKey: "AKIAEXAMPLE"
    secretKey: "supersecretkey"
```

To avoid storing credentials in values, use an existing Secret:

```yaml
backup:
  enabled: true
  s3:
    endpoint: "https://minio.example.com"
    bucket: "openhab-backups"
    existingSecret: "my-s3-credentials"   # keys: access-key, secret-key
```

See [Automated Backup Guide](docs/backup.md) for full details including restore instructions.

## Architecture Guides

- [ConfigMaps & Live Reload](docs/configmaps-live-reload.md)
- [Storage](docs/storage.md)
- [Security](docs/security.md)
- [Prometheus Metrics](docs/metrics.md)
- [Automated Backup](docs/backup.md)

## First Boot — Admin Setup

openHAB does not support injecting admin credentials via environment variables.
On first boot, navigate to the web UI and complete the setup wizard to create
your administrator account.

Credentials are stored persistently in `/openhab/userdata/jsondb/auth.json`.

## Startup Time

openHAB loads OSGi bundles at startup. Expect:
- **First boot**: 60-120 seconds
- **Subsequent starts**: 30-60 seconds (warm cache)

The chart configures a startup probe with a 5-minute window to accommodate this.

## Ingress & WebSocket

openHAB's `/rest/events` endpoint uses Server-Sent Events (SSE). When using
nginx Ingress, add these annotations for proper websocket/SSE support:

```yaml
ingress:
  annotations:
    nginx.ingress.kubernetes.io/proxy-read-timeout: "3600"
    nginx.ingress.kubernetes.io/proxy-send-timeout: "3600"
    nginx.ingress.kubernetes.io/proxy-http-version: "1.1"
    nginx.ingress.kubernetes.io/configuration-snippet: |
      proxy_set_header Upgrade $http_upgrade;
      proxy_set_header Connection "upgrade";
```

## Non-Goals

This chart intentionally does NOT:
- Support multiple replicas (openHAB does not support clustering)
- Automatically inject admin credentials (not supported by openHAB)
- Manage openHAB addon installation (use the web UI or Karaf console)

## Contributing

See [CONTRIBUTING.md](../../CONTRIBUTING.md)
