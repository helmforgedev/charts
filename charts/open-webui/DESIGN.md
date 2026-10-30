<!-- SPDX-License-Identifier: Apache-2.0 -->
# Open WebUI chart design

## Scope

This chart deploys one Open WebUI web application and the Kubernetes resources
needed to expose and persist it. It can use SQLite for a small installation,
the bundled PostgreSQL and Redis charts, or operator-managed PostgreSQL and
Redis services. Ollama and OpenAI-compatible model endpoints remain external.

The chart also provides an optional PostgreSQL-to-S3 backup CronJob. It does not
deploy language models, object storage, an ingress controller, a certificate
issuer, or a monitoring stack.

## Architecture

The application Deployment exposes the named `http` port. A Service selects
only pods labeled with `app.kubernetes.io/component: web`; backup Job pods use a
different component label and therefore never become Service endpoints. The
default NetworkPolicy allows inbound traffic only to the named HTTP port while
leaving egress open for model APIs, identity providers, package hubs, and other
operator-selected integrations.

The runtime data directory, `/app/backend/data`, uses a PVC by default. The
Deployment uses `Recreate` so an upgrade cannot temporarily run two Open WebUI
processes against the same SQLite database or `ReadWriteOnce` volume.

When `postgresql.enabled=true`, an init container waits for the bundled database
and the application constructs `DATABASE_URL` from Secret-backed credentials.
When `redis.enabled=true`, both `REDIS_URL` and `WEBSOCKET_REDIS_URL` target the
Redis client Service and obtain the password from the subchart Secret.

## Design choices and trade-offs

### Single application replica

The chart intentionally renders one application replica. Current Open WebUI
guidance requires PostgreSQL, Redis, shared or object-backed file storage,
coordinated database migrations, and other tuning for multi-node operation.
Exposing only `replicaCount` would imply a safe capability the chart does not
yet orchestrate. Operators needing horizontal scale should manage those
requirements explicitly and track a future chart enhancement.

### SQLite remains the zero-configuration default

SQLite provides a useful evaluation path, but it is only suitable on directly
attached local storage and for one process. Network-backed PVCs can suffer lock
failures or corruption. PostgreSQL is the documented production choice.

### Recreate upgrades

`Recreate` introduces brief downtime. The alternative, a rolling update, can
start incompatible application versions or concurrent migrations against the
same database and storage. Data safety takes precedence over zero-downtime
updates for the supported single-replica architecture.

### Open egress with isolated ingress

Open WebUI is an integration hub whose destinations cannot be predicted by the
chart. A default-deny egress policy would break configured model backends and
identity providers. Operators can replace `networkPolicy.egress` with a
workload-specific allowlist.

### Secret-backed connection strings

Inline database and Redis URLs are accepted for compatibility, but the chart
places them into generated Secrets instead of rendering them directly in the
Deployment. Existing Secrets are preferred because Helm release values can
still expose inline credentials to users who can read release metadata.

## Data and persistence

The data PVC stores the SQLite database, uploads, and cached embedding assets.
An existing claim can be supplied for lifecycle control outside Helm. The chart
does not delete retained application Secrets during uninstall.

The backup CronJob supports PostgreSQL only. Bundled PostgreSQL credentials are
discovered through the subchart contract. For an external database, backup
connection fields and a password Secret are intentionally explicit because a
complete `DATABASE_URL` Secret cannot be safely parsed by Helm templates.

Backup archives are streamed through a shared `emptyDir` from `pg_dump` to the
pinned HelmForge MinIO client image. Backup retention, encryption, lifecycle,
restore validation, and disaster-recovery replication belong to the target
object-storage policy.

## Production boundary

A production installation should use PostgreSQL, define resource requests and
limits from measured load, configure TLS at the ingress, use existing Secrets,
back up the database, and test restore procedures. The bundled database is a
convenience and not a managed database service.

The chart does not promise highly available Open WebUI. It also does not verify
the availability, capacity, latency, or data-handling policy of external model
providers. Those systems remain part of the operator's production design.

## Security boundary

The default pod and container contexts enable `RuntimeDefault` seccomp, disable
privilege escalation, and drop all Linux capabilities. Kubernetes API tokens
are not mounted. A dedicated ServiceAccount and ingress-isolating NetworkPolicy
are created by default.

The official Open WebUI image declares UID 0 and uses writable application and
home paths, so `runAsNonRoot` and `readOnlyRootFilesystem` are not enabled by
default. Operators may override the contexts only after validating a compatible
image and writable-volume layout. This exception is explicit rather than
claiming a control the upstream image cannot reliably satisfy.

The NetworkPolicy does not make external traffic trustworthy. TLS validation,
provider credentials, identity-provider policy, prompt/data governance, and
model endpoint authorization remain operator responsibilities.

## Observability boundary

Startup and liveness checks use `/health`; readiness uses `/health/db` so a pod
is removed from Service endpoints when its database is unavailable. Kubernetes
events, pod logs, probe status, CronJob status, and Service endpoints are the
built-in operational signals.

The chart does not deploy a metrics exporter, ServiceMonitor, log collector, or
alert rules because Open WebUI does not expose a stable chart-owned Prometheus
contract. Operators should integrate their platform observability stack and
avoid collecting prompts, API keys, or conversation content in logs.

## Known gaps and limitations

- Horizontal scaling is not automated.
- SQLite on network filesystems is unsupported upstream.
- The S3 backup covers PostgreSQL, not uploaded files or embedding caches.
- Restore is deliberately operator-driven and must be tested separately.
- Egress is open unless the operator supplies restrictive rules.
- The official image prevents secure non-root and read-only-root defaults.
- Metrics and alerts are outside the current chart contract.

## Non-goals

- Deploying Ollama, GPUs, models, or an OpenAI-compatible inference server.
- Managing PostgreSQL or Redis beyond their optional HelmForge subcharts.
- Provisioning buckets, ingress controllers, DNS, certificates, or identity
  providers.
- Compiling plugins, functions, or image extensions at pod startup.
- Claiming multi-replica safety without shared storage and migration control.

## References

- [Open WebUI](https://openwebui.com/)
- [Open WebUI documentation](https://docs.openwebui.com/)
- [Configuration guide](docs/configuration.md)
- [Operations guide](docs/operations.md)
- [Security guide](docs/security.md)
