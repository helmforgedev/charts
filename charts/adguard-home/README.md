# AdGuard Home

A Helm chart for deploying [AdGuard Home](https://adguard.com/adguard-home/overview.html) on Kubernetes
using the official [adguard/adguardhome](https://hub.docker.com/r/adguard/adguardhome) container image.

## Installation

### HTTPS Repository

```bash
helm repo add helmforge https://repo.helmforge.dev
helm repo update
helm install adguard-home helmforge/adguard-home
```

### OCI Registry

```bash
helm install adguard-home oci://ghcr.io/helmforgedev/helm/adguard-home
```

## Quick Start

By default, the chart starts in **wizard mode** (port 3000). Complete the setup wizard through the web UI to configure AdGuard Home.

```bash
helm install adguard-home oci://ghcr.io/helmforgedev/helm/adguard-home

# Access the setup wizard
kubectl port-forward svc/adguard-home-web 3000:80
# Then visit http://localhost:3000
```

To skip the wizard and deploy a pre-configured instance, provide `config.adGuardHome` with your desired configuration. See the [preconfigured example](examples/preconfigured.yaml).

## Features

- **Network-Wide Ad Blocking** - DNS-level filtering for all devices on the network
- **Two Deployment Modes** - wizard mode for initial setup or pre-configured mode for automated deployments
- **DNS over HTTPS / TLS** - configurable encrypted upstream DNS
- **AdGuardHome Sync** - optional multi-instance synchronization via [adguardhome-sync](https://github.com/bakito/adguardhome-sync)
- **S3 Backup** - automated CronJob-based backup to any S3-compatible storage
- **Separate DNS Service** - dedicated LoadBalancer for DNS traffic independent of the web UI
- **Dual-Stack** - `ipFamilyPolicy`/`ipFamilies` on both web and DNS services for IPv4/IPv6 clusters
- **Gateway API** - opt-in `HTTPRoute` for the web UI (alternative to Ingress; requires Gateway API CRDs)
- **ExternalSecrets** - opt-in `ExternalSecret` to source `AdGuardHome.yaml` from an external secrets store
- **Ingress Support** - configurable ingress with TLS for the web admin interface
- **Config Seeding** - initial configuration is preserved across upgrades (only seeded on first run)

## Configuration

### Wizard Mode (Default)

```yaml
# No config.adGuardHome - wizard runs on first access at port 3000
service:
  dns:
    type: LoadBalancer
    loadBalancerIP: "192.168.1.53"
```

### Pre-Configured Mode

```yaml
config:
  adGuardHome:
    http:
      address: 0.0.0.0:80
    users:
      - name: admin
        # bcrypt hash - generate with: htpasswd -bnBC 10 "" 'PASSWORD' | cut -d: -f2
        password: "$2y$10$..."
    dns:
      bind_hosts:
        - 0.0.0.0
      port: 53
      upstream_dns:
        - https://dns.cloudflare.com/dns-query
        - https://dns.google/dns-query
      bootstrap_dns:
        - 1.1.1.1
        - 8.8.8.8
      protection_enabled: true
      filtering_enabled: true
    filters:
      - enabled: true
        url: https://adguardteam.github.io/HostlistsRegistry/assets/filter_1.txt
        name: AdGuard DNS filter
        id: 1
    schema_version: 29

service:
  dns:
    type: LoadBalancer
    loadBalancerIP: "192.168.1.53"
```

### Production (Full Setup)

```yaml
config:
  adGuardHome:
    http:
      address: 0.0.0.0:80
    users:
      - name: admin
        password: "$2y$10$..."
    dns:
      bind_hosts:
        - 0.0.0.0
      port: 53
      upstream_dns:
        - https://dns.cloudflare.com/dns-query
      bootstrap_dns:
        - 1.1.1.1
    schema_version: 29

persistence:
  conf:
    size: 512Mi
  work:
    size: 5Gi

resources:
  requests:
    cpu: 100m
    memory: 128Mi
  limits:
    cpu: 500m
    memory: 512Mi

service:
  dns:
    type: LoadBalancer
    loadBalancerIP: "192.168.1.53"

ingress:
  enabled: true
  ingressClassName: traefik
  annotations:
    cert-manager.io/cluster-issuer: letsencrypt-prod
  hosts:
    - host: adguard.example.com
      paths:
        - path: /
          pathType: Prefix
  tls:
    - hosts:
        - adguard.example.com
      secretName: adguard-home-tls

sync:
  enabled: true
  origin:
    url: "http://adguard-primary:80"
    username: admin
    password: changeme
  replicas:
    - url: "http://adguard-replica:80"
      username: admin
      password: changeme

backup:
  enabled: true
  s3:
    endpoint: https://s3.us-east-1.amazonaws.com
    bucket: adguard-backups
    accessKey: AKIAIOSFODNN7EXAMPLE
    secretKey: wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY
```

## Parameters

### Image

| Key | Default | Description |
|-----|---------|-------------|
| `image.repository` | `adguard/adguardhome` | Container image |
| `image.tag` | `""` (appVersion) | Image tag (auto-prefixed with `v`) |
| `image.pullPolicy` | `IfNotPresent` | Pull policy |

### General Configuration

| Key | Default | Description |
|-----|---------|-------------|
| `config.adGuardHome` | `{}` | Pre-seed AdGuardHome.yaml config (empty = wizard mode) |
| `config.existingSecret` | `""` | Existing Secret with `AdGuardHome.yaml` key |

### Persistence

| Key | Default | Description |
|-----|---------|-------------|
| `persistence.conf.enabled` | `true` | Enable conf volume (/opt/adguardhome/conf) |
| `persistence.conf.size` | `256Mi` | Conf PVC size |
| `persistence.conf.storageClass` | `""` | Storage class |
| `persistence.conf.existingClaim` | `""` | Use existing PVC |
| `persistence.work.enabled` | `true` | Enable work volume (/opt/adguardhome/work) |
| `persistence.work.size` | `2Gi` | Work PVC size |
| `persistence.work.storageClass` | `""` | Storage class |
| `persistence.work.existingClaim` | `""` | Use existing PVC |

### Services

| Key | Default | Description |
|-----|---------|-------------|
| `service.web.type` | `ClusterIP` | Web UI service type |
| `service.web.port` | `80` | Web UI port |
| `service.web.ipFamilyPolicy` | `~` | Dual-stack policy (`SingleStack`, `PreferDualStack`, `RequireDualStack`) |
| `service.web.ipFamilies` | `[]` | IP families (`IPv4`, `IPv6`) |
| `service.dns.type` | `LoadBalancer` | DNS service type |
| `service.dns.port` | `53` | DNS port |
| `service.dns.loadBalancerIP` | `""` | Fixed IP for DNS stability |
| `service.dns.ipFamilyPolicy` | `~` | Dual-stack policy (`SingleStack`, `PreferDualStack`, `RequireDualStack`) |
| `service.dns.ipFamilies` | `[]` | IP families (`IPv4`, `IPv6`) |

### Ingress

| Key | Default | Description |
|-----|---------|-------------|
| `ingress.enabled` | `false` | Enable ingress for web UI |
| `ingress.ingressClassName` | `traefik` | Ingress class (traefik, nginx, etc.) |
| `ingress.hosts` | `[]` | Ingress hosts and paths |
| `ingress.tls` | `[]` | TLS configuration |

### Probes

| Key | Default | Description |
|-----|---------|-------------|
| `probes.startup.enabled` | `true` | Enable startup probe |
| `probes.liveness.enabled` | `true` | Enable liveness probe |
| `probes.readiness.enabled` | `true` | Enable readiness probe |

### Sync (adguardhome-sync)

| Key | Default | Description |
|-----|---------|-------------|
| `sync.enabled` | `false` | Enable sync Deployment |
| `sync.image.tag` | `v0.9.0` | Sync image version |
| `sync.origin.url` | `""` | Origin instance URL |
| `sync.origin.username` | `""` | Origin admin username |
| `sync.origin.password` | `""` | Origin admin password |
| `sync.replicas` | `[]` | Replica instances (url, username, password) |
| `sync.cron` | `*/10 * * * *` | Sync schedule (empty = daemon mode) |
| `sync.runOnStart` | `true` | Sync immediately on startup |
| `sync.existingSecret` | `""` | Pre-created Secret for credentials |

### Backup

| Key | Default | Description |
|-----|---------|-------------|
| `backup.enabled` | `false` | Enable backup CronJob |
| `backup.schedule` | `0 2 * * *` | Backup schedule |
| `backup.s3.endpoint` | `""` | S3-compatible endpoint URL |
| `backup.s3.bucket` | `""` | Target bucket |
| `backup.s3.prefix` | `adguard-home` | Prefix inside bucket |
| `backup.s3.accessKey` | `""` | Inline access key |
| `backup.s3.secretKey` | `""` | Inline secret key |
| `backup.s3.existingSecret` | `""` | Pre-created Secret for S3 credentials |

### Gateway API

| Key | Default | Description |
|-----|---------|-------------|
| `gateway.enabled` | `false` | Render an `HTTPRoute` for the web UI (requires Gateway API CRDs) |
| `gateway.annotations` | `{}` | Annotations for the `HTTPRoute` |
| `gateway.parentRefs` | `[]` | Gateway parent refs — **required** when `gateway.enabled=true`; each entry must have `name` |
| `gateway.hostnames` | `[]` | Hostnames the `HTTPRoute` matches |
| `gateway.path` | `/` | Path prefix |
| `gateway.pathType` | `PathPrefix` | Path match type |

### External Secrets Operator

| Key | Default | Description |
|-----|---------|-------------|
| `externalSecrets.enabled` | `false` | Render an `ExternalSecret` for the config secret |
| `externalSecrets.apiVersion` | `external-secrets.io/v1` | ExternalSecrets API version |
| `externalSecrets.refreshInterval` | `"0"` | Refresh interval (`"0"` = create-once bootstrap) |
| `externalSecrets.secretStoreRef.name` | `""` | SecretStore / ClusterSecretStore name — **required** |
| `externalSecrets.secretStoreRef.kind` | `ClusterSecretStore` | Store kind |
| `externalSecrets.target.creationPolicy` | `Owner` | Secret creation policy |
| `externalSecrets.data` | `[]` | Data mappings — **must** include an entry with `secretKey: AdGuardHome.yaml` |

> `externalSecrets.enabled=true` requires `config.existingSecret` to be set. The rendered `ExternalSecret` targets that same Secret name to avoid credential drift.

### Scheduling

| Key | Default | Description |
|-----|---------|-------------|
| `nodeSelector` | `{}` | Node selector |
| `tolerations` | `[]` | Tolerations |
| `affinity` | `{}` | Affinity rules |
| `topologySpreadConstraints` | `[]` | Topology spread |
| `priorityClassName` | `""` | Priority class |
| `terminationGracePeriodSeconds` | `30` | Shutdown grace period |

## Resources Generated

| Resource | Condition | Description |
|----------|-----------|-------------|
| Deployment | Always | AdGuard Home server (single replica, Recreate strategy) |
| Service (Web) | Always | Web admin port 80 (ClusterIP by default) |
| Service (DNS) | Always | DNS ports TCP/UDP 53 (LoadBalancer by default) |
| PersistentVolumeClaim (conf) | `persistence.conf.enabled` | Configuration volume |
| PersistentVolumeClaim (work) | `persistence.work.enabled` | Working data volume |
| Secret | `config.adGuardHome` set | AdGuardHome.yaml config |
| Ingress | `ingress.enabled` | Web admin ingress |
| HTTPRoute | `gateway.enabled` | Gateway API route for the web UI |
| ExternalSecret | `externalSecrets.enabled` | Fetches AdGuardHome.yaml from external secrets store |
| ServiceAccount | `serviceAccount.create` | Dedicated SA |
| Deployment (sync) | `sync.enabled` | adguardhome-sync |
| Secret (sync) | `sync.enabled`, no `existingSecret` | Sync credentials |
| CronJob (backup) | `backup.enabled` | Automated S3 backup |
| ConfigMap (backup) | `backup.enabled` | Backup scripts |
| Secret (backup) | `backup.enabled`, no S3 `existingSecret` | S3 credentials |

### Dual-Stack DNS Service

```yaml
service:
  web:
    ipFamilyPolicy: PreferDualStack
    ipFamilies:
      - IPv4
      - IPv6
  dns:
    type: LoadBalancer
    ipFamilyPolicy: PreferDualStack
    ipFamilies:
      - IPv4
      - IPv6
```

### Gateway API (HTTPRoute)

```yaml
gateway:
  enabled: true
  parentRefs:
    - name: envoy
      namespace: envoy-gateway
  hostnames:
    - adguard.example.com
  path: /
  pathType: PathPrefix
```

### External Secrets (ESO)

```yaml
config:
  existingSecret: my-adguard-config-secret

externalSecrets:
  enabled: true
  secretStoreRef:
    name: my-store
    kind: ClusterSecretStore
  data:
    - secretKey: AdGuardHome.yaml
      remoteRef:
        key: adguard-home/config
        property: AdGuardHome.yaml
```

## Examples

- [Simple](examples/simple.yaml) - wizard mode with DNS LoadBalancer
- [Pre-configured](examples/preconfigured.yaml) - skip wizard, ingress, filter lists
- [Production](examples/production.yaml) - sync, backup, ingress, resource limits

## Architecture Guides

- [AdGuardHome Sync](docs/sync.md) - multi-instance configuration synchronization
- [Backup](docs/backup.md) - automated S3 backup and restore

## Connection

After installation:

```bash
# Get DNS LoadBalancer IP
kubectl get svc <release>-adguard-home-dns -o jsonpath='{.status.loadBalancer.ingress[0].ip}'

# Access web UI (wizard mode)
kubectl port-forward svc/<release>-adguard-home-web 3000:80
# Then visit http://localhost:3000

# Access web UI (pre-configured mode)
kubectl port-forward svc/<release>-adguard-home-web 8080:80
# Then visit http://localhost:8080
```

## Non-Goals

This chart intentionally does not support:

- **Multi-replica DNS** - AdGuard Home is designed as a single instance; use sync for multi-site setups
- **Built-in DNS-over-HTTPS proxy** - use a dedicated reverse proxy or ingress controller for TLS termination
- **Automatic filter list management** - filter lists are managed through the AdGuard Home web UI or config

<!-- @AI-METADATA
type: chart-readme
title: AdGuard Home Helm Chart
description: Deploy AdGuard Home DNS ad/tracker blocker on Kubernetes with sync and S3 backup
keywords: adguard-home, dns, ad-blocker, tracker-blocker, helm, kubernetes, sync, backup
purpose: Installation guide, configuration reference, and operational documentation for the adguard-home Helm chart
scope: Chart
relations:
  - charts/adguard-home/docs/sync.md
  - charts/adguard-home/docs/backup.md
  - charts/adguard-home/values.yaml
path: charts/adguard-home/README.md
version: 1.0
date: 2026-03-23
-->
