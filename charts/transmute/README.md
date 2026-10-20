# Transmute Helm Chart

Production-ready Helm chart for [Transmute](https://transmute.sh), a self-hosted audio and video transcoding and media conversion service with queue management and OIDC integration.

## Prerequisites

- Kubernetes 1.26+
- Helm 3.8.0+
- Optional: External Secrets Operator, Gateway API CRDs

## Installation

```bash
helm repo add helmforge https://repo.helmforge.dev
helm repo update
helm install transmute helmforge/transmute --namespace media --create-namespace
```

## Configuration Parameters

| Parameter | Description | Default |
| --------- | ----------- | ------- |
| `image.repository` | Transmute container image | `ghcr.io/transmute-app/transmute` |
| `image.tag` | Container image tag | `1.0.0` |
| `auth.enabled` | Enable internal authentication | `true` |
| `auth.initialAdmin.email` | Initial admin email address | `""` |
| `auth.initialAdmin.password` | Initial admin password | `""` |
| `oidc.enabled` | Enable OpenID Connect SSO | `false` |
| `oidc.providerUrl` | OIDC Issuer / Discovery URL | `""` |
| `oidc.clientId` | OIDC Client ID | `""` |
| `ingress.enabled` | Enable Kubernetes Ingress | `false` |
| `ingress.ingressClassName` | Ingress class name | `""` |
| `httpRoute.enabled` | Enable Gateway API HTTPRoute | `false` |
| `externalSecrets.enabled` | Enable External Secrets integration | `false` |
| `persistence.enabled` | Enable persistent storage | `true` |
| `persistence.size` | Storage volume size | `20Gi` |

## Security Scan

### Security Scan: `transmute`

| Framework          | Score         |
| ------------------ | ------------- |
| MITRE + NSA + SOC2 | **98.50000%** |

> Security posture acceptable.

Measured using Kubescape 4.0.13 against default manifests. This assesses Kubernetes deployment configuration, not the absence of upstream application vulnerabilities.
