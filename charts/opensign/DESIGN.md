# OpenSign chart design

## Goals

- Package the official OpenSign frontend and backend without rebuilding them.
- Render only immutable image references despite upstream's floating channels.
- Provide secure defaults that run under Kubernetes restricted pod security.
- Use maintained HelmForge dependencies for stateful services.
- Make local PVC and external S3 deployments explicit and recoverable.
- Validate real application behavior on local k3d.

## Workload split

The frontend and backend are separate Deployments and Services. This mirrors
the upstream Docker topology and allows independent frontend scaling. The
frontend is stateless after its build directory is copied to a writable
`emptyDir`; the backend owns MongoDB access, migrations, email, signing, and
document storage.

The frontend starts with two replicas, rolling updates, a PodDisruptionBudget,
and optional autoscaling. The backend uses one replica and `Recreate` because
upstream migrations execute during process startup. Increasing backend replicas
would create an unsupported migration and local-storage concurrency model.

## Filesystem and identity

Both official containers run as UID/GID 1000 with a read-only root filesystem,
all Linux capabilities dropped, and the default seccomp profile. Init
containers copy image-owned mutable content into bounded writable volumes
before the application starts. The backend application tree uses copy-up so
upstream PFX and export operations can write temporary files without making the
container root filesystem writable.

The generated Secret uses Helm `lookup` to retain the Parse master key across
upgrades and has the Helm keep policy. Existing Secret and External Secrets
paths are first-class for GitOps and disaster recovery.

## Data services

The default database is HelmForge MongoDB 1.8.6 with authentication enabled.
The external MongoDB path accepts either a Secret key or a URI. The chart never
deploys both modes simultaneously.

Local documents use a retained PVC. S3 mode requires a bucket, endpoint, public
base URL, region, and credentials. MongoDB and document storage must be backed
up consistently because metadata and files form one logical transaction set.

## Networking

The React frontend and Parse API receive distinct Ingresses or HTTPRoutes.
Separate hosts avoid controller-specific path rewriting and keep the browser's
API URL unambiguous. Ingress and Gateway API are mutually exclusive.

NetworkPolicy isolates frontend and backend pods, allows DNS and required
service paths, and exposes extension points for private infrastructure. Public
egress is limited to HTTP/HTTPS and configured SMTP; operators must declare
private peers through complete `extraEgress` rules.

## Validation

Unit tests cover workload structure, immutable images, storage, secrets,
External Secrets, routing, dual-stack Services, HPA/PDB behavior, and validation
errors. The k3d smoke performs HTTP checks against both components, inspects
runtime identity, confirms retained identity, and rejects restarts, crash logs,
or unexplained critical events.

The chart is complete only after `make validate-chart CHART=opensign`, template
standards, dependency policy, attribution, documentation lint, site sync, and
the linked site tests all pass.
