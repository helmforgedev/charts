# DDNS Updater Helm Chart

Deploy [ddns-updater](https://github.com/qdm12/ddns-updater) on Kubernetes using the official
[qmcgaw/ddns-updater](https://hub.docker.com/r/qmcgaw/ddns-updater) Docker image. Keep DNS A/AAAA records updated
across 50+ providers with a responsive web UI.

This chart currently deploys `qmcgaw/ddns-updater:2.10.0`.

## Features

- **50+ DNS providers** — Cloudflare, Route53, DuckDNS, Namecheap, GoDaddy, Hetzner, and more
- **Web UI** — responsive dashboard for monitoring update status
- **Multi-provider** — manage records across different providers in a single deployment
- **Persistent history** — update history stored in a PVC
- **Existing secrets** — bring your own Secret for credentials
- **Ingress support** — expose the web UI with TLS
- **Restricted runtime** — non-root container, read-only root filesystem, dropped capabilities, and ServiceAccount token automount disabled

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
| `image.repository` | `docker.io/qmcgaw/ddns-updater` | ddns-updater container image repository |
| `image.tag` | `2.10.0` | ddns-updater container image tag |
| `config.settings` | `[]` | DNS records to update (provider-specific) |
| `config.existingSecret` | `""` | Existing secret with config.json |
| `ddns.period` | `5m` | Check interval |
| `ddns.httpTimeout` | `10s` | HTTP timeout |
| `ddns.publicIpFetchers` | `all` | IP detection method (all, http, dns) |
| `ddns.updateCooldownPeriod` | `5m` | Minimum interval between updates for the same record |
| `ddns.logLevel` | `info` | Log level |
| `ddns.port` | `8000` | Web UI container port |
| `ddns.rootUrl` | `/` | Web UI root URL path |
| `persistence.enabled` | `true` | Persist update history |
| `persistence.size` | `256Mi` | PVC size |
| `resources.requests.cpu` | `10m` | Default CPU request |
| `resources.requests.memory` | `32Mi` | Default memory request |
| `resources.limits.cpu` | `100m` | Default CPU limit |
| `resources.limits.memory` | `128Mi` | Default memory limit |
| `serviceAccount.automountServiceAccountToken` | `false` | Mount Kubernetes API token into pods |
| `service.port` | `80` | Web UI service port |
| `ingress.enabled` | `false` | Enable ingress |
| `podSecurityContext.runAsUser` | `1000` | Upstream image user |
| `securityContext.readOnlyRootFilesystem` | `true` | Keep the container root filesystem read-only |

## Operations

Use `config.existingSecret` for production credentials so DNS provider tokens are not stored in values files.
Before upgrading, confirm the provider-specific configuration format against the upstream documentation and inspect pod logs after rollout:

```bash
kubectl logs -l app.kubernetes.io/name=ddns-updater --all-containers --tail=100
```

## Security Scan

🟢 Security Scan: `ddns-updater`

| Framework | Score |
|---|---|
| MITRE + NSA + SOC2 | **93.94%** |

> ✅ Security posture acceptable.

Local details:

| Framework | Score |
|---|---|
| MITRE | 100.00% |
| NSA | 95.00% |
| SOC2 | 80.00% |

The remaining local scan findings are expected for raw chart scanning and
platform-level controls: NetworkPolicy and egress firewall policy are supplied
by the platform layer because DNS provider APIs and public IP detection
endpoints vary by deployment.

## More Information

- [Supported providers](docs/providers.md)
- [Upstream documentation](https://github.com/qdm12/ddns-updater)
- [Source code](https://github.com/helmforgedev/charts/tree/main/charts/ddns-updater)
