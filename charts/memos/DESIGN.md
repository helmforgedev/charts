# Memos Chart Design

This chart deploys Memos as a stateful web application using the official `docker.io/neosmemo/memos:0.29.1` image.

## Product Model

Memos is not a stateless frontend.
It serves the UI and API from one process and stores durable data through a database plus a local data directory.
In the default upstream Docker workflow, the data directory is `/var/opt/memos`.
For SQLite this includes the database file, and for external databases it can still include local assets and instance data.

The chart therefore uses a StatefulSet instead of a Deployment. The identity is stable, the PersistentVolumeClaim is owned by the workload, and upgrades keep the same data directory.

## Default Topology

Defaults target a production-style single instance:

- `replicaCount: 1`
- `database.driver: sqlite`
- `persistence.enabled: true`
- `MEMOS_DATA=/var/opt/memos`
- non-root UID/GID `10001`
- ServiceAccount token automount disabled

This matches the upstream runtime model and avoids implying that SQLite can be shared safely by multiple pods.

## External Database Mode

Memos supports `sqlite`, `mysql`, and `postgres` through `MEMOS_DRIVER` and `MEMOS_DSN`. The chart models this as:

- `database.driver`
- `database.dsn`
- `database.existingSecret`
- `database.existingSecretKey`

Inline DSNs render into a chart-managed Secret. Existing Secrets are preferred for GitOps and production because they keep database credentials out of Helm values.

The chart intentionally still requires a data volume with MySQL/PostgreSQL.
External database mode moves relational state, but the upstream documentation calls out that local assets and instance data remain tied
to the data directory.

## Scaling

The chart blocks `replicaCount > 1` with SQLite.
Multiple pods can only be rendered when `database.driver` is `mysql` or `postgres`.
Even then, operators should verify asset storage and application behavior for their use case before treating the deployment as fully
horizontally scalable.

PDB support is available but disabled by default because a single replica with SQLite cannot tolerate voluntary disruption without downtime.

## Exposure

The chart supports:

- ClusterIP/NodePort/LoadBalancer Service
- Kubernetes Ingress with `ingressClassName`
- Gateway API HTTPRoute
- dual-stack Service fields

`memos.instanceUrl` maps to `MEMOS_INSTANCE_URL` and should be set for any reverse-proxied deployment so generated URLs match the public endpoint.

## Security Choices

The upstream image runs as non-root UID/GID `10001`; the chart aligns its pod and container security contexts with that identity.
`readOnlyRootFilesystem` remains false because the application writes to its mounted data directory and upstream entrypoint behavior can adjust
mounted-volume ownership.

`memos.allowPrivateWebhooks` defaults to false. Enabling it can be useful for internal automation, but it expands the outbound request surface and should be paired with network controls.

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

Behavioral validation uses the default SQLite topology because it can run in an isolated k3d cluster without a fake external database dependency.
