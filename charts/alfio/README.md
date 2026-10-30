<!-- SPDX-License-Identifier: Apache-2.0 -->

# alf.io Helm Chart

Deploy [alf.io](https://alf.io), an open-source event ticketing and attendee
management platform, with its official image and PostgreSQL.

## Features

- Official alf.io image pinned to `2.0-M5-2609`
- Bundled HelmForge PostgreSQL or an external PostgreSQL service
- Real Spring Boot listener configuration independent from the Service port
- Startup, liveness, and readiness checks on `/healthz`
- Non-root, read-only, capability-free security defaults
- Service-account token disabled and ingress NetworkPolicy enabled by default
- Optional Ingress with TLS configuration

## Install

```bash
helm repo add helmforge https://repo.helmforge.dev
helm repo update
helm install alfio helmforge/alfio \
  --set alfio.baseUrl=https://tickets.example.com
```

The equivalent OCI install is:

```bash
helm install alfio oci://ghcr.io/helmforgedev/helm/alfio \
  --set alfio.baseUrl=https://tickets.example.com
```

Access a ClusterIP installation locally:

```bash
kubectl port-forward service/alfio-alfio 8080:80
```

Then open `http://localhost:8080`. alf.io guides the administrator through
first-time setup.

## Production Example

```yaml
alfio:
  baseUrl: https://tickets.example.com

postgresql:
  enabled: false

database:
  external:
    host: postgres.example.com
    port: "5432"
    name: alfio
    username: alfio
    existingSecret: alfio-db-credentials
    existingSecretPasswordKey: password

ingress:
  enabled: true
  ingressClassName: nginx
  hosts:
    - host: tickets.example.com
      paths:
        - path: /
          pathType: Prefix
  tls:
    - hosts:
        - tickets.example.com
      secretName: alfio-tls

resources:
  requests:
    cpu: 250m
    memory: 512Mi
  limits:
    memory: 1Gi
```

## Listener and Service Ports

`alfio.containerPort` changes the port used by the actual Spring Boot process.
`service.port` changes only the Kubernetes Service port. The Service always
targets the named application port.

```yaml
alfio:
  containerPort: 8081

service:
  port: 9080
```

## Security

The defaults run the official image as UID/GID `1001`, drop all capabilities,
disable privilege escalation and API token mounting, enable `RuntimeDefault`
seccomp, and make the root filesystem read-only. `/tmp` is the only chart-owned
writable application path. A NetworkPolicy permits inbound traffic only to the
named HTTP listener.

If the cluster CNI does not enforce NetworkPolicy, the object has no traffic
effect. Egress remains unrestricted for payment providers, email, webhooks, and
external databases. Use an existing Secret for database credentials and keep
the release at a patched upstream version.

### Security Scan: `alfio`

| Framework | Score |
| --- | --- |
| MITRE + NSA + SOC2 | **78.79%** |

> Security posture includes non-root execution, a read-only root filesystem,
> disabled token mounting, default ingress isolation, and operator-owned TLS,
> database, identity, and egress controls.

## Architecture

One single-replica Deployment serves the web application and API through a
ClusterIP Service and optional Ingress. A database wait init container gates
startup. PostgreSQL owns all durable state; the application pod and its `/tmp`
volume are disposable. See the architecture guide for ownership boundaries and
request flow.

## Database and Operations

The bundled database is appropriate for evaluation and small installations
that accept release-owned database lifecycle. Production platforms should
normally use external PostgreSQL with platform backup, restore testing,
replication, and maintenance processes.

- [Architecture](docs/architecture.md)
- [Database configuration](docs/database.md)
- [Security](docs/security.md)
- [Operations](docs/operations.md)
- [Simple example](examples/simple.yaml)
- [External PostgreSQL example](examples/external-postgresql.yaml)

## Key Values

| Key | Default | Description |
| --- | --- | --- |
| `alfio.containerPort` | `8080` | Port used by the Spring Boot process |
| `alfio.baseUrl` | `""` | Public URL used by attendees and administrators |
| `alfio.profiles` | `"jdbc-session"` | Additional Spring profiles |
| `service.port` | `80` | Kubernetes Service port |
| `networkPolicy.enabled` | `true` | Restrict inbound traffic to HTTP |
| `serviceAccount.automountServiceAccountToken` | `false` | Mount a Kubernetes API token |
| `postgresql.enabled` | `true` | Deploy the PostgreSQL subchart |
| `ingress.enabled` | `false` | Create an Ingress |

## Troubleshooting

```bash
kubectl get pods -l app.kubernetes.io/instance=alfio
kubectl logs deployment/alfio-alfio --all-containers --tail=200
kubectl get endpointslices -l kubernetes.io/service-name=alfio-alfio
kubectl get networkpolicy alfio-alfio -o yaml
```

If startup remains blocked, validate PostgreSQL DNS, port, credentials, and
network reachability. If probes fail after a listener override, confirm that
`SERVER_PORT`, the named container port, and the Service target are aligned in
the rendered Deployment.

## Limitations

- The application is deliberately single-replica.
- The chart does not manage application-level backups, SMTP, payments, WAF, or
  certificate issuers.
- Operators must test PostgreSQL restores and size resources for sale traffic.

## More Information

- [alf.io documentation](https://alf.io/docs)
- [alf.io releases](https://github.com/alfio-event/alf.io/releases)
- [Chart source](https://github.com/helmforgedev/charts/tree/main/charts/alfio)
