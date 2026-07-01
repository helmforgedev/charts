# Poznote

Self-hosted note-taking and documentation platform with SQLite persistence.

## Installation

### Using HTTPS Repository

```bash
helm repo add helmforge https://repo.helmforge.dev
helm install my-release helmforge/poznote
```

### Using OCI Repository

```bash
helm install my-release oci://ghcr.io/helmforgedev/helm/poznote --version 1.0.0
```

## Quick Start

### Minimal Configuration

```yaml
# Deploy with defaults -- PVC enabled, port 80
persistence:
  data:
    enabled: true
```

### With Ingress

```yaml
ingress:
  enabled: true
  ingressClassName: nginx
  hosts:
    - host: notes.example.com
  tls:
    - secretName: notes-tls
      hosts:
        - notes.example.com
```

## Features

- Official upstream image pinned to stable release
- SQLite persistence via single PVC
- Ingress and Gateway API exposure
- OIDC/SSO authentication support
- External Secrets Operator integration
- NetworkPolicy for traffic isolation
- PodDisruptionBudget for voluntary disruption safety
- Dual-stack Service support
- Pod Security Standards baseline compliance

## Configuration

### Parameters

#### Global Parameters

| Parameter | Description | Default |
|-----------|-------------|---------|
| `nameOverride` | Override chart name | `""` |
| `fullnameOverride` | Override full release name | `""` |
| `commonLabels` | Extra labels for all objects | `{}` |

#### Image Parameters

| Parameter | Description | Default |
|-----------|-------------|---------|
| `image.repository` | Image repository | `ghcr.io/timothepoznanski/poznote` |
| `image.tag` | Image tag | `6.29.0` |
| `image.pullPolicy` | Pull policy | `IfNotPresent` |

#### Application Parameters

| Parameter | Description | Default |
|-----------|-------------|---------|
| `app.port` | HTTP port (nginx listen port) | `80` |
| `app.timezone` | Container timezone | `UTC` |
| `app.debug` | Enable debug mode | `false` |

#### Persistence Parameters

| Parameter | Description | Default |
|-----------|-------------|---------|
| `persistence.data.enabled` | Enable data PVC | `true` |
| `persistence.data.size` | PVC size | `5Gi` |
| `persistence.data.storageClass` | Storage class | `""` |
| `persistence.data.existingClaim` | Use existing PVC | `""` |

#### Exposure Parameters

| Parameter | Description | Default |
|-----------|-------------|---------|
| `service.type` | Service type | `ClusterIP` |
| `service.port` | Service port | `80` |
| `ingress.enabled` | Enable Ingress | `false` |
| `ingress.ingressClassName` | Ingress class | `traefik` |
| `gatewayAPI.enabled` | Enable Gateway API | `false` |

#### Security Parameters

| Parameter | Description | Default |
|-----------|-------------|---------|
| `secrets.existingSecret` | Existing Secret for OIDC | `""` |
| `secrets.oidcClientId` | Inline OIDC client ID | `""` |
| `secrets.oidcClientSecret` | Inline OIDC client secret | `""` |
| `poznote.oidc.disableNormalLogin` | Force SSO-only login | `false` |

## Examples

- [Simple Development Setup](examples/simple.yaml)
- [Ingress Exposure](examples/ingress.yaml)
- [Gateway API Exposure](examples/gateway-api.yaml)
- [OIDC Secured](examples/secured.yaml)

## Architecture Guides

- [Storage Guide](docs/storage.md)
- [Exposure Guide](docs/exposure.md)
- [Authentication Guide](docs/authentication.md)

## Connecting to Poznote

```bash
kubectl port-forward svc/my-release-poznote 8080:80
# Open http://127.0.0.1:8080
# Default login: admin_change_me / admin
```

## Non-Goals

This chart intentionally does NOT:

- Support multi-replica scaling (SQLite limitation)
- Provide a database subchart (SQLite is embedded)
- Bundle the MCP server container (separate deployment concern)

## Security Scan

Security Scan: `poznote`

| Framework | Score |
|---|---|
| MITRE + NSA + SOC2 | **87.878784%** |

> Security posture acceptable.

## Contributing

See [CONTRIBUTING.md](../../CONTRIBUTING.md)
