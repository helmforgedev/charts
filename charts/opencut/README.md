# OpenCut Helm Chart

OpenCut is an open-source video editor. This HelmForge chart deploys the
OpenCut web application with PostgreSQL and Redis dependencies, plus a
Redis-over-HTTP bridge required by the upstream application runtime.

## Highlights

- HelmForge-maintained `docker.io/helmforge/opencut:v0.3.0` image.
- PostgreSQL and Redis subcharts for a turnkey install.
- `serverless-redis-http` bridge for `UPSTASH_REDIS_REST_*` compatibility.
- External Redis REST endpoint support when the in-cluster bridge is disabled.
- External Secrets Operator integration for external database credentials.
- Gateway API, Ingress, dual-stack Service support, HPA, PDB, NetworkPolicy,
  schema, and Helm tests.
- Production, external-service, and networking guides with runnable examples.

## Install

```bash
helm install opencut oci://ghcr.io/helmforgedev/helm/opencut \
  --set opencut.siteUrl=https://opencut.example.com \
  --set opencut.betterAuthSecret="$(openssl rand -hex 32)"
```

## External Database

```yaml
postgresql:
  enabled: false

database:
  external:
    host: postgres.example.com
    name: opencut
    username: opencut
    existingSecret: opencut-db
    existingSecretPasswordKey: database-password
```

## Bundled Subcharts

The chart uses the HelmForge PostgreSQL and Redis subcharts by default. OpenCut
derives connection hosts and Secret names from the same `nameOverride`,
`fullnameOverride`, and architecture settings used by those dependencies. Redis
standalone mode connects through the client Service, while Redis replication
mode connects the HTTP bridge to the primary Service.

## Networking

Ingress uses the HelmForge-standard `ingress.ingressClassName` key:

```yaml
ingress:
  enabled: true
  ingressClassName: traefik
  hosts:
    - host: opencut.example.com
      paths:
        - path: /
          pathType: Prefix
```

Gateway API support is exposed through a single `gateway` block:

```yaml
gateway:
  enabled: true
  parentRefs:
    - name: public
  hostnames:
    - opencut.example.com
```

## Documentation

- [Design](DESIGN.md)
- [Production guide](docs/production.md)
- [External services](docs/external-services.md)
- [Networking](docs/networking.md)
- [Examples](examples/)

## External Secrets

```yaml
postgresql:
  enabled: false

database:
  external:
    host: postgres.example.com
    existingSecret: opencut-db
    existingSecretPasswordKey: database-password

externalSecrets:
  enabled: true
  secretStoreRef:
    name: platform-secrets
  data:
    - secretKey: database-password
      remoteRef:
        key: opencut/database
        property: password
```

## Local Validation

```bash
helm dependency build charts/opencut
helm lint charts/opencut
helm template opencut charts/opencut -f charts/opencut/ci/ci-values.yaml
helm unittest charts/opencut
kubeconform -strict -summary rendered.yaml
```

### 🟢 Security Scan: `opencut`

| Framework | Score |
|---|---|
| MITRE + NSA + SOC2 | **92.85354%** |

> ✅ Security posture acceptable.
