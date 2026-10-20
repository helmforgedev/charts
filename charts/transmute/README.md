# Transmute

Production-ready Helm chart for Transmute, a self-hosted audio and video
transcoding and compression platform powered by FFmpeg, Libvips, and modern hardware acceleration.

[![Artifact HUB](https://img.shields.io/endpoint?url=https://artifacthub.io/badge/repository/helmforge)](https://artifacthub.io/packages/helm/helmforge/transmute)

## Installation

### HTTPS Repository

"helmforge" already exists with the same configuration, skipping
Hang tight while we grab the latest from your chart repositories...
...Successfully got an update from the "helmforge" chart repository
Update Complete. ⎈Happy Helming!⎈

### OCI Registry

## Quick Start

## Features

- **Audio & Video Transcoding** via FFmpeg and Libvips
- **Single-writer Queue Architecture** with persistent state in
- **OpenID Connect (OIDC)** native Single Sign-On integration
- **Modern Exposure Patterns** via Ingress and canonical Gateway API
- **External Secrets Operator (ESO)** integration with native secret fallback
- **Hardened Security**: Non-root execution (),  capabilities dropped, and  seccomp

### Security Scan: `transmute`

| Framework          | Score         |
| ------------------ | ------------- |
| MITRE + NSA + SOC2 | **98.50000%** |

> Security posture acceptable.

Measured using Kubescape 4.0.13 against default manifests. This assesses Kubernetes deployment configuration, not the absence of upstream application vulnerabilities.

## Configuration

### Minimal (Simple Setup)

### Production (Full Setup)

## Parameters

### Image & Common

| Parameter | Description | Default |
|---|---|---|
|  | Transmute container image |  |
|  | Pinned upstream version |  |
|  | Image pull policy |  |

### Storage & Persistence

| Parameter | Description | Default |
|---|---|---|
|  | Enable persistent storage for job queues |  |
|  | Storage volume size |  |
|  | Volume access mode |  |
|  | Attach pre-existing PVC |  |

### Networking & Traffic

| Parameter | Description | Default |
|---|---|---|
|  | Kubernetes Service type |  |
|  | Service HTTP port |  |
|  | Enable standard Ingress |  |
|  | Enable Gateway API HTTPRoutes |  |
|  | List of HTTPRoute configurations |  |

### Authentication & Secrets

| Parameter | Description | Default |
|---|---|---|
|  | Name of existing secret for credentials |  |
|  | Enable OpenID Connect SSO |  |
|  | Enable External Secrets integration |  |

## Upgrading

### Upgrading to v2.1.1

Version 2.x updates the upstream transcoding worker engine and standardizes Gateway API
routing under the  key.

## Connection & First Access

### Port-Forward Access

### Retrieve Admin Password

## Architecture Guides

- [Design and boundaries](DESIGN.md)
- [Operations and integrations guide](docs/operations.md)
