# Exposing Attic

Attic serves its API and Nix binary-cache protocol on one HTTP port. The chart
supports Kubernetes Ingress and Gateway API HTTPRoute. Both are disabled by
default and may coexist when an operator deliberately needs both surfaces.

## TLS is required for external use

JWT bearer tokens and cache traffic must not traverse untrusted networks over
plain HTTP. Terminate TLS at the Ingress controller, Gateway or an external
load balancer and set `config.apiEndpoint` to the resulting HTTPS URL.

## Large uploads

Nix closures can contain large NAR uploads and slow clients. Controller defaults
for body size, buffering and timeouts are frequently too small. Configure those
limits in controller-specific annotations or Gateway policy resources.

For ingress-nginx, a typical starting point is:

```yaml
ingress:
  annotations:
    nginx.ingress.kubernetes.io/proxy-body-size: "0"
    nginx.ingress.kubernetes.io/proxy-read-timeout: "600"
    nginx.ingress.kubernetes.io/proxy-send-timeout: "600"
```

Validate limits against the largest closure your builders upload.

## Gateway API

Each `gatewayAPI.httpRoutes` item renders one HTTPRoute. The chart injects its
Service backend when `rules` is omitted. Operators own Gateway listeners,
certificates and cross-namespace grants.

```yaml
gatewayAPI:
  enabled: true
  httpRoutes:
    - parentRefs:
        - name: public
          namespace: gateway-system
          sectionName: https
      hostnames:
        - cache.example.com
```

Check route status after installation:

```bash
kubectl -n attic get httproute -o yaml
```

Both `Accepted=True` and `ResolvedRefs=True` are required.

## Host validation

The public hostname must be present in three places:

1. the Ingress host or HTTPRoute hostname;
2. `config.apiEndpoint`;
3. `config.allowedHosts`.

Misalignment normally appears as HTTP 400 responses or client URLs pointing to
an internal address.

## S3 presigned URLs

When a custom S3-compatible endpoint is configured, upstream may expose it in
presigned URLs. Use an endpoint reachable by Nix clients. An internal-only
MinIO Service name is insufficient for clients outside the cluster.

## Subpaths

Root-host routing is the supported default. If a controller rewrites Attic
under a subpath, test login, cache creation, `.narinfo` responses, NAR upload
and NAR download. The API and substituter endpoint must use the same canonical
path semantics.
