# OpenCut Helm Chart

OpenCut is an open-source video editor. This HelmForge chart deploys the
OpenCut web application with PostgreSQL and Redis dependencies, plus a
Redis-over-HTTP bridge required by the upstream application runtime.

## Features

- HelmForge-maintained `docker.io/helmforge/opencut:v0.3.0` image.
- PostgreSQL and Redis subcharts for a turnkey install.
- `serverless-redis-http` bridge for `UPSTASH_REDIS_REST_*` compatibility.
- External Redis REST endpoint support when the in-cluster bridge is disabled.
- External Secrets Operator integration for external database credentials.
- Gateway API, Ingress, dual-stack Service support, HPA, PDB, NetworkPolicy,
  schema, and Helm tests.
- Production, external-service, and networking guides with runnable examples.

## Architecture

The OpenCut web Deployment listens on `containerPorts.http` and connects to
PostgreSQL plus an Upstash-compatible Redis HTTP endpoint. By default, the
release owns HelmForge PostgreSQL and Redis subcharts and runs a dedicated
`serverless-redis-http` bridge. The Service ports remain independent of both
process listener ports. See [DESIGN.md](DESIGN.md) for trust boundaries and
dependency modes.

## Install

```bash
helm install opencut oci://ghcr.io/helmforgedev/helm/opencut \
  --set opencut.siteUrl=https://opencut.example.com \
  --set opencut.betterAuthSecret="$(openssl rand -hex 32)"
```

## Examples

### External Database

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

NetworkPolicy can append full custom web egress rules while keeping the generated
DNS, database, Redis HTTP bridge, and HTTPS egress rules:

```yaml
networkPolicy:
  enabled: true
  extraEgress: []
```

## Configuration

| Parameter | Default | Description |
| --- | --- | --- |
| `containerPorts.http` | `3000` | OpenCut process HTTP listener. |
| `service.port` | `80` | OpenCut Service port; targets the named HTTP port. |
| `opencut.siteUrl` | `""` | Public URL used by authentication callbacks and browser links. |
| `opencut.betterAuthSecret` | `""` | Stable Better Auth secret; set explicitly for production. |
| `opencut.marbleApiUrl` | `https://api.marblecms.com` | Marble CMS API URL. |
| `opencut.extraEnv` | `[]` | Additional environment variables, excluding chart-managed listener variables. |
| `postgresql.enabled` | `true` | Deploy the bundled HelmForge PostgreSQL chart. |
| `database.external.host` | `""` | External PostgreSQL host when the bundled database is disabled. |
| `redis.enabled` | `true` | Deploy the bundled HelmForge Redis chart. |
| `redisHttp.enabled` | `true` | Deploy the Redis-over-HTTP bridge. |
| `redisHttp.containerPorts.http` | `80` | Redis HTTP bridge process listener (`SRH_PORT`). |
| `redisHttp.service.port` | `80` | Redis HTTP bridge Service port. |
| `redisHttp.external.url` | `""` | External Upstash-compatible endpoint when the bridge is disabled. |
| `ingress.enabled` | `false` | Render an Ingress. |
| `gateway.enabled` | `false` | Render a Gateway API HTTPRoute. |
| `networkPolicy.enabled` | `false` | Isolate OpenCut and the Redis HTTP bridge. |
| `autoscaling.enabled` | `false` | Enable the OpenCut HorizontalPodAutoscaler. |
| `pdb.enabled` | `true` | Render a PodDisruptionBudget. |

`containerPorts.http` and `redisHttp.containerPorts.http` change the real
application listeners through `PORT` and `SRH_PORT`. They do not change
`service.port` or `redisHttp.service.port`.

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

## Troubleshooting

- If the web pod is healthy but traffic fails, compare `service.port`, the
  named `targetPort`, and `containerPorts.http`.
- If authentication redirects to the wrong origin, set `opencut.siteUrl` to
  the exact externally visible URL.
- If the Redis HTTP bridge is not ready, verify its token, Redis credentials,
  and that `SRH_PORT` matches `redisHttp.containerPorts.http`.
- If NetworkPolicy is enabled, confirm DNS, PostgreSQL, Redis, and required
  HTTPS destinations are allowed.

### Security Scan: `opencut`

| Framework | Score |
| --- | --- |
| MITRE + NSA + SOC2 | **92.85354%** |

Security posture: acceptable.
