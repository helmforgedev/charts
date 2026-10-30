# Immich Helm Chart

Immich is a self-hosted photo and video management platform. This HelmForge
chart deploys Immich server, machine learning, a Redis/Valkey-compatible cache,
and the upstream VectorChord PostgreSQL image recommended by Immich.

## Features

- Official Immich images pinned to `v3.1.0`.
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

## Configuration

The chart keeps application listeners, Service exposure, persistence, and
dependency selection as separate controls. Review the complete contract in
[`values.yaml`](values.yaml) before production use.

| Area | Primary values | Default behavior |
|---|---|---|
| Server | `server.*`, `service.*`, `resources` | One server pod listening on port `2283` behind a ClusterIP Service |
| Machine learning | `machineLearning.*` | One pod with a persistent `10Gi` model cache |
| Uploads | `server.persistence.*` | Persistent `50Gi` ReadWriteOnce volume |
| PostgreSQL | `postgresql.*`, `database.external.*` | Bundled PostgreSQL `2.1.1` with the Immich VectorChord image |
| Cache | `valkey.*` | Bundled Redis `3.1.0` aliased as `valkey` |
| Exposure | `ingress.*`, `gateway.*` | Disabled until explicitly configured |
| Credentials | `externalSecrets.*`, existing Secret fields | Generated dependency credentials unless an external source is selected |

The schema validates every documented default and rejects invalid listener
ports, replica counts, persistence sizes, and enum values during `helm lint`,
`helm template`, install, and upgrade.

Inspect the complete effective contract before each upgrade and keep the values
file under version control:

```bash
helm show values oci://ghcr.io/helmforgedev/helm/immich > immich-defaults.yaml
helm upgrade --install immich oci://ghcr.io/helmforgedev/helm/immich \
  --namespace immich --create-namespace --values immich-values.yaml
```

Compare new defaults with the previous release before reusing production
values. In particular, verify PostgreSQL extension compatibility, Secret key
names, persistence access modes, and the selected Redis topology. Helm owns the
Kubernetes resources, while database migrations, backup validation, and
certificate lifecycle remain operator responsibilities.

## Persistence

Persistent storage is enabled by default for uploads, PostgreSQL, internal cache, and
machine-learning model cache. For local smoke tests, disable persistence with
the k3d values file.

## Upgrading to Immich 3

Immich 3 removes support for `pgvecto.rs`. Check the active database extension
and effective `DB_VECTOR_EXTENSION` setting (`vectorchord` or `pgvector`). If
the database still uses `pgvecto.rs`, complete the upstream migration before
upgrading. Back up the database and uploads first; external PostgreSQL
migrations must be performed outside Helm. The server performs its application
database migrations during startup, and this chart's bundled PostgreSQL image
already uses VectorChord.

See the [Immich 3 migration guide](https://immich.app/blog/v3-migration) and
[VectorChord upgrade instructions](https://docs.immich.app/install/upgrading/#migrating-to-vectorchord). External
databases should follow the [standalone PostgreSQL migration guide](https://docs.immich.app/administration/postgres-standalone).

## Examples

### Extra Server Volumes

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

### External Database

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

### Gateway API

```yaml
gateway:
  enabled: true
  parentRefs:
    - name: public
      namespace: gateway-system
  hostnames:
    - immich.example.com
```

### Ingress

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

### NetworkPolicy

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

## Architecture

Clients reach the named `http` Service port, which targets the configurable
Immich listener. The server writes media to the uploads volume, metadata to
PostgreSQL, queue and cache data to Redis/Valkey, and inference requests to the
separate machine-learning Service. See [DESIGN.md](DESIGN.md) for the Mermaid
topology, dependency modes, trust boundaries, and known limitations.

## Security

- Pods use the RuntimeDefault seccomp profile and drop all Linux capabilities.
- Privilege escalation is disabled and ServiceAccount token automounting is off
  by default.
- Database and cache passwords are read from Kubernetes Secrets; plaintext
  values are intended only for local evaluation.
- NetworkPolicy is opt-in. Its default rule permits namespace ingress and all
  egress for dependency and external API compatibility; restrict both lists to
  match the cluster threat model.
- TLS terminates at an operator-managed Ingress or Gateway. The chart does not
  provision certificates or controllers.

## Troubleshooting

| Symptom | Check | Resolution |
|---|---|---|
| Server waits for PostgreSQL | `kubectl logs deploy/<release>-immich -c wait-for-postgresql` | Verify the selected host, port, Secret, and required database extensions. |
| Server waits for cache | `kubectl logs deploy/<release>-immich -c wait-for-valkey` | Verify the Valkey Service name or external cache endpoint. |
| Scaling is rejected during rendering | Upload or model-cache access modes | Use `ReadWriteMany` storage before adding replicas. |
| Machine-learning probes fail | `kubectl logs deploy/<release>-immich-machine-learning` | Confirm model-cache capacity and resource limits. |
| Ingress returns no endpoint | Service endpoints and route class | Confirm the controller, hostname, and `service.targetPort`. |

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
