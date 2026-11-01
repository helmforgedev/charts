# OpenReel Video Helm Chart

OpenReel Video is an open-source, browser-based video editor. This chart serves
the static application with the HelmForge-maintained image and Kubernetes
defaults tuned for WebCodecs and WASM workloads.

## Features

- HelmForge-maintained `docker.io/helmforge/openreel-video:v0.5.0` image.
- Non-root NGINX runtime on port `8080`.
- `/healthz` endpoint for probes and Helm tests.
- COOP/COEP headers are included in the image for SharedArrayBuffer, WebCodecs,
  and WASM-heavy browser workflows.
- Gateway API, Ingress, dual-stack Service support, HPA, PDB, NetworkPolicy,
  schema, and Helm tests.
- Production, networking, and runtime documentation with runnable examples.

## Architecture

OpenReel Video is a stateless single-container web application. NGINX serves the
compiled browser editor on port `8080`; media import, timeline processing, and
export happen in the user's browser. The chart does not provision a database,
object storage, queue, or server-side encoder. A Service fronts the Deployment,
with optional Ingress or Gateway API routing. See [DESIGN.md](DESIGN.md) for the
topology and responsibility boundaries.

## Install

```bash
helm install openreel-video oci://ghcr.io/helmforgedev/helm/openreel-video
```

## Gateway API

```yaml
gateway:
  enabled: true
  parentRefs:
    - name: public
      namespace: gateway-system
  hostnames:
    - openreel.example.com
```

## Ingress

```yaml
ingress:
  enabled: true
  ingressClassName: traefik
  hosts:
    - host: openreel.example.com
      paths:
        - path: /
          pathType: Prefix
```

## NetworkPolicy

```yaml
networkPolicy:
  enabled: true
  extraEgress: []
```

Use `networkPolicy.extraEgress` to append full custom egress rules.

## Configuration Reference

The schema documents every default leaf while remaining tolerant of values
stored by earlier releases. Important settings are:

| Value | Default | Purpose |
| --- | --- | --- |
| `global` | `{}` | Parent-chart and platform integration values |
| `replicaCount` | `1` | Static web replicas when HPA is disabled |
| `revisionHistoryLimit` | `3` | Retained Deployment revisions |
| `image.repository` | `docker.io/helmforge/openreel-video` | HelmForge-maintained image |
| `image.tag` | `v0.5.0` | Pinned OpenReel Video image tag |
| `serviceAccount.create` | `true` | Create a dedicated ServiceAccount |
| `serviceAccount.automountServiceAccountToken` | `false` | Keep API credentials out of the pod |
| `service.type` | `ClusterIP` | Kubernetes Service type |
| `service.port` | `80` | Client-facing Service port |
| `service.targetPort` | `8080` | Fixed NGINX listener; keep this at `8080` |
| `ingress.enabled` | `false` | Render an Ingress |
| `gateway.enabled` | `false` | Render an HTTPRoute |
| `networkPolicy.enabled` | `false` | Restrict ingress and deny egress by default |
| `autoscaling.enabled` | `false` | Manage replicas with an HPA |
| `pdb.enabled` | `true` | Render a PodDisruptionBudget |
| `probes.liveness` | enabled | Liveness check against `/healthz` |
| `probes.readiness` | enabled | Readiness check against `/healthz` |
| `resources` | small requests and limits | Container CPU and memory budget |
| `podSecurityContext` | UID/GID `101` | Verified unprivileged image identity |
| `securityContext` | hardened | Read-only root, no escalation, drop all capabilities |
| `tmpVolume.enabled` | `true` | Writable `/tmp` for unprivileged NGINX |
| `extraObjects` | `[]` | Additional templated Kubernetes resources |

The pinned image declares user `101` and exposes port `8080`; its NGINX
configuration also listens on `8080`. Changing only `service.targetPort` does
not reconfigure NGINX and will make probes and traffic fail.

## Production Example

```yaml
replicaCount: 2

ingress:
  enabled: true
  ingressClassName: traefik
  hosts:
    - host: openreel.example.com
      paths:
        - path: /
          pathType: Prefix

networkPolicy:
  enabled: true

resources:
  requests:
    cpu: 50m
    memory: 64Mi
  limits:
    cpu: 500m
    memory: 256Mi
```

Because rendering happens in the browser, size replicas for static asset
delivery and concurrent downloads, not for video encoding CPU. Preserve the
image's COOP and COEP response headers in any proxy or CDN.

## Security

The default pod runs as the image's verified UID/GID `101`, disables Service
Account token mounting, uses RuntimeDefault seccomp, drops every Linux
capability, prevents privilege escalation, and keeps the root filesystem
read-only. The `/tmp` emptyDir is the only writable runtime path required by
NGINX. NetworkPolicy is opt-in because ingress-controller namespace selectors
and policies vary by cluster; when enabled, the default allows inbound HTTP
from cluster namespaces and denies all egress.

## Troubleshooting

- If probes fail, confirm `service.targetPort` is `8080` and inspect
  `kubectl logs deploy/RELEASE-openreel-video`.
- If the editor loads but browser APIs fail, verify that the edge preserves
  `Cross-Origin-Opener-Policy` and `Cross-Origin-Embedder-Policy` headers.
- If traffic stops after enabling NetworkPolicy, add the intended ingress or
  Gateway controller peers to `networkPolicy.ingress`.
- If NGINX reports a read-only filesystem error, keep `tmpVolume.enabled=true`
  and do not weaken the remaining container security controls.
- For an upgrade, use `helm upgrade --reuse-values` only after reviewing stored
  values; the chart keeps the existing image, port, and security defaults.

## Documentation

- [Design](DESIGN.md)
- [Production guide](docs/production.md)
- [Networking](docs/networking.md)
- [Runtime](docs/runtime.md)
- [Examples](examples/)

## Local Validation

```bash
helm lint charts/openreel-video --strict
helm template openreel-video charts/openreel-video -f charts/openreel-video/ci/ci-values.yaml
helm unittest charts/openreel-video
kubeconform -strict -summary rendered.yaml
```

### Security Scan: `openreel-video`

| Framework | Score |
| --- | --- |
| MITRE + NSA + SOC2 | **86.580086%** |

Security posture: acceptable.
