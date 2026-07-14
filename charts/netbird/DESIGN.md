# NetBird chart design

## Architecture

NetBird now documents a combined self-hosted deployment for new installs. The chart follows that model instead of the legacy split `management`, `signal`, `relay`, and `coturn` layout.

The chart renders two Deployments:

- `server`: `netbirdio/netbird-server`, configured through `/etc/netbird/config.yaml`
- `dashboard`: `netbirdio/dashboard`, configured to talk to the public server URL

The server exposes HTTP, UDP STUN, metrics, and health ports. The dashboard exposes HTTP only.

## Configuration

The default mode renders a Kubernetes Secret containing `config.yaml` from chart values.
This keeps the chart easy to install while keeping sensitive data out of ConfigMaps.
Production users can set `server.config.existingSecret` to mount a complete upstream
configuration file instead.

The rendered config disables embedded TLS because Kubernetes deployments normally terminate TLS at an Ingress, Gateway, load balancer, or external reverse proxy.

## Storage and scaling

The default store engine is `sqlite`, stored under `/var/lib/netbird`.
With sqlite, `server.replicaCount` must remain `1` because concurrent writers are unsafe.
The validation helper blocks sqlite scale-out.

For high availability, use the default PostgreSQL subchart for self-contained
installs or configure an external `postgres` or `mysql` database through
`database.external`. PostgreSQL is the only bundled database dependency in v1
because upstream documents it as the recommended production store. MySQL remains
available as an external store for organizations standardized on it.

SQLite is still supported, but only for single-replica lab or small installs.
Set `database.mode=sqlite` and `postgresql.enabled=false` explicitly.

## Exposure

The chart provides:

- a server Service with TCP HTTP/gRPC, metrics, health, and UDP STUN ports
- a dashboard Service
- Ingress routing that can target `dashboard` or `server` per path
- Gateway API HTTPRoute routing that can target `dashboard` or `server`

UDP `3478` is intentionally modeled as a Service port because Ingress does not handle UDP.
Clusters should expose it through a LoadBalancer, Gateway implementation, or
infrastructure-specific UDP listener.

## Security posture

The server container defaults to non-root execution, dropped Linux capabilities, disabled
ServiceAccount token mounting, optional NetworkPolicy, and Secret-backed configuration.
The dashboard image uses upstream `supervisord` and nginx, which start as root, adjust
runtime directory ownership, set worker user and group, and drop privileges internally.
The chart therefore keeps a dashboard-specific securityContext with only `CHOWN`,
`SETGID`, and `SETUID` added back plus writable emptyDir mounts for nginx runtime paths.
