# certimate

Deploy [Certimate](https://github.com/certimate-go/certimate), a self-hosted certificate automation platform for ACME issuance, deployment, renewal, and monitoring.

This chart packages the official `certimate/certimate:v0.4.26` image and follows the upstream container contract: HTTP on port `8090` and durable PocketBase data under `/app/pb_data`.

## Production Defaults

- one Deployment using `Recreate` strategy for single-writer PocketBase storage
- one PersistentVolumeClaim mounted at `/app/pb_data`
- restricted ServiceAccount token mounting by default
- Kubernetes Ingress and Gateway API HTTPRoute support
- optional NetworkPolicy with explicit additional egress for ACME DNS APIs, DNS, SMTP, webhooks, and target deployment systems
- ExternalSecret support for environment variables or other integration secrets
- test hook for in-cluster HTTP reachability

## Install

```bash
helm repo add helmforge https://helmforge.dev/charts
helm install certimate helmforge/certimate
```

Forward the service for the first login:

```bash
kubectl port-forward svc/certimate 8090:8090
```

Then open `http://127.0.0.1:8090`.

The upstream image documents a default administrator account. Change it
immediately after first login, then store production users, provider
credentials, workflows, and certificate material on persistent storage.

## Exposure

```yaml
ingress:
  enabled: true
  ingressClassName: traefik
  hosts:
    - host: certs.example.com
      paths:
        - path: /
          pathType: Prefix
  tls:
    - secretName: certimate-tls
      hosts:
        - certs.example.com
```

Gateway API is also supported:

```yaml
gatewayAPI:
  enabled: true
  httpRoutes:
    - parentRefs:
        - name: public
          namespace: gateway-system
      hostnames:
        - certs.example.com
```

## Operations

Back up the PersistentVolumeClaim before upgrades. Certimate stores its
PocketBase database, uploaded certificate material, ACME account state, workflow
definitions, and provider credentials under `/app/pb_data`.

For production, enable `networkPolicy.enabled` and add egress rules for the DNS
providers, certificate deployment targets, SMTP relays, webhook endpoints, and
ACME endpoints required by your workflows.

## Security Scan

Local security scan:

```text
Image: certimate/certimate:v0.4.26
Scanner: pending local repository security scan
Result: pending
```

The chart is designed for the HelmForge security scan workflow. Local scan
evidence must be refreshed before merge with the repository security tooling and
then pasted into this section if required by the release checklist.

## Documentation

- [Storage](docs/storage.md)
- [Exposure](docs/exposure.md)
