# Architecture

## Overview

Envoy Gateway (EG) is a Kubernetes operator built on the Gateway API. This chart deploys the EG controller, which then manages Envoy proxy pods automatically.

## Components

### Controller (managed by this chart)

- Watches Gateway API resources (GatewayClass, Gateway, HTTPRoute, etc.)
- Watches EG-specific CRDs (SecurityPolicy, BackendTrafficPolicy, etc.)
- Provisions and configures Envoy proxy pods automatically

### Standalone CRD lifecycle release

- Installs 8 Envoy Gateway v1.9.0 and 10 Gateway API v1.6.1 Experimental CRDs
  before the application release
- Owns the Gateway API safe-upgrade admission policy and binding
- Applies CRD upgrades server-side before controller upgrades because Helm does
  not upgrade objects from `crds/`
- Establishes the discovery boundary required by a validated first `helm diff`

The local CRD subchart remains enabled by default only as the migration bridge
from application chart 1.10.1. Existing users first upgrade with
`crds.enabled=true`, then follow [the ownership-preserving CRD migration](crd-migration.md)
before setting it to `false`. New installations apply `envoy-gateway-crds`
first and install this application release with `crds.enabled=false`.

### Certgen Job (managed by this chart)

- Runs as a pre-install/pre-upgrade Helm hook
- Generates TLS certificates for the controller webhook and xDS server
- Stores certs in Secrets: `<release>-certs`

### GatewayClass (managed by this chart)

- Registers the controller with the Gateway API
- References the EnvoyProxy CRD for proxy shape configuration

### EnvoyProxy resource (managed by this chart)

- Configures how EG provisions proxy pods:
  - `proxy.kind: Deployment|DaemonSet`
  - Replicas, resources, service type
  - HPA configuration

### Gateway (managed by this chart, optional)

- Creates a default `Gateway` resource when `gateway.create: true`
- The `Gateway` resource triggers EG to provision Envoy proxy pods
- Users create `HTTPRoute`, `TCPRoute`, `GRPCRoute` etc. that attach to this Gateway

### Envoy Proxy Pods (managed by EG operator, NOT by this chart)

- Created automatically when a `Gateway` resource exists
- Named `envoy-<namespace>-<gateway-name>-<uid>`
- Service is also created automatically with the same naming convention

## Request Flow

```text
Client
  │
  ▼
Envoy Proxy Pod (EG-managed)
  │  ← routes configured by HTTPRoute resources
  ▼
Backend Service
```text

## Policy Hierarchy

Policies attach to Gateway API resources via `targetRef`:

```text
GatewayClass ← EnvoyProxy (proxy shape)
     │
Gateway ← SecurityPolicy (auth)
     │   ← ClientTrafficPolicy (listener TLS, connection limits)
     │   ← BackendTrafficPolicy (retries, timeouts, circuit breaking)
     │
HTTPRoute ← SecurityPolicy (per-route auth override)
          ← BackendTrafficPolicy (per-route traffic override)
     │
Backend Service
```

## Quick Start

1. Install chart → GatewayClass + EnvoyProxy + certgen job run
2. `gateway.create: true` → Gateway resource created → EG provisions proxy pods + service
3. Create HTTPRoutes that reference the Gateway
4. (Optional) Create SecurityPolicy, BackendTrafficPolicy, ClientTrafficPolicy for advanced config
