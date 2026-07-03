# NoteDiscovery Helm Chart

Deploy [NoteDiscovery](https://github.com/gamosoft/NoteDiscovery), a
self-hosted Markdown knowledge base with graph view, search, sharing, and MCP
integration.

This chart packages the official `ghcr.io/gamosoft/notediscovery:0.27.3` image
and exposes the runtime settings that matter for Kubernetes: persistent note
storage, generated or externally managed `config.yaml`, optional authentication,
ingress/Gateway API exposure, network policy, pod disruption budget, and
non-root security context.

## Architecture

NoteDiscovery runs as one Python web service listening on port `8000`. The
upstream container stores durable notes and related files under `/app/data` and
reads application settings from `/app/config.yaml`.

The default chart topology is intentionally conservative:

- one Deployment replica with `Recreate` rollout strategy
- one PersistentVolumeClaim mounted at `/app/data`
- generated ConfigMap for unauthenticated `config.yaml`
- ServiceAccount token automount disabled
- non-root container security context

When authentication is enabled, the generated `config.yaml` is stored in a
Kubernetes Secret so `secret_key`, `password`, and `api_key` are not rendered
into a ConfigMap. For GitOps and production, prefer `auth.existingSecret` with a
complete `config.yaml` key.

## Install

```bash
helm repo add helmforge https://repo.helmforge.dev
helm install notediscovery helmforge/notediscovery
```

Forward the service for local validation:

```bash
kubectl port-forward svc/notediscovery 8000:8000
```

Then open `http://127.0.0.1:8000`.

## Production Values

```yaml
notediscovery:
  allowedOrigins:
    - https://notes.example.com

auth:
  enabled: true
  existingSecret: notediscovery-config
  existingSecretKey: config.yaml

ingress:
  enabled: true
  ingressClassName: traefik
  hosts:
    - host: notes.example.com
      paths:
        - path: /
          pathType: Prefix
  tls:
    - secretName: notediscovery-tls
      hosts:
        - notes.example.com

persistence:
  enabled: true
  size: 20Gi

resources:
  requests:
    cpu: 100m
    memory: 256Mi
  limits:
    cpu: 1
    memory: 1Gi

networkPolicy:
  enabled: true
  extraEgress:
    - to:
        - ipBlock:
            cidr: 10.0.0.0/8
      ports:
        - protocol: TCP
          port: 8443
```

Create the existing Secret with a complete NoteDiscovery config file:

```yaml
apiVersion: v1
kind: Secret
metadata:
  name: notediscovery-config
type: Opaque
stringData:
  config.yaml: |
    app:
      name: "NoteDiscovery"
    server:
      host: "0.0.0.0"
      port: 8000
      reload: false
      allowed_origins:
        - https://notes.example.com
      debug: false
    storage:
      notes_dir: "/app/data"
      plugins_dir: "./plugins"
    search:
      enabled: true
    ui:
      autosave_delay_ms: 1000
    authentication:
      enabled: true
      secret_key: "replace-with-a-long-random-secret"
      password: "replace-with-a-strong-password"
      session_max_age: 604800
      api_key: ""
```

## Authentication

`auth.enabled=false` is the default so first-time local installs start without
credentials. For any shared or internet-facing deployment, enable authentication
and provide either:

- `auth.secretKey` and `auth.password`, which render into a chart-managed Secret
- `auth.existingSecret`, which must contain a complete `config.yaml`

`auth.existingSecret` is preferred for production because it avoids putting secret values in Helm values files.

## Storage

Back up the PersistentVolumeClaim before upgrades. NoteDiscovery stores notes
and local application data under `/app/data` by default.

The chart blocks `replicaCount > 1` unless `persistence.existingClaim` is set.
Multiple pods require storage semantics chosen by the operator, typically a
shared ReadWriteMany claim; the default generated claim is a single-writer
volume.

## Network Policy

`networkPolicy.enabled=true` restricts inbound HTTP traffic to the configured
`networkPolicy.ingressFrom` peers, or to all namespaces when `ingressFrom` is
empty. `networkPolicy.extraEgress` enables egress isolation and appends custom
egress rules after built-in DNS and HTTPS allowances.

## Documentation

- [Storage](docs/storage.md)
- [Authentication](docs/authentication.md)
- [Exposure](docs/exposure.md)
- [MCP integration](docs/mcp.md)

## Security Scan: `notediscovery`

| Framework | Score |
|---|---|
| Overall | **87.37%** |
| MITRE | **100.00%** |
| NSA | **82.50%** |
| SOC2 | **86.67%** |

> Security posture acceptable.
