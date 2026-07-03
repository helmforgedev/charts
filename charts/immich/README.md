# Immich Helm Chart

Immich is a self-hosted photo and video management platform. This HelmForge
chart deploys Immich server, machine learning, a Redis/Valkey-compatible cache,
and the upstream VectorChord PostgreSQL image recommended by Immich.

## Highlights

- Official Immich images pinned to `v2.7.5`.
- Internal PostgreSQL uses `ghcr.io/immich-app/postgres:14-vectorchord0.4.3-pgvectors0.2.0`.
- Internal cache uses the HelmForge Redis chart aliased as `valkey` for
  Redis/Valkey-compatible protocol support.
- Machine learning service enabled by default with a model cache volume.
- External database and Redis/Valkey support with External Secrets Operator hooks.
- Gateway API, Ingress, dual-stack Service support, HPA, PDB, NetworkPolicy,
  schema, and Helm tests.
- Production, external-service, and networking guides with runnable examples.

## Install

```bash
helm install immich oci://ghcr.io/helmforgedev/helm/immich
```

## Persistence

Persistent storage is enabled by default for uploads, PostgreSQL, internal cache, and
machine-learning model cache. For local smoke tests, disable persistence with
the k3d values file.

## Extra Server Volumes

Use `extraVolumes` and `extraVolumeMounts` to mount additional ConfigMaps,
Secrets, or PVCs into the Immich server container. This is useful for custom
configuration files and read-only external media locations.

```yaml
extraVolumes:
  - name: external-media
    persistentVolumeClaim:
      claimName: external-media
  - name: immich-config
    configMap:
      name: immich-config

extraVolumeMounts:
  - name: external-media
    mountPath: /mnt/external-media
    readOnly: true
  - name: immich-config
    mountPath: /config/immich
    readOnly: true
```

## External Database

```yaml
postgresql:
  enabled: false
database:
  external:
    host: postgres.example.com
    database: immich
    username: immich
    existingSecret: immich-db
    existingSecretPasswordKey: database-password
```

## Gateway API

```yaml
gateway:
  enabled: true
  parentRefs:
    - name: public
      namespace: gateway-system
  hostnames:
    - immich.example.com
```

## Ingress

```yaml
ingress:
  enabled: true
  ingressClassName: traefik
  hosts:
    - host: immich.example.com
      paths:
        - path: /
          pathType: Prefix
```

## NetworkPolicy

```yaml
networkPolicy:
  enabled: true
  extraEgress:
    - to:
        - ipBlock:
            cidr: 10.0.0.0/8
      ports:
        - protocol: TCP
          port: 443
```

## Documentation

- [Design](DESIGN.md)
- [Production guide](docs/production.md)
- [External services](docs/external-services.md)
- [Networking](docs/networking.md)
- [Examples](examples/)

## Local Validation

```bash
helm dependency build charts/immich
helm lint --strict charts/immich
helm unittest --with-subchart=false charts/immich
helm template immich charts/immich -f charts/immich/ci/ci-values.yaml
```

### Security Scan: `immich`

| Framework | Score |
|---|---|
| MITRE + NSA + SOC2 | **88.61111%** |

Security posture acceptable.
