# Memos Chart Design

This chart deploys Memos as a stateful web application using the official `docker.io/neosmemo/memos:0.30.0` image.

## Product Model

Memos is not a stateless frontend. It serves the UI and API from one process and stores durable data through a database
plus a local data directory. In the default upstream Docker workflow, the data directory is `/var/opt/memos`. For SQLite
this includes the database file, and for external databases it can still include local assets and instance data.

The chart therefore uses a StatefulSet instead of a Deployment. The identity is stable, the PersistentVolumeClaim is
owned by the workload, and upgrades keep the same data directory.

## Default Topology

Defaults target a production-style single instance:

- `replicaCount: 1`
- `database.driver: sqlite`
- `persistence.enabled: true`
- `MEMOS_DATA=/var/opt/memos`
- non-root UID/GID `10001`
- ServiceAccount token automount disabled
- read-only image filesystem with an explicit temporary volume
- protected loopback administrator setup before public exposure
- generated closed-registration GENERAL policy with an explicit adoption opt-out
- default ingress and egress isolation

This matches the upstream runtime model and avoids implying that SQLite can be shared safely by multiple pods.

## External Database Mode

Memos supports `sqlite`, `mysql`, and `postgres` through `MEMOS_DRIVER` and `MEMOS_DSN`. The chart models this as:

- `database.driver`
- `database.dsn`
- `database.existingSecret`
- `database.existingSecretKey`

Inline DSNs render into a chart-managed Secret. Existing Secrets are preferred for GitOps and production because they
keep database credentials out of Helm values.

Bundled PostgreSQL and MySQL use maintained HelmForge dependencies. External component mode supplies endpoint metadata
separately from the password Secret. A pinned official Node helper builds the native DSN in a memory volume, including
correct PostgreSQL URI encoding or MySQL Go-DSN syntax, and waits for TCP availability. The native application then
authenticates and runs its migrations. External component defaults verify TLS certificates and hostnames.

The chart intentionally still requires a data volume with MySQL/PostgreSQL. External database mode moves relational
state, but the upstream documentation calls out that local assets and instance data remain tied to the data directory.

## Scaling

The chart blocks `replicaCount > 1` with SQLite. Multiple pods can only be rendered when `database.driver` is `mysql` or
`postgres`. Even then, the chart requires `persistence.existingClaim` so all replicas mount the same `MEMOS_DATA`
storage. Generated StatefulSet PVCs are per-pod and are not valid for scaled Memos because uploads or local instance
data can diverge by ordinal.

PDB support is available but disabled by default because a single replica with SQLite cannot tolerate voluntary
disruption without downtime.

## Exposure

The chart supports:

- ClusterIP/NodePort/LoadBalancer Service
- Kubernetes Ingress with `ingressClassName`
- Gateway API HTTPRoute
- dual-stack Service fields

`memos.instanceUrl` maps to `MEMOS_INSTANCE_URL`. An empty value selects private mode; a nonempty value also permits
anonymous public-content access and RSS. It is never inferred from Ingress or Gateway hostnames.

## Deployment Configuration

`provisioning.existingSecret` mounts one Kubernetes Secret at `/etc/secrets`, the fixed upstream scan path. Secret keys
become Memos provisioning filenames, which lets operators provide OAuth2 identity providers and supported
instance-setting groups without storing their values in the application database or Helm release values. The mount is
read-only and group-readable by the chart's non-root `fsGroup`.

The chart does not copy provisioning data into another Secret or attempt reconciliation. Memos validates the complete
file set before starting HTTP services and reloads it only on process restart.

## Security Choices

The upstream image runs as non-root UID/GID `10001`; the chart aligns its pod and container security contexts with that
identity. `readOnlyRootFilesystem` is true; the application writes to the data and temporary volumes. The protected
bootstrap copies the unchanged native binary into an emptyDir and runs it with the same identity, without root ownership
repair.

`memos.allowPrivateWebhooks` defaults to false. Enabling it can be useful for internal automation, but it expands the
outbound request surface and should be paired with network controls.

## Validation Scope

The chart has template tests for:

- runtime environment variables
- SQLite and external database contracts
- Secret creation and Secret references
- invalid scaling/database combinations
- NetworkPolicy
- PDB
- dual-stack Service fields
- Ingress TLS rendering
- valueFrom preservation
- HTTP `/healthz` probes
- deployment-configuration Secret mounting

Behavioral validation exercises SQLite and native PostgreSQL/MySQL servers, bundled dependencies, certificate-verified
external SQL, two replicas sharing data, protected bootstrap, native memo/attachment CRUD, PAT-authenticated MCP and
revocation, real OAuth2 code exchange and linking, trusted S3 storage, External Secrets and fresh-PVC SQLite recovery.
The scaled local fixture proves shared-state behavior on one node; production multi-node placement still requires an
appropriate shared storage backend and independently resilient database topology.
