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
| `image.tag` | Image tag | `6.80.0` |
| `image.pullPolicy` | Pull policy | `IfNotPresent` |

#### Application Parameters

| Parameter | Description | Default |
|-----------|-------------|---------|
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
| `poznote.sharing.hideRestrictUsers` | Hide user restriction controls in sharing dialogs | `false` |

## Examples

- [Simple Development Setup](examples/simple.yaml)
- [Ingress Exposure](examples/ingress.yaml)
- [Gateway API Exposure](examples/gateway-api.yaml)
- [OIDC Secured](examples/secured.yaml)
- [Production](examples/production.yaml)

## Architecture Guides

- [Storage Guide](docs/storage.md)
- [Exposure Guide](docs/exposure.md)
- [Authentication Guide](docs/authentication.md)
- [Production Guide](docs/production.md)

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

## Upgrade Notes

Poznote `6.80.0` includes the 6.69–6.80 background export, restore and import
workers, chunked archive uploads, snapshot retention and conflict-safe autosave.
Complete backups and restores now continue in detached workers, with progress
polled by the browser. Keep the pod running until the job completes and verify
its final status before downloading or relying on the backup.

Back up the complete `data` PVC before upgrading and verify a restore in a
separate instance. It contains SQLite, notes, attachments and application
configuration. Existing S3 integrations remain application configuration;
confirm attachment access when exporting or restoring an account.

Shared links default to read-only. API integrations should retain the returned
note version and use `if_version` or `If-Match` to detect concurrent edits.
MCP user selection and optional `POZNOTE_MCP_AUTH_TOKEN` apply to the separate
MCP server; the chart does not deploy or expose it. Review the
[upstream releases](https://github.com/timothepoznanski/poznote/releases)
before upgrading integrations.

## Security Scan

Security Scan: `poznote`

| Framework | Score |
|---|---|
| MITRE + NSA + SOC2 | **87.88%** |

> Security posture acceptable.

## Contributing

See [CONTRIBUTING.md](../../CONTRIBUTING.md)
