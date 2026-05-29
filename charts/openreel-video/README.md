# OpenReel Video Helm Chart

OpenReel Video is an open-source, browser-based video editor. This chart serves
the static application with the HelmForge-maintained image and Kubernetes
defaults tuned for WebCodecs and WASM workloads.

## Highlights

- HelmForge-maintained `docker.io/helmforge/openreel-video:v0.4.0` image.
- Non-root NGINX runtime on port `8080`.
- `/healthz` endpoint for probes and Helm tests.
- COOP/COEP headers are included in the image for SharedArrayBuffer, WebCodecs,
  and WASM-heavy browser workflows.
- Gateway API, Ingress, dual-stack Service support, HPA, PDB, NetworkPolicy,
  schema, and Helm tests.
- Production, networking, and runtime documentation with runnable examples.

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
