# certimate

Deploy [Certimate](https://github.com/certimate-go/certimate), a self-hosted certificate automation platform for ACME issuance, deployment, renewal, and monitoring.

This chart packages the official `certimate/certimate:v0.4.35` image and follows the upstream container contract: HTTP on port `8090` and durable PocketBase data under `/app/pb_data`.

## Features and architecture

- one Deployment using `Recreate` strategy for single-writer PocketBase storage
- one `10Gi` PersistentVolumeClaim mounted at `/app/pb_data`
- explicit `persistence.ephemeral=true` opt-in for disposable emptyDir installs
- default resource requests and memory limit for scheduler and Kubescape hygiene
- restricted ServiceAccount token mounting by default
- ephemeral writable `/tmp` storage while the container root filesystem remains read-only
- optional `tmpStorage.sizeLimit` with matching ephemeral-storage request and limit
- Kubernetes Ingress and Gateway API HTTPRoute support
- optional NetworkPolicy with explicit additional egress for ACME DNS APIs, DNS, SMTP, webhooks, and target deployment systems
- ExternalSecret support for environment variables or other integration secrets
- test hook for in-cluster HTTP reachability

The chart runs one Recreate Deployment because PocketBase state is single-writer.
See [DESIGN.md](DESIGN.md) for the topology, production boundaries and intentional
limitations.

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

## Configuration

Keep `app.port` as the real Certimate listener and use `service.port` only for the
Kubernetes Service. Production settings should explicitly preserve the PVC,
security ownership, image pin and workflow-specific environment sources. Start
from [secured.yaml](examples/secured.yaml); the [simple](examples/simple.yaml),
[Ingress](examples/ingress.yaml) and [Gateway API](examples/gateway-api.yaml)
examples cover other supported paths. The complete values contract is in
`values.yaml` and `values.schema.json`.

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

Certimate 0.4.35 adds OpenSSH user-certificate authentication for SSH
credentials and fixes Cloudflare SSL and Alibaba Cloud CAS certificate
deployments. It does not change the container port, storage path, or chart
configuration contract. Review the
[official release](https://github.com/certimate-go/certimate/releases/tag/v0.4.35).

Before upgrading, export current overrides, review them against the new defaults
and preserve `persistence.existingClaim`, storage size/class, UID/GID ownership,
ports and environment sources. Pin the reviewed chart version explicitly. Test
both PocketBase login and a representative issuance/deployment workflow after the
upgrade; a successful Helm revision alone is not proof of certificate continuity.

Certimate's upstream deployment uses PocketBase-local state. This chart does not
ship PostgreSQL, MySQL, or Redis subcharts because the product does not expose an
official external database mode for its application state. Treat the PVC as the
database and certificate material authority.

For production, enable `networkPolicy.enabled` and add egress rules for the DNS
providers, certificate deployment targets, SMTP relays, webhook endpoints, and
ACME endpoints required by your workflows.

## Security Scan

Local security scan:

```text
Image: certimate/certimate:v0.4.35
Scanner: Kubescape v4.0.9, frameworks MITRE, NSA, SOC2
Result: 93.93939 compliance score
```

The local scan reported no critical or high-severity failures. Remaining medium
findings are expected until operators enable a production NetworkPolicy matching
their ACME, DNS provider, SMTP, webhook, and deployment destinations.

## Troubleshooting

Inspect the Deployment logs and events, verify `/api/health`, and confirm that UID
1000 can write both `/app/pb_data` and `/tmp`. If certificate workflows fail while
the UI remains healthy, validate DNS, ACME, SMTP and deployment-target egress
independently. A NetworkPolicy that permits only the UI path can still block every
workflow integration.

## Documentation

- [Storage](docs/storage.md)
- [Exposure](docs/exposure.md)
