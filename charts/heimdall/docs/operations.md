# Heimdall Operations

## Access

For local access without ingress, forward the Service:

```bash
kubectl port-forward svc/<release>-heimdall 8080:80
```

Then open `http://localhost:8080/`.

For production access, enable ingress and set at least one host:

```yaml
ingress:
  enabled: true
  ingressClassName: traefik
  hosts:
    - host: dashboard.example.com
      paths:
        - path: /
          pathType: Prefix
```

TLS is optional. Add `ingress.tls` only when the certificate Secret is available
or cert-manager annotations will create it.

## Persistence

Heimdall writes its SQLite database and configuration files to `/config`.
Persistence is enabled by default:

```yaml
persistence:
  enabled: true
  size: 1Gi
```

Use `persistence.existingClaim` when a platform-owned PVC should be reused:

```yaml
persistence:
  enabled: true
  existingClaim: heimdall-config
```

Disabling persistence is appropriate only for disposable environments:

```yaml
persistence:
  enabled: false
```

## File Ownership

The LinuxServer image uses `PUID` and `PGID` to align application file
ownership with the mounted volume:

```yaml
heimdall:
  puid: 1000
  pgid: 1000
  timezone: America/New_York
```

If the pod starts but cannot write configuration, confirm the PVC supports the
configured IDs or set a compatible pod/container security context.

## Upgrade Behavior

When persistence is enabled, the Deployment uses `Recreate` strategy to avoid
two pods writing to the same SQLite-backed `/config` directory during upgrades.

## Troubleshooting

Check rollout:

```bash
kubectl rollout status deployment/<release>-heimdall
```

Check pod logs:

```bash
kubectl logs -l app.kubernetes.io/instance=<release> --all-containers --tail=100
```

Check PVC binding:

```bash
kubectl get pvc -l app.kubernetes.io/instance=<release>
```

<!-- @AI-METADATA
type: chart-docs
title: Heimdall Operations
description: Operational guidance for Heimdall access, persistence, ownership, upgrades, and troubleshooting
keywords: heimdall, operations, persistence, pvc, ingress, linuxserver
purpose: Document production operations for the Heimdall chart
scope: Chart
relations:
  - charts/heimdall/README.md
  - charts/heimdall/values.yaml
path: charts/heimdall/docs/operations.md
version: 1.0
date: 2026-06-14
-->
