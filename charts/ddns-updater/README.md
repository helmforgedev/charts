# DDNS Updater Helm Chart

Deploy [ddns-updater](https://github.com/qdm12/ddns-updater) on Kubernetes using the official [qmcgaw/ddns-updater](https://hub.docker.com/r/qmcgaw/ddns-updater) Docker image. Keep DNS A/AAAA records updated across 50+ providers with a responsive web UI.

## Features

- **50+ DNS providers** — Cloudflare, Route53, DuckDNS, Namecheap, GoDaddy, Hetzner, and more
- **Web UI** — responsive dashboard for monitoring update status
- **Multi-provider** — manage records across different providers in a single deployment
- **Persistent history** — update history stored in a PVC
- **Existing secrets** — bring your own Secret for credentials
- **Ingress support** — expose the web UI with TLS

## Installation

**HTTPS repository:**

```bash
helm repo add helmforge https://repo.helmforge.dev
helm repo update
helm install ddns-updater helmforge/ddns-updater -f values.yaml
```

**OCI registry:**

```bash
helm install ddns-updater oci://ghcr.io/helmforgedev/helm/ddns-updater -f values.yaml
```

## Quick Start

```yaml
# values.yaml
config:
  settings:
    - provider: cloudflare
      zone_identifier: "your-zone-id"
      domain: "example.com"
      host: "@"
      ttl: 300
      token: "your-cloudflare-api-token"
      proxied: false
      ip_version: "ipv4"
```

Access the web UI:

```bash
kubectl port-forward svc/<release>-ddns-updater 8000:80
# Open http://localhost:8000
```

## Using an Existing Secret

Store your `config.json` in a Kubernetes Secret:

```bash
kubectl create secret generic ddns-config \
  --from-file=config.json=./config.json
```

```yaml
config:
  existingSecret: ddns-config
  existingSecretKey: config.json
```

## Multi-Provider Example

```yaml
config:
  settings:
    - provider: cloudflare
      zone_identifier: "cf-zone-id"
      domain: "example.com"
      host: "@"
      token: "cf-token"
      proxied: true
    - provider: duckdns
      domain: "myhost.duckdns.org"
      token: "duck-token"
    - provider: namecheap
      domain: "example.org"
      host: "home"
      password: "ddns-password"
```

## Default Values

| Key | Default | Description |
|-----|---------|-------------|
| `config.settings` | `[]` | DNS records to update (provider-specific) |
| `config.existingSecret` | `""` | Existing secret with config.json |
| `ddns.period` | `5m` | Check interval |
| `ddns.httpTimeout` | `10s` | HTTP timeout |
| `ddns.publicIpFetchers` | `all` | IP detection method (all, http, dns) |
| `ddns.logLevel` | `info` | Log level |
| `ddns.port` | `8000` | Web UI container port |
| `ddns.rootUrl` | `/` | Web UI root URL path |
| `persistence.enabled` | `true` | Persist update history |
| `persistence.size` | `256Mi` | PVC size |
| `service.port` | `80` | Web UI service port |
| `ingress.enabled` | `false` | Enable ingress |

## More Information

- [Supported providers](docs/providers.md)
- [Upstream documentation](https://github.com/qdm12/ddns-updater)
- [Source code](https://github.com/helmforgedev/charts/tree/main/charts/ddns-updater)

<!-- @AI-METADATA
@description: README for the ddns-updater Helm chart
@type: chart-readme
@chart: ddns-updater
@path: charts/ddns-updater/README.md
@date: 2026-03-23
@relations:
  - charts/ddns-updater/values.yaml
  - charts/ddns-updater/docs/providers.md
-->
