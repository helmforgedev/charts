# Pi-hole DNS Sinkhole

A Helm chart for deploying [Pi-hole](https://pi-hole.net/) on Kubernetes using the official [pihole/pihole](https://hub.docker.com/r/pihole/pihole) container image.

## Installation

### HTTPS Repository

```bash
helm repo add helmforge https://repo.helmforge.dev
helm repo update
helm install pihole helmforge/pihole
```

### OCI Registry

```bash
helm install pihole oci://ghcr.io/helmforgedev/helm/pihole
```

## Quick Start

```bash
helm install pihole oci://ghcr.io/helmforgedev/helm/pihole \
  --set admin.password=changeme \
  --set serviceDns.loadBalancerIP=192.168.1.53
```

## Features

- **Network-Wide Ad Blocking** — DNS-level filtering for all devices on the network
- **Custom DNS Records** — Local A records, CNAME records, and dnsmasq configuration
- **Unbound Sidecar** — Optional recursive DNS resolver eliminating third-party DNS dependency
- **Pi-hole v6+ Support** — Uses `FTLCONF_` environment variables for modern configuration
- **Prometheus Metrics** — pihole-exporter sidecar with ServiceMonitor support
- **Ingress Support** — Configurable ingress with TLS for the web admin interface
- **DHCP Support** — Optional DHCP server with hostNetwork mode
- **DNSSEC Validation** — Optional DNS Security Extensions

## Configuration

### Minimal (Simple Setup)

```yaml
admin:
  password: "change-me"

serviceDns:
  type: LoadBalancer
  loadBalancerIP: "192.168.1.53"
```

### Production (Full Setup)

```yaml
pihole:
  timezone: America/Sao_Paulo
  dnssec: true

admin:
  existingSecret: pihole-admin
  existingSecretKey: password

unbound:
  enabled: true
  resources:
    requests:
      cpu: 50m
      memory: 64Mi
    limits:
      cpu: 200m
      memory: 128Mi

dns:
  customRecords:
    - "192.168.1.1 router.home"
    - "192.168.1.10 nas.home"
  cnameRecords:
    - "cname=media.home,nas.home"

persistence:
  enabled: true
  size: 2Gi

resources:
  requests:
    cpu: 100m
    memory: 128Mi
  limits:
    cpu: 500m
    memory: 512Mi

serviceDns:
  type: LoadBalancer
  loadBalancerIP: "192.168.1.53"
  externalTrafficPolicy: Local

ingress:
  enabled: true
  ingressClassName: traefik
  annotations:
    cert-manager.io/cluster-issuer: letsencrypt-prod
  hosts:
    - host: pihole.home
      paths:
        - path: /
          pathType: Prefix
  tls:
    - secretName: pihole-tls
      hosts:
        - pihole.home

metrics:
  enabled: true
  serviceMonitor:
    enabled: true
    labels:
      release: prometheus
```

## Parameters

### Pi-hole

| Key | Default | Description |
|-----|---------|-------------|
| `image.repository` | `docker.io/pihole/pihole` | Pi-hole container image repository |
| `image.tag` | `2026.04.0` | Pi-hole container image tag (Core v6.4.1, FTL v6.6) |
| `image.pullPolicy` | `IfNotPresent` | Pi-hole image pull policy |
| `pihole.timezone` | `UTC` | Timezone for logs and scheduled tasks |
| `pihole.upstreamDns` | `8.8.8.8;8.8.4.4` | Upstream DNS servers (semicolon-delimited) |
| `pihole.listeningMode` | `ALL` | DNS listening mode (LOCAL, ALL, SINGLE, BIND) |
| `pihole.dnssec` | `false` | Enable DNSSEC validation |
| `pihole.extraEnv` | `[]` | Additional environment variables |

### Admin

| Key | Default | Description |
|-----|---------|-------------|
| `admin.password` | `""` | Web admin password (auto-generated if empty) |
| `admin.existingSecret` | `""` | Existing secret for admin password |
| `admin.existingSecretKey` | `password` | Key in existing secret |

### DNS Records

| Key | Default | Description |
|-----|---------|-------------|
| `dns.customRecords` | `[]` | Custom local DNS A records ("IP HOSTNAME") |
| `dns.cnameRecords` | `[]` | Custom CNAME records (dnsmasq format) |
| `dns.customDnsmasq` | `[]` | Custom dnsmasq configuration lines |
| `dns.adlists` | `[]` | Blocklist URLs for gravity database |
| `dns.whitelist` | `[]` | Whitelisted domains |
| `dns.blacklist` | `[]` | Blacklisted domains |
| `dns.regex` | `[]` | Regex filters for blocking |

### Gravity

| Key | Default | Description |
|-----|---------|-------------|
| `gravity.enabled` | `true` | Reconcile Pi-hole gravity schema and Helm-managed lists before Pi-hole starts |
| `gravity.updateOnInit` | `true` | Run `pihole -g` in a follow-up init container after Helm-managed lists are reconciled |
| `gravity.resources` | `{}` | Resources for the gravity schema/list init container |
| `gravity.updateResources` | `{}` | Resources for the gravity update init container |

### Persistence

| Key | Default | Description |
|-----|---------|-------------|
| `persistence.enabled` | `true` | Enable persistent storage |
| `persistence.storageClass` | `""` | Storage class |
| `persistence.accessMode` | `ReadWriteOnce` | PVC access mode |
| `persistence.size` | `1Gi` | PVC size |
| `persistence.existingClaim` | `""` | Use existing PVC |

### Services

| Key | Default | Description |
|-----|---------|-------------|
| `hostNetwork` | `false` | Use host network for the main Pi-hole pod |
| `dnsPolicy` | `""` | Pod DNS policy; defaults to `ClusterFirstWithHostNet` when host networking is enabled |
| `serviceDns.type` | `LoadBalancer` | DNS service type |
| `serviceDns.port` | `53` | DNS port |
| `serviceDns.loadBalancerIP` | — | Fixed IP for DNS stability |
| `serviceDns.externalTrafficPolicy` | — | External traffic policy |
| `serviceWeb.type` | `ClusterIP` | Web admin service type |
| `serviceWeb.port` | `80` | Web admin port |

### Ingress

| Key | Default | Description |
|-----|---------|-------------|
| `ingress.enabled` | `false` | Enable ingress |
| `ingress.ingressClassName` | `""` | Ingress class (traefik, nginx, etc.) |
| `ingress.hosts` | `[]` | Ingress hosts and paths |
| `ingress.tls` | `[]` | TLS configuration |

### Metrics

| Key | Default | Description |
|-----|---------|-------------|
| `metrics.enabled` | `false` | Enable pihole-exporter sidecar |
| `metrics.image.tag` | `v0.4.0` | pihole-exporter version |
| `metrics.port` | `9617` | Metrics port |
| `metrics.serviceMonitor.enabled` | `false` | Create ServiceMonitor |
| `metrics.serviceMonitor.interval` | `30s` | Scrape interval |

### Unbound

| Key | Default | Description |
|-----|---------|-------------|
| `unbound.enabled` | `false` | Enable Unbound sidecar |
| `unbound.image.tag` | `1.22.0` | Unbound version |
| `unbound.port` | `5335` | Unbound listening port |
| `unbound.resources` | `{}` | Resources for Unbound |

### DHCP

| Key | Default | Description |
|-----|---------|-------------|
| `dhcp.enabled` | `false` | Enable DHCP server |
| `dhcp.hostNetwork` | `false` | Use host network for DHCP |

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
| Deployment | Always | Pi-hole server (single replica, Recreate strategy) |
| Service (DNS) | Always | DNS ports TCP/UDP 53 (LoadBalancer by default) |
| Service (Web) | Always | Web admin port 80 (ClusterIP by default) |
| PersistentVolumeClaim | `persistence.enabled` | Pi-hole data volume |
| Secret | No `admin.existingSecret` | Admin password |
| ConfigMap | Custom DNS/dnsmasq config | DNS records and dnsmasq config |
| Ingress | `ingress.enabled` | Web admin ingress |
| ServiceAccount | `serviceAccount.create` | Dedicated SA |
| ServiceMonitor | `metrics.serviceMonitor.enabled` | Prometheus scrape config |

## Examples

- [Simple](examples/simple.yaml) — minimal deployment with fixed DNS IP
- [Production](examples/production.yaml) — Unbound, ingress, metrics, custom DNS
- [Custom DNS](examples/custom-dns.yaml) — local DNS records and conditional forwarding

## Architecture Guides

- [Unbound Recursive DNS](docs/unbound.md) — privacy-focused recursive DNS resolution

## Connection

After installation, configure your network to use Pi-hole as DNS:

```bash
# Get DNS LoadBalancer IP
kubectl get svc <release>-pihole-dns -o jsonpath='{.status.loadBalancer.ingress[0].ip}'

# Get admin password
kubectl get secret <release>-pihole -o jsonpath='{.data.password}' | base64 -d

# Access web admin
kubectl port-forward svc/<release>-pihole-web 8080:80
# Then visit http://localhost:8080/admin
```

## Non-Goals

This chart intentionally does not support:

- **Multi-instance clustering** — Pi-hole does not support clustering natively
- **Gravity Sync** — Use a separate tool or manual sync for multi-instance setups
- **Built-in VPN** — Use a dedicated VPN solution (WireGuard, etc.)

<!-- @AI-METADATA
type: chart-readme
title: Pi-hole Helm Chart
description: Deploy Pi-hole DNS sinkhole on Kubernetes with Unbound recursive DNS, Prometheus metrics, and ingress support
keywords: pihole, dns, ad-blocker, helm, kubernetes, unbound, dnsmasq, metrics
purpose: Installation guide, configuration reference, and operational documentation for the pihole Helm chart
scope: Chart
relations:
  - charts/pihole/docs/unbound.md
  - charts/pihole/values.yaml
path: charts/pihole/README.md
version: 1.0
date: 2026-03-23
-->
