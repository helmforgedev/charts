# Heimdall Chart Design

## Scope

This chart deploys one Heimdall application dashboard backed by its native
SQLite database and `/config` filesystem. It owns the Deployment, Service,
optional Ingress, persistent volume, ingress NetworkPolicy, and optional S3
backup CronJob needed for a production-oriented single-instance installation.

## Architecture

The Deployment runs the pinned official `docker.io/linuxserver/heimdall` image.
LinuxServer's `/init` process starts NGINX and PHP-FPM, while `PUID`, `PGID`, and
`TZ` control file ownership and timezone behavior. A named `http` container port
connects the application listener to the Service, probes, NetworkPolicy, and
Ingress.

Heimdall stores its SQLite database, settings, and uploaded assets in `/config`.
Persistence therefore uses a single PVC and the Deployment switches to a
`Recreate` strategy when that PVC is enabled. The optional backup CronJob reads
the same PVC, creates a compressed archive, and uploads it to an S3-compatible
endpoint.

## Design Choices

- `heimdall.containerPort` changes the actual NGINX plain-HTTP listener. The
  wrapper patches both the image default and an existing `/config` site file
  before handing control to `/init`.
- `service.port` remains an independent cluster-facing port and targets the
  named `http` port.
- The workload is fixed at one replica because Heimdall uses SQLite and does not
  provide a supported multi-writer storage model.
- The chart defaults to persistent storage and uses `Recreate` to prevent two
  pods from writing to one `ReadWriteOnce` volume during an update.
- S3 credentials may come from an existing Secret. Inline credentials exist for
  disposable tests and are not the production path.

## Production Boundary

The chart provides the Kubernetes workload, persistence contract, network
entry points, probes, and backup mechanism. Operators remain responsible for
the StorageClass, Ingress controller, TLS certificate lifecycle, S3 lifecycle
and retention policies, restoring and testing backups, capacity planning, and
availability of the Kubernetes cluster.

Heimdall is intentionally single-replica. The chart does not claim horizontal
availability or zero-downtime upgrades. Enhanced application tiles contact
their configured upstream services from the Heimdall pod; their credentials,
availability, and authorization remain operator responsibilities.

## Security Boundary

The main container starts as root because the LinuxServer `/init` contract must
prepare `/config` and then apply `PUID`/`PGID`. The chart documents this
exception and still disables privilege escalation, drops all capabilities, adds
back only the capabilities needed by the init sequence and privileged HTTP
binding, and applies `RuntimeDefault` seccomp. A read-only root filesystem is
not enabled because s6-overlay and the upstream image write outside `/config`
during initialization.

ServiceAccount token automount is disabled by default. The NetworkPolicy
isolates ingress to the named HTTP port for the server pod. It deliberately does
not isolate egress because enhanced tiles need to call operator-selected URLs;
deployments with a known destination set should add an egress policy outside
the chart. Backup containers use read-only root filesystems, no token, and all
capabilities dropped. The archive init container runs as root so it can read
root-owned TLS material under `/config`; it receives only `DAC_READ_SEARCH`,
the PVC is mounted read-only, and privilege escalation remains disabled. The
uploader remains non-root.

## Observability Boundary

Startup, readiness, and liveness probes verify the root HTTP route. Kubernetes
events, rollout state, pod restart counts, and container logs are the supported
operational signals. Heimdall does not expose a native Prometheus metrics
endpoint, and this chart does not install an exporter or monitoring stack.

## Known Gaps

- There is no supported multi-replica or autoscaling mode.
- Backup archives are created while Heimdall is online; operators requiring a
  transactional snapshot should stop writers or validate restores against their
  workload pattern.
- Default egress remains unrestricted for enhanced application tiles.
- The chart exposes upstream HTTP only; TLS terminates at an Ingress or another
  external proxy.

## Non-Goals

- Managing applications linked from the dashboard.
- Backing up services referenced by Heimdall tiles.
- Provisioning DNS, certificates, S3 buckets, or storage infrastructure.
- Adding an external database or unsupported Heimdall clustering layer.
- Replacing cluster-level monitoring, policy enforcement, or disaster recovery.

## Validation

Unit tests cover every rendered resource, listener overrides, identity labels,
security defaults, validation failures, persistence, ingress, and backup. CI
scenarios cover default, ephemeral, ingress, backup, and non-default listener
configurations. `scripts/runtime-smoke.mjs` proves the effective image and NGINX
listener, Service routing, application response, and `/config` writability in
k3d. The required complete gate is `make validate-chart CHART=heimdall`.
