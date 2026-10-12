# OpenReplay chart design

## Goals

- Deploy the complete OpenReplay OSS application topology.
- Remove the bundled ingress-controller requirement.
- Make data services and credentials independently replaceable.
- Keep component images reproducible with tag plus digest pins.
- Expose operational limits instead of claiming unverified high availability.

## Architecture

Clients reach one Caddy router Service through a conventional Ingress,
Gateway API HTTPRoute, LoadBalancer, or port-forward. Caddy performs the
OpenReplay-specific path routing and forwards to internal component Services.
Workers share an RWX scratch claim. PostgreSQL stores metadata, ClickHouse
stores analytics, Valkey coordinates transient state, and RustFS or an external
S3 service stores recordings and assets.

## Dependency modes

Bundled PostgreSQL, Redis, and ClickHouse use HelmForge subcharts and are
conditions in `Chart.yaml`. Bundled RustFS is rendered directly because no
HelmForge RustFS chart exists. Operators can disable any bundled dependency and
provide its endpoint. Credential lookup is unified through the application
Secret contract.

## Routing

The router handles `/`, `/v2/api`, `/ingest`, `/ws-assist`, `/spot`, recording
object paths, and `/script`. Ingress and HTTPRoute both target this single
Service, so controller-specific rewrite annotations are unnecessary. TLS is
terminated at the operator-owned Ingress controller or Gateway listener.

## Security

Service account token mounting is disabled. Pods run non-root where their
official images permit it, drop all capabilities, use the RuntimeDefault
seccomp profile, and receive read-only root filesystems when compatible.
Secrets may be generated, supplied by an existing Secret, or reconciled by
External Secrets Operator. NetworkPolicy is optional because egress endpoints
are environment-specific; complete extra egress rules are supported.

## Availability limits

Application services can be scaled independently, but bundled data services
are singleton defaults and do not make a highly available installation. The
assist service defaults to one replica because portable Gateway API does not
provide upstream's `peerId`-derived affinity. Production HA requires external
HA data services, tested RWX storage, and controller-specific load-balancing
policy where session affinity is required.

## Validation profile

The default production topology is fully rendered and unit tested. The k3d
behavioral profile runs the real pinned frontend plus router, with migrations
and data-plane workers disabled, proving image pull, readiness, routing, HTTP
response, logs, events, upgrade, and cleanup without requiring an 8 GiB CI
node. This exception is explicit and does not redefine the production default.
