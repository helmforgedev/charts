<!-- SPDX-License-Identifier: Apache-2.0 -->
# Automatisch Configuration

## Process model

The chart runs a web Deployment and, by default, a worker Deployment. The web
process serves the UI and API and performs database migrations during startup.
The worker sets `WORKER=true` and executes jobs from Redis. Disabling
`worker.enabled` is useful only for maintenance or deliberate external worker
management; normal installations require a worker for workflow execution.

`automatisch.extraEnv` is appended to both processes. Do not use it to replace
chart-managed `PORT`, datastore, or cryptographic variables because duplicate
environment names have ambiguous behavior.

## Listener and Service ports

`automatisch.containerPorts.http` controls the process listener. The chart maps
it to the container's named `http` port and the upstream `PORT` environment
variable. `service.port` controls the Kubernetes Service port only.
`automatisch.host` defaults to `0.0.0.0` so probes and Services can reach the
process; do not change it to loopback in Kubernetes.

```yaml
automatisch:
  containerPorts:
    http: 8080

service:
  port: 80
```

With this configuration, Automatisch listens on 8080 inside the pod while
clients use port 80 on the Service.

## Datastores

The default configuration deploys HelmForge PostgreSQL and Redis subcharts:

```yaml
postgresql:
  enabled: true
  auth:
    database: automatisch
    username: automatisch

redis:
  enabled: true
```

For external services, disable each subchart and use the corresponding
external block:

```yaml
postgresql:
  enabled: false
redis:
  enabled: false

database:
  external:
    host: postgres.example.com
    port: "5432"
    name: automatisch
    username: automatisch
    existingSecret: automatisch-db
    existingSecretPasswordKey: password

redis_config:
  external:
    host: redis.example.com
    port: "6379"
    existingSecret: automatisch-redis
    existingSecretPasswordKey: password
```

Inline `database.external.password` and `redis_config.external.password` are
supported for evaluation but store credentials in Helm release values. Prefer
existing Secrets in production. The bundled Redis password is read from the
HelmForge Redis subchart Secret automatically.

## Worker scaling

Scale background execution independently from the web process:

```yaml
worker:
  enabled: true
  replicaCount: 3
  resources:
    requests:
      cpu: 200m
      memory: 256Mi
    limits:
      memory: 512Mi
```

Increasing workers increases concurrency and may increase third-party API and
database load. Review integration rate limits and Redis capacity first.

## Network policy

The default policy permits inbound traffic only to the named HTTP port and
permits all egress because workflows contact arbitrary integration endpoints.
To restrict egress, replace the default rule with rules covering cluster DNS,
PostgreSQL, Redis, and approved external destinations.

```yaml
networkPolicy:
  enabled: true
  ingress: []
  egress:
    - to:
        - ipBlock:
            cidr: 10.0.0.0/8
```

Kubernetes NetworkPolicy cannot express DNS names. Use an egress proxy or a CNI
with FQDN policy support when destination names are required.

## Scheduling and resources

`resources` applies to the web container and `worker.resources` applies to the
worker. Shared scheduling values (`nodeSelector`, `tolerations`, `affinity`,
`topologySpreadConstraints`, and `priorityClassName`) apply to both Deployments.

## Related guides

- [README](../README.md)
- [Chart design](../DESIGN.md)
- [Operations](operations.md)
- [Security](security.md)
- [External datastore example](../examples/external-datastores.yaml)
- [Production example](../examples/production.yaml)
