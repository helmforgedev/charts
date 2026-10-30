# Countly Chart Design

## Scope

This chart deploys the official combined Countly server image and either the
HelmForge MongoDB dependency or a user-managed MongoDB endpoint. It owns the
application Deployment, Service, optional HTTP exposure, credential references,
NetworkPolicy, and optional MongoDB-to-S3 backup CronJob.

## Architecture

One Countly pod runs the upstream API and dashboard processes. The API listener
receives SDK events on `countly.apiPort`; the dashboard listener serves the web
application on `countly.dashboardPort`. The Service publishes those listeners
as `service.apiPort` and `service.port` through named targets. All durable
application state is stored in MongoDB.

The bundled database is intended for straightforward installations. Production
operators can disable it and provide one MongoDB URI directly, through an
existing Secret, or through External Secrets.

## Design Choices

- The official combined image is retained instead of rebuilding Countly.
- Listener overrides are passed to Countly's native
  `COUNTLY_CONFIG_API_API_PORT` and
  `COUNTLY_CONFIG_FRONTEND_WEB_PORT` variables.
- The dashboard is the default Ingress and HTTPRoute backend. The ingestion API
  remains a second Service port so operators can expose it under a deliberate
  network boundary.
- The backup is a two-container pipeline: `mongodump` writes a temporary
  archive and the uploader transfers it to S3-compatible storage.
- `mongodumpArgs` is an array and is passed as arguments, not evaluated as shell
  source.

## Production Boundary

The chart does not create a MongoDB replica set, external load balancer, TLS
certificate, object-store bucket policy, or disaster-recovery schedule.
Operators own MongoDB topology, storage classes, public exposure, DNS, TLS,
capacity planning, retention, and restore drills. The backup work directory is
ephemeral; a node failure during a run requires the job to retry from the
beginning.

## Security Boundary

Service-account tokens are disabled by default. Init and backup containers run
non-root with read-only root filesystems, dropped capabilities, and
`RuntimeDefault` seccomp. A NetworkPolicy is created by default.

The upstream `countly/countly-server:25.05.4` combined image is an explicit
exception: its `/sbin/my_init` supervisor starts as root and then uses
`setuser countly` for the Node.js API and dashboard processes. Therefore the
main container cannot safely use `runAsNonRoot` or a read-only root filesystem
without replacing the upstream entrypoint. Privilege escalation is disabled
and the pod uses `RuntimeDefault` seccomp. Review this exception when upgrading
the upstream image.

The default NetworkPolicy preserves plugin compatibility by allowing egress and
cluster ingress to the two Countly listeners. Production users should replace
`networkPolicy.ingressFrom` and `networkPolicy.egress` with environment-specific
peers for MongoDB, DNS, mail, webhooks, push providers, and other enabled
plugins.

## Observability Boundary

Kubernetes startup, readiness, and liveness probes verify the dashboard socket.
The runtime gate verifies both dashboard and ingestion listeners through the
Service. Countly application metrics, logs, alert rules, and MongoDB monitoring
remain operator responsibilities; use `countly.extraEnv` and the platform log
pipeline for upstream-supported integrations.

## Known Gaps

- The official combined image is amd64-only for this pinned release.
- The chart does not provision a highly available MongoDB topology.
- Backups cover MongoDB data only and require an independent restore drill.
- NetworkPolicy cannot infer every destination required by optional Countly
  plugins, so its default egress is intentionally open.
- The default Ingress and HTTPRoute expose only the dashboard listener.

## Non-Goals

- Building or patching Countly images.
- Installing commercial Countly plugins or licenses.
- Managing SDK configuration in client applications.
- Provisioning MongoDB users, S3 IAM policies, DNS, or TLS issuers.
- Claiming high availability from a single Countly Deployment.

## References

- [Countly server](https://github.com/Countly/countly-server)
- [Configuration guide](docs/configuration.md)
- [Operations guide](docs/operations.md)
- [Security guide](docs/security.md)
- [Backup and restore guide](docs/backup-and-restore.md)
